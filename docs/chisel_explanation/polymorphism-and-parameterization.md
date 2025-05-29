---
layout: docs
title:  "多态和参数化"
section: "chisel3"
---

# 多态和参数化

_本节内容较为深入，初次阅读可以跳过。_

Scala 是一种强类型语言，使用参数化类型来定义泛型函数和类。在本节中，我们将展示 Chisel 用户如何使用参数化类来定义自己的可重用函数和类。

## 参数化函数

早些时候我们定义了基于 `Bool` 的 `Mux2`，现在我们展示如何定义一个泛型的多路复用器函数。我们将这个函数定义为接收一个布尔条件和 con 和 alt 参数（对应于 then 和 else 表达式），类型为 `T`：

```scala
def Mux[T <: Bits](c: Bool, con: T, alt: T): T = { ... }
```

这里 `T` 必须是 `Bits` 的子类。
Scala 确保在每次使用 `Mux` 时，都能找到实际 con 和 alt 参数类型的公共超类，否则会导致 Scala 编译类型错误。
例如，

```scala
Mux(c, UInt(10), UInt(11))
```

会产生一个 `UInt` 类型的线，因为 `con` 和 `alt` 参数都是 `UInt` 类型。

<!---
Jack: I cannot seem to get this to actually work
      Scala does not like the * in FIR since it could be from UInt or SInt

我们现在展示一个更高级的参数化函数示例，用于在 Chisel `Num` 上定义内积 FIR 数字滤波器。

FIR 内积滤波器在数学上的定义为：
\begin{equation}
y[t] = \sum_j w_j * x_j[t-j]
\end{equation}


其中 `x` 是输入，`w` 是权重向量。
在 Chisel 中可以定义为：


```scala
def delays[T <: Data](x: T, n: Int): List[T] =
  if (n <= 1) List(x) else x :: delays(RegNext(x), n - 1)

def FIR[T <: Data with Num[T]](ws: Seq[T], x: T): T =
  ws zip delays(x, ws.length) map { case (a, b) => a * b } reduce (_ + _)
```

其中
`delays` 创建其输入的增量延迟列表，`reduce` 根据二元组合函数 `f` 构造一个归约电路。在这种情况下，`reduce` 创建一个求和电路。最后，`FIR` 函数被限制为在 `Num` 类型的输入上工作，其中定义了 Chisel 的乘法和加法。
--->
## 参数化类

就像参数化函数一样，我们也可以参数化类使其更易复用。例如，我们可以使 Filter 类泛化以使用任何类型的连接。我们通过参数化 `FilterIO` 类并定义构造函数来接收类型 `T` 的单个参数 `gen` 来实现这一点，如下所示：

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
```

```scala
// 原始代码块中的标记: mdoc:silent
class FilterIO[T <: Data](gen: T) extends Bundle {
  val x = Input(gen)
  val y = Output(gen)
}
```

现在我们可以通过定义一个也接受连接类型构造函数参数并将其传递给 `FilterIO` 接口构造函数的模块类来定义 `Filter`：

```scala
// 原始代码块中的标记: mdoc:silent
class Filter[T <: Data](gen: T) extends Module {
  val io = IO(new FilterIO(gen))
  // ...
}
```

我们现在可以这样定义一个基于 `PLink` 的 `Filter`：

```scala
// 原始代码块中的标记: mdoc:invisible
class SimpleLink extends Bundle {
  val data = Output(UInt(16.W))
  val valid = Output(Bool())
}
class PLink extends SimpleLink {
  val parity = Output(UInt(5.W))
}
```

```scala
// 原始代码块中的标记: mdoc:compile-only
val f = Module(new Filter(new PLink))
```

泛型 FIFO 可以这样定义：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.util.log2Up

class DataBundle extends Bundle {
  val a = UInt(32.W)
  val b = UInt(32.W)
}

class Fifo[T <: Data](gen: T, n: Int) extends Module {
  val io = IO(new Bundle {
    val deq = Output(gen)
    val enq = Input(gen)
    val deqEn = Input(Bool())
    val enqEn = Input(Bool())
    val empty = Output(Bool())
    val full = Output(Bool())
  })
  val enqPtr = RegInit(0.U(log2Up(n).W))
  val deqPtr = RegInit(0.U(log2Up(n).W))
  val empty = enqPtr === deqPtr
  val full = (enqPtr + 1.U) === deqPtr
  val doEnq = io.enqEn && !full
  val doDeq = io.deqEn && !empty
  
  when (doEnq) {
    enqPtr := enqPtr + 1.U
  }
  when (doDeq) {
    deqPtr := deqPtr + 1.U
  }
  val ram = Mem(n, gen)
  when (doEnq) {
    ram(enqPtr) := io.enq
  }
  ram(deqPtr) <> io.deq
}
```

一个包含 8 个 DataBundle 类型元素的 FIFO 可以这样实例化：

```scala
// 原始代码块中的标记: mdoc:compile-only
val fifo = Module(new Fifo(new DataBundle, 8))
```

也可以定义一个泛型的解耦（ready/valid）接口：

```scala
// 原始代码块中的标记: mdoc:invisible:reset
import chisel3._
class DataBundle extends Bundle {
  val a = UInt(32.W)
  val b = UInt(32.W)
}
```

```scala
// 原始代码块中的标记: mdoc:silent
class DecoupledIO[T <: Data](data: T) extends Bundle {
  val ready = Input(Bool())
  val valid = Output(Bool())
  val bits  = Output(data)
}
```

这个模板可以用来为任何信号集添加握手协议：

```scala
// 原始代码块中的标记: mdoc:silent
class DecoupledDemo extends DecoupledIO(new DataBundle)
```

现在 FIFO 接口可以简化为：

```scala
// 原始代码块中的标记: mdoc:silent
class Fifo[T <: Data](data: T, n: Int) extends Module {
  val io = IO(new Bundle {
    val enq = Flipped(new DecoupledIO(data))
    val deq = new DecoupledIO(data)
  })
  // ...
}
```

## 基于模块的参数化

你也可以基于其他模块而不仅仅是类型来参数化模块。下面是一个基于其他模块而不是类型参数化的模块示例。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.RawModule
import chisel3.experimental.BaseModule

// 提供一个更具体的接口，因为泛型 Module
// 在编译时不提供关于泛型模块 IO 的信息
trait MyAdder {
    def in1: UInt
    def in2: UInt
    def out: UInt
}

class Mod1 extends RawModule with MyAdder {
    val in1 = IO(Input(UInt(8.W)))
    val in2 = IO(Input(UInt(8.W)))
    val out = IO(Output(UInt(8.W)))
    out := in1 + in2
}

class Mod2 extends RawModule with MyAdder {
    val in1 = IO(Input(UInt(8.W)))
    val in2 = IO(Input(UInt(8.W)))
    val out = IO(Output(UInt(8.W)))
    out := in1 - in2
}

class X[T <: BaseModule with MyAdder](genT: => T) extends Module {
    val io = IO(new Bundle {
        val in1 = Input(UInt(8.W))
        val in2 = Input(UInt(8.W))
        val out = Output(UInt(8.W))
    })
    val subMod = Module(genT)
    subMod.in1 := io.in1
    subMod.in2 := io.in2
    io.out := subMod.out
}
```
