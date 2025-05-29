---
layout: docs
title:  "DataView"
section: "chisel3"
---

# DataView

_Chisel 3.5 中的新功能_

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
```

## 简介

DataView 是一种将 Scala 对象视为 `chisel3.Data` 子类型的机制。
通常，这对于将 `chisel3.Data` 的一个子类型视为另一个子类型很有用。
可以将 `DataView` 视为从 _目标_ 类型 `T` 到 _视图_ 类型 `V` 的映射。
这类似于类型转换（如 `.asTypeOf`），但有几个区别：
1. 视图是 _可连接的_ —对视图的连接将发生在目标上
2. 与结构性的类型转换（对底层位的重新解释）不同，DataView 是一种可定制的映射
3. 视图可以是 _部分的_ —目标中的每个字段不必都包含在映射中

## 一个激励性示例 (AXI4)

[AXI4](https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface) 是数字设计中常见的接口。
使用 AXI4 的典型 Verilog 外设将定义写通道，如下所示：
```verilog
module my_module(
  // Write Channel
  input        AXI_AWVALID,
  output       AXI_AWREADY,
  input [3:0]  AXI_AWID,
  input [19:0] AXI_AWADDR,
  input [1:0]  AXI_AWLEN,
  input [1:0]  AXI_AWSIZE,
  // ...
);
```

这将对应于以下 Chisel Bundle：

```scala
// 原始代码块中的标记: mdoc
class VerilogAXIBundle(val addrWidth: Int) extends Bundle {
  val AWVALID = Output(Bool())
  val AWREADY = Input(Bool())
  val AWID = Output(UInt(4.W))
  val AWADDR = Output(UInt(addrWidth.W))
  val AWLEN = Output(UInt(2.W))
  val AWSIZE = Output(UInt(2.W))
  // The rest of AW and other AXI channels here
}

// Instantiated as
class my_module extends RawModule {
  val AXI = IO(new VerilogAXIBundle(20))
}
```

在 Chisel 设计中将 Verilog 模块实例化为 `BlackBoxes` 时，表示与标准 Verilog 接口匹配的内容非常重要。
然而，Chisel 开发人员通常更喜欢通过像 `Decoupled` 这样的实用工具使用组合，而不是像上面那样平面地处理 `ready` 和 `valid`。
这个接口的更 "Chisel 化" 实现可能如下所示：

```scala
// 原始代码块中的标记: mdoc
// Note that both the AW and AR channels look similar and could use the same Bundle definition
class AXIAddressChannel(val addrWidth: Int) extends Bundle {
  val id = UInt(4.W)
  val addr = UInt(addrWidth.W)
  val len = UInt(2.W)
  val size = UInt(2.W)
  // ...
}
import chisel3.util.Decoupled
// We can compose the various AXI channels together
class AXIBundle(val addrWidth: Int) extends Bundle {
  val aw = Decoupled(new AXIAddressChannel(addrWidth))
  // val ar = new AXIAddressChannel
  // ... Other channels here ...
}
// Instantiated as
class MyModule extends RawModule {
  val axi = IO(new AXIBundle(20))
}
```

当然，这会导致看起来非常不同的 Verilog：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new MyModule {
  override def desiredName = "MyModule"
  axi := DontCare // Just to generate Verilog in this stub
})
```

那么，我们如何使用更结构化的类型同时保持预期的 Verilog 接口呢？
认识一下 DataView：

```scala
// 原始代码块中的标记: mdoc
import chisel3.experimental.dataview._

// We recommend putting DataViews in a companion object of one of the involved types
object AXIBundle {
  // Don't be afraid of the use of implicits, we will discuss this pattern in more detail later
  implicit val axiView: DataView[VerilogAXIBundle, AXIBundle] = DataView(
    // The first argument is a function constructing an object of View type (AXIBundle)
    // from an object of the Target type (VerilogAXIBundle)
    vab => new AXIBundle(vab.addrWidth),
    // The remaining arguments are a mapping of the corresponding fields of the two types
    _.AWVALID -> _.aw.valid,
    _.AWREADY -> _.aw.ready,
    _.AWID -> _.aw.bits.id,
    _.AWADDR -> _.aw.bits.addr,
    _.AWLEN -> _.aw.bits.len,
    _.AWSIZE -> _.aw.bits.size,
    // ...
  )
}
```

