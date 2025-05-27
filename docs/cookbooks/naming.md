
```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
import chisel3.docs.emitSystemVerilog
```
# 命名手册

[TOC]

### 我仍然有_T信号，这可以修复吗？

请参见下一个回答！

### 我有许多具有相同名称的线路，如`x`、`x_1`和`x_2`。如何使它们更容易理解？

带有`_T`名称或Chisel必须统一命名的信号
通常是在循环、函数调用或`when`谓词中生成的中间值。
它们也可能被`assert`或`prints`等验证语句使用。
在这些情况下，编译器插件通常找不到好的前缀来为生成的
中间信号命名，因此无法为它们命名或必须为它们创建唯一的名称。

我们建议您手动插入对`prefix`的调用以澄清这些情况：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.experimental.prefix
class ExamplePrefix extends Module {

  Seq.tabulate(2) { i =>
    Seq.tabulate(2) { j =>
      prefix(s"loop_${i}_${j}"){
        val x = WireInit((i*0x10+j).U(8.W))
        dontTouch(x)
      }
    }
  }
}
```
```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new ExamplePrefix)
```
### 如何为`when`子句生成的代码获得更好的名称？

`prefix` API可以帮助处理`when`子句内的代码：

```scala
// 原始代码块中的标记: mdoc:silent
class ExampleWhenPrefix extends Module {

  val in = IO(Input(UInt(4.W)))
  val out = IO(Output(UInt(4.W)))

  out := DontCare

  Seq.tabulate(2) { i =>
    val j = i + 1
    prefix(s"clause_${j}") {
      when (in === j.U) {
        val foo = Reg(UInt(4.W))
        foo := in + j.U(4.W)
        out := foo
      }
    }
  }
}
```
```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new ExampleWhenPrefix)
```

### 我仍然看到_GEN信号，这可以修复吗？

`_GEN`信号通常由FIRRTL编译器生成，而不是Chisel库。我们正在努力
用更多上下文相关的名称重命名这些信号，但这是一项正在进行的工作。感谢您的关注！

### 如何使我的模块拥有更稳定的名称，而不是'Module_1'和'Module_42'？

这是模块不稳定性问题的一个例子，这是由于几个模块共享完全相同的名称造成的。要解决这个问题，您必须为您的`Module`添加更多的特异性，以避免这些名称冲突。

这可以通过利用`desiredName`和`typeName` API来实现。
`desiredName`用于指示`Modules`的名称（例如，受传入参数的影响），而`typeName`对于由`Data`的子类进行类型参数化的模块很有用。重写`desiredName`可以减少甚至消除名称冲突。例如，假设您的模块如下所示：

```scala
// 原始代码块中的标记: mdoc:silent
class MyModule[T <: Data](gen: T) extends Module {
  // ...
}
```

We can override `desiredName` of the module to include the type name of the `gen` parameter like so:

```scala
// 原始代码块中的标记: mdoc:invisible:reset
import chisel3._
import chisel3.util.Queue
import chisel3.docs.emitSystemVerilog
```

```scala
// 原始代码块中的标记: mdoc
class MyModule[T <: Data](gen: T) extends Module {
  override def desiredName = s"MyModule_${gen.typeName}"
}
```

您的`MyModule`的任何实例现在都将具有包含类型参数的Verilog模块名称。

```scala
// 原始代码块中的标记: mdoc:compile-only
val foo = Module(new MyModule(UInt(4.W))) // MyModule_UInt4
val bar = Module(new MyModule(Vec(3, UInt(4.W)))) // MyModule_Vec3_UInt4
```

请注意，所有基本的Chisel工具模块，如`Queue`，都已经像这样实现了`desiredName`：

```scala
// 原始代码块中的标记: mdoc:compile-only
val fooQueue = Module(new Queue(UInt(8.W), 4)) // Verilog模块将被命名为'Queue4_UInt8'
val barQueue = Module(new Queue(SInt(12.W), 3)) // ...以及'Queue3_SInt12'
val bazQueue = Module(new Queue(Bool(), 16)) // ...以及'Queue16_Bool'
```

### 如何为我的数据类型编写自己的`typeName`？

如果您使用自己的用户定义的`Bundle`，您可以通过重写它来增加其自身`typeName`的特异性。所有`Data`类型都有一个简单的默认`typeName`实现（仅仅是其类名），但您可以自己重写这个：

```scala
// 原始代码块中的标记: mdoc:silent
class MyBundle[T <: Data](gen: T, intParam: Int) extends Bundle {
  // 为此Bundle生成一个稳定的typeName。这个实现中存在两个'词'：
  // bundle的名称加上其整数参数（类似于'MyBundle9'）
  // 以及生成器的typeName，它本身可以由'词'组成
  // （类似于'Vec3_UInt4'）
  override def typeName = s"MyBundle${intParam}_${gen.typeName}"

