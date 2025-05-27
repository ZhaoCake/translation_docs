# 通用技巧手册

请注意，这些示例使用了Chisel的scala风格打印。

[TOC]

## 类型转换

### 如何从Bundle实例创建UInt？

在[`Bundle`](https://www.chisel-lang.org/api/latest/chisel3/Bundle.html)实例上调用[`asUInt`](https://www.chisel-lang.org/api/latest/chisel3/Bundle.html#asUInt:chisel3.UInt)。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class MyBundle extends Bundle {
  val foo = UInt(4.W)
  val bar = UInt(4.W)
}

class Foo extends Module {
  val bundle = Wire(new MyBundle)
  bundle.foo := 0xc.U
  bundle.bar := 0x3.U
  val uint = bundle.asUInt
  printf(cf"$uint") // 195

  // Test
  assert(uint === 0xc3.U)
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo)
```

### 如何从UInt创建Bundle？

使用[`asTypeOf`](https://www.chisel-lang.org/api/latest/chisel3/UInt.html#asTypeOf[T%3C:chisel3.Data](that:T):T)方法将[`UInt`](https://www.chisel-lang.org/api/latest/chisel3/UInt.html)重新解释为[`Bundle`](https://www.chisel-lang.org/api/latest/chisel3/Bundle.html)的类型。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class MyBundle extends Bundle {
  val foo = UInt(4.W)
  val bar = UInt(4.W)
}

class Foo extends Module {
  val uint = 0xb4.U
  val bundle = uint.asTypeOf(new MyBundle)

  printf(cf"$bundle") // Bundle(foo -> 11, bar -> 4)

  // Test
  assert(bundle.foo === 0xb.U)
  assert(bundle.bar === 0x4.U)
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo)
```

### 如何将Bundle/Vec连接到0？

你可以像上面那样使用`asTypeOf`。如果你不想关心你要连接的对象的类型，你可以使用`chiselTypeOf`：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class MyBundle extends Bundle {
  val foo = UInt(4.W)
  val bar = Vec(4, UInt(1.W))
}

class Foo(typ: MyBundle) extends Module {
  val bundleA = IO(Output(typ))
  val bundleB = IO(Output(typ))

  // typ已经是一个Chisel数据类型，所以可以直接在这里使用它，但你
  // 需要知道bundleA的类型是typ
  bundleA := 0.U.asTypeOf(typ)

  // bundleB是一个硬件数据IO(Output(...))，所以需要调用chiselTypeOf，
  // 但这将适用于任何类型的bundleB：
  bundleB := 0.U.asTypeOf(chiselTypeOf(bundleB))
}
```
```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo(new MyBundle))
```
### 如何从UInt创建一个布尔值的Vec？

使用[`VecInit`](https://www.chisel-lang.org/api/latest/chisel3/VecInit$.html)，传入通过[`asBools`](https://www.chisel-lang.org/api/latest/chisel3/UInt.html#asBools:Seq[chisel3.Bool])方法生成的`Seq[Bool]`。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class Foo extends Module {
  val uint = 0xc.U
  val vec = VecInit(uint.asBools)

  printf(cf"$vec") // Vec(0, 0, 1, 1)

  // Test
  assert(vec(0) === false.B)
  assert(vec(1) === false.B)
  assert(vec(2) === true.B)
  assert(vec(3) === true.B)
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo)
```

### 如何从布尔值的Vec创建UInt？

