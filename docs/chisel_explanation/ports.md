---
layout: docs
title:  "Ports"
section: "chisel3"
---

# 端口

端口用作硬件组件的接口。端口实际上就是一个 `Data` 对象，其成员都被赋予了方向。

Chisel 提供了端口构造器，允许在构造时为对象添加方向（输入或输出）。基本的端口构造器通过 `Input` 或 `Output` 包装端口的类型。

下面是一个端口声明的例子：

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
```

```scala
// 原始代码块中的标记: mdoc
class Decoupled extends Bundle {
  val ready = Output(Bool())
  val data  = Input(UInt(32.W))
  val valid = Input(Bool())
}
```

在定义了 ```Decoupled``` 之后，它就成为了一个新的类型，可以根据需要用于模块接口或命名的线集合。

通过将方向信息折叠到对象声明中，Chisel 能够提供后面将要描述的强大的接线构造。

## 检查模块端口

(Chisel 3.2+)

Chisel 3.2 引入了 `DataMirror.modulePorts`，可以用来检查任何 Chisel 模块的 IO（这包括来自 `import chisel3._` 和 `import Chisel._` 的模块，以及来自这两个包的 BlackBox）。
以下是如何使用这个 API 的示例：

```scala
// 原始代码块中的标记: mdoc
import chisel3.reflect.DataMirror
import chisel3.stage.ChiselGeneratorAnnotation

class Adder extends Module {
  val a = IO(Input(UInt(8.W)))
  val b = IO(Input(UInt(8.W)))
  val c = IO(Output(UInt(8.W)))
  c := a +& b
}

class Test extends Module {
  val adder = Module(new Adder)
  // 仅用于调试
  adder.a := DontCare
  adder.b := DontCare

  // 检查 adder 的端口
  // 查看下面的结果
  DataMirror.modulePorts(adder).foreach { case (name, port) => {
    println(s"Found port $name: $port")
  }}
}
```

这将打印以下内容：
```scala
// 原始代码块中的标记: mdoc:passthrough
println("```")
chisel3.docs.emitSystemVerilog(new Test): Unit // 抑制字符串输出，只想看到标准输出
println("```")
```
