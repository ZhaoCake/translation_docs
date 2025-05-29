---

layout: docs

title:  "<> 和 := 连接运算符深入探讨"

section: "chisel3"

---

# 连接运算符深入探讨

Chisel 包含两个连接运算符，`:=` 和 `<>`。本文档深入解释了这两者的区别以及何时使用其中之一。这些区别通过使用 Scastie 示例的实验来演示，这些示例使用 `DecoupledIO`。



### 实验设置

```scala mdoc
// 以下示例使用的导入
import chisel3._
import chisel3.util.DecoupledIO
```

该实验的图表可以在[此处](https://docs.google.com/document/d/14C918Hdahk2xOGSJJBT-ZVqAx99_hg3JQIq-vaaifQU/edit?usp=sharing)查看。
![实验图像](https://raw.githubusercontent.com/chipsalliance/chisel3/master/docs/src/images/connection-operators-experiment.svg?sanitize=true)

```scala mdoc:silent
class Wrapper extends Module{
  val io = IO(new Bundle {
  val in = Flipped(DecoupledIO(UInt(8.W)))
  val out = DecoupledIO(UInt(8.W))
  })
  val p = Module(new PipelineStage)
  val c = Module(new PipelineStage)
  // 连接生产者到IO
  p.io.a <> io.in
  // 连接生产者到消费者
  c.io.a <> p.io.b
  // 连接消费者到IO
  io.out <> c.io.b
}
class PipelineStage extends Module{
  val io = IO(new Bundle{
    val a = Flipped(DecoupledIO(UInt(8.W)))
    val b = DecoupledIO(UInt(8.W))
  })
  io.b <> io.a
}
```
下面我们可以看到这个示例的生成Verilog：
```scala mdoc:verilog
chisel3.docs.emitSystemVerilog(new Wrapper)
```
## 概念1：`<>` 是可交换的

该实验旨在测试 `<>` 的功能，使用上述实验。

实现这一点涉及翻转 `<>` 运算符的右侧（RHS）和左侧（LHS），并观察 `<>` 如何反应。
（实验的Scastie链接：https://scastie.scala-lang.org/Shorla/LVhlbkFQQnq7X3trHfgZZQ）




```scala mdoc:silent:reset
import chisel3._
import chisel3.util.DecoupledIO

class Wrapper extends Module{
  val io = IO(new Bundle {
  val in = Flipped(DecoupledIO(UInt(8.W)))
  val out = DecoupledIO(UInt(8.W))
  })
  val p = Module(new PipelineStage)
  val c = Module(new PipelineStage)
  // 连接生产者到I/O
  io.in <> p.io.a
  // 连接生产者到消费者
  p.io.b <> c.io.a
  // 连接消费者到I/O
  c.io.b <> io.out
}
class PipelineStage extends Module{
  val io = IO(new Bundle{
    val a = Flipped(DecoupledIO(UInt(8.W)))
    val b = DecoupledIO(UInt(8.W))
  })
  io.a <> io.b
}
```
下面我们可以看到这个示例的生成Verilog：
```scala mdoc:verilog
chisel3.docs.emitSystemVerilog(new Wrapper)
```
### 结论：
Verilog保持不变，没有产生错误，表明 `<>` 运算符是可交换的。




## 概念2：`:=` 表示从RHS分配所有LHS信号，无论LHS的方向如何。
使用与上面相同的实验代码，我们设置测试 `:=` 的功能
我们在上面的示例代码中将所有 `<>` 实例替换为 `:=`。
(实验的Scastie链接：https://scastie.scala-lang.org/Shorla/o1ShdaY3RWKf0IIFwwQ1UQ/1)

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.DecoupledIO

class Wrapper extends Module{
  val io = IO(new Bundle {
  val in = Flipped(DecoupledIO(UInt(8.W)))
  val out = DecoupledIO(UInt(8.W))
  })
  val p = Module(new PipelineStage)
  val c = Module(new PipelineStage)
  // 连接生产者到I/O
  p.io.a := io.in
  // 连接生产者到消费者
  c.io.a := p.io.b
  // 连接消费者到I/O
  io.out := c.io.b
}
class PipelineStage extends Module{
  val io = IO(new Bundle{
    val a = Flipped(DecoupledIO(UInt(8.W)))
    val b = DecoupledIO(UInt(8.W))
  })
  io.a := io.b
}
```
下面我们可以看到这个示例的错误消息：
```scala mdoc:crash
circt.stage.ChiselStage.emitSystemVerilog(new Wrapper)
```
### 结论：
`:=` 运算符逐字段遍历LHS，并尝试将其连接到RHS中具有相同名称的信号。如果LHS上的某个内容实际上是Input，或者RHS上相应的信号是Output，则会出现如上所示的错误。

## 概念3：始终使用 `:=` 将 DontCare 分配给 Wires
当将 `DontCare` 分配给没有方向的内容时，应该使用 `:=` 还是 `<>`？
我们将使用下面的示例代码找出答案：
（实验的Scastie链接：https://scastie.scala-lang.org/Shorla/ZIGsWcylRqKJhZCkKWlSIA/1）

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.DecoupledIO

class Wrapper extends Module{
  val io = IO(new Bundle {
  val in = Flipped(DecoupledIO(UInt(8.W)))
  val out = DecoupledIO(UInt(8.W))
  })
  val p = Module(new PipelineStage)
  val c = Module(new PipelineStage)
  //connect Producer to IO
  io.in := DontCare
  p.io.a <> DontCare
  val tmp = Wire(Flipped(DecoupledIO(UInt(8.W))))
  tmp := DontCare
  p.io.a <> io.in
  // connect producer to consumer
  c.io.a <> p.io.b
  //connect consumer to IO
  io.out <> c.io.b
}
class PipelineStage extends Module{
  val io = IO(new Bundle{
    val a = Flipped(DecoupledIO(UInt(8.W)))
    val b = DecoupledIO(UInt(8.W))
  })
  io.b <> io.a
}
```
Below we can see the resulting Verilog for this example:
```scala mdoc:verilog
chisel3.docs.emitSystemVerilog(new Wrapper)
```
### 结论：
如果使用 `<>` 将无方向的wire `tmp` 分配给 DontCare，我们会得到一个错误。但在上面的示例中，我们使用了 `:=` 并且没有发生错误。
当使用 `:=` 将wire分配给DontCare时，不会发生错误。

因此，当将 `DontCare` 分配给 `Wire` 时，始终使用 `:=`。


## 概念4：您可以使用 `<>` 或 `:=` 将 `DontCare` 分配给有方向的内容（IOs）
当将 `DontCare` 分配给有方向的内容时，应该使用 `:=` 还是 `<>`？
我们将使用下面的示例代码找出答案：
（实验的Scastie链接：https://scastie.scala-lang.org/Shorla/ZIGsWcylRqKJhZCkKWlSIA/1）

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.DecoupledIO

class Wrapper extends Module{
  val io = IO(new Bundle {
  val in = Flipped(DecoupledIO(UInt(8.W)))
  val out = DecoupledIO(UInt(8.W))
  })
  val p = Module(new PipelineStage)
  val c = Module(new PipelineStage)
  //connect Producer to IO
  io.in := DontCare
  p.io.a <> DontCare
  val tmp = Wire(Flipped(DecoupledIO(UInt(8.W))))
  tmp := DontCare
  p.io.a <> io.in
  // connect producer to consumer
  c.io.a <> p.io.b
  //connect consumer to IO
  io.out <> c.io.b
}
class PipelineStage extends Module{
  val io = IO(new Bundle{
    val a = Flipped(DecoupledIO(UInt(8.W)))
    val b = DecoupledIO(UInt(8.W))
  })
  io.b <> io.a
}
```
下面我们可以看到这个示例的生成Verilog：
```scala mdoc:verilog
chisel3.docs.emitSystemVerilog(new Wrapper)
```
### 结论：
`<>` 和 `:=` 都可以用于将有方向的内容（IOs）分配给DontCare，如分别在 `io.in` 和 `p.io.a` 中所示。这基本上是等效的，因为在这种情况下，`<>` 和 `:=` 都将从LHS确定方向。


## 概念5：`<>` 在至少有一个已知流向的内容之间工作（IO或子IO）。

如果至少有一个已知流向，`<>` 会做什么？这将通过下面的实验代码展示：
（实验的Scastie链接：https://scastie.scala-lang.org/Shorla/gKx9ReLVTTqDTk9vmw5ozg）

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.DecoupledIO

class Wrapper extends Module{
  val io = IO(new Bundle {
  val in = Flipped(DecoupledIO(UInt(8.W)))
  val out = DecoupledIO(UInt(8.W))
  })
  val p = Module(new PipelineStage)
  val c = Module(new PipelineStage)
  //连接生产者到IO
    // 对于这个实验，我们添加一个临时wire看看是否有效...
  //p.io.a <> io.in
  val tmp = Wire(DecoupledIO(UInt(8.W)))
  // 连接中间wire
  tmp <> io.in
  p.io.a <> tmp
  // 连接生产者到消费者
  c.io.a <> p.io.b
  //连接消费者到IO
  io.out <> c.io.b
}
class PipelineStage extends Module{
  val io = IO(new Bundle{
    val a = Flipped(DecoupledIO(UInt(8.W)))
    val b = DecoupledIO(UInt(8.W))
  })
  io.b <> io.a
}
```
下面我们可以看到这个示例的生成Verilog：
```scala mdoc
chisel3.docs.emitSystemVerilog(new Wrapper)
```
### 结论：
上述连接顺利进行，没有错误，这表明只要有至少一个有方向的内容（IO或子模块的IO）来"固定"方向，`<>` 就可以工作。


## 概念6：`<>` 和 `:=` 通过字段名称连接信号。
这个实验创建了一个MockDecoupledIO，它与DecoupledIO具有相同名称的字段。Chisel允许我们连接它并生成相同的verilog，即使MockDecoupledIO和DecoupledIO是不同的类型。
（实验的Scastie链接：https://scastie.scala-lang.org/Uf4tQquvQYigZAW705NFIQ）

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.DecoupledIO

class MockDecoupledIO extends Bundle {
  val valid = Output(Bool())
  val ready = Input(Bool())
  val bits = Output(UInt(8.W))
}
class Wrapper extends Module{
  val io = IO(new Bundle {
  val in = Flipped(new MockDecoupledIO())
  val out = new MockDecoupledIO()
  })
  val p = Module(new PipelineStage)
  val c = Module(new PipelineStage)
  // 连接生产者到I/O
  p.io.a <> io.in
  // 连接生产者到消费者
  c.io.a <> p.io.b
  // 连接消费者到I/O
  io.out <> c.io.b
}
class PipelineStage extends Module{
  val io = IO(new Bundle{
    val a = Flipped(DecoupledIO(UInt(8.W)))
    val b = DecoupledIO(UInt(8.W))
  })
  io.a <> io.b
}
```
下面我们可以看到这个示例的生成Verilog：
```scala mdoc:verilog
chisel3.docs.emitSystemVerilog(new Wrapper)
```
这里是另一个实验，我们删除了MockDecoupledIO的一个字段：
（实验的Scastie链接：https://scastie.scala-lang.org/ChtkhKCpS9CvJkjjqpdeIA）

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.DecoupledIO

class MockDecoupledIO extends Bundle {
  val valid = Output(Bool())
  val ready = Input(Bool())
  //val bits = Output(UInt(8.W))
}
class Wrapper extends Module{
  val io = IO(new Bundle {
  val in = Flipped(new MockDecoupledIO())
  val out = new MockDecoupledIO()
  })
  val p = Module(new PipelineStage)
  val c = Module(new PipelineStage)
  // 连接生产者到I/O
  p.io.a <> io.in
  // 连接生产者到消费者
  c.io.a <> p.io.b
  // 连接消费者到I/O
  io.out <> c.io.b
}
class PipelineStage extends Module{
  val io = IO(new Bundle{
    val a = Flipped(DecoupledIO(UInt(8.W)))
    val b = DecoupledIO(UInt(8.W))
  })
  io.a <> io.b
}
```
下面我们可以看到这个示例的错误信息：
```scala mdoc:crash
circt.stage.ChiselStage.emitSystemVerilog(new Wrapper)
```
这个失败是因为缺少了 `bits` 字段。

### 结论：
对于 `:=`，Scala类型不需要匹配，但RHS必须提供LHS上的所有信号，否则将出现Chisel编译错误。RHS上可能有额外的信号，这些信号将被忽略。对于 `<>`，Scala类型不需要匹配，但LHS和RHS之间的所有信号必须完全匹配。在这两种情况下，字段的顺序无关紧要。