使用内置函数[`asUInt`](https://www.chisel-lang.org/api/latest/chisel3/Vec.html#asUInt:chisel3.UInt)

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class Foo extends Module {
  val vec = VecInit(true.B, false.B, true.B, true.B)
  val uint = vec.asUInt

  printf(cf"$uint") // 13

  // Test
  // (记住Vec中最左侧的Bool是低位)
  assert(0xd.U === uint)

}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo)
```

### 如何连接Bundle字段的子集？

参见[DataView cookbook](dataview#how-do-i-connect-a-subset-of-bundle-fields)。

## 向量和寄存器

### 我可以创建2D或3D向量吗？

是的。使用`VecInit`，你可以创建包含Chisel类型向量的向量。方法`fill`和`tabulate`可以创建这些多维向量。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class MyBundle extends Bundle {
  val foo = UInt(4.W)
  val bar = UInt(4.W)
}

class Foo extends Module {
  //2D Fill
  val twoDVec = VecInit.fill(2, 3)(5.U)
  //3D Fill
  val myBundle = Wire(new MyBundle)
  myBundle.foo := 0xc.U
  myBundle.bar := 0x3.U
  val threeDVec = VecInit.fill(1, 2, 3)(myBundle)
  assert(threeDVec(0)(0)(0).foo === 0xc.U && threeDVec(0)(0)(0).bar === 0x3.U)

  //2D Tabulate
  val indexTiedVec = VecInit.tabulate(2, 2){ (x, y) => (x + y).U }
  assert(indexTiedVec(0)(0) === 0.U)
  assert(indexTiedVec(0)(1) === 1.U)
  assert(indexTiedVec(1)(0) === 1.U)
  assert(indexTiedVec(1)(1) === 2.U)
  //3D Tabulate
  val indexTiedVec3D = VecInit.tabulate(2, 3, 4){ (x, y, z) => (x + y * z).U }
  assert(indexTiedVec3D(0)(0)(0) === 0.U)
  assert(indexTiedVec3D(1)(1)(1) === 2.U)
  assert(indexTiedVec3D(1)(1)(2) === 3.U)
  assert(indexTiedVec3D(1)(1)(3) === 4.U)
  assert(indexTiedVec3D(1)(2)(3) === 7.U)
}
```
```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo)
```


### 如何创建寄存器的向量？

**规则！使用Reg的Vec而不是Vec的Reg！**

你创建一个[Vec类型的Reg](#how-do-i-create-a-reg-of-type-vec)。因为Vec是一个*类型*（如`UInt`、`Bool`）而不是一个*值*，我们必须将Vec绑定到某个具体的*值*。

### 如何创建Vec类型的Reg？

有关更多信息，[`Vec`](https://www.chisel-lang.org/api/latest/chisel3/Vec.html)的API文档提供了更多信息。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class Foo extends Module {
  val regOfVec = Reg(Vec(4, UInt(32.W))) // 32位UInts的寄存器
  regOfVec(0) := 123.U                   // 对Vec元素的赋值
  regOfVec(1) := 456.U
  regOfVec(2) := 789.U
  regOfVec(3) := regOfVec(0)

  // 初始化为零的32位UInts的Vec类型的Reg
  //   注意Seq.fill构造了4个值为0的32位UInt字面量
  //   VecInit(...)然后构造了这些字面量的Wire
  //   然后Reg被初始化为Wire的值（这给它相同的类型）
  val initRegOfVec = RegInit(VecInit(Seq.fill(4)(0.U(32.W))))
}
```
```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo)
```


### 如何部分重置聚合寄存器？

最简单的方法是使用部分指定的[Bundle字面量](../appendix/experimental-features#bundle-literals)
或[Vec字面量](../appendix/experimental-features#vec-literals)来匹配Reg的类型。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.experimental.BundleLiterals._

class MyBundle extends Bundle {
  val foo = UInt(8.W)
  val bar = UInt(8.W)
}

class MyModule extends Module {
  // 只有.foo会被重置，.bar将没有重置值
  val reg = RegInit((new MyBundle).Lit(_.foo -> 123.U))
}
```

如果你的初始值不是字面量，或者你只是喜欢这种方式，你可以使用一个
Wire作为Reg的初始值。只需将你不希望重置的字段连接到`DontCare`。

