---
layout: docs
title:  "Printing"
section: "chisel3"
---

# Chisel 中的打印

Chisel 提供 `printf` 函数用于调试目的。它有两种风格：

* [Scala 风格](#scala-风格)
* [C 风格](#c-风格)

Chisel 还提供了"日志"支持，除了默认的标准错误输出外，还可以打印到文件，详见[日志](#日志)。

## Scala 风格

Chisel 也支持类似于 [Scala 字符串插值](http://docs.scala-lang.org/overviews/core/string-interpolation.html) 的 printf 风格。Chisel 提供了一个自定义的字符串插值器 `cf`，它遵循 C 风格的格式说明符（参见下面的 [C 风格](#c-风格) 部分）。

注意，Scala 的 s-插值器在 Chisel 构造中不受支持，会抛出错误：

```scala mdoc:invisible
import chisel3._
```

```scala mdoc:fail
class MyModule extends Module {
  val in = IO(Input(UInt(8.W)))
  printf(s"in = $in\n")
}
```

相反，请使用 Chisel 的 `cf` 插值器，如下例所示：

```scala mdoc:compile-only
val myUInt = 33.U
printf(cf"myUInt = $myUInt") // myUInt = 33
```

注意，当连接 `cf"..."` 字符串时，你需要以 `cf"..."` 字符串开头：

```scala mdoc:compile-only
// 不会对第二个字符串进行插值
val myUInt = 33.U
printf("my normal string" + cf"myUInt = $myUInt")
```

### 简单格式化

其他格式可用如下：

```scala mdoc:compile-only
val myUInt = 33.U
// 十六进制
printf(cf"myUInt = 0x$myUInt%x") // myUInt = 0x21
// 二进制
printf(cf"myUInt = $myUInt%b") // myUInt = 100001
// 字符
printf(cf"myUInt = $myUInt%c") // myUInt = !
```

### 特殊值

在你的 `cf` 插值字符串中可以包含一些特殊值：

* `HierarchicalModuleName` (`%m`)：当前模块的层次名称
* `SimulationTime` (`%T`)：当前仿真时间（与 Verilog 的 `%t` 不同，它不接受参数）
* `Percent` (`%%`)：字面上的 `%`

```scala mdoc:compile-only
printf(cf"hierarchical path = $HierarchicalModuleName\n") // hierarchical path = <verilog.module.path>
printf(cf"hierarchical path = %m\n") // 等同于上面的例子

printf(cf"simulation time = $SimulationTime\n") // simulation time = <simulation.time>
printf(cf"simulation time = %T\n") // 等同于上面的例子

printf(cf"100$Percent\n") // 100%
printf(cf"100%%\n") // 等同于上面的例子
```

### 格式修饰符

Chisel 支持 `%d`、`%x` 和 `%b` 的标准 Verilog 风格修饰符，位于 `%` 和格式说明符之间。

Verilog 模拟器会将值填充到信号的宽度。
对于十进制格式，使用空格进行填充。
对于所有其他格式，使用 `0` 进行填充。

* 非负字段宽度会覆盖默认的 Verilog 值大小。
* 指定字段宽度为 `0` 将始终以最小宽度显示值（无零填充和空格填充）。

```scala mdoc:compile-only
val foo = WireInit(UInt(32.W), 33.U)
printf(cf"foo = $foo%d!\n")  // foo =         33!
printf(cf"foo = $foo%0d!\n") // foo = 33!
printf(cf"foo = $foo%4d!\n") // foo =   33!
printf(cf"foo = $foo%x!\n")  // foo = 00000021!
printf(cf"foo = $foo%0x!\n") // foo = 21!
printf(cf"foo = $foo%4x!\n") // foo = 0021!
val bar = WireInit(UInt(8.W), 5.U)
printf(cf"bar = $bar%b!\n")  // foo = 00000101!
printf(cf"bar = $bar%0b!\n") // foo = 101!
printf(cf"bar = $bar%4b!\n") // foo = 0101!
```

### 聚合数据类型

Chisel 为 Vec 和 Bundle 提供了默认的自定义"美化打印"功能。Vec 的默认打印类似于打印 Scala 的 Seq 或 List，而打印 Bundle 类似于打印 Scala Map。

```scala mdoc:compile-only
val myVec = VecInit(5.U, 10.U, 13.U)
printf(cf"myVec = $myVec") // myVec = Vec(5, 10, 13)

val myBundle = Wire(new Bundle {
  val foo = UInt()
  val bar = UInt()
})
myBundle.foo := 3.U
myBundle.bar := 11.U
printf(cf"myBundle = $myBundle") // myBundle = Bundle(a -> 3, b -> 11)
```

### 自定义打印

Chisel 还提供了为用户定义的 Bundle 指定自定义打印格式的功能。

```scala mdoc:compile-only
class Message extends Bundle {
  val valid = Bool()
  val addr = UInt(32.W)
  val length = UInt(4.W)
  val data = UInt(64.W)
  
  override def toPrintable: Printable = {
    cf"Message:\n" +
    cf"  valid  : $valid\n" +
    cf"  addr   : 0x$addr%x\n" +
    cf"  length : $length\n" +
    cf"  data   : 0x$data%x"
  }
}

val myMessage = Wire(new Message)
myMessage.valid := true.B
myMessage.addr := "h1234".U
myMessage.length := 10.U
myMessage.data := "hdeadbeef".U

printf(cf"$myMessage")
```

打印结果将如下：

```
Message:
  valid  : 1
  addr   : 0x00001234
  length : 10
  data   : 0x00000000deadbeef
```

注意 `cf` 插值"字符串"之间使用 `+` 的用法。`cf` 插值的结果可以使用 `+` 运算符连接。

## C 风格

Chisel 提供 `printf`，其风格类似于 C 语言的 `printf`。它接受一个双引号括起来的格式字符串和可变数量的参数，这些参数将在上升沿时被打印。Chisel 支持以下格式说明符：

| 格式说明符 | 含义 |
| :-----: | :-----: |
| `%d` | 十进制数 |
| `%x` | 十六进制数 |
| `%b` | 二进制数 |
| `%c` | 8 位 ASCII 字符 |
| `%n` | 信号名称 |
| `%N` | 信号的全名 |
| `%%` | 字面上的百分号 |
| `%m` | 层次名称 |
| `%T` | 仿真时间 |

`%d`、`%x` 和 `%b` 支持上述[格式修饰符](#格式修饰符)部分描述的修饰符。

它还支持一小部分转义字符：

| 转义字符 | 含义 |
| :-----: | :-----: |
| `\n` | 换行 |
| `\t` | 制表符 |
| `\"` | 字面上的双引号 |
| `\'` | 字面上的单引号 |
| `\\` | 字面上的反斜杠 |

注意，单引号不需要转义，但转义是合法的。

因此，`printf` 的使用方式与 C 语言中非常相似：

```scala mdoc:compile-only
val myUInt = 32.U
printf("myUInt = %d", myUInt) // myUInt = 32
```

## 日志

Chisel 通过 `SimLog` API 支持日志记录。
`SimLog` 提供了一种将仿真日志写入文件或标准错误的方法。当你需要以下功能时，它特别有用：
* 将仿真输出写入特定文件。
* 在单个仿真中拥有多个日志文件。
* 编写可重用的代码，以便可以针对不同的日志目标。

### 基本用法

`SimLog` 最常见的用法是写入文件：

```scala mdoc:compile-only
class MyModule extends Module {
  val log = SimLog.file("logfile.log")
  val in = IO(Input(UInt(8.W)))
  log.printf(cf"in = $in%d\n")
}
```

你也可以使用默认文件描述符写入标准错误：

```scala mdoc:compile-only
class MyModule extends Module {
  val log = SimLog.StdErr
  val in = IO(Input(UInt(8.W)))
  log.printf(cf"in = $in%d\n")
}
```

:::note
这与标准的 `printf` 是相同的。
:::

SimLog 文件名本身可以是 `Printable` 值：

```scala mdoc:compile-only
class MyModule extends Module {
  val idx = IO(Input(UInt(8.W)))
  val log = SimLog.file(cf"logfile_$idx%0d.log")
  val in = IO(Input(UInt(8.W)))
  log.printf(cf"in = $in%d\n")
}
```

强烈建议在文件名中使用 `%0d` 与 UInts 一起使用，以避免文件名中出现空格。

:::warning
注意避免在文件名中使用未初始化的寄存器。
:::

### 编写通用代码

`SimLog` 允许你编写可以与任何日志目标一起使用的代码。这在创建可重用组件时非常有用：

```scala mdoc:compile-only
class MyLogger(log: SimLog) extends Module {
  val in = IO(Input(UInt(8.W)))
  log.printf(cf"in = $in%d\n")
}

// 使用文件
val withFile = Module(new MyLogger(SimLog.file("data.log")))

// 使用标准错误
val withStderr = Module(new MyLogger(SimLog.StdErr))
```

### 刷新

`SimLog` 对象可以被刷新，以确保所有缓冲的输出都被写入。
这在使用被记录的输出作为协同仿真组件（如检查器或黄金模型）的输入时非常有用。

```scala mdoc:compile-only
val log = SimLog.file("logfile.log")
val in = IO(Input(UInt(8.W)))
log.printf(cf"in = $in%d\n")
log.flush() // 立即刷新缓冲的输出。
```

你也可以刷新标准错误：

```scala mdoc:compile-only
SimLog.StdErr.flush() // 这将刷新所有标准输出。
```