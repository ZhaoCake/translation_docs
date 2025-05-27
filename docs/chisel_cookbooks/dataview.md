# DataView技巧手册

[TOC]

## 如何将Data视为UInt或反之？

子字查看（在`DataViews`中使用连接或位提取）目前尚不支持。
我们打算在未来实现这一功能，但目前，请使用常规转换
（`.asUInt`和`.asTypeOf`）。

## 如何为具有类型参数的Bundle创建DataView？

不要使用`val`，而是使用可以有类型参数的`def`：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.experimental.dataview._

class Foo[T <: Data](val foo: T) extends Bundle
class Bar[T <: Data](val bar: T) extends Bundle

object Foo {
  implicit def view[T <: Data]: DataView[Foo[T], Bar[T]] = {
    DataView(f => new Bar(f.foo.cloneType), _.foo -> _.bar)
    // .cloneType是必要的，因为传递给此函数的f将是绑定的硬件
  }
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// 确保这在详细化过程中工作，非文档部分
class MyModule extends RawModule {
  val in = IO(Input(new Foo(UInt(8.W))))
  val out = IO(Output(new Bar(UInt(8.W))))
  out := in.viewAs[Bar[UInt]]
}
chisel3.docs.emitSystemVerilog(new MyModule)
```
如果你将类型参数化类视为一系列不同的类（每个类型参数对应一个类），
你可以将`implicit def`视为每个类型参数的`DataViews`生成器。

## 如何为具有可选字段的Bundle创建DataView？

不要使用默认的`DataView` apply方法，而是使用`DataView.mapping`：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.experimental.dataview._

class Foo(val w: Option[Int]) extends Bundle {
  val foo = UInt(8.W)
  val opt = w.map(x => UInt(x.W))
}
class Bar(val w: Option[Int]) extends Bundle {
  val bar = UInt(8.W)
  val opt = w.map(x => UInt(x.W))
}

object Foo {
  implicit val view: DataView[Foo, Bar] =
    DataView.mapping(
      // 第一个参数始终是从目标创建视图的函数
      f => new Bar(f.w),
      // 现在，不是可变参数列表中的单独映射元组，而是一个函数
      // 该函数接受目标和视图并返回元组的Iterable
      (f, b) =>  List(f.foo -> b.bar) ++ f.opt.map(_ -> b.opt.get)
                                   // ^ 注意，我们可以附加选项，因为它们是Iterable！

    )
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// 确保这在详细化过程中工作，非文档部分
class MyModule extends RawModule {
  val in = IO(Input(new Foo(Some(8))))
  val out = IO(Output(new Bar(Some(8))))
  out := in.viewAs[Bar]
}
chisel3.docs.emitSystemVerilog(new MyModule)
```

## 如何连接Bundle字段的子集？

Chisel 3要求连接的类型完全匹配。
DataView提供了一种机制，可以将一个`Bundle`对象"视为"另一个类型，
这允许它们被连接。

### 如何将Bundle视为父类型（超类）？

要将`Bundles`视为父类型，只需使用`viewAsSupertype`并提供父类型的模板对象：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.experimental.dataview._

class Foo extends Bundle {
  val foo = UInt(8.W)
}
class Bar extends Foo {
  val bar = UInt(8.W)
}
class MyModule extends Module {
  val foo = IO(Input(new Foo))
  val bar = IO(Output(new Bar))
  bar.viewAsSupertype(new Foo) := foo // bar.foo := foo.foo
  bar.bar := 123.U           // 所有字段都需要连接
}
```
```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new MyModule)
```

### 当父类型是抽象的（如trait）时，如何将Bundle视为父类型？

给定以下共享公共`trait`的`Bundles`：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.experimental.dataview._

trait Super extends Bundle {
  def bitwidth: Int
  val a = UInt(bitwidth.W)
}
class Foo(val bitwidth: Int) extends Super {
  val foo = UInt(8.W)
}
class Bar(val bitwidth: Int) extends Super {
  val bar = UInt(8.W)
}
```

`Foo`和`Bar`不能直接连接，但可以通过将它们都视为其共同超类型`Super`的实例来连接。
直接的方法可能会遇到以下问题：

```scala
// 原始代码块中的标记: mdoc:fail
class MyModule extends Module {
  val foo = IO(Input(new Foo(8)))
  val bar = IO(Output(new Bar(8)))
  bar.viewAsSupertype(new Super) := foo.viewAsSupertype(new Super)
}
```

问题是`viewAs`需要一个对象作为类型模板（以便可以克隆它），
但是`traits`是抽象的，不能被实例化。
解决方案是创建一个_匿名类_的实例，并将该对象用作`viewAs`的参数。
我们可以这样做：

```scala
// 原始代码块中的标记: mdoc:silent
class MyModule extends Module {
  val foo = IO(Input(new Foo(8)))
  val bar = IO(Output(new Bar(8)))
  val tpe = new Super { // 添加花括号创建一个匿名类
    def bitwidth = 8 // We must implement any abstract methods
  }
  bar.viewAsSupertype(tpe) := foo.viewAsSupertype(tpe)
}
```
通过在trait名称后添加花括号，我们告诉Scala创建一个新的具体
trait子类，并创建它的实例。
正如注释中所指出的，抽象方法仍然必须被实现。
这与编写`new Bundle {}`时发生的情况相同，
花括号创建了一个新的具体子类；然而，由于`Bundle`没有抽象方法，
主体内容可以为空。

### 如何使用`.viewAs`而不是`.viewAsSupertype(type)`？

虽然`viewAsSupertype`对一次性转换很有帮助，但每次都需要提供类型模板对象
可能会很麻烦。
由于子类型关系，你可以使用`PartialDataView.supertype`来创建一个
从Bundle类型到父类型的`DataView`，只需提供从子类型实例构造
父类型实例的函数。
相应字段的映射由Chisel自动确定为在父类型中定义的字段。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.experimental.dataview._

class Foo(x: Int) extends Bundle {
  val foo = UInt(x.W)
}
class Bar(val x: Int) extends Foo(x) {
  val bar = UInt(x.W)
}
// 定义一个DataView，无需指定映射！
implicit val view: DataView[Bar, Foo] = PartialDataView.supertype[Bar, Foo](b => new Foo(b.x))

class MyModule extends Module {
  val foo = IO(Input(new Foo(8)))
  val bar = IO(Output(new Bar(8)))
  bar.viewAs[Foo] := foo // bar.foo := foo.foo
  bar.bar := 123.U       // 所有字段都需要连接
}
```
```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new MyModule)
```