  // ...
}
```

现在，如果您在诸如`Queue`这样的模块中使用您的`MyBundle`：

```scala
// 原始代码块中的标记: mdoc:compile-only
val fooQueue = Module(new Queue(new MyBundle(UInt(4.W), 3), 16)) // Queue16_MyBundle3_UInt4
```

对于`typeName`和随后的`desiredName`的建议模式是将单个整数类参数与名称本身折叠（例如，`Queue4`，`UInt3`，`MyBundle9`）形成"词"，并用下划线分隔这些"词"（`Queue4_UInt3`，`FooBundle_BarType4`）。

目前，具有多个整数参数的`Bundles`尚未被任何内置模块解决，因此为这些`Bundles`实现一个描述性和足够可区分的`typeName`留给读者作为练习。然而，整数不应该在`typeName`的最后出现下划线（例如，`MyBundle_1`），因为这是用于重复的_相同_语法，因此会引起混淆。必须区分所有名为`Queue32_MyBundle_4_1`、`Queue32_MyBundle_4_2`、`Queue32_MyBundle_4_3`等的模块确实是不理想的！

### 我不想一遍又一遍地重写`typeName`！有没有生成`typeName`的简单方法？

是的，通过实验性的`HasAutoTypename`特质。这个特质可以混入到您的`Bundle`中，根据该`Bundle`的构造函数参数自动生成一个类似元组的`typeName`。让我们看看前面的例子：

```scala
// 原始代码块中的标记: mdoc:invisible:reset
import chisel3._
```

```scala
// 原始代码块中的标记: mdoc:silent
class MyBundle[T <: Data](gen: T, intParam: Int) extends Bundle {
  override def typeName = s"MyBundle_${gen.typeName}_${intParam}"
  // ...
}
```

```scala
// 原始代码块中的标记: mdoc
new MyBundle(UInt(8.W), 3).typeName
```

```scala
// 原始代码块中的标记: mdoc:invisible:reset
import chisel3._
import chisel3.docs.emitSystemVerilog
```

自动生成的`typeName`采用`{Bundle名称}_{参数值1}_{参数值2}_{...}`的形式，因此我们的`MyBundle`可以等效地表示为：
```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.experimental.HasAutoTypename
class MyBundle[T <: Data](gen: T, intParam: Int) extends Bundle with HasAutoTypename {
  // ...
  // 注意：这里没有`override def typeName`语句
}
```

```scala
// 原始代码块中的标记: mdoc
new MyBundle(UInt(8.W), 3).typeName
```

### 我可以在FIRRTL中命名我的bundle，这样就不会生成极长的bundle类型吗？

是的，使用`HasTypeAlias`特质。FIRRTL有一个结构，可以用类型别名来别名一个bundle类型，如下所示：

```
circuit Top :
  type MyBundle = { foo : UInt<8>, bar : UInt<1>}

  module Top :
    //...
```

这些可以通过在用户定义的`Record`中混入`HasTypeAlias`并实现一个名为`aliasName`的字段，其中包含一个`RecordAlias(...)`实例，从Chisel自动发出。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.experimental.{HasTypeAlias, RecordAlias}

class AliasedBundle extends Bundle with HasTypeAlias {
  override def aliasName = RecordAlias("MyAliasedBundle")
  val foo = UInt(8.W)
  val bar = Bool()
}
```

让我们看看当我们使用这个`Bundle`生成FIRRTL时会发生什么：

```scala
// 原始代码块中的标记: mdoc:invisible
import circt.stage.ChiselStage.{emitCHIRRTL => emitFIRRTL}
```
```scala
// 原始代码块中的标记: mdoc
emitFIRRTL(new Module {
  val wire = Wire(new AliasedBundle)
})
```

