---
layout: docs
title:  "Probes"
section: "chisel3"
---

# 探测器

_探测器_ 是一种编码硬件 _引用_ 的方式，这个引用后续将通过名称被引用。从机制上讲，探测器是一种生成包含层次名称的 SystemVerilog 的方法（参见：SystemVerilog 2023 规范的第 23.6 节）。

探测器通常用于为一个单元暴露"验证接口"，以便进行调试、测试或检查，而无需向最终硬件添加端口。当与[层](layers)结合使用时，它们可以根据 Verilog 编译时的决定选择性地存在于设计中。

:::warning

探测器 _不是_ 影子数据流。它们 _不是_ 一种在避免使用端口的情况下连接任意硬件的机制。它们更接近于传统编程语言中的"引用"，只是它们有额外的限制。具体来说，探测器最终会通过名称被访问，而且该名称必须在其访问位置处明确地解析到被探测的值。

:::

## 概述

基于用户想要对硬件进行的访问类型，有两种探测器。_只读探测器_ 允许对硬件进行只读访问。_读写探测器_ 允许对硬件进行读写访问。

只读探测器通常用于被动验证（例如，断言或监视器）或调试（例如，构建微架构的架构调试"视图"）。读写探测器通常用于更主动的验证（例如，注入故障以测试故障恢复机制，或作为覆盖难以达到的覆盖率的一种方式）。

处理探测器的 API 位于 `chisel3.probe` 包中。

### 只读探测器

要创建硬件值的只读探测器，使用 `ProbeValue` API。要创建只读探测器 _类型_，使用 `Probe` API。探测器是端口和线的合法类型，但不是状态元素（例如，寄存器或内存）的合法类型。

:::note

探测器作为线的合法类型可能会令人惊讶。然而，Chisel 中的线的行为更像变量，而不是"硬件线"（或 Verilog 的网类型）。从这个角度来看，探测器（一个引用）可以通过变量传递是很自然的。

:::

探测器与普通的 Chisel 硬件类型不同。普通的 Chisel 硬件可以通过所谓的"最后连接语义"多次连接，最后一次连接"胜出"，而探测器类型只能被 _定义_ 一次。定义探测器的 API 不出所料地称为 `define`。这用于通过层次结构"转发"探测器，例如，用被探测值的线来定义探测器端口。

为了方便起见，你也可以使用标准的 Chisel 连接操作符，它们会自动为你隐式使用 `define` 操作符。

要读取探测器类型的值，使用 `read` API。

下面的示例展示了使用之前介绍的所有 API 的电路。同时展示了 `define` 和标准 Chisel 连接操作符的使用。仔细使用 `dontTouch` 来防止跨探测器进行优化，以使输出不会变得过于简单。

```scala mdoc:silent
import chisel3._
import chisel3.probe.{Probe, ProbeValue, define, read}

class Bar extends RawModule {
  val a_port = IO(Probe(Bool()))
  val b_port = IO(Output(Probe(Bool())))
  val a_probe = ProbeValue(Wire(Bool()))
  val b_probe = ProbeValue(RegInit(false.B))
  
  define(a_port, a_probe)
  b_port :<= b_probe // 与 define(b_port, b_probe) 相同
}

class Foo extends RawModule {
  val bar = Module(new Bar)

  private val a_read = dontTouch(WireInit(read(bar.a_port)))
  private val b_read = dontTouch(WireInit(read(bar.b_port)))
}
```

上述电路的 SystemVerilog 如下所示：

```scala mdoc:verilog
circt.stage.ChiselStage.emitSystemVerilog(
  new Foo,
  Array("--lower-memories")
)
```

上述 SystemVerilog 中有几点值得注意：

1. 线 `a_read` 和 `b_read` 是由指向模块 `Bar` 内部的 _层次名称_ 驱动的。模块 `Bar` 上 _没有_ 创建端口。这样做的目的是通过避免端口和连线来减少面积和延迟。然而，这不利地影响了生成的 SystemVerilog 的可理解性。

2. 通过探测器实现可观测性是有代价的。虽然上面的电路在其简单性上是有些人为的，但如果硬件被探测，这可能会限制将硬件优化为更简单实现的能力。只读探测器对优化和更改硬件调度的限制比读写探测器要少。然而，它们仍然有影响。

### 读写探测器

要创建硬件值的读写探测器，使用 `RWProbeValue` API。要创建读写探测器 _类型_，使用 `RWProbe` API。与只读探测器一样，读写探测器是端口和线的合法类型，但不是状态元素（例如，寄存器或内存）的合法类型。

与只读探测器一样，读写探测器使用 `define` API 或标准的 Chisel 连接操作符进行转发。

读写探测器可以使用与只读探测器相同的 `read` API 进行读取。提供了多个不同的操作来写入读写探测器。`force` 和 `forceInitial` API 用于覆写读写探测器硬件的值。`release` 和 `releaseInitial` API 用于停止覆写读写探测器硬件的值。

:::note