```scala
// 原始代码块中的标记: mdoc:silent
class MyModule2 extends Module {
  val reg = RegInit({
    // Wire可以在reg之前构造，而不是在RegInit范围内，
    // 但这种风格有很好的词法作用域行为，保持Wire的私有性
    val init = Wire(new MyBundle)
    init := DontCare // 没有字段会被重置
    init.foo := 123.U // 最后连接覆盖，.foo被重置
    init
  })
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new MyModule)
chisel3.docs.emitSystemVerilog(new MyModule2)
```


## Bundles

### 如何处理别名Bundle字段？

```scala
// 原始代码块中的标记: mdoc:invisible:reset
import chisel3._

class Top[T <: Data](gen: T) extends Module {
  val in = IO(Input(gen))
  val out = IO(Output(gen))
  out := in
}
```

在创建Bundle时遵循`gen`模式可能会导致一些难以理解的错误消息：

```scala 
// mdoc
class AliasedBundle[T <: Data](gen: T) extends Bundle {
  val foo = gen
  val bar = gen
}
```

```scala
// 原始代码块中的标记: mdoc:crash
getVerilogString(new Top(new AliasedBundle(UInt(8.W))))
```

这个错误表明`AliasedBundle`的字段`foo`和`bar`在内存中是完全相同的对象。
这对Chisel来说是个问题，因为我们需要能够区分`foo`和`bar`的使用，但当它们引用相同时无法区分。

注意，以下示例看起来不同，但会给你带来完全相同的问题：

```scala 
// mdoc
class AlsoAliasedBundle[T <: Data](val gen: T) extends Bundle {
                                // ^ 这个val使`gen`成为一个字段，就像`foo`
  val foo = gen
}
```

通过使`gen`成为一个`val`，它成为`class`的公共字段，就像`foo`一样。

```scala
// 原始代码块中的标记: mdoc:crash
getVerilogString(new Top(new AlsoAliasedBundle(UInt(8.W))))
```

有几种方法可以解决这个问题，每种方法都有自己的优缺点。

#### 1. 0-arity函数参数

与其将对象作为参数传递，你可以传递一个0-arity函数（无参数的函数）：

```scala 
// mdoc
class UsingAFunctionBundle[T <: Data](gen: () => T) extends Bundle {
  val foo = gen()
  val bar = gen()
}
```

注意`gen`的类型现在是`() => T`。
因为它现在是一个函数而不是`Data`的子类型，你可以安全地将`gen`设为`val`，而不会
使它成为`Bundle`的硬件字段。

注意这也意味着你必须将`gen`作为函数传递，例如：

```scala
// 原始代码块中的标记: mdoc:silent
chisel3.docs.emitSystemVerilog(new Top(new UsingAFunctionBundle(() => UInt(8.W))))
```

##### 别名警告

**警告**：你必须确保`gen`创建新对象，而不是捕获已构造的值：

```scala
// 原始代码块中的标记: mdoc:crash
class MisusedFunctionArguments extends Module {
  // 这种用法是正确的
  val in = IO(Input(new UsingAFunctionBundle(() => UInt(8.W))))

  // 这种用法是不正确的
  val fizz = UInt(8.W)
  val out = IO(Output(new UsingAFunctionBundle(() => fizz)))
}
getVerilogString(new MisusedFunctionArguments)
```
在上面的例子中，值`fizz`和`out`的字段`foo`和`bar`在内存中都是同一个对象。


#### 2. By-name函数参数

