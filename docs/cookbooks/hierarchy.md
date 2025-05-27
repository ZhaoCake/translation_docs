
# 层次结构手册

[TOC]

## 如何实例化具有相同模块参数化的多个实例？

在此包发布之前，Chisel用户依赖FIRRTL编译器中的去重功能来将结构相同的模块合并为一个模块（即"去重"）。
这个包引入了以下新的API，以便直接在Chisel中启用多重实例化模块。

`Definition(...)`允许详细说明一个模块，但实际上并不实例化该模块。
相反，它返回一个代表该模块定义的`Definition`类。

`Instance(...)`接受一个`Definition`并将其实例化，返回一个`Instance`对象。

`Instantiate(...)`提供了与`Module(...)`类似的API，但它使用
`Definition`和`Instance`来为给定的参数集只详细说明一次模块。
它返回一个`Instance`对象。

将与`Definition`/`Instance` API一起使用的模块（类或特质）应在类/特质定义处标记
为`@instantiable`注解。

要使模块的成员变量可从`Instance`对象访问，它们必须用`@public`注解标记。
请注意，这只能从Scala的角度访问 - 它本身不是跨模块引用的机制。

### 使用Definition和Instance

在以下示例中，使用`Definition`、`Instance`、`@instantiable`和`@public`来创建
一个模块`AddOne`的特定参数化的多个实例。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
import chisel3.experimental.hierarchy.{Definition, Instance, instantiable, public}

@instantiable
class AddOne(width: Int) extends Module {
  @public val in  = IO(Input(UInt(width.W)))
  @public val out = IO(Output(UInt(width.W)))
  out := in + 1.U
}

class AddTwo(width: Int) extends Module {
  val in  = IO(Input(UInt(width.W)))
  val out = IO(Output(UInt(width.W)))
  val addOneDef = Definition(new AddOne(width))
  val i0 = Instance(addOneDef)
  val i1 = Instance(addOneDef)
  i0.in := in
  i1.in := i0.out
  out   := i1.out
}
```
```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new AddTwo(10))
```

### 使用Instantiate

与上面类似，以下示例使用`Instantiate`创建
`AddOne`的多个实例。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.experimental.hierarchy.Instantiate

class AddTwoInstantiate(width: Int) extends Module {
  val in  = IO(Input(UInt(width.W)))
  val out = IO(Output(UInt(width.W)))
  val i0 = Instantiate(new AddOne(width))
  val i1 = Instantiate(new AddOne(width))
  i0.in := in
  i1.in := i0.out
  out   := i1.out
}
```
```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new AddTwoInstantiate(16))
```

## 如何访问实例的内部字段？

您可以使用`@public`注解标记用`@instantiable`注解标记的Module类或特质的内部成员。
要求是该字段可公开访问，是`val`或`lazy val`，并且必须有`Lookupable`的实现。

默认支持的类型有：

1. `Data`
2. `BaseModule`
3. `MemBase`
4. `IsLookupable`
5. 包含满足这些要求的类型的`Iterable`/`Option`/`Either`
6. 基本类型如`String`、`Int`、`BigInt`、`Unit`等。

要将超类的成员标记为`@public`，请使用以下模式（以`val clock`为例）。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.experimental.hierarchy.{instantiable, public}

@instantiable
class MyModule extends Module {
  @public val clock = clock
}
```

对于不正确标记为`@public`的内容，您会收到以下错误消息：

```scala
// 原始代码块中的标记: mdoc:reset:fail
import chisel3._
import chisel3.experimental.hierarchy.{instantiable, public}

object NotValidType

@instantiable
class MyModule extends Module {
  @public val x = NotValidType
}
```

## 如何使我的字段可从实例访问？

如果实例的字段很简单（例如`Int`、`String`等），它们可以直接标记为`@public`。

通常，字段更复杂（例如用户定义的case类）。
如果一个case类仅由简单类型组成（即它*不*包含任何`Data`、`BaseModules`、memories或`Instances`），
它可以扩展`IsLookupable`特质。
这向Chisel表明`IsLookupable`类的实例可以从实例内部访问。
（如果类*确实*包含诸如`Data`或模块之类的内容，[请参见下面的部分](#如何使包含Data或模块的case类可从实例访问)。）

但是，确保这些参数对定义的**所有**实例都是真实的。
例如，如果我们的参数包含一个特定于实例的id字段，但默认为零，
那么定义的id将返回给所有实例。
如果其他代码假设id字段是正确的，这种行为变化可能导致错误。

因此，当将普通模块转换为使用此包时，
您需要小心标记为`IsLookupable`的内容。

在以下示例中，我们添加了特质`IsLookupable`以允许成员被标记为`@public`。

In the following example, we added the trait `IsLookupable` to allow the member to be marked `@public`.

```scala
// 原始代码块中的标记: mdoc:reset:silent
import chisel3._
import chisel3.experimental.hierarchy.{Definition, Instance, instantiable, IsLookupable, public}

