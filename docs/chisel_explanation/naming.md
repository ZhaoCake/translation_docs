---
layout: docs
title:  "Naming"
section: "chisel3"
---
# 命名

从历史上看，Chisel 在可靠地捕获信号名称方面一直存在问题。这主要是由于两个原因：
(1) 主要依赖反射来查找名称
(2) 使用 `@chiselName` 宏，但其行为不可靠

Chisel 3.4 引入了一个自定义的 Scala 编译器插件，使得在声明信号时能够可靠且自动地捕获信号名称。此外，这个版本还大量使用了新的前缀 API，使得从函数调用中以编程方式生成的信号名称更加稳定。

本文档解释了 Chisel 中信号和模块名称的命名机制。关于如何修复系统性命名稳定性问题的实例，请参考命名 [cookbook](../cookbooks/naming)。

### 编译器插件

```scala
// 原始代码块中的标记: mdoc
// Imports used by the following examples
import chisel3._
import chisel3.experimental.{prefix, noPrefix}
```

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3.docs.emitSystemVerilog
```

Chisel 用户还必须在构建设置中包含编译器插件。
在 SBT 中，配置类似这样：

```scala
// 对于 Chisel 5.0.0+ 版本
addCompilerPlugin("org.chipsalliance" % "chisel-plugin" % "5.0.0" cross CrossVersion.full)
// 对于较早的 Chisel3 版本，例如 3.6.0
addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % "3.6.0" cross CrossVersion.full)
```

这个插件会在 Scala 编译器的 'typer' 阶段之后运行。它会寻找形如 `val x = y` 的用户代码，其中 `x` 的类型是 `chisel3.Data`、`chisel3.MemBase` 或 `chisel3.experimental.BaseModule`。对于每一行符合这些条件的代码，它都会重写该行。在下面的例子中，注释行展示了上面那行代码被重写后的形式。

如果这行代码在 bundle 声明中或是模块实例化，它会被重写为使用 `withName` 的调用，该调用会为信号/模块命名。

```scala
// 原始代码块中的标记: mdoc
class MyBundle extends Bundle {
  val foo = Input(UInt(3.W))
  // val foo = withName("foo")(Input(UInt(3.W)))
}
class Example1 extends Module {
  val io = IO(new MyBundle())
  // val io = withName("io")(IO(new MyBundle()))
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new Example1)
```

否则，它还会被重写为包含名称作为前缀，这个前缀会应用到在 val 声明的右侧执行过程中生成的所有信号：

```scala
// 原始代码块中的标记: mdoc
class Example2 extends Module {
  val in = IO(Input(UInt(2.W)))
  // val in = withName("in")(prefix("in")(IO(Input(UInt(2.W)))))

  val out1 = IO(Output(UInt(4.W)))
  // val out1 = withName("out1")(prefix("out1")(IO(Output(UInt(4.W)))))
  val out2 = IO(Output(UInt(4.W)))
  // val out2 = withName("out2")(prefix("out2")(IO(Output(UInt(4.W)))))
  val out3 = IO(Output(UInt(4.W)))
  // val out3 = withName("out3")(prefix("out3")(IO(Output(UInt(4.W)))))

  def func() = {
    val squared = in * in
    // val squared = withName("squared")(prefix("squared")(in * in))
    out1 := squared
    val delay = RegNext(squared)
    // val delay = withName("delay")(prefix("delay")(RegNext(squared)))
    delay
  }

  val masked = 0xa.U & func()
  // val masked = withName("masked")(prefix("masked")(0xa.U & func()))
  // 注意：在 `func()` 内部创建的值会带有 `masked` 前缀

  out2 := masked + 1.U
  out3 := masked - 1.U
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new Example2)
```

前缀也可以从连接左侧信号的名称推导出来。
虽然这不是通过编译器插件实现的，但行为应该感觉类似：

```scala
// 原始代码块中的标记: mdoc
class ConnectPrefixing extends Module {
  val in = IO(Input(UInt(2.W)))
  // val in = withName("in")(prefix("in")(IO(Input(UInt(2.W)))))

  val out1 = IO(Output(UInt(4.W)))
  // val out1 = withName("out1")(prefix("out1")(IO(Output(UInt(4.W)))))
  val out2 = IO(Output(UInt(4.W)))
  // val out2 = withName("out2")(prefix("out2")(IO(Output(UInt(4.W)))))

  out1 := { // 从技术上讲，这里没有被 withName 和 prefix 包装
    // 但 Chisel 运行时仍会使用 `out1` 的名称作为前缀
    val squared = in * in
    out2 := squared
    val delayed = RegNext(squared)
    // val delayed = withName("delayed")(prefix("delayed")(RegNext(squared)))
    delayed + 1.U
  }
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new ConnectPrefixing)
```

注意，当硬件类型嵌套在 `Option` 或 `Iterable` 的子类型中时，命名机制也同样有效：

```scala
// 原始代码块中的标记: mdoc
class Example3 extends Module {
  val in = IO(Input(UInt(2.W)))
  // val in = withName("in")(prefix("in")(IO(Input(UInt(2.W)))))

  val out = IO(Output(UInt(4.W)))
  // val out = withName("out")(prefix("out")(IO(Output(UInt(4.W)))))

  def func() = {
    val delay = RegNext(in)
    delay + 1.U
  }

  val opt = Some(func())
  // 注意：func() 中的寄存器会带有 `opt` 前缀：
  // val opt = withName("opt")(prefix("opt")(Some(func()))

  out := opt.get + 1.U
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new Example3)
```

还有一个重载的变体可以通过 unapply 提供的名称为硬件命名：

```scala
// 原始代码块中的标记: mdoc
class UnapplyExample extends Module {
  val foo = IO(Input(UInt(2.W)))
  def mkIO() = (IO(Input(UInt(2.W))), foo, IO(Output(UInt(2.W))))
  val (in, _, out) = mkIO()
  // val (in, _, out) = withName("in", "", "out")(mkIO())