功能上与(1)相同，但语法更加微妙，你可以使用[Scala按名称函数参数](https://docs.scala-lang.org/tour/by-name-parameters.html)：

```scala 
// mdoc
class UsingByNameParameters[T <: Data](gen: => T) extends Bundle {
  val foo = gen
  val bar = gen
}
```

使用这种方式，传递参数时不包括`() =>`：

```scala
// 原始代码块中的标记: mdoc:silent
chisel3.docs.emitSystemVerilog(new Top(new UsingByNameParameters(UInt(8.W))))
```

注意，由于这只是(1)的语法糖，[同样的警告适用](#aliased-warning)。

#### 3. 带方向的Bundle字段

你也可以用`Output(...)`包装字段，这会创建传递参数的新实例。
Chisel将`Output`视为"默认方向"，所以如果所有字段都是输出，该`Bundle`在功能上等同于没有方向字段的`Bundle`。

```scala
// 原始代码块中的标记: mdoc
class DirectionedBundle[T <: Data](gen: T) extends Bundle {
  val foo = Output(gen)
  val bar = Output(gen)
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
chisel3.docs.emitSystemVerilog(new Top(new DirectionedBundle(UInt(8.W))))
```

这种方法诚然有点丑陋，并且可能误导其他阅读代码的人，因为它暗示这个Bundle旨在用作`Output`。

#### 4. 直接调用`.cloneType`

你也可以直接在你的`gen`参数上调用`.cloneType`。
虽然我们试图对用户隐藏这个实现细节，但`.cloneType`是Chisel创建`Data`对象新实例的机制：

```scala
// 原始代码块中的标记: mdoc
class UsingCloneTypeBundle[T <: Data](gen: T) extends Bundle {
  val foo = gen.cloneType
  val bar = gen.cloneType
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
chisel3.docs.emitSystemVerilog(new Top(new UsingCloneTypeBundle(UInt(8.W))))
```

### <a name="bundle-unable-to-clone"></a> 如何处理"无法克隆"错误？

大多数Chisel对象需要被克隆，以区分bundle字段的软件表示和其"绑定"的硬件
表示，其中"绑定"是生成硬件组件的过程。对于Bundle字段，这种克隆应该通过
编译器插件自动发生。

但在某些情况下，插件可能无法克隆Bundle字段。当这种情况发生时，
最常见的情况是当Bundle字段的`chisel3.Data`部分嵌套在其他数据结构中，
编译器插件无法弄清楚如何克隆整个结构。最好避免这种嵌套结构。

解决这个问题有几种方法 - 如果适当，你可以尝试用Input(...)、Output(...)或Flipped(...)包装
有问题的字段。你也可以尝试使用`chisel3.reflect.DataMirror`中的`chiselTypeClone`方法
手动克隆Bundle中的每个字段。以下是一个Bundle的例子，其字段不会被克隆：

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
import scala.collection.immutable.ListMap
```

```scala
// 原始代码块中的标记: mdoc:crash
class CustomBundleBroken(elts: (String, Data)*) extends Record {
  val elements = ListMap(elts: _*)

  def apply(elt: String): Data = elements(elt)
}

class NewModule extends Module {
  val out = Output(UInt(8.W))
  val recordType = new CustomBundleBroken("fizz" -> UInt(16.W), "buzz" -> UInt(16.W))
  val record = Wire(recordType)
  val uint = record.asUInt
  val record2 = uint.asTypeOf(recordType)
  out := record
}
getVerilogString(new NewModule)
```

你可以使用`chiselTypeClone`来克隆元素，如下所示：


```scala
// 原始代码块中的标记: mdoc
import chisel3.reflect.DataMirror
import chisel3.experimental.requireIsChiselType

class CustomBundleFixed(elts: (String, Data)*) extends Record {
  val elements = ListMap(elts.map {
    case (field, elt) =>
      requireIsChiselType(elt)
      field -> DataMirror.internal.chiselTypeClone(elt)
  }: _*)

  def apply(elt: String): Data = elements(elt)
}
```

## 如何创建有限状态机(FSM)？

建议的方法是使用`ChiselEnum`构造表示FSM状态的枚举类型。
然后用`switch`/`is`和`when`/`.elsewhen`/`.otherwise`处理状态转换。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.util.{switch, is}

object DetectTwoOnes {
  object State extends ChiselEnum {
    val sNone, sOne1, sTwo1s = Value
  }
}

/* 这个FSM检测两个连续的1 */
class DetectTwoOnes extends Module {
  import DetectTwoOnes.State
  import DetectTwoOnes.State._

  val io = IO(new Bundle {
    val in = Input(Bool())
    val out = Output(Bool())
    val state = Output(State())
  })

  val state = RegInit(sNone)

  io.out := (state === sTwo1s)
  io.state := state

  switch (state) {
    is (sNone) {
      when (io.in) {
        state := sOne1
      }
    }
    is (sOne1) {
      when (io.in) {
        state := sTwo1s
      } .otherwise {
        state := sNone
      }
    }
    is (sTwo1s) {
      when (!io.in) {
        state := sNone
      }
    }
  }
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new DetectTwoOnes)
```

注意：`is`语句可以接受多个条件，例如`is (sTwo1s, sOne1) { ... }`。

## 如何像在Verilog中那样解包值（"反向连接"）？

在Verilog中，你可以做类似下面的操作来解包值`z`：

```verilog
wire [1:0] a;
wire [3:0] b;
wire [2:0] c;
wire [8:0] z = [...];
assign {a,b,c} = z;
```

解包通常对应于将非结构化数据类型重新解释为结构化数据类型。
通常，这种结构化类型在设计中广泛使用，并已经如下例中所示进行了声明：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class MyBundle extends Bundle {
  val a = UInt(2.W)
  val b = UInt(4.W)
  val c = UInt(3.W)
}
```

在Chisel中实现这一点的最简单方法是：

```scala
// 原始代码块中的标记: mdoc:silent
class Foo extends Module {
  val z = Wire(UInt(9.W))
  z := DontCare // 这是一个虚拟连接
  val unpacked = z.asTypeOf(new MyBundle)
  printf("%d", unpacked.a)
  printf("%d", unpacked.b)
  printf("%d", unpacked.c)
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo)
```

如果你**真的**需要为一次性情况做这个（三思而后行！你很可能可以使用bundle更好地构造代码），那么rocket-chip有一个[Split工具](https://github.com/freechipsproject/rocket-chip/blob/723af5e6b69e07b5f94c46269a208a8d65e9d73b/src/main/scala/util/Misc.scala#L140)可以完成这个。

## 如何进行子字赋值（为UInt中的某些位赋值）？

你可能尝试做类似以下的事情，你想只为Chisel类型的某些位赋值。
下面，对`io.out(0)`的左侧连接是不允许的。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class Foo extends Module {
  val io = IO(new Bundle {
    val bit = Input(Bool())
    val out = Output(UInt(10.W))
  })
  io.out(0) := io.bit
}
```

如果你尝试编译这个，你会得到一个错误。
```scala
// 原始代码块中的标记: mdoc:crash
getVerilogString(new Foo)
```

Chisel3 *不支持子字赋值*。
这是因为子字赋值通常暗示可以使用聚合/结构化类型进行更好的抽象，即，`Bundle`或`Vec`。

如果你必须以这种方式表达，一种方法是将你的`UInt`分解为`Bool`的`Vec`，然后再转回来：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class Foo extends Module {
  val io = IO(new Bundle {
    val in = Input(UInt(10.W))
    val bit = Input(Bool())
    val out = Output(UInt(10.W))
  })
  val bools = VecInit(io.in.asBools)
  bools(0) := io.bit
  io.out := bools.asUInt
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new Foo)
```

## 如何创建可选的I/O？

以下示例是一个模块，只有当给定参数为`true`时才包含可选端口`out2`。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class ModuleWithOptionalIOs(flag: Boolean) extends Module {
  val io = IO(new Bundle {
    val in = Input(UInt(12.W))
    val out = Output(UInt(12.W))
    val out2 = if (flag) Some(Output(UInt(12.W))) else None
  })

  io.out := io.in
  if (flag) {
    io.out2.get := io.in
  }
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new ModuleWithOptionalIOs(true))
```

以下是一个整个`IO`是可选的示例：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class ModuleWithOptionalIO(flag: Boolean) extends Module {
  val in = if (flag) Some(IO(Input(Bool()))) else None
  val out = IO(Output(Bool()))

  out := in.getOrElse(false.B)
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new ModuleWithOptionalIO(true))
```

## 如何创建没有前缀的I/O？

在大多数情况下，你可以简单地多次调用`IO`：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class MyModule extends Module {
  val in = IO(Input(UInt(8.W)))
  val out = IO(Output(UInt(8.W)))

  out := in +% 1.U
}
```

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new MyModule)
```

如果你有一个`Bundle`，你想从中创建没有正常`val`前缀的端口，你可以使用`FlatIO`：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class MyBundle extends Bundle {
  val foo = Input(UInt(8.W))
  val bar = Output(UInt(8.W))
}

class MyModule extends Module {
  val io = FlatIO(new MyBundle)

  io.bar := io.foo +% 1.U
}
```

请注意，这里没有看到`io_`！

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new MyModule)
```

## 如何在Module内覆盖隐式时钟或复位信号？

要更改代码区域的时钟或复位信号，请使用`withClock`、`withReset`或`withClockAndReset`。
有关示例和详细信息，请参阅[多时钟域](../chisel_explanations/multi-clock)。

要覆盖`Module`整个作用域的时钟或复位信号，你可以混入`ImplicitClock`和`ImplicitReset`特质。

例如，你可以如下"门控"默认隐式时钟：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
class MyModule extends Module with ImplicitClock {
  val gate = IO(Input(Bool()))
  val in = IO(Input(UInt(8.W)))
  val out = IO(Output(UInt(8.W)))
  // 我们可以直接将其分配给val implicitClock，但这样可以让我们给它一个自定义名称
  val gatedClock = (clock.asBool || gate).asClock
  // 该特质要求我们实现这个引用时钟的方法
  // 注意这是一个def，但实际的时钟值必须分配给一个val
  override protected def implicitClock = gatedClock

  val r = Reg(UInt(8.W))
  out := r
  r := in
}
```

