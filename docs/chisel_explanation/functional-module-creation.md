---
layout: docs
title:  "函数式模块创建"
section: "chisel3"
---

# 函数式模块创建

Scala中的对象有一个预先存在的创建函数（方法）称为`apply`。
当对象在表达式中用作值时（这基本上意味着构造函数被调用），这个方法决定了返回的值。
处理硬件模块时，人们期望模块输出能代表硬件模块的功能。
因此，我们有时希望在表达式中使用对象作为值时，返回的值是模块的输出。
由于硬件模块表示为Scala对象，可以通过定义对象的`apply`方法来返回模块的输出来实现这一点。
这可以被称为为模块构建创建函数式接口。
如果我们将此应用于标准mux2示例，我们希望在表达式中使用mux2时返回mux2输出端口。
实现这一点需要构建一个构造函数，该函数将多路复用器输入作为参数并返回多路复用器输出：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._

class Mux2 extends Module {
  val io = IO(new Bundle {
    val sel = Input(Bool())
    val in0 = Input(UInt())
    val in1 = Input(UInt())
    val out = Output(UInt())
  })
  io.out := Mux(io.sel, io.in0, io.in1)
}

object Mux2 {
  def apply(sel: UInt, in0: UInt, in1: UInt) = {
    val m = Module(new Mux2)
    m.io.in0 := in0
    m.io.in1 := in1
    m.io.sel := sel
    m.io.out
  }
}
```

正如我们在代码示例中看到的，我们定义了`apply`方法，以Mux2输入作为方法参数，并将Mux2输出作为函数的返回值。
通过这种方式定义模块，以后实现这个常规模块的更大、更复杂的版本会更容易。
例如，我们之前是这样实现Mux4的：

```scala
// 原始代码块中的标记: mdoc:silent
class Mux4 extends Module {
  val io = IO(new Bundle {
    val in0 = Input(UInt(1.W))
    val in1 = Input(UInt(1.W))
    val in2 = Input(UInt(1.W))
    val in3 = Input(UInt(1.W))
    val sel = Input(UInt(2.W))
    val out = Output(UInt(1.W))
  })
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

然而，通过使用我们为Mux2重新定义的创建函数，现在我们可以在编写Mux4输出表达式时将Mux2输出用作模块本身的值：

```scala
// 原始代码块中的标记: mdoc:invisible:reset
// 我们需要重新执行此操作以允许我们`reset`
// 然后重新定义Mux4
import chisel3._

class Mux2 extends Module {
  val io = IO(new Bundle {
    val sel = Input(Bool())
    val in0 = Input(UInt())
    val in1 = Input(UInt())
    val out = Output(UInt())
  })
  io.out := Mux(io.sel, io.in0, io.in1)
}

object Mux2 {
  def apply(sel: UInt, in0: UInt, in1: UInt) = {
    val m = Module(new Mux2)
    m.io.in0 := in0
    m.io.in1 := in1
    m.io.sel := sel
    m.io.out
  }
}
```

```scala
// 原始代码块中的标记: mdoc:silent
class Mux4 extends Module {
  val io = IO(new Bundle {
    val in0 = Input(UInt(1.W))
    val in1 = Input(UInt(1.W))
    val in2 = Input(UInt(1.W))
    val in3 = Input(UInt(1.W))
    val sel = Input(UInt(2.W))
    val out = Output(UInt(1.W))
  })
  io.out := Mux2(io.sel(1),
                 Mux2(io.sel(0), io.in0, io.in1),
                 Mux2(io.sel(0), io.in2, io.in3))
}
```

这使我们能够编写更直观可读的硬件连接描述，类似于软件表达式求值。
