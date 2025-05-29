---
layout: docs
title:  "接口和连接"
section: "chisel3"
---

# 接口和连接

对于更复杂的模块，在定义模块的IO时定义和实例化接口类通常很有用。首先，接口类促进了重用，允许用户一次性捕获常见接口并以有用的形式表示。

其次，接口允许用户通过支持生产者和消费者模块之间的批量连接来大幅减少布线工作。最后，用户可以在一个地方对大型接口进行更改，减少添加或删除接口部分时所需的更新次数。

请注意，Chisel有一些内置的标准接口，应尽可能使用它们以实现互操作性（例如Decoupled）。

## 端口：子类和嵌套

如我们之前所见，用户可以通过定义继承Bundle的类来定义自己的接口。例如，用户可以定义一个用于数据握手的简单链接，如下所示：

```scala mdoc:invisible
import chisel3._
import chisel3.docs.emitSystemVerilog
```

```scala mdoc:silent
class SimpleLink extends Bundle {
  val data = Output(UInt(16.W))
  val valid = Output(Bool())
}
```

然后我们可以通过使用bundle继承来添加奇偶校验位来扩展SimpleLink：
```scala mdoc:silent
class PLink extends SimpleLink {
  val parity = Output(UInt(5.W))
}
```
一般来说，用户可以使用继承将接口组织成层次结构。

从那里我们可以通过将两个PLink嵌套到一个新的FilterIO bundle中来定义过滤器接口：
```scala mdoc:silent
class FilterIO extends Bundle {
  val x = Flipped(new PLink)
  val y = new PLink
}
```
其中flip递归地改变bundle的方向，将输入变为输出，将输出变为输入。

我们现在可以通过定义扩展Module的filter类来定义过滤器：
```scala mdoc:silent
class Filter extends Module {
  val io = IO(new FilterIO)
  // ...
}
```
其中io字段包含FilterIO。

## Bundle向量

除了单个元素外，元素向量形成了更丰富的层次结构接口。例如，为了创建一个具有输入向量的交叉开关，产生输出向量，并由UInt输入选择，我们使用Vec构造函数：
```scala mdoc:silent
import chisel3.util.log2Ceil
class CrossbarIo(n: Int) extends Bundle {
  val in = Vec(n, Flipped(new PLink))
  val sel = Input(UInt(log2Ceil(n).W))
  val out = Vec(n, new PLink)
}
```
其中Vec将大小作为第一个参数，将返回端口的块作为第二个参数。