这会生成以下Verilog：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new MyModule)
```

如果你不关心覆盖时钟的名称，你可以直接将其分配给`val implicitClock`：
```scala
override protected val implicitClock = (clock.asBool || gate).asClock
```

`ImplicitReset`的工作方式类似于`ImplicitClock`。

## 如何最小化输出向量中使用的位数？

使用推断宽度和`Seq`而不是`Vec`：

考虑：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

// 计算每个位位置及之前的置位数
class CountBits(width: Int) extends Module {
  val bits = IO(Input(UInt(width.W)))
  val countVector = IO(Output(Vec(width, UInt())))

  private val countSequence = Seq.tabulate(width)(i => Wire(UInt()))
  countSequence.zipWithIndex.foreach { case (port, i) =>
    port := util.PopCount(bits(i, 0))
  }
  countVector := countSequence
}

class Top(width: Int) extends Module {
  val countBits = Module(new CountBits(width))
  countBits.bits :<>= DontCare
  dontTouch(countBits.bits)
  dontTouch(countBits.countVector)
}
```

注意，顶层模块或公共模块不能有未知宽度。

与`Vecs`表示单一的Chisel类型且每个元素必须具有相同宽度不同，
与`Vecs`表示单一的Chisel类型且每个元素必须具有相同宽度不同，
`Seq`是纯Scala构造，因此从Chisel的角度来看，它们的元素是独立的，可以有不同的宽度。

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Top(4))
  // 通过删除');'之后的所有内容来删除模块的主体
  .split("\\);")
  .head + ");\n"