这个 `DataView` 是从我们平坦的、Verilog 风格的 AXI Bundle 到更具组合性的 Chisel 风格的 AXI Bundle 的映射。
它允许我们定义与预期的 Verilog 接口匹配的端口，同时操作它就像它是更结构化的类型：

```scala
// 原始代码块中的标记: mdoc
class AXIStub extends RawModule {
  val AXI = IO(new VerilogAXIBundle(20))
  val view = AXI.viewAs[AXIBundle]

  // We can now manipulate `AXI` via `view`
  view.aw.bits := 0.U.asTypeOf(new AXIAddressChannel(20)) // zero everything out by default
  view.aw.valid := true.B
  when (view.aw.ready) {
    view.aw.bits.id := 5.U
    view.aw.bits.addr := 1234.U
    // We can still manipulate AXI as well
    AXI.AWLEN := 1.U
  }
}
```

这将生成与标准命名约定匹配的 Verilog：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new AXIStub)
```

请注意，如果 _目标_ 和 _视图_ 类型都是 `Data` 的子类型（如本例中所示），
则 `DataView` 是 _可逆的_。
这意味着我们可以轻松地从现有的 `DataView[VerilogAXIBundle, AXIBundle]` 创建一个 `DataView[AXIBundle, VerilogAXIBundle]`，我们只需要提供一个函数，从 `AXIBundle` 的实例构造一个 `VerilogAXIBundle`：

```scala
// 原始代码块中的标记: mdoc:silent
// Note that typically you should define these together (eg. inside object AXIBundle)
implicit val axiView2: DataView[AXIBundle, VerilogAXIBundle] = AXIBundle.axiView.invert(ab => new VerilogAXIBundle(ab.addrWidth))
```

以下示例展示了这一点，并说明了 `DataView` 的另一个用例 — 连接不相关的类型：

```scala
// 原始代码块中的标记: mdoc
class ConnectionExample extends RawModule {
  val in = IO(new AXIBundle(20))
  val out = IO(Flipped(new VerilogAXIBundle(20)))
  out.viewAs[AXIBundle] <> in
}
```

这导致相应的字段在生成的 Verilog 中连接：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new ConnectionExample)
```

## 其他用例

虽然在 AXI4 示例中映射 `Bundle` 类型的能力非常引人注目，
但 DataView 还有许多其他应用。
重要的是，由于 `DataView` 的 _目标_ 不必是 `Data`，它提供了一种使用
`非 Data` 对象与需要 `Data` 的 API 的方法。

### 元组

对于 `非 Data` 类型来说，`DataView` 最有用的用途之一就是将 Scala 元组视为 `Bundles`。
例如，在引入 `DataView` 之前的 Chisel 中，有人可能尝试对元组使用 `Mux`，
并看到如下错误：

<!-- Todo will need to ensure built-in code for Tuples is suppressed once added to stdlib -->

```scala
// 原始代码块中的标记: mdoc:fail
class TupleExample extends RawModule {
  val a, b, c, d = IO(Input(UInt(8.W)))
  val cond = IO(Input(Bool()))
  val x, y = IO(Output(UInt(8.W)))
  (x, y) := Mux(cond, (a, b), (c, d))
}
```

问题是，像 `Mux` 和 `:=` 这样的 Chisel 原语只对 `Data` 的子类型进行操作，
而元组（作为 Scala 标准库的成员）不是 `Data` 的子类。
`DataView` 提供了一种机制，可以 _查看_ `Tuple` 就像它是一个 `Data`：