  out := in & foo
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new UnapplyExample)
```

注意，在这些情况下，编译器插件不会插入前缀，因为不清楚前缀应该是什么。
希望获得前缀的用户可以按照下面的 [described below](#prefixing) 提供前缀。

### Prefixing

如上所述，编译器插件会自动尝试为您添加一些信号的前缀。
但是，您也可以通过调用 `prefix(...)` 添加自己的前缀：

还要注意，前缀是相互附加的（包括编译器插件生成的前缀）：

```scala
// 原始代码块中的标记: mdoc
class Example6 extends Module {
  val in = IO(Input(UInt(2.W)))
  val out = IO(Output(UInt(4.W)))

  val add = prefix("foo") {
    val sum = RegNext(in + 1.U)
    sum + 1.U
  }

  out := add
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new Example6)
```

有时您可能希望禁用前缀。这可能发生在您编写库函数并且不希望出现前缀行为的情况下。
在这种情况下，您可以调用 `noPrefix`：

```scala
// 原始代码块中的标记: mdoc
class Example7 extends Module {
  val in = IO(Input(UInt(2.W)))
  val out = IO(Output(UInt(4.W)))

  val add = noPrefix {
    val sum = RegNext(in + 1.U)
    sum + 1.U
  }

  out := add
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new Example7)
```

### Suggest a Signal's Name (or the instance name of a Module)

如果您想指定信号的名称，可以始终使用 `.suggestName` API。请注意，建议的名称仍然会被前缀（包括插件生成的前缀）。您可以始终使用 `noPrefix` 对象来去除前缀。

```scala
// 原始代码块中的标记: mdoc
class Example8 extends Module {
  val in = IO(Input(UInt(2.W)))
  val out = IO(Output(UInt(4.W)))

  val add = {
    val sum = RegNext(in + 1.U).suggestName("foo")
    sum + 1.U
  }

  out := add
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new Example8)
```

注意，使用 `.suggestName` 并不会影响源自 val 名称的前缀；
但是，它 _可以_ 影响源自连接（例如 `:=`）的前缀：

```scala
// 原始代码块中的标记: mdoc
class ConnectionPrefixExample extends Module {
  val in0 = IO(Input(UInt(2.W)))
  val in1 = IO(Input(UInt(2.W)))

  val out0 = {
    val port = IO(Output(UInt(5.W)))
    // 即使这个 suggestName 在 mul 之前，作用于 port
    // 但此作用域中使用的前缀是源自 `val out0`，所以这并不影响 mul 的名称
    port.suggestName("foo")
    // out0_mul
    val mul = RegNext(in0 * in1)
    port := mul + 1.U
    port
  }

  val out1 = IO(Output(UInt(4.W)))
  val out2 = IO(Output(UInt(4.W)))

  out1 := {
    // out1_sum
    val sum = RegNext(in0 + in1)
    sum + 1.U
  }
  // 在上面，所以并不影响下面的前缀
  out1.suggestName("bar")

  // 在前面，所以会影响下面的前缀
  out2.suggestName("fizz")
  out2 := {
    // fizz_diff
    val diff = RegNext(in0 - in1)
    diff + 1.U
  }
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new ConnectionPrefixExample)
```

正如这个例子所示，这种行为在某种程度上是不一致的，因此在未来的 Chisel 版本中可能会有所变化。


### Behavior for "Unnamed signals" (aka "Temporaries")

如果您想表示信号的名称无关紧要，可以在 val 的名称前加上 `_` 前缀。
Chisel 会在前缀中保留以 `_` 开头的约定，以表示通过前缀生成的信号是匿名信号。
例如：

```scala
// 原始代码块中的标记: mdoc
class TemporaryExample extends Module {
  val in0 = IO(Input(UInt(2.W)))
  val in1 = IO(Input(UInt(2.W)))

  val out = {
    // 我们需要 2 个端口，以便 firtool 维护公共子表达式
    val port0 = IO(Output(UInt(4.W)))
    // out_port1
    val port1 = IO(Output(UInt(4.W)))
    val _sum = in0 + in1
    port0 := _sum + 1.U
    port1 := _sum - 1.U
    // port0 被返回，所以会得到名称 "out"
    port0
  }
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new TemporaryExample)
```

如果一个匿名信号本身被用来生成前缀，前导的 `_` 将被忽略，以避免在进一步嵌套信号的名称中出现双下划线 `__`。


```scala
// 原始代码块中的标记: mdoc
class TemporaryPrefixExample extends Module {
  val in0 = IO(Input(UInt(2.W)))
  val in1 = IO(Input(UInt(2.W)))
  val out0 = IO(Output(UInt(3.W)))
  val out1 = IO(Output(UInt(4.W)))

  val _sum = {
    val x = in0 + in1
    out0 := x
    x + 1.U
  }
  out1 := _sum & 0x2.U
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new TemporaryPrefixExample)
```


### Set a Module Name

如果您想指定模块的名称（而不是模块实例的名称），可以始终覆盖 `desiredName` 值。请注意，您可以通过模块的参数对名称进行参数化。这是使您的模块名称更稳定的好方法，强烈建议您这样做。

```scala
// 原始代码块中的标记: mdoc
class Example9(width: Int) extends Module {
  override val desiredName = s"EXAMPLE9WITHWIDTH$width"
  val in = IO(Input(UInt(width.W)))
  val out = IO(Output(UInt((width + 2).W)))

  val add = (in + (in + in).suggestName("foo"))

  out := add
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new Example9(8))
emitSystemVerilog(new Example9(1))
```