case class MyCaseClass(width: Int) extends IsLookupable

@instantiable
class MyModule extends Module {
  @public val x = MyCaseClass(10)
}

class Top extends Module {
  val inst = Instance(Definition(new MyModule))
  println(s"Width is ${inst.x.width}")
}
```
```scala
// 原始代码块中的标记: mdoc:passthrough
println("```")
// 运行详细说明，以便上面的println显示出来
circt.stage.ChiselStage.elaborate(new Top)
println("```")
```

## 如何使包含Data或模块的case类可从实例访问？

对于包含`Data`、`BaseModule`、`MemBase`或`Instance`类型的case类，您可以提供`Lookupable`类型类的实现。

**注意，模块的Lookupable已被弃用，请改用转换为Instance（使用`.toInstance`）。**

考虑以下case类：

```scala
// 原始代码块中的标记: mdoc:reset
import chisel3._
import chisel3.experimental.hierarchy.{Definition, Instance, instantiable, public}

@instantiable
class MyModule extends Module {
  @public val wire = Wire(UInt(8.W))
}
case class UserDefinedType(name: String, data: UInt, inst: Instance[MyModule])
```

默认情况下，`UserDefinedType`的实例将无法从实例中访问：

```scala
// 原始代码块中的标记: mdoc:fail
@instantiable
class HasUserDefinedType extends Module {
  val inst = Module(new MyModule)
  val wire = Wire(UInt(8.W))
  @public val x = UserDefinedType("foo", wire, inst.toInstance)
}
```

我们可以为`UserDefinedType`实现`Lookupable`类型类，以使其可访问。
这涉及在`UserDefinedType`的伴生对象中定义一个隐式val。
因为`UserDefinedType`有三个字段，我们使用`Lookupable.product3`工厂。
它接受4个类型参数：case类的类型，以及其每个字段的类型。

**如果任何字段是`BaseModules`，您必须将它们更改为`Instance[_]`才能定义`Lookupable`类型类。**

有关类型类的更多信息，请参阅[DataView部分关于类型类](https://www.chisel-lang.org/chisel3/docs/explanations/dataview#type-classes)。

```scala
// 原始代码块中的标记: mdoc
import chisel3.experimental.hierarchy.Lookupable
object UserDefinedType {
  // 使用Lookupable.Simple类型别名作为返回类型。
  implicit val lookupable: Lookupable.Simple[UserDefinedType] =
    Lookupable.product3[UserDefinedType, String, UInt, Instance[MyModule]](
      // 提供将UserDefinedType转换为元组的配方。
      x => (x.name, x.data, x.inst),
      // 提供将元组转换为用户定义类型的配方。
      // 对于case类，您可以使用内置的工厂方法。
      UserDefinedType.apply
    )
}
```

现在，我们可以从实例中访问`UserDefinedType`的实例：

```scala
// 原始代码块中的标记: mdoc
@instantiable
class HasUserDefinedType extends Module {
  val inst = Module(new MyModule)
  val wire = Wire(UInt(8.W))
  @public val x = UserDefinedType("foo", wire, inst.toInstance)
}
class Top extends Module {
  val inst = Instance(Definition(new HasUserDefinedType))
  println(s"Name is: ${inst.x.name}")
}
```

## 如何使类型参数化的case类可从实例访问？

考虑以下类型参数化的case类：

```scala
// 原始代码块中的标记: mdoc:reset
import chisel3._
import chisel3.experimental.hierarchy.{Definition, Instance, instantiable, public}