所有对读写探测器的写入都是通过会转换成 SystemVerilog `force`/`release` 语句的 API 完成的（参见：SystemVerilog 2023 规范的第 10.6 节）。故意不允许使用普通的 Chisel 连接来写入读写探测器。换句话说，读写探测器 _不_ 参与最后连接语义。

:::

下面的示例展示了使用之前介绍的所有 API 的电路。同时展示了 `define` 和标准 Chisel 连接操作符的使用。仔细使用 `dontTouch` 来防止跨探测器进行优化，以使输出不会变得过于简单。

```scala mdoc:reset:silent
import chisel3._
import chisel3.probe.{RWProbe, RWProbeValue, force, forceInitial, read, release, releaseInitial}

class Bar extends RawModule {
  val a_port = IO(RWProbe(Bool()))
  val b_port = IO(RWProbe(UInt(8.W)))

  private val a = WireInit(Bool(), true.B)
  a_port :<= RWProbeValue(a)

  private val b = WireInit(UInt(8.W), 0.U)
  b_port :<= RWProbeValue(b)
}

class Foo extends Module {
  val cond = IO(Input(Bool()))

  private val bar = Module(new Bar)

  // Example usage of forceInitial/releaseInitial:
  forceInitial(bar.a_port, false.B)
  releaseInitial(bar.a_port)

  // Example usage of force/release:
  when (cond) {
    force(bar.b_port, 42.U)
  }.otherwise {
    release(bar.b_port)
  }

  // The read API may still be used:
  private val a_read = dontTouch(WireInit(read(bar.a_port)))
}
```

上述电路的 SystemVerilog 如下所示：

```scala mdoc:verilog
circt.stage.ChiselStage.emitSystemVerilog(
  new Foo,
  Array("--throw-on-first-error"),
  firtoolOpts = Array(
    "-strip-debug-info",
    "-disable-all-randomization",
    "-enable-layers=Verification",
    "-enable-layers=Verification.Assert",
    "-enable-layers=Verification.Assume",
    "-enable-layers=Verification.Cover"
  )
)
```

在上述 SystemVerilog 中，有几点值得评论：

1. 可写性是非常具有侵入性的。为了编译一个写探测器，必须阻止其目标上的所有优化，并且无法进行任何"穿透"目标的优化。这是因为对读写探测器的任何写入都必须影响下游用户。

2. 写入读写探测器的 API（例如，`force`）是非常底层的，并且与 SystemVerilog 紧密耦合。在使用这些 API 和验证生成的 SystemVerilog 是否符合预期时，请格外小心。

:::warning

并非所有模拟器都正确实现了 SystemVerilog 规范中描述的强制和释放！在使用读写探测器时要小心。你可能需要使用符合 SystemVerilog 的模拟器。

:::

## Verilog ABI

早期的示例仅显示探测器在电路内部的使用。然而，探测器也可以编译成 SystemVerilog，以便在电路外部使用。

考虑以下示例电路。在其中，内部寄存器的值通过只读探测器暴露。

```scala mdoc:reset:silent
import chisel3._
import chisel3.probe.{Probe, ProbeValue}

class Foo extends Module {

  val d = IO(Input(UInt(32.W)))
  val q = IO(Output(UInt(32.W)))
  val r_probe = IO(Output(Probe(UInt(32.W))))

  private val r = Reg(UInt(32.W))

  q :<= r

  r_probe :<= ProbeValue(r)
}
```

上述电路的 SystemVerilog 如下所示：

```scala mdoc:verilog
circt.stage.ChiselStage.emitSystemVerilog(
  new Foo,
  Array("--throw-on-first-error"),
  firtoolOpts = Array(
    "-strip-debug-info",
    "-disable-all-randomization",
    "-enable-layers=Verification",
    "-enable-layers=Verification.Assert",
    "-enable-layers=Verification.Assume",
    "-enable-layers=Verification.Cover"
  )
)
```

作为编译的一部分，针对每个公共模块，这将生成一个具有特定文件名的附加文件：`ref_<module-name>.sv`。在这个文件中，将为该公共模块的每个探测器端口定义一个 SystemVerilog 文本宏。该宏的名称由模块名和探测器端口名派生而来：`ref_<module-name>_<probe-name>`。

使用此 ABI，可以在其他地方实例化该模块（例如，通过 SystemVerilog 测试平台）并访问其被探测的内部。

:::info

