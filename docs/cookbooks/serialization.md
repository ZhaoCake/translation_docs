
# 序列化手册

[TOC]

## 为什么需要序列化模块
Chisel提供了非常灵活的硬件设计体验。但是，在设计相对大型的设计时，有时会变得过于灵活，因为模块的参数可能来自：1. 全局变量；2. 外部类；3. 熵（时间、随机）。这使得描述"如何复现这个单一模块？"变得非常困难或不可能。这禁止对模块生成器进行单元测试，并在进行ECO的后合成阶段引入问题：对模块A的更改可能导致模块B的更改。
因此，提供了`SerializableModuleGenerator`、`SerializableModule[T <: SerializableModuleParameter]`和`SerializableModuleParameter`来解决这些问题。
对于任何`SerializableModuleGenerator`，Chisel可以通过添加这些约束来自动序列化和反序列化它：
1. `SerializableModule`不应该是内部类，因为外部类是它的一个参数；
1. `SerializableModule`有且只有一个参数，其类型为`SerializableModuleParameter`。
1. 模块既不依赖于全局变量，也不使用不可重现的函数（随机、时间等），这应该由用户保证，因为Scala无法检测它。

它可以提供这些好处：
1. 用户可以使用`SerializableModuleGenerator(module: class[SerializableModule], parameter: SerializableModuleParameter)`来自动序列化模块及其参数。
1. 用户可以在其他可序列化参数中嵌套`SerializableModuleGenerator`以表示相对较大的参数。
1. 用户可以将任何`SerializableModuleGenerator`详细说明为单个模块进行测试。


## 如何使用`SerializableModuleGenerator`序列化模块
这非常简单，如下面的例子所示，`GCD`模块以`width`作为其参数。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
import chisel3.experimental.{SerializableModule, SerializableModuleGenerator, SerializableModuleParameter}
import upickle.default._

// 为GCDSerializableModuleParameter提供序列化函数
object GCDSerializableModuleParameter {
  implicit def rwP: ReadWriter[GCDSerializableModuleParameter] = macroRW
}

// 参数
case class GCDSerializableModuleParameter(width: Int) extends SerializableModuleParameter

// 模块
class GCDSerializableModule(val parameter: GCDSerializableModuleParameter)
    extends Module
    with SerializableModule[GCDSerializableModuleParameter] {
  val io = IO(new Bundle {
    val a = Input(UInt(parameter.width.W))
    val b = Input(UInt(parameter.width.W))
    val e = Input(Bool())
    val z = Output(UInt(parameter.width.W))
  })
  val x = Reg(UInt(parameter.width.W))
  val y = Reg(UInt(parameter.width.W))
  val z = Reg(UInt(parameter.width.W))
  val e = Reg(Bool())
  when(e) {
    x := io.a
    y := io.b
    z := 0.U
  }
  when(x =/= y) {
    when(x > y) {
      x := x - y
    }.otherwise {
      y := y - x
    }
  }.otherwise {
    z := x
  }
  io.z := z
}
```
使用`upickle`中的`write`函数，它应该返回一个json字符串：
```scala mdoc
val j = upickle.default.write(
  SerializableModuleGenerator(
    classOf[GCDSerializableModule],
    GCDSerializableModuleParameter(32)
  )
)
```

然后，您可以从json字符串读取并详细说明模块：
```scala mdoc:compile-only
circt.stage.ChiselStage.emitSystemVerilog(
  upickle.default.read[SerializableModuleGenerator[GCDSerializableModule, GCDSerializableModuleParameter]](
    ujson.read(j)
  ).module()
)