```

## 如何解决"动态索引...对于被提取者来说太宽/太窄..."？

当动态索引的宽度不是索引Vec或UInt的正确大小时，Chisel会发出警告。
"正确大小"意味着索引的宽度应该是被索引者大小的log2。
如果被索引者的大小不是2的幂，则使用log2结果的上限。

```scala
// 原始代码块中的标记: mdoc:invisible:reset
import chisel3._
// 辅助函数，丢弃返回值，使其不显示在mdoc中
def compile(gen: => chisel3.RawModule): Unit = {
  circt.stage.ChiselStage.emitCHIRRTL(gen)
}
```

当索引没有足够的位来寻址被提取者中的所有条目或位时，你可以使用`.pad`增加索引的宽度。

```scala
// 原始代码块中的标记: mdoc
class TooNarrow extends RawModule {
  val extractee = Wire(UInt(7.W))
  val index = Wire(UInt(2.W))
  extractee(index)
}
compile(new TooNarrow)
```

这可以用`pad`修复：

```scala
// 原始代码块中的标记: mdoc
class TooNarrowFixed extends RawModule {
  val extractee = Wire(UInt(7.W))
  val index = Wire(UInt(2.W))
  extractee(index.pad(3))
}
compile(new TooNarrowFixed)
```

#### 当索引太宽时使用位提取

```scala
// 原始代码块中的标记: mdoc
class TooWide extends RawModule {
  val extractee = Wire(Vec(8, UInt(32.W)))
  val index = Wire(UInt(4.W))
  extractee(index)
}
compile(new TooWide)
```

这可以通过位提取修复：

```scala
// 原始代码块中的标记: mdoc
class TooWideFixed extends RawModule {
  val extractee = Wire(Vec(8, UInt(32.W)))
  val index = Wire(UInt(4.W))
  extractee(index(2, 0))
}
compile(new TooWideFixed)
```

注意，大小为1的`Vecs`和`UInts`应该由零宽度的`UInt`索引：

```scala
// 原始代码块中的标记: mdoc
class SizeOneVec extends RawModule {
  val extractee = Wire(Vec(1, UInt(32.W)))
  val index = Wire(UInt(0.W))
  extractee(index)
}
compile(new SizeOneVec)
```

因为`pad`只在所需宽度小于参数当前宽度时才进行填充，
你可以在宽度可能在不同情况下太宽或太窄时将`pad`与位提取结合使用

```scala
// 原始代码块中的标记: mdoc
import chisel3.util.log2Ceil
class TooWideOrNarrow(extracteeSize: Int, indexWidth: Int) extends Module {
  val extractee = Wire(Vec(extracteeSize, UInt(8.W)))
  val index = Wire(UInt(indexWidth.W))
  val correctWidth = log2Ceil(extracteeSize)
  extractee(index.pad(correctWidth)(correctWidth - 1, 0))
}
compile(new TooWideOrNarrow(8, 2))
compile(new TooWideOrNarrow(8, 4))
```

对于`UInts`的动态位选择（但不是`Vec`的动态索引），另一种选择是对被提取者进行动态
右移，然后只选择单个位：
```scala
// 原始代码块中的标记: mdoc
class TooWideOrNarrowUInt(extracteeSize: Int, indexWidth: Int) extends Module {
  val extractee = Wire(UInt(extracteeSize.W))
  val index = Wire(UInt(indexWidth.W))
  (extractee >> index)(0)
}
compile(new TooWideOrNarrowUInt(8, 2))
compile(new TooWideOrNarrowUInt(8, 4))
```

## 如何在Chisel中使用Verilog的"case相等"运算符？

Verilog有"case相等"（`===`）和"不等"（`!==`）运算符。
它们通常用于在断言中忽略未知（`X`）值。

Chisel不直接支持Verilog的`X`，但可以使用`chisel3.util.circt.isX`检查值是否为`X`。
`isX`通常用于保护断言免受`X`的影响，这与Verilog的case相等行为类似。

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.util.circt.IsX

class AssertButAllowX extends Module {
  val in = IO(Input(UInt(8.W)))

  // 断言in永远不为零；也不在X出现时触发断言。
  assert(IsX(in) || in =/= 0.U, "in should never equal 0")
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// Hidden but will make sure this actually compiles
chisel3.docs.emitSystemVerilog(new AssertButAllowX)
```

