---
layout: docs
title:  "Bundle和Vec"
section: "chisel3"
---

# Bundle和Vec

`Bundle`和`Vec`是允许用户通过聚合其他类型来扩展Chisel数据类型集合的类。

Bundle将几个可能具有不同类型的命名字段组合成一个连贯的单元，很像C语言中的`struct`。用户通过定义一个作为`Bundle`子类的类来定义自己的bundle。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class MyFloat extends Bundle {
  val sign        = Bool()
  val exponent    = UInt(8.W)
  val significand = UInt(23.W)
}

class ModuleWithFloatWire extends RawModule {
  val x  = Wire(new MyFloat)
  val xs = x.sign
}
```

你可以使用实验性的[Bundle字面量](../appendix/experimental-features#bundle-literals)功能创建字面量Bundle。

Scala的惯例是使用UpperCamelCase命名类，我们建议你在Chisel代码中遵循这一惯例。

Vec创建一个可索引的元素向量，构造方式如下：

```scala
// 原始代码块中的标记: mdoc:silent
class ModuleWithVec extends RawModule {
  // 5个23位有符号整数的向量。
  val myVec = Wire(Vec(5, SInt(23.W)))

  // 连接到向量的一个元素。
  val reg3 = myVec(3)
}
```

（注意我们指定了数量，然后是`Vec`元素的类型。我们还指定了`SInt`的宽度）

原始类(`SInt`, `UInt`和`Bool`)加上聚合类(`Bundle`和`Vec`)都继承自一个共同的超类`Data`。每个最终继承自`Data`的对象都可以在硬件设计中表示为一个位向量。

Bundle和Vec可以任意嵌套以构建复杂的数据结构：

```scala
// 原始代码块中的标记: mdoc:silent
class BigBundle extends Bundle {
 // 5个23位有符号整数的向量。
 val myVec = Vec(5, SInt(23.W))
 val flag  = Bool()
 // 先前定义的bundle。
 val f     = new MyFloat
}
```

注意，内置的Chisel原始和聚合类在创建实例时不需要`new`，而新的用户数据类型则需要。可以定义一个Scala的`apply`构造函数，使得用户数据类型也不需要`new`，这在[函数构造器](../explanations/functional-module-creation)中有描述。

### 翻转Bundle

`Flipped()`函数递归地翻转Bundle/Record中的所有元素。这对于构建相互连接的双向接口非常有用（例如`Decoupled`）。请看下面的例子。

```scala
// 原始代码块中的标记: mdoc:silent
class ABBundle extends Bundle {
  val a = Input(Bool())
  val b = Output(Bool())
}
class MyFlippedModule extends RawModule {
  // Bundle的正常实例化
  // 'a'是输入，'b'是输出
  val normalBundle = IO(new ABBundle)
  normalBundle.b := normalBundle.a

  // Flipped递归地翻转所有Bundle字段的方向
  // 现在'a'是输出，'b'是输入
  val flippedBundle = IO(Flipped(new ABBundle))
  flippedBundle.a := flippedBundle.b
}
```

这会生成以下Verilog：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new MyFlippedModule())
```

### MixedVec

(Chisel 3.2+)

`Vec`的所有元素必须具有相同的参数化。如果我们想创建一个Vec，其中元素具有相同的类型但不同的参数化，我们可以使用MixedVec：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.util.MixedVec
class ModuleMixedVec extends Module {
  val io = IO(new Bundle {
    val x = Input(UInt(3.W))
    val y = Input(UInt(10.W))
    val vec = Output(MixedVec(UInt(3.W), UInt(10.W)))
  })
  io.vec(0) := io.x
  io.vec(1) := io.y
}
```

我们也可以以编程方式创建MixedVec中的类型：

```scala
// 原始代码块中的标记: mdoc:silent
class ModuleProgrammaticMixedVec(x: Int, y: Int) extends Module {
  val io = IO(new Bundle {
    val vec = Input(MixedVec((x to y) map { i => UInt(i.W) }))
    // ...
  })
  // ...模块的其余部分放在这里...
}
```

### 关于`cloneType`的说明（对于Chisel < 3.5）

注意：此部分**仅适用于Chisel 3.5之前的版本**。
从Chisel 3.5开始，`Bundle`**不应该**`override def cloneType`，
因为当使用chisel3编译器插件推断`cloneType`时，这会导致编译器错误。

由于Chisel建立在Scala和JVM之上，
它需要知道如何为各种目的构造`Bundle`的副本
（创建线网、IO等）。
如果你有一个参数化的`Bundle`，而Chisel无法自动弄清楚如何
克隆它，你将需要在你的bundle中创建一个自定义的`cloneType`方法。
在绝大多数情况下，**这不是必需的**，
因为Chisel可以自动弄清楚如何克隆大多数`Bundle`：

```scala
// 原始代码块中的标记: mdoc:silent
class MyCloneTypeBundle(val bitwidth: Int) extends Bundle {
   val field = UInt(bitwidth.W)
   // ...
}
```

唯一的注意事项是，如果你将类型为`Data`的东西作为"生成器"参数传递，
在这种情况下，你应该将其设为`private val`，并定义一个`cloneType`方法，
使用`override def cloneType = (new YourBundleHere(...)).asInstanceOf[this.type]`。

例如，考虑以下`Bundle`。因为它的`gen`变量不是`private val`，用户必须
显式定义`cloneType`方法：

<!-- 无法编译这个，因为cloneType现在是一个错误 -->
```scala
import chisel3.util.{Decoupled, Irrevocable}
class RegisterWriteIOExplicitCloneType[T <: Data](gen: T) extends Bundle {
  val request  = Flipped(Decoupled(gen))
  val response = Irrevocable(Bool())
  override def cloneType = new RegisterWriteIOExplicitCloneType(gen).asInstanceOf[this.type]
}
```

我们可以通过将`gen`设为private来使其推断cloneType，因为它是一个"类型参数"：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.util.{Decoupled, Irrevocable}
class RegisterWriteIO[T <: Data](private val gen: T) extends Bundle {
  val request  = Flipped(Decoupled(gen))
  val response = Irrevocable(Bool())
}
```