case class ParameterizedUserDefinedType[A, T <: Data](value: A, data: T)
```

与`HasUserDefinedType`类似，我们需要定义一个隐式提供`Lookupable`类型类。
然而，与上面的简单示例不同，我们使用`implicit def`来处理类型参数：

```scala
// 原始代码块中的标记: mdoc
import chisel3.experimental.hierarchy.Lookupable
object ParameterizedUserDefinedType {
  // 类型类实例化是递归的，所以A和T都必须有Lookupable实例。
  // 我们通过上下文绑定`: Lookupable`为A要求这一点。
  // Data是Chisel内置的，所以已知具有Lookupable实例。
  implicit def lookupable[A : Lookupable, T <: Data]: Lookupable.Simple[ParameterizedUserDefinedType[A, T]] =
    Lookupable.product2[ParameterizedUserDefinedType[A, T], A, T](
      x => (x.value, x.data),
      ParameterizedUserDefinedType.apply
    )
}
```

现在，我们可以从实例中访问`ParameterizedUserDefinedType`的实例：

```scala
// 原始代码块中的标记: mdoc
class ChildModule extends Module {
  @public val wire = Wire(UInt(8.W))
}
@instantiable
class HasUserDefinedType extends Module {
  val wire = Wire(UInt(8.W))
  @public val x = ParameterizedUserDefinedType("foo", wire)
  @public val y = ParameterizedUserDefinedType(List(1, 2, 3), wire)
}
class Top extends Module {
  val inst = Instance(Definition(new HasUserDefinedType))
  println(s"x.value is: ${inst.x.value}")
  println(s"y.value.head is: ${inst.y.value.head}")
}
```

## 如何使具有大量字段的case类可从实例访问？

Lookupable提供了从`product1`到`product5`的工厂。
如果您的类有超过5个字段，您可以在映射中使用嵌套元组作为"伪字段"。

```scala
// 原始代码块中的标记: mdoc
case class LotsOfFields(a: Data, b: Data, c: Data, d: Data, e: Data, f: Data)
object LotsOfFields {
  implicit val lookupable: Lookupable.Simple[LotsOfFields] =
    Lookupable.product5[LotsOfFields, Data, Data, Data, Data, (Data, Data)](
      x => (x.a, x.b, x.c, x.d, (x.e, x.f)),
      // 这次不能直接使用工厂方法，因为我们必须解包元组。
      { case (a, b, c, d, (e, f)) => LotsOfFields(a, b, c, d, e, f) },
    )
}
```

## 如何从Definition查找字段，如果我不想实例化它？

就像`Instance`一样，`Definition`也包含`@public`成员的访问器。
因此，您可以直接访问它们：

```scala
// 原始代码块中的标记: mdoc:reset:silent
import chisel3._
import chisel3.experimental.hierarchy.{Definition, instantiable, public}

@instantiable
class AddOne(val width: Int) extends RawModule {
  @public val width = width
  @public val in  = IO(Input(UInt(width.W)))
  @public val out = IO(Output(UInt(width.W)))
  out := in + 1.U
}

class Top extends Module {
  val definition = Definition(new AddOne(10))
  println(s"Width is: ${definition.width}")
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Top())
```

## 如何通过其子实例参数化模块？

在引入这个包之前，父模块在实例化子模块时必须传递所有必要的参数。
这带来了一个不幸的后果，即父模块的参数总是必须包含子模块的
参数，这是一种不必要的耦合，导致了一些反模式。

现在，父模块可以将子模块的`Definition`作为参数，并直接实例化它。
此外，它可以分析用于定义中的参数来参数化自身。
从某种意义上说，现在子模块实际上可以参数化父模块。

在以下示例中，我们创建了`AddOne`的定义，并将该定义传递给`AddTwo`。
`AddTwo`端口的宽度现在从`AddOne`实例的参数化中派生。

```scala
// 原始代码块中的标记: mdoc:reset
import chisel3._
import chisel3.experimental.hierarchy.{Definition, Instance, instantiable, public}

@instantiable
class AddOne(val width: Int) extends Module {
  @public val width = width
  @public val in  = IO(Input(UInt(width.W)))
  @public val out = IO(Output(UInt(width.W)))
  out := in + 1.U
}