`HasTypeAlias`还支持嵌套的bundle：
```scala
// 原始代码块中的标记: mdoc:silent
class Child extends Bundle with HasTypeAlias {
  override def aliasName = RecordAlias("ChildBundle")
  val x = UInt(8.W)
}

class Parent extends Bundle with HasTypeAlias {
  override def aliasName = RecordAlias("ParentBundle")
  val child = new Child
}
```
```scala
// 原始代码块中的标记: mdoc
emitFIRRTL(new Module {
  val wire = Wire(new Parent)
})
```

### 为什么我在FIRRTL中总是看到_stripped后缀？我没有在`aliasName`中指定这个。

您正在结合使用`Input(...)`或`Output(...)`与包含`Flipped(...)`的别名`Record`。这些翻转值被`Input`和`Output`剥离，这从根本上改变了父`Record`的类型：

```scala
// 原始代码块中的标记: mdoc:silent
class StrippedBundle extends Bundle with HasTypeAlias {
  override def aliasName = RecordAlias("StrippedBundle")
  val flipped = Flipped(UInt(8.W))
  val normal = UInt(8.W)
}
```

```scala
// 原始代码块中的标记: mdoc
emitFIRRTL(new Module {
  val in = IO(Input(new StrippedBundle))
})
```

注意bundle类型不包含`flip flipped : UInt<8>`字段，别名获得了`"_stripped"`后缀！这个`Bundle`类型不再与我们在Chisel中编写的相同，所以我们必须将其区分为这样。

默认情况下，附加到`Record`名称的后缀是`"_stripped"`。用户可以通过传递给`RecordAlias(alias, strippedSuffix)`的附加字符串参数来定义这个：

```scala
// 原始代码块中的标记: mdoc:silent
class CustomStrippedBundle extends Bundle with HasTypeAlias {
  override def aliasName = RecordAlias("StrippedBundle", "Foo")
  val flipped = Flipped(UInt(8.W))
  val normal = UInt(8.W)
}
```

```scala
// 原始代码块中的标记: mdoc
emitFIRRTL(new Module {
  val in = IO(Input(new CustomStrippedBundle))
})
```

### 我想添加一些硬件或断言，但每次我这样做时，所有的信号名称都会变化！

这是经典的"ECO"问题，我们在[解释](../explanations/naming)中提供了描述。简而言之，
我们建议将所有额外的逻辑包装在一个前缀作用域中，这可以启用一个唯一的命名空间。这应该防止
名称冲突，这是触发所有那些烦人的信号名称变化的原因！

### 我想强制一个信号（或实例）名称为某个特定值，如何做到这一点？

使用`.suggestName`方法，它在所有继承`Data`的类上都可用。

### 如何在代码的某些部分中省略前缀？

您可以使用`noPrefix { ... }`来从该作用域中生成的所有信号中剥离前缀。

```scala
// 原始代码块中的标记: mdoc
import chisel3.experimental.noPrefix

class ExampleNoPrefix extends Module {
  val in = IO(Input(UInt(2.W)))
  val out = IO(Output(UInt(5.W)))

  val add = noPrefix {
    // foo不会得到前缀
    val foo = RegNext(in + 1.U)
    foo + in
  }

  out := add
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new ExampleNoPrefix)
```

### 我仍然没有得到我想要的名称。例如，内联一个实例会改变我的名称！

在FIRRTL转换重命名信号/实例的情况下，您可以使用`forcename` API：

```scala
// 原始代码块中的标记: mdoc
import chisel3.util.experimental.{forceName, InlineInstance}

class WrapperExample extends Module {
  val in = IO(Input(UInt(3.W)))
  val out = IO(Output(UInt(3.W)))
  val inst = Module(new Wrapper)
  inst.in := in
  out := inst.out
}
class Wrapper extends Module with InlineInstance {
  val in = IO(Input(UInt(3.W)))
  val out = IO(Output(UInt(3.W)))
  val inst = Module(new MyLeaf)
  forceName(inst, "inst")
  inst.in := in
  out := inst.out
}
class MyLeaf extends Module {
  val in = IO(Input(UInt(3.W)))
  val out = IO(Output(UInt(3.W)))
  out := in
}
```
```scala
// 原始代码块中的标记: mdoc:verilog
emitSystemVerilog(new WrapperExample)
```

这可以用来重命名实例和非聚合类型的信号。
