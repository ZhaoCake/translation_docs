---
layout: docs
title:  "未连接的线"
section: "chisel3"
---

# 未连接的线

无效化 API [(#645)](https://github.com/freechipsproject/chisel3/pull/645) 为 Chisel 添加了将未连接的线作为错误报告的支持。

在这个 pull request 之前，Chisel 会自动为 `Module IO()` 和每个 `Wire()` 定义生成一个 firrtl `is invalid`。
这使得检测输出信号从未被驱动的情况变得困难。
Chisel 现在支持一个 `DontCare` 元素，它可以连接到输出信号，表明该信号是故意不被驱动的。
除非信号由硬件驱动或连接到 `DontCare`，否则 Firrtl 将会报错"not fully initialized"（未完全初始化）。

### API

输出信号可以连接到 DontCare，在生成相应的 firrtl 时将生成 `is invalid`。

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
```
```scala
// 原始代码块中的标记: mdoc:silent

class Out extends Bundle { 
  val debug = Bool()
  val debugOption = Bool()
}
val io = new Bundle { val out = new Out }
```

```scala
// 原始代码块中的标记: mdoc:compile-only
io.out.debug := true.B
io.out.debugOption := DontCare
```

这表明信号 `io.out.debugOption` 是故意不被驱动的，firrtl 不应该为这个信号发出"not fully initialized"错误。

这也可以应用于聚合类型和单个信号：

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
```
```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class ModWithVec extends Module {
  // ...
  val nElements = 5
  val io = IO(new Bundle {
    val outs = Output(Vec(nElements, Bool()))
  })
  io.outs <> DontCare
  // ...
}

class TrivialInterface extends Bundle {
  val in  = Input(Bool())
  val out = Output(Bool())
}

class ModWithTrivalInterface extends Module {
  // ...
  val io = IO(new TrivialInterface)
  io <> DontCare
  // ...
}
```

### 确定未连接的元素

我有一个包含 42 个线的接口。
它们中哪一个未连接？

firrtl 错误消息应该包含类似这样的内容：
```bash
firrtl.passes.CheckInitialization$RefNotInitializedException:  @[:@6.4] : [module Router]  Reference io is not fully initialized.
   @[Decoupled.scala 38:19:@48.12] : node _GEN_23 = mux(and(UInt<1>("h1"), eq(UInt<2>("h3"), _T_84)), _GEN_2, VOID) @[Decoupled.scala 38:19:@48.12]
   @[Router.scala 78:30:@44.10] : node _GEN_36 = mux(_GEN_0.ready, _GEN_23, VOID) @[Router.scala 78:30:@44.10]
   @[Router.scala 75:26:@39.8] : node _GEN_54 = mux(io.in.valid, _GEN_36, VOID) @[Router.scala 75:26:@39.8]
   @[Router.scala 70:50:@27.6] : node _GEN_76 = mux(io.load_routing_table_request.valid, VOID, _GEN_54) @[Router.scala 70:50:@27.6]
   @[Router.scala 65:85:@19.4] : node _GEN_102 = mux(_T_62, VOID, _GEN_76) @[Router.scala 65:85:@19.4]
   : io.outs[3].bits.body <= _GEN_102
```
第一行是初始错误报告。
后续缩进并以源代码行信息开头的行表示涉及有问题信号的连接。
不幸的是，如果这些是涉及复用器的 `when` 条件，可能很难解读。
组中的最后一行，缩进并以 `:` 开头的行应该指示未初始化的信号组件。
这个示例（来自 [Router 教程](https://github.com/ucb-bar/chisel-tutorial/blob/release/src/main/scala/examples/Router.scala)）
是在输出队列位未被初始化时产生的。
旧代码是：
```scala
  io.outs.foreach { out => out.noenq() }
```
它初始化了队列的 `valid` 位，但没有初始化实际的输出值。
修复是：
```scala
  io.outs.foreach { out =>
    out.bits := 0.U.asTypeOf(out.bits)
    out.noenq()
  }
```