## 批量连接
一旦我们定义了接口，我们可以通过[`MonoConnect`](https://www.chisel-lang.org/api/latest/chisel3/Data.html#:=)运算符（`:=`）或[`BiConnect`](https://www.chisel-lang.org/api/latest/chisel3/Data.html#%3C%3E)运算符（`<>`）连接到它。


### `MonoConnect`算法
`MonoConnect.connect`，或`:=`，按元素执行单向连接。

请注意，这不是可交换的。在调用此函数之前已经确定了明确的源和接收器。

连接操作将递归地遍历左侧Data（与右侧Data一起）。
如果在左侧的移动无法在右侧匹配，将抛出异常。右侧允许有额外的字段。
Vec必须具有完全相同的大小。

请注意，LHS元素必须是可写的，因此必须满足以下条件之一：
- 是内部可写节点（`Reg`或`Wire`）
- 是当前模块的输出
- 是当前模块的子模块的输入

请注意，RHS元素必须是可读的，因此必须满足以下条件之一：
- 是内部可读节点（`Reg`、`Wire`、`Op`）
- 是字面值
- 是当前模块或当前模块的子模块的端口


### `BiConnect`算法
`BiConnect.connect`，或`<>`，按元素执行双向连接。请注意，参数是左右（而不是源和接收器），因此该操作的意图是可交换的。连接操作将递归地遍历左侧`Data`（与右侧`Data`一起）。如果在左侧的移动无法在右侧匹配，或者右侧有额外的字段，将抛出异常。

> 注意：我们强烈鼓励使用[`Connectable`运算符](https://www.chisel-lang.org/chisel3/docs/explanations/connectable.html)而不是`<>`运算符编写新代码。

使用双连接`<>`运算符，我们现在可以将两个过滤器组合成一个过滤器块，如下所示：
```scala mdoc:silent
class Block extends Module {
  val io = IO(new FilterIO)
  val f1 = Module(new Filter)
  val f2 = Module(new Filter)
  f1.io.x <> io.x
  f1.io.y <> f2.io.x
  f2.io.y <> io.y
}
```

双向批量连接运算符`<>`将同名的叶端口相互连接。Bundle的Scala类型不需要匹配。如果任一侧缺少一个命名信号，Chisel将给出如下例所示的错误：

```scala mdoc:silent

class NotReallyAFilterIO extends Bundle {
  val x = Flipped(new PLink)
  val y = new PLink
  val z = Output(new Bool())
}
class Block2 extends Module {
  val io1 = IO(new FilterIO)
  val io2 = IO(Flipped(new NotReallyAFilterIO))

  io1 <> io2
}
```
下面我们可以看到这个例子的结果错误：
```scala mdoc:crash
emitSystemVerilog(new Block2)
```
双向连接应该只用于**有方向的元素**（如IO），例如，连接两个线不受支持，因为Chisel不一定能自动确定方向。
例如，即使可以从端点知道方向，在此处放置两个临时线并连接它们也不会起作用：

```scala mdoc:silent

class BlockWithTemporaryWires extends Module {
  val io = IO(new FilterIO)
  val f1 = Module(new Filter)
  val f2 = Module(new Filter)
  f1.io.x <> io.x
 val tmp1 = Wire(new FilterIO)
 val tmp2 = Wire(new FilterIO)
  f1.io.y <> tmp1
  tmp1 <> tmp2
  tmp2 <> f2.io.x
  f2.io.y <> io.y
}

```
下面我们可以看到这个例子的结果错误：
```scala mdoc:crash
emitSystemVerilog(new BlockWithTemporaryWires)
```
有关更多详细信息，请参见[连接运算符深入探讨](connection-operators)

注意：当使用`Chisel._`（兼容模式）而不是`chisel3._`时，`:=`运算符以类似于`<>`的双向方式工作，但不完全相同。

## 标准就绪-有效接口（ReadyValidIO / Decoupled）

Chisel为就绪-有效接口提供了标准接口（例如在AXI中使用）。
就绪-有效接口由`ready`信号、`valid`信号和存储在`bits`中的一些数据组成。
`ready`位表示消费者*准备好*消费数据。
`valid`位表示生产者在`bits`上有*有效*数据。
当`ready`和`valid`都被断言时，数据从生产者传输到消费者。
提供了一个便利方法`fire`，如果`ready`和`valid`都被断言，则该方法被断言。

通常，我们使用实用函数[`Decoupled()`](https://chisel.eecs.berkeley.edu/api/latest/chisel3/util/Decoupled$.html)将任何类型转换为就绪-有效接口，而不是直接使用[ReadyValidIO](http://chisel.eecs.berkeley.edu/api/latest/chisel3/util/ReadyValidIO.html)。

* `Decoupled(...)`创建一个生产者/输出就绪-有效接口（即bits是输出）。
* `Flipped(Decoupled(...))`创建一个消费者/输入就绪-有效接口（即bits是输入）。

查看以下示例Chisel代码，以更好地理解确切生成的内容：

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.Decoupled

/**
  * 使用Decoupled(...)创建一个生产者接口。
  * 即，它有bits作为输出。
  * 这会产生以下端口：
  *   input         io_readyValid_ready,
  *   output        io_readyValid_valid,
  *   output [31:0] io_readyValid_bits
  */
class ProducingData extends Module {
  val io = IO(new Bundle {
    val readyValid = Decoupled(UInt(32.W))
  })
  // 对io.readyValid.ready做些什么
  io.readyValid.valid := true.B
  io.readyValid.bits := 5.U
}

/**
  * 使用Flipped(Decoupled(...))创建一个消费者接口。
  * 即，它有bits作为输入。
  * 这会产生以下端口：
  *   output        io_readyValid_ready,
  *   input         io_readyValid_valid,
  *   input  [31:0] io_readyValid_bits
  */
class ConsumingData extends Module {
  val io = IO(new Bundle {
    val readyValid = Flipped(Decoupled(UInt(32.W)))
  })
  io.readyValid.ready := false.B
  // 对io.readyValid.valid做些什么
  // 对io.readyValid.bits做些什么
}
```

`DecoupledIO`是一个就绪-有效接口，其*约定*是不对取消断言`ready`或`valid`或`bits`的稳定性做任何保证。
这意味着`ready`和`valid`也可以在没有数据传输的情况下取消断言。

`IrrevocableIO`是一个就绪-有效接口，其*约定*是在`valid`被断言且`ready`被取消断言时，`bits`的值不会改变。
此外，消费者在`ready`为高而`valid`为低的周期后应保持`ready`被断言。
请注意，*不可撤销*约束*仅是一个约定*，无法通过接口强制执行。
Chisel不会自动生成检查器或断言来强制执行*不可撤销*约定。