## 可预测的命名

### 如何使Chisel在when/withClockAndReset等块中正确命名信号？

使用编译器插件，如果仍然不能达到你想要的效果，请查看[命名手册](naming)。

### 如何使Chisel正确命名向量读取的结果？
目前，使用动态索引时会丢失名称信息。例如：
```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class Foo extends Module {
  val io = IO(new Bundle {
    val in = Input(Vec(4, Bool()))
    val idx = Input(UInt(2.W))
    val en = Input(Bool())
    val out = Output(Bool())
  })

  val x = io.in(io.idx)
  val y = x && io.en
  io.out := y
}
```

上面的代码丢失了`x`名称，而是使用`_GEN_3`（其他`_GEN_*`信号是预期的）。

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Foo)
```

这可以通过创建一个线网并将动态索引连接到该线网来解决：
```scala
val x = WireInit(io.in(io.idx))
```

```scala
// 原始代码块中的标记: mdoc:invisible
class Foo2 extends Module {
  val io = IO(new Bundle {
    val in = Input(Vec(4, Bool()))
    val idx = Input(UInt(2.W))
    val en = Input(Bool())
    val out = Output(Bool())
  })

  val x = WireInit(io.in(io.idx))
  val y = x && io.en
  io.out := y
}
```

这会产生：
```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Foo2)
```

### 如何动态设置/参数化模块的名称？

你可以覆盖`desiredName`函数。这适用于普通的Chisel模块和`BlackBox`。例如：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._

class Coffee extends BlackBox {
    val io = IO(new Bundle {
        val I = Input(UInt(32.W))
        val O = Output(UInt(32.W))
    })
    override def desiredName = "Tea"
}

class Salt extends Module {
    val io = IO(new Bundle {})
    val drink = Module(new Coffee)
    override def desiredName = "SodiumMonochloride"

    drink.io.I := 42.U
}
```

