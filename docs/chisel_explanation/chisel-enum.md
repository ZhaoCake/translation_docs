---
layout: docs
title:  "枚举"
section: "chisel3"
---

# ChiselEnum

ChiselEnum类型可用于减少在编码多路复用器选择器、操作码和功能单元操作时出错的可能性。
与`Chisel.util.Enum`相比，`ChiselEnum`是`Data`的子类，这意味着它们可以用于定义`Bundle`中的字段，包括在`IO`中。

## 功能和示例

```scala
// 原始代码块中的标记: mdoc
// 在以下示例中使用的导入
import chisel3._
import chisel3.util._
```

```scala
// 原始代码块中的标记: mdoc:invisible
// 用于打印来自Chisel elab的stdout的辅助程序
// 可能与以下问题有关：https://github.com/scalameta/mdoc/issues/517
import java.io._
import firrtl.seqToAnnoSeq
import _root_.logger.Logger
def grabLog[T](thunk: => T): (String, T) = {
  val baos = new ByteArrayOutputStream()
  val stream = new PrintStream(baos, true, "utf-8")
  val ret = Logger.makeScope(Nil) {
   Logger.setOutput(stream)
   thunk
  }
  (baos.toString, ret)
}
```

下面我们看到ChiselEnum被用作RISC-V核的多路复用器选择器。虽然将对象包装在包中不是必需的，但强烈建议这样做，因为这样可以更容易地在多个文件中使用该类型。

```scala
// 原始代码块中的标记: mdoc
// package CPUTypes {
object AluMux1Sel extends ChiselEnum {
  val selectRS1, selectPC = Value
}
// 我们可以通过打印每个Value来查看映射
AluMux1Sel.all.foreach(println)
```

这里我们看到一个使用AluMux1Sel的多路复用器，用于在不同输入之间进行选择。

```scala
// 原始代码块中的标记: mdoc
import AluMux1Sel._

class AluMux1Bundle extends Bundle {
  val aluMux1Sel = Input(AluMux1Sel())
  val rs1Out     = Input(Bits(32.W))
  val pcOut      = Input(Bits(32.W))
  val aluMux1Out = Output(Bits(32.W))
}

class AluMux1File extends Module {
  val io = IO(new AluMux1Bundle)

  // aluMux1Out的默认值
  io.aluMux1Out := 0.U

  switch (io.aluMux1Sel) {
    is (selectRS1) {
      io.aluMux1Out := io.rs1Out
    }
    is (selectPC) {
      io.aluMux1Out := io.pcOut
    }
  }
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new AluMux1File)
```

ChiselEnum还允许用户通过向`Value(...)`传递一个`UInt`来直接设置值，
如下所示。注意，每个`Value`的大小必须严格大于前一个。

```scala
// 原始代码块中的标记: mdoc
object Opcode extends ChiselEnum {
    val load  = Value(0x03.U) // i "load"  -> 000_0011
    val imm   = Value(0x13.U) // i "imm"   -> 001_0011
    val auipc = Value(0x17.U) // u "auipc" -> 001_0111
    val store = Value(0x23.U) // s "store" -> 010_0011
    val reg   = Value(0x33.U) // r "reg"   -> 011_0011
    val lui   = Value(0x37.U) // u "lui"   -> 011_0111
    val br    = Value(0x63.U) // b "br"    -> 110_0011
    val jalr  = Value(0x67.U) // i "jalr"  -> 110_0111
    val jal   = Value(0x6F.U) // j "jal"   -> 110_1111
}
```

用户可以通过传递一个起始点然后使用常规Value定义，"跳跃"到一个值并继续递增。

```scala
// 原始代码块中的标记: mdoc
object BranchFunct3 extends ChiselEnum {
    val beq, bne = Value
    val blt = Value(4.U)
    val bge, bltu, bgeu = Value
}
// 我们可以通过打印每个Value来查看映射
BranchFunct3.all.foreach(println)
```

## 类型转换

你可以使用`.asUInt`将枚举转换为`UInt`：

```scala
// 原始代码块中的标记: mdoc
class ToUInt extends RawModule {
  val in = IO(Input(Opcode()))
  val out = IO(Output(UInt(in.getWidth.W)))
  out := in.asUInt
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// 总是需要运行Chisel来查看是否有具体化错误
chisel3.docs.emitSystemVerilog(new ToUInt)
```

你可以通过将`UInt`传递给`ChiselEnum`对象的apply方法，从`UInt`转换为枚举：

```scala
// 原始代码块中的标记: mdoc
class FromUInt extends Module {
  val in = IO(Input(UInt(7.W)))
  val out = IO(Output(Opcode()))
  out := Opcode(in)
}
```

然而，如果你从`UInt`转换为Enum类型，而该Enum的值中有未定义的状态
可能被`UInt`命中，你将看到类似如下的警告：