class AddTwo(addOneDef: Definition[AddOne]) extends Module {
  val i0 = Instance(addOneDef)
  val i1 = Instance(addOneDef)
  val in  = IO(Input(UInt(addOneDef.width.W)))
  val out = IO(Output(UInt(addOneDef.width.W)))
  i0.in := in
  i1.in := i0.out
  out   := i1.out
}
```
```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new AddTwo(Definition(new AddOne(10))))
```

## 如何使用新的层次结构特定的Select函数？

Select函数可以在模块被详细说明后应用，可以在Chisel Aspect中或在父模块中应用于子模块。

有七个层次结构特定的函数，除了`ios`以外，它们要么返回`Instance`，要么返回`Definition`：
 - `instancesIn(parent)`：返回直接在`parent`中本地实例化的所有实例
 - `instancesOf[type](parent)`：返回直接在`parent`中本地实例化的所有提供的`type`的实例
 - `allInstancesOf[type](root)`：返回从`root`开始，直接和间接地实例化的，本地和深层的所有提供的`type`的实例
 - `definitionsIn`：返回直接在`parent`中本地实例化的所有实例的定义
 - `definitionsOf[type]`：返回直接在`parent`中本地实例化的所有提供的`type`的实例的定义
 - `allDefinitionsOf[type]`：返回从`root`开始，直接和间接地实例化的，本地和深层的所有提供的`type`的实例的定义
 - `ios`：返回提供的定义或实例的所有I/O。

为了演示这一点，考虑以下情况。我们模拟了一个示例，其中我们使用`Select.allInstancesOf`和`Select.allDefinitionsOf`来注解`EmptyModule`的实例和定义。
当注解逻辑在详细说明后执行时，我们打印结果`Target`。
如所示，尽管`EmptyModule`实际上只被详细说明了一次，但根据如何选择实例或定义，我们仍然提供不同的目标。

```scala
// 原始代码块中的标记: mdoc:reset
import chisel3._
import chisel3.experimental.hierarchy.{Definition, Instance, Hierarchy, instantiable, public}

@instantiable
class EmptyModule extends Module {
  println("Elaborating EmptyModule!")
}

@instantiable
class TwoEmptyModules extends Module {
  val definition = Definition(new EmptyModule)
  val i0         = Instance(definition)
  val i1         = Instance(definition)
}

class Top extends Module {
  val definition = Definition(new TwoEmptyModules)
  val instance   = Instance(definition)
  aop.Select.allInstancesOf[EmptyModule](instance).foreach { i =>
    experimental.annotate(i) {
      println("instance: " + i.toTarget)
      Nil
    }
  }
  aop.Select.allDefinitionsOf[EmptyModule](instance).foreach { d =>
    experimental.annotate(d) {
      println("definition: " + d.toTarget)
      Nil
    }
  }
}
```
```scala
// 原始代码块中的标记: mdoc:passthrough
println("```")
val x = circt.stage.ChiselStage.emitCHIRRTL(new Top)
println("```")
```

您还可以在`Definition`或`Instance`上使用`Select.ios`来适当地注解I/O：

```scala
// 原始代码块中的标记: mdoc
@instantiable
class InOutModule extends Module {
  @public val in = IO(Input(Bool()))
  @public val out = IO(Output(Bool()))
  out := in
}

@instantiable
class TwoInOutModules extends Module {
  val in = IO(Input(Bool()))
  val out = IO(Output(Bool()))
  val definition = Definition(new InOutModule)
  val i0         = Instance(definition)
  val i1         = Instance(definition)
  i0.in := in
  i1.in := i0.out
  out := i1.out
}

class InOutTop extends Module {
  val definition = Definition(new TwoInOutModules)
  val instance   = Instance(definition)
  aop.Select.allInstancesOf[InOutModule](instance).foreach { i =>
    aop.Select.ios(i).foreach { io =>
      experimental.annotate(io) {
        println("instance io: " + io.toTarget)
        Nil
      }
    }
  }
  aop.Select.allDefinitionsOf[InOutModule](instance).foreach { d =>
    aop.Select.ios(d).foreach { io =>
      experimental.annotate(io) {
        println("definition io: " + io.toTarget)
        Nil
      }
    }
  }
}
```
```scala
// 原始代码块中的标记: mdoc:passthrough
println("```")
val y = circt.stage.ChiselStage.emitCHIRRTL(new InOutTop)
println("```")
```