对Chisel模块`Salt`进行详细化会在输出的Verilog中产生我们为`Salt`和`Coffee`所"期望的名称"：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Salt)
```

## 方向性

### 如何从双向Bundle（或其他Data）中去除方向？

给定一个双向端口，如`Decoupled`，如果你尝试将其直接连接到寄存器，将会得到错误：

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.util.Decoupled
class BadRegConnect extends Module {
  val io = IO(new Bundle {
    val enq = Decoupled(UInt(8.W))
  })

  val monitor = Reg(chiselTypeOf(io.enq))
  monitor := io.enq
}
```

```scala
// 原始代码块中的标记: mdoc:crash
getVerilogString(new BadRegConnect)
```

While there is no construct to "strip direction" in Chisel3, wrapping a type in `Output(...)`
(the default direction in Chisel3) will
set all of the individual elements to output direction.
This will have the desired result when used to construct a Register:

```scala
// 原始代码块中的标记: mdoc:silent:reset
import chisel3._
import chisel3.util.Decoupled
class CoercedRegConnect extends Module {
  val io = IO(new Bundle {
    val enq = Flipped(Decoupled(UInt(8.W)))
  })

  // Make a Reg which contains all of the bundle's signals, regardless of their directionality
  val monitor = Reg(Output(chiselTypeOf(io.enq)))
  // Even though io.enq is bidirectional, := will drive all fields of monitor with the fields of io.enq
  monitor := io.enq
}
```

<!-- Just make sure it actually works -->
```scala
// 原始代码块中的标记: mdoc:invisible
chisel3.docs.emitSystemVerilog(new CoercedRegConnect {
  // Provide default connections that would just muddy the example
  io.enq.ready := true.B
  // dontTouch so that it shows up in the Verilog
  dontTouch(monitor)
})
```