```scala
// 原始代码块中的标记: mdoc
// We need a type to represent the Tuple
class HWTuple2[A <: Data, B <: Data](val _1: A, val _2: B) extends Bundle

// Provide DataView between Tuple and HWTuple
implicit def view[A <: Data, B <: Data]: DataView[(A, B), HWTuple2[A, B]] =
  DataView(tup => new HWTuple2(tup._1.cloneType, tup._2.cloneType),
           _._1 -> _._1, _._2 -> _._2)
```

现在，我们可以使用 `.viewAs` 将元组视为 `Data` 的子类型：

```scala
// 原始代码块中的标记: mdoc
class TupleVerboseExample extends RawModule {
  val a, b, c, d = IO(Input(UInt(8.W)))
  val cond = IO(Input(Bool()))
  val x, y = IO(Output(UInt(8.W)))
  (x, y).viewAs[HWTuple2[UInt, UInt]] := Mux(cond, (a, b).viewAs[HWTuple2[UInt, UInt]], (c, d).viewAs[HWTuple2[UInt, UInt]])
}
```

这比直接使用元组就像它们是 `Data` 一样的原始想法要冗长得多。
我们可以通过提供一个隐式转换来改进它，该转换将 `Tuple` 视为 `HWTuple2`：

```scala
// 原始代码块中的标记: mdoc
import scala.language.implicitConversions
implicit def tuple2hwtuple[A <: Data, B <: Data](tup: (A, B)): HWTuple2[A, B] =
  tup.viewAs[HWTuple2[A, B]]
```

现在，原始代码就可以工作了！

```scala
// 原始代码块中的标记: mdoc
class TupleExample extends RawModule {
  val a, b, c, d = IO(Input(UInt(8.W)))
  val cond = IO(Input(Bool()))
  val x, y = IO(Output(UInt(8.W)))
  (x, y) := Mux(cond, (a, b), (c, d))
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Always emit Verilog to make sure it actually works
chisel3.docs.emitSystemVerilog(new TupleExample)
```

