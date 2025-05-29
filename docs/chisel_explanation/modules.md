---
layout: docs
title:  "模块"
section: "chisel3"
---

# 模块

Chisel的*模块*在定义生成电路的层次结构方面与Verilog的*模块*非常相似。

层次模块命名空间在下游工具中是可访问的，有助于调试和物理布局。用户定义的模块被定义为一个*类*，它：

 - 继承自`Module`，
 - 包含至少一个被包装在模块的`IO()`方法中的接口（传统上存储在名为```io```的端口字段中），以及
 - 在其构造函数中将子电路连接在一起。

例如，考虑将你自己的两输入多路复用器定义为一个模块：
```scala mdoc:silent
import chisel3._
class Mux2IO extends Bundle {
  val sel = Input(UInt(1.W))
  val in0 = Input(UInt(1.W))
  val in1 = Input(UInt(1.W))
  val out = Output(UInt(1.W))
}

class Mux2 extends Module {
  val io = IO(new Mux2IO)
  io.out := (io.sel & io.in1) | (~io.sel & io.in0)
}
```

到模块的接线接口是以```Bundle```形式的端口集合。模块的接口通过名为```io```的字段定义。对于```Mux2```，```io```被定义为具有四个字段的bundle，每个多路复用器端口一个。

```:=```赋值运算符，在这里用于定义的主体中，是Chisel中的一个特殊运算符，它将左侧的输入连接到右侧的输出。

### 模块层次结构

我们现在可以构建电路层次结构，其中我们使用较小的子模块构建较大的模块。例如，我们可以通过将三个2输入多路复用器连接在一起，以```Mux2```模块为基础构建一个4输入多路复用器模块：

```scala mdoc:silent
class Mux4IO extends Bundle {
  val in0 = Input(UInt(1.W))
  val in1 = Input(UInt(1.W))
  val in2 = Input(UInt(1.W))
  val in3 = Input(UInt(1.W))
  val sel = Input(UInt(2.W))
  val out = Output(UInt(1.W))
}
class Mux4 extends Module {
  val io = IO(new Mux4IO)

  val m0 = Module(new Mux2)
  m0.io.sel := io.sel(0)
  m0.io.in0 := io.in0
  m0.io.in1 := io.in1

  val m1 = Module(new Mux2)
  m1.io.sel := io.sel(0)
  m1.io.in0 := io.in2
  m1.io.in1 := io.in3

  val m3 = Module(new Mux2)
  m3.io.sel := io.sel(1)
  m3.io.in0 := m0.io.out
  m3.io.in1 := m1.io.out

  io.out := m3.io.out
}
```

我们再次将模块接口定义为```io```并连接输入和输出。在这种情况下，我们使用```Module```构造函数和Scala```new```关键字创建三个```Mux2```子模块，以创建一个新对象。然后我们将它们彼此连接并连接到```Mux4```接口的端口。

注意：Chisel的`Module`有一个隐式时钟（称为`clock`）和一个隐式复位（称为`reset`）。要创建没有隐式时钟和复位的模块，Chisel提供了`RawModule`。

### `RawModule`

`RawModule`是一个**不提供隐式时钟和复位**的模块。当Chisel模块与期望时钟或复位的特定命名约定的设计接口时，这可能很有用。

然后我们可以用它代替*Module*的用法：
```scala mdoc:silent
import chisel3.{RawModule, withClockAndReset}

class Foo extends Module {
  val io = IO(new Bundle{
    val a = Input(Bool())
    val b = Output(Bool())
  })
  io.b := !io.a
}

class FooWrapper extends RawModule {
  val a_i  = IO(Input(Bool()))
  val b_o  = IO(Output(Bool()))
  val clk  = IO(Input(Clock()))
  val rstn = IO(Input(Bool()))

  val foo = withClockAndReset(clk, !rstn){ Module(new Foo) }

  foo.io.a := a_i
  b_o := foo.io.b
}
```

在上面的例子中，`RawModule`用于更改模块`SlaveSpi`的复位极性。实际上，默认情况下，复位在Chisel模块中是高有效的，然后使用`withClockAndReset(clock, !rstn)`，我们可以在整个设计中使用低有效复位。

时钟只是按原样连接，但如果需要，`RawModule`可以与`BlackBox`结合使用，例如连接差分时钟输入。