```scala
// 原始代码块中的标记: mdoc:passthrough
println("```")
_root_.circt.stage.ChiselStage.emitCHIRRTL(new FromUInt): Unit // Suppress String output
println("```")
```

（注意，由于我们的文档生成流程的特殊性，Enum的名称看起来很丑，在正常使用中
会更整洁）。

你可以通过使用`.safe`工厂方法来避免这个警告，该方法返回转换后的Enum以及
一个`Bool`，指示Enum是否处于有效状态：

```scala
// 原始代码块中的标记: mdoc
class SafeFromUInt extends Module {
  val in = IO(Input(UInt(7.W)))
  val out = IO(Output(Opcode()))
  val (value, valid) = Opcode.safe(in)
  assert(valid, "Enum状态必须有效，得到了%d！", in)
  out := value
}
```

现在将不会有警告：

```scala
// 原始代码块中的标记: mdoc:passthrough
println("```")
_root_.circt.stage.ChiselStage.emitCHIRRTL(new SafeFromUInt): Unit // Suppress String output
println("```")
```

你也可以使用`suppressEnumCastWarning`来抑制警告。这主要
用于从[[UInt]]转换为包含Enum的Bundle类型，
其中[[UInt]]已知对Bundle类型有效。

```scala
// 原始代码块中的标记: mdoc
class MyBundle extends Bundle {
  val addr = UInt(8.W)
  val op = Opcode()
}

class SuppressedFromUInt extends Module {
  val in = IO(Input(UInt(15.W)))
  val out = IO(Output(new MyBundle()))
  suppressEnumCastWarning {
    out := in.asTypeOf(new MyBundle)
  }
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
val (log3, _) = grabLog(_root_.circt.stage.ChiselStage.emitCHIRRTL(new SuppressedFromUInt))
assert(log3.isEmpty)
```

## 测试

枚举值的_类型_是`<ChiselEnum对象>.Type`，这对于将值作为参数传递给函数
（或任何其他需要类型注解的时候）非常有用。
在枚举值上调用`.litValue`将返回该对象的整数值，表示为
[`BigInt`](https://www.scala-lang.org/api/2.12.13/scala/math/BigInt.html)。

```scala
// 原始代码块中的标记: mdoc
def expectedSel(sel: AluMux1Sel.Type): Boolean = sel match {
  case AluMux1Sel.selectRS1 => (sel.litValue == 0)
  case AluMux1Sel.selectPC  => (sel.litValue == 1)
  case _                    => false
}
```

枚举值类型还定义了一些用于处理`ChiselEnum`值的便捷方法。例如，继续使用RISC-V操作码
示例，可以使用`.isOneOf`方法轻松创建一个硬件信号，该信号仅在LOAD/STORE操作时
（当枚举值等于`Opcode.load`或`Opcode.store`时）有效：

```scala
// 原始代码块中的标记: mdoc
class LoadStoreExample extends Module {
  val io = IO(new Bundle {
    val opcode = Input(Opcode())
    val load_or_store = Output(Bool())
  })
  io.load_or_store := io.opcode.isOneOf(Opcode.load, Opcode.store)
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// 总是需要运行Chisel来查看是否有具体化错误
chisel3.docs.emitSystemVerilog(new LoadStoreExample)
```

`ChiselEnum`对象上定义的一些其他有用方法有：

* `.all`：返回枚举中的枚举值
* `.getWidth`：返回硬件类型的宽度

## 解决方法

截至Chisel v3.4.3（2020年7月1日），值的宽度总是被推断。
为了解决这个问题，你可以添加一个额外的`Value`来强制使用所需的宽度。
在下面的例子中，我们添加了一个字段`ukn`来强制宽度为3位：

```scala
// 原始代码块中的标记: mdoc
object StoreFunct3 extends ChiselEnum {
    val sb, sh, sw = Value
    val ukn = Value(7.U)
}
// 我们可以通过打印每个Value来查看映射
StoreFunct3.all.foreach(println)
```

不支持有符号值，所以如果你想要有符号值，你必须使用`.asSInt`转换UInt。

## 其他资源

ChiselEnum类型比上面所述的更强大。它允许Sequence、Vec和Bundle赋值，以及使用`.next`操作
来允许逐步遍历顺序状态，并使用`.isValid`来检查硬件值是否是有效的`Value`。ChiselEnum的源代码可以在
[这里](https://github.com/chipsalliance/chisel3/blob/2a96767097264eade18ff26e1d8bce192383a190/core/src/main/scala/chisel3/StrongEnum.scala)
的`EnumFactory`类中找到。ChiselEnum操作的例子可以在
[这里](https://github.com/chipsalliance/chisel3/blob/dd6871b8b3f2619178c2a333d9d6083805d99e16/src/test/scala/chiselTests/StrongEnum.scala)找到。