请注意，这个例子忽略了 `DataProduct`，它是另一个必需的部分（参见[下面关于它的文档](#dataproduct)）。

所有这些通过单个导入即可供用户使用：
```scala
// 原始代码块中的标记: mdoc:reset
import chisel3.experimental.conversions._
```

## 全面性和 PartialDataView

```scala
// 原始代码块中的标记: mdoc:reset:invisible
import chisel3._
import chisel3.experimental.dataview._
```

如果 _目标_ 类型的所有字段和 _视图_ 类型的所有字段都包含在映射中，则 `DataView` 是 _全面的_。
如果不小心遗漏了 `DataView` 中的字段，Chisel 将报错。
例如：

```scala
// 原始代码块中的标记: mdoc
class BundleA extends Bundle {
  val foo = UInt(8.W)
  val bar = UInt(8.W)
}
class BundleB extends Bundle {
  val fizz = UInt(8.W)
}
```

```scala
// 原始代码块中的标记: mdoc:crash
// We forgot BundleA.foo in the mapping!
implicit val myView: DataView[BundleA, BundleB] = DataView(_ => new BundleB, _.bar -> _.fizz)
class BadMapping extends Module {
   val in = IO(Input(new BundleA))
   val out = IO(Output(new BundleB))
   out := in.viewAs[BundleB]
}
// We must run Chisel to see the error
getVerilogString(new BadMapping)
```

正如该错误所暗示的，如果我们 *想要* 视图是非全面的，我们可以使用 `PartialDataView`：

```scala
// 原始代码块中的标记: mdoc
// A PartialDataView does not have to be total for the Target
implicit val myView: DataView[BundleA, BundleB] = PartialDataView[BundleA, BundleB](_ => new BundleB, _.bar -> _.fizz)
class PartialDataViewModule extends Module {
   val in = IO(Input(new BundleA))
   val out = IO(Output(new BundleB))
   out := in.viewAs[BundleB]
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new PartialDataViewModule)
```

虽然 `PartialDataViews` 对于 _目标_ 不必是全面的，但 `PartialDataViews` 和 `DataViews`
必须始终对 _视图_ 是全面的。
这导致 `PartialDataViews` **不能** 以与 `DataViews` 相同的方式进行反转。

例如：

```scala
// 原始代码块中的标记: mdoc:crash
implicit val myView2 = myView.invert(_ => new BundleA)
class PartialDataViewModule2 extends Module {
   val in = IO(Input(new BundleA))
   val out = IO(Output(new BundleB))
   // Using the inverted version of the mapping
   out.viewAs[BundleA] := in
}
// We must run Chisel to see the error
getVerilogString(new PartialDataViewModule2)
```

如前所述，映射**始终**必须对 `视图` 是全面的。

## 高级详情

`DataView` 利用了 Scala 的特性，这些特性对许多 Chisel 用户来说可能是新的——特别是
[类型类](#type-classes)。

### 类型类

[类型类](https://en.wikipedia.org/wiki/Type_class)是编写多态代码的强大语言特性。
它们是 "现代编程语言" 如
Scala、
Swift（参见[协议](https://docs.swift.org/swift-book/LanguageGuide/Protocols.html)）
和 Rust（参见[特质](https://doc.rust-lang.org/book/ch10-02-traits.html)）中的常见特性。
类型类可能看起来类似于面向对象编程中的继承，但有一些
重要的区别：

1. 你可以为你不拥有的类型提供类型类（例如，在第三方库中定义的类型，
  Scala 标准库或 Chisel 本身）
2. 你可以为没有子类型关系的多种类型编写单个类型类
3. 你可以为同一类型提供多个不同的类型类

对于 `DataView`，（1）是至关重要的，因为我们希望能够实现内置 Scala
类型（如元组和 `Seqs`）的 `DataViews`。此外，`DataView` 有两个类型参数（_目标_ 和
_视图_ 类型），所以继承并不真正有意义——哪种类型会 `扩展` `DataView`？

在 Scala 2 中，类型类不是内置的语言特性，而是使用 implicits 实现的。
有兴趣的读者可以参考这些很好的资源：
* [基本教程](https://scalac.io/blog/typeclasses-in-scala/)
* [StackOverflow 上的精彩解释](https://stackoverflow.com/a/5598107/2483329)

请注意，Scala 3 已经添加了内置的类型类语法，但这不适用于 Chisel 3，
Chisel 3 目前只支持 Scala 2。

### 隐式解析

鉴于 `DataView` 是使用隐式实现的，了解隐式解析很重要。
每当编译器看到需要隐式参数时，它首先在 _当前作用域_ 中查找
然后在 _隐式作用域_ 中查找。

1. 当前作用域
    * 在当前作用域中定义的值
    * 显式导入
    * 通配符导入
2. 隐式作用域
    * 类型的伴生对象
    * 参数类型的隐式作用域
    * 类型参数的隐式作用域
    
如果在任一阶段找到多个隐式，则使用静态重载规则来解决它。
简单来说，如果一个隐式适用于比另一个更特定的类型，则会选择更特定的隐式。
如果在给定阶段内多个隐式适用，则编译器会抛出模糊的隐式解析错误。


本节大量借鉴了 [[1]](https://stackoverflow.com/a/5598107/2483329) 和
[[2]](https://stackoverflow.com/a/8694558/2483329)。
特别是，参见 [1] 中的示例。

#### 隐式解析示例

为了帮助澄清一点，让我们考虑隐式解析如何为 `DataView` 工作。
考虑 `viewAs` 的定义：

```scala
def viewAs[V <: Data](implicit dataView: DataView[T, V]): V
```

借助前一节的知识，我们知道每当我们调用 `.viewAs` 时，
Scala 编译器首先会在当前作用域（定义的或导入的）中查找 `DataView[T, V]`，
然后在 `DataView`、`T` 和 `V` 的伴生对象中查找。
这实现了一个相当强大的模式，即 `DataView` 的默认或典型实现
应该定义在两种类型之一的伴生对象中。
我们可以将以这种方式定义的 `DataViews` 视为 "低优先级默认值"。
如果给定用户想要不同的行为，它们可以被特定导入覆盖。
例如：

给定以下类型：

```scala
// 原始代码块中的标记: mdoc
class Foo extends Bundle {
  val a = UInt(8.W)
  val b = UInt(8.W)
}
class Bar extends Bundle {
  val c = UInt(8.W)
  val d = UInt(8.W)
}
object Foo {
  implicit val f2b: DataView[Foo, Bar] = DataView(_ => new Bar, _.a -> _.c, _.b -> _.d)
  implicit val b2f: DataView[Bar, Foo] = f2b.invert(_ => new Foo)
}
```

这在 _隐式作用域_ 中提供了 `DataView` 的实现，作为 `Foo` 和 `Bar` 之间的 "默认" 映射（甚至不需要导入！）：

```scala
// 原始代码块中的标记: mdoc
class FooToBar extends Module {
  val foo = IO(Input(new Foo))
  val bar = IO(Output(new Bar))
  bar := foo.viewAs[Bar]
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new FooToBar)
```

然而，`Foo` 和 `Bar` 的某些用户可能希望不同的行为，
也许他们更喜欢 "交换" 行为而不是直接映射：

```scala
// 原始代码块中的标记: mdoc
object Swizzle {
  implicit val swizzle: DataView[Foo, Bar] = DataView(_ => new Bar, _.a -> _.d, _.b -> _.c)
}
// Current scope always wins over implicit scope
import Swizzle._
class FooToBarSwizzled extends Module {
  val foo = IO(Input(new Foo))
  val bar = IO(Output(new Bar))
  bar := foo.viewAs[Bar]
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new FooToBarSwizzled)
```

### DataProduct

`DataProduct` 是 `DataView` 用来验证用户提供的映射正确性的类型类。
为了使类型 "可视"（即 `DataView` 的 `目标` 类型），它必须有一个 `DataProduct` 的实现。

例如，假设我们有一些非 Bundle 类型：
```scala
// 原始代码块中的标记: mdoc
// Loosely based on chisel3.util.Counter
class MyCounter(val width: Int) {
  /** Indicates if the Counter is incrementing this cycle */
  val active = WireDefault(false.B)
  val value = RegInit(0.U(width.W))
  def inc(): Unit = {
    active := true.B
    value := value + 1.U
  }
  def reset(): Unit = {
    value := 0.U
  }
}
```

假设我们想将 `MyCounter` 视为 `Valid[UInt]`：

```scala
// 原始代码块中的标记: mdoc:fail
import chisel3.util.Valid
implicit val counterView = DataView[MyCounter, Valid[UInt]](c => Valid(UInt(c.width.W)), _.value -> _.bits, _.active -> _.valid)
```

如你所见，这在 Scala 编译时失败了。
我们需要提供 `DataProduct[MyCounter]` 的实现，它为 Chisel 提供了一种方法来访问 `MyCounter` 内部类型为 `Data` 的对象：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.util.Valid
implicit val counterProduct: DataProduct[MyCounter] = new DataProduct[MyCounter] {
  // The String part of the tuple is a String path to the object to help in debugging
  def dataIterator(a: MyCounter, path: String): Iterator[(Data, String)] =
    List(a.value -> s"$path.value", a.active -> s"$path.active").iterator
}
// Now this works
implicit val counterView: DataView[MyCounter, Valid[UInt]] = DataView(c => Valid(UInt(c.width.W)), _.value -> _.bits, _.active -> _.valid)
```

为什么这很有用？
这就是 Chisel 如何能够检查[上面描述的](#totality-and-partialdataview)全面性的方法。
除了检查用户是否在映射中遗漏了一个字段外，它还允许 Chisel 检查
用户是否在映射中包含了一个 `Data`，而这个 `Data` 实际上不是 _目标_ 也不是 _视图_ 的一部分。