有关探测器端口降低 ABI 的确切定义，请参见 [FIRRTL
ABI
Specification](https://github.com/chipsalliance/firrtl-spec/releases/latest/download/abi.pdf)。

:::

## 层彩色探测器

探测器允许进行层彩色处理。即，这是声明探测器的存在取决于特定层是否启用的一种机制。要声明探测器为层彩色的，`Probe` 或 `RWProbe` 类型接受一个可选参数，指示层彩色是什么。以下示例声明了两个具有不同层颜色的探测器端口：

```scala mdoc:reset:silent
import chisel3._
import chisel3.layer.{Layer, LayerConfig}
import chisel3.probe.{Probe, ProbeValue}

object A extends Layer(LayerConfig.Extract())
object B extends Layer(LayerConfig.Extract())

class Foo extends Module {
  val a = IO(Output(Probe(Bool(), A)))
  val b = IO(Output(Probe(UInt(8.W), B)))
}
```

有关层彩色探测器的更多信息，请参见[层文档的相关子部分](layers#layer-colored-probes-and-wires)。

## 为什么不允许输入探测器

不允许输入探测器（无论是只读还是读写类型）。这是一个故意的决定，源于探测器的要求以及如何将探测器编译为 SystemVerilog。

首先，探测器是引用。它们引用某处存在的硬件。它们不是硬件线。它们不是"影子"端口。它们不代表"影子"数据流。

其次，探测器总是有两个部分：实际被探测的硬件和使用引用被探测硬件的操作。使用探测器的操作必须在其特定位置能够明确地引用被探测的硬件。正如下面的示例所示，输入探测器在这方面是有问题的。

考虑以下使用假设输入探测器的非法 Chisel：

``` scala
import chisel3._
import chisel3.probe.{Probe, ProbeValue, read}

module Baz extends RawModule {
  val probe = IO(Input(Probe(Bool())))

  val b = WireInit(read(probe))
}

module Bar extends RawModule {
  val probe = IO(Input(Probe(Bool())))

  val baz = Module(new Baz)
  baz.probe :<= probe

}

module Foo extends RawModule {

  val w = Wire(Bool())

  val bar = Module(new Bar)
  bar.probe :<= ProbeValue(w)
}
```

这可以编译成以下 SystemVerilog：

``` verilog
module Baz();

  wire b = Foo.a;

endmodule

module Bar();

  Baz baz();

endmodule

module Foo();

  wire a;

  Bar bar();

endmodule
```

SystemVerilog 提供了一种解析 _向上_ 层次名称的算法（参见：SystemVerilog 2023 规范的第 23.8 节）。这通过在当前作用域中查找名称的根（`Foo`）并在失败时向上移动一个级别并尝试查找来工作。然后，这将重复，直到找到名称（或在到达电路顶部时出错）。然而，该算法对中介模块施加了严格的命名限制。例如，在上述示例中，`Foo` 这个名称不能在 `Baz` 中或在 `Baz` 和 `Foo` 之间的 _中介_ 模块中存在。这很容易与无法更改的名称发生冲突，例如公共模块或公共模块端口。

此外，任何使用解析向上层次名称的模块都限制了其自由实例化的能力。在上面的电路中，`Baz` 是单实例化的。然而，如果 `Baz` 被多次实例化，则可以给它两个不同的输入探测器。这将意味着 `Baz` 不能被编译成单个 Verilog 模块。它必须针对每个唯一的层次名称而重复。这可能会导致级联的重复效应，父模块、祖父模块等也必须被重复。这种不可预测性被用户视为不可接受。

由于这些限制（对中介模块名称的限制和为了解析层次名称而进行的重复），输入探测器的使用被认为是有问题的。尽管它们可以被编译，但结果将是不可预测的，并且当出现问题时，用户很难调试。

因此，输入探测器作为设计点被拒绝，并且不计划实现。

## BoringUtils

探测器故意是一个底层 API。例如，如果一个设计需要暴露一个探测器端口，它可能需要向其与被探测值之间的所有中介模块添加探测器端口。

有关更灵活的 API，请考虑使用 `chisel3.util.experimental.BoringUtils`。这提供了更高级的 API，自动为用户创建探测器端口：

- `rwTap`：创建信号的读写探测器并将其路由到调用位置
- `tap`：创建信号的读探测器并将其路由到调用位置
- `tapAndRead`：创建信号的读探测器，将其路由到调用位置，并读取它（从探测器转换为真实硬件）

例如，考虑最初为只读探测器显示的原始示例。这可以使用 `BoringUtils` 重写得更简洁：

```scala mdoc:reset:silent
import chisel3._
import chisel3.util.experimental.BoringUtils

class Bar extends RawModule {
  val a = dontTouch(WireInit(Bool(), true.B))
}

class Foo extends RawModule {

  private val bar = Module(new Bar)

  private val a_read = dontTouch(WireInit(BoringUtils.tapAndRead(bar.a)))
}
```

上述电路的 SystemVerilog 如下所示：

```scala mdoc:verilog
circt.stage.ChiselStage.emitSystemVerilog(
  new Foo,
  firtoolOpts = Array(
    "-strip-debug-info",
    "-disable-all-randomization",
    "-enable-layers=Verification",
    "-enable-layers=Verification.Assert",
    "-enable-layers=Verification.Assume",
    "-enable-layers=Verification.Cover"
  )
)
```

为了做到这一点，它要求被探测的目标在 Scala 的角度是公共的。

:::note

`BoringUtils` 仅适合在 _一个编译单元内_ 使用。此外，过度使用 `BoringUtils` 可能导致非常混乱的硬件生成器，其中端口级接口是不可预测的。

:::

如果在可能创建输入探测器的情况下使用 `BoringUtils` API，它将创建一个非探测器输入端口。
