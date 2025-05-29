---
layout: docs
title:  "内部函数"
section: "chisel3"
---

# 内部函数

Chisel *内部函数（Intrinsics）*用于表达实现定义的功能。
内部函数为特定编译器提供了一种方式，可以扩展语言的功能，而这些功能无法通过库代码实现。

内部函数将由实现进行类型检查。可用的内部函数由实现文档记录。

`Intrinsic`和`IntrinsicExpr`可用于创建内部函数语句和表达式。

### 参数化

参数可以作为参数传递给IntModule构造函数。

### 内部函数表达式示例

以下代码为名为"MyIntrinsic"的内部函数创建一个内部函数。
它接受一个名为"STRING"的参数，并有几个输入。

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
// Below is required for scala 3 migration
import chisel3.experimental.fromStringToStringParam
```

```scala
// 原始代码块中的标记: mdoc:compile-only
class Foo extends RawModule {
  val myresult = IntrinsicExpr("MyIntrinsic", UInt(32.W), "STRING" -> "test")(3.U, 5.U)
}
```
