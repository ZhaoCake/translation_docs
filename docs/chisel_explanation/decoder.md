---
layout: docs
title:  "解码器"
section: "chisel3"
---

# 解码器

在复杂设计中，从数据总线来的大型`UInt`识别特定模式并基于这种观察将动作分派到下一个流水线阶段是很常见的。执行此操作的电路可以称为"解码器"，例如总线交叉开关中的地址解码器或CPU前端的指令解码器。Chisel在`util.exprimental.decode`包中提供了一些实用类来生成它们。

## 基本解码器
`decoder`提供的最简单API本质上只是一个编码您所需输入和输出的`TruthTable`。
```scala mdoc:silent
import chisel3._
import chisel3.util.BitPat
import chisel3.util.experimental.decode._

class SimpleDecoder extends Module {
  val table = TruthTable(
    Map(
      BitPat("b001") -> BitPat("b?"),
      BitPat("b010") -> BitPat("b?"),
      BitPat("b100") -> BitPat("b1"),
      BitPat("b101") -> BitPat("b1"),
      BitPat("b111") -> BitPat("b1")
    ),
    BitPat("b0"))
  val input = IO(Input(UInt(3.W)))
  val output = IO(Output(UInt(1.W)))
  output := decoder(input, table)
}
```

## DecoderTable
当解码结果涉及多个字段，每个字段具有自己的语义时，`TruthTable`很快就会变得难以维护。`DecoderTable` API旨在从结构化定义生成解码器表。

从结构化信息到其编码的桥梁是`DecodePattern`特质。`bitPat`成员定义了解码真值表中的输入`BitPat`，其他成员可以定义为包含结构化信息。

要生成解码真值表的输出端，要使用的特质是`DecodeField`。给定一个实现`DecodePattern`对象的实例，`genTable`方法应返回所需的输出。

```scala mdoc:silent
import chisel3.util.BitPat
import chisel3.util.experimental.decode._

case class Pattern(val name: String, val code: BigInt) extends DecodePattern {
  def bitPat: BitPat = BitPat("b" + code.toString(2))
}

object NameContainsAdd extends BoolDecodeField[Pattern] {
  def name = "name contains 'add'"
  def genTable(i: Pattern) = if (i.name.contains("add")) y else n
}
```

然后所有`DecodePattern`案例可以从外部源生成或读取。有了所有`DecodeField`对象，解码器可以轻松生成，输出可以由相应的`DecodeField`读取。
```scala mdoc:silent
import chisel3._
import chisel3.util.experimental.decode._

class SimpleDecodeTable extends Module {
  val allPossibleInputs = Seq(Pattern("addi", BigInt("0x2")) /* 可以生成 */)
  val decodeTable = new DecodeTable(allPossibleInputs, Seq(NameContainsAdd))
  
  val input = IO(Input(UInt(4.W)))
  val isAddType = IO(Output(Bool()))
  val decodeResult = decodeTable.decode(input)
  isAddType := decodeResult(NameContainsAdd)
}
```
