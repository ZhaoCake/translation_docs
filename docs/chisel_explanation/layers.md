---
layout: docs
title:  "层"
section: "chisel3"
---

# 层

层描述了用户希望在Verilog生成时_可选_包含的Chisel生成器功能。实际上，它们是一种访问SystemVerilog的`bind`构造和`` `ifdef ``预处理器宏的功能。按照设计，层的可选功能不允许影响层外的逻辑。

层通常用于描述设计验证代码或调试逻辑，用户希望能够稍后禁用（出于性能、详细程度或整洁原因）或内部使用，但从交付给客户的版本中排除。

## 概述

一个层由两部分组成：

1. 一个层_声明_，以及
1. Chisel模块内的一个或多个_层块_。

声明表示可以存在可选功能。层块包含可选功能。

有两种类型的层。层类型决定了_约定_，即层的层块在Verilog中如何表示以及启用层的机制。可用的层类型有：

1. "提取"层：其块被降级为使用`bind`实例化的模块，可以通过在Verilog生成期间包含文件来启用，以及
2. "内联"层：其块将被`` `ifdef ``宏保护，可以通过设置Verilog预处理器定义来启用。

提取层还可以指定写入其附属物的目录。

:::info

关于这些SystemVerilog概念的更多信息，IEEE 1800-2023标准在第23.11节讨论了`bind`，在第23.6节讨论了`` `ifdef ``。

:::

要声明一个层，在scala中创建一个继承抽象类`chisel3.layer.Layer`的单例`object`，向层构造函数传递`chisel3.layer.LayerConfig.Extract`类的对象（用于提取层），或者对象`chisel3.layer.LayerConfig.Inline`（用于内联层）。

下面，声明了一个提取层和一个内联层：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.layer.{Layer, LayerConfig}

object A extends Layer(LayerConfig.Extract())

object B extends Layer(LayerConfig.Inline)
```

层可以嵌套。在父层下嵌套子层意味着子层可以访问父层中的构造。换句话说，只有在父层已启用的情况下，子层才会被启用。要声明嵌套层，请在另一个声明内扩展`chisel3.layer.Layer`抽象类。

以下示例定义了一个包含两个嵌套层的提取层：

```scala
// 原始代码块中的标记: mdoc:silent
object C extends Layer(LayerConfig.Extract()) {
  object D extends Layer(LayerConfig.Extract())
  object E extends Layer(LayerConfig.Inline) {
    object F extends Layer(LayerConfig.Inline)
  }
}
```

:::info

SystemVerilog禁止在另一个`bind`实例化下进行`bind`实例化。然而，Chisel允许嵌套提取层。FIRRTL编译器会重构嵌套的提取层，使其成为通过端口通信的兄弟模块。

:::

:::warning

提取层不能嵌套在内联层下。然而，内联层可以嵌套在提取层下。

任何包含层块或传递性地在其子模块中包含层块的模块都不能在层块下实例化。

:::

与一个层相关联的_层块_，向模块添加可选功能，如果该层启用，则启用该功能。要定义一个层块，请在Chisel模块内使用`chisel3.layer.block`并传递它应该关联的层。

在层块内部，可以使用词法范围内可见的任何Chisel或Scala值。层块不能返回值。层块内创建的任何值在层块外都不可访问，除非使用层着色探针。

以下示例在模块`Foo`内定义层块。每个层块包含一个捕获其可见词法范围中的值的线。（对于嵌套层块，此范围包括其父层块。）：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
import chisel3.layer.block

class Foo extends RawModule {
  val port = IO(Input(Bool()))

  block(A) {
    val a = WireInit(port)
  }

  block(B) {
    val b = WireInit(port)
  }

  block(C) {
    val c = WireInit(port)
    block(C.D) {
      val d = WireInit(port | c)
    }
    block(C.E) {
      val e = WireInit(port ^ c)
      block (C.E.F) {
        val f = WireInit(port & e)
      }
    }
  }
}
```

如果可能，层块API会自动为您创建父层块。在以下示例中，直接在模块中创建`C.D`的层块是合法的：

```scala
// 原始代码块中的标记: mdoc:silent
class Bar extends RawModule {
  block (C.D) {}
}
```

形式上，只要当前作用域是请求层的_祖先_，就可以创建与层关联的层块。

:::info

这个要求是一个_祖先_关系，而不是一个_严格祖先_关系。这意味着在同一层的层块下嵌套一个层块是合法的，如：

```scala
// 原始代码块中的标记: mdoc:silent
class Baz extends RawModule {
  block(A) {
    block(A) {}
  }
}
```

:::

## Verilog ABI

层使用FIRRTL ABI编译为SystemVerilog。这个ABI定义了Chisel设计中层块的行为以及如何在设计编译为SystemVerilog后启用层。

:::info

有关层的FIRRTL ABI的确切定义，请参阅[FIRRTL ABI规范](https://github.com/chipsalliance/firrtl-spec/releases/latest/download/abi.pdf)。

:::

### 提取层

提取层的层块从设计中移除。要启用一个层，应该在设计中包含一个特定名称的文件。这个文件以`layers-`开头，然后包括电路名称和所有层名称，用破折号（`-`）分隔。

例如，对于上面声明的模块`Foo`，这将产生三个文件，每个提取层一个：

```
layers-Foo-A.sv
layers-Foo-C.sv
layers-Foo-C-D.sv
```

要在编译时启用这些层中的任何一个，应该在构建中包含适当的文件。可以包含任意文件组合。只包含子层的文件将自动包含其父层的文件。

### 内联层

内联层的层块用条件编译指令保护。要启用内联层，在编译设计时设置预处理器定义。预处理器定义以`layer_`开头，然后包括电路名称和所有层名称，用美元符号（`$`）分隔。父提取层名称出现在宏中。

例如，对于上面声明的模块`Foo`，这将对三个宏敏感，每个内联层一个：

```
layer_Foo$B
layer_Foo$C$E
layer_Foo$C$E$F
```

## 用户定义的层

用户可以自由定义任意数量的层。之前显示的所有层都是用户定义的，例如，`A`和`C.E`是用户定义的层。只有当用户定义的层有层块用户时，它们才会被发送到FIRRTL。要更改此行为并无条件地发出用户定义的层，请使用`chisel3.layer.addLayer` API。

:::tip

在创建新的用户定义层之前，请考虑使用下面定义的内置层。此外，如果在一个更大的项目中工作，该项目可能有自己的用户定义层，您应该使用这些层。这是因为ABI会影响构建系统。请咨询项目的技术负责人，看看是否是这种情况。

:::

## 内置层

Chisel提供了几个内置层。这些层的完整Scala路径如下所示。所有内置层都是提取层：

```
chisel3.layers.Verification
├── chisel3.layers.Verification.Assert
├── chisel3.layers.Verification.Assume
└── chisel3.layers.Verification.Cover
```

这些内置层具有双重目的。首先，这些层与将验证代码隔离的常见用例相匹配。`Verification`层用于常见的验证附属物。`Assert`、`Assume`和`Cover`层分别用于断言、假设和覆盖语句。其次，Chisel标准库在其许多API中使用它们。_除非另外包装在不同的层块中，否则以下操作会自动放置在层中_：

* 打印被放置在`Verification`层中
* 断言被放置在`Verification.Assert`层中
* 假设被放置在`Verification.Assume`层中
* 覆盖被放置在`Verification.Cover`层中

为了输出的可预测性，这些层将始终出现在Chisel发出的FIRRTL中。要更改此行为，请使用`firtool`命令行选项_专门化_这些层（通过使它们始终启用或禁用来移除它们的可选性）。使用`-enable-layers`启用一个层，`-disable-layers`禁用一个层，或者`-default-layer-specialization`设置默认专门化。

:::tip

用户可以使用高级API用用户定义的层扩展内置层。为此，必须将层父级指定为隐式值。

以下示例将层`Debug`嵌套到`Verification`层：

```scala
// 原始代码块中的标记: mdoc:silent
object UserDefined {
  // Define an implicit val `root` of type `Layer` to cause layers which can see
  // this to use `root` as their parent layer.  This allows us to nest the
  // user-defined `Debug` layer under the built-in `Verification` layer.
  implicit val root: Layer = chisel3.layers.Verification
  object Debug extends Layer(LayerConfig.Inline)
}
```

:::

## 层着色

虽然层不允许影响设计或其父层，但通常允许层块将信息从其包含模块发送出去，以便同一层或子层的层块读取是有用且必要的。具有这种可选属性的硬件被称为_层着色_。探针和线都可以进行层着色。

### 层着色探针和线

层着色探针是一种在用户在Verilog生成期间启用其相应层时存在的探针。层着色探针用于描述可选的验证、调试或日志接口。

层着色线用作已定义探针值的临时存储。它们用于同一模块中同一层的层块之间的通信，或者在将探针转发到端口时作为临时存储。

如果在启用探针或线的颜色时启用了`define`，则层着色探针或线可以是`define`的目标。如果在启用`read`时启用了探针或线的颜色，则可以从层着色探针或线中`read`。换句话说，您可以写入您的层或子层，您可以从您的层或父层读取。

:::info

有关更多信息，请参阅[FIRRTL规范](https://github.com/chipsalliance/firrtl-spec/releases/latest/download/spec.pdf)的层着色部分。

:::

下面的示例显示了两个层着色探针端口和一个以合法方式驱动的层着色探针线：

```scala
// 原始代码块中的标记: mdoc:reset
import chisel3._
import chisel3.layer.{Layer, LayerConfig}
import chisel3.probe.{Probe, ProbeValue, define}

object A extends Layer(LayerConfig.Extract())
object B extends Layer(LayerConfig.Extract())

class Foo extends RawModule {
  val a = IO(Output(Probe(Bool(), A)))
  val b = IO(Output(Probe(Bool(), B)))

  layer.block(A) {
    val a_wire = WireInit(false.B)
    define(a, ProbeValue(a_wire))
  }

  val b_wire_probe = Wire(Probe(Bool(), B))
  define(b, b_wire_probe)

  layer.block(B) {
    val b_wire = WireInit(false.B)
    define(b_wire_probe, ProbeValue(b_wire))
  }

}
```

此外，由于从层块内驱动层着色探针线的模式很常见，层块也能够直接返回层着色线。为此，层块的返回值必须是`Data`的子类型。

使用此功能，可以按如下方式重写第二个层块：

``` scala mdoc:silent
class Bar extends RawModule {
  val b = IO(Output(Probe(Bool(), B)))

  val b_wire_probe = layer.block(B) {
    val b_wire = WireInit(false.B)
    define(b_wire_probe, ProbeValue(b_wire))
  }

  define(b, b_wire_probe)
}
```

:::info

在实现中，从层块返回的值将导致在层块之前创建一个线。即，模块`Bar`中显示的内容只是`Foo`中编写内容的Chisel简写。如FIRRTL规范中所述，层块没有返回值的能力。

:::

### 启用层

在使用层着色探针时，通常方便地授予对一个或多个颜色的探针的访问权限。例如，测试台通常希望_启用_被测设计中的所有层，以便获得对层着色探针端口的访问权限，这对于高级设计验证是必要的。如果没有额外的功能，这种用例仅使用层着色就得不到很好的支持。首先，在测试台中封装所有代码到层块中是乏味的。其次，测试台可能需要读取没有父子关系的不同颜色的探针。没有层块能够同时合法地从不同的探针读取并组合结果。

为了支持这种用例，Chisel提供了`layer.enable` API。此API授予对实例化模块的已启用层的任何层着色探针的访问权限。可以多次使用此API以启用多个层。

下面的示例实例化了前一节中的模块`Foo`。在启用层`A`和`B`后，模块可以从颜色为`A`和`B`的探针读取，并在单个操作中使用它们的结果：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.layer.enable
import chisel3.probe.read

class Bar extends RawModule {

  enable(A)
  enable(B)

  val foo = Module(new Foo)

  val c = read(foo.a) ^ read(foo.b)

}
```

## 示例

### 简单提取层

下面的设计有一个单一的提取层，启用后，将添加一个检查溢出的断言。根据FIRRTL ABI，我们可以预期在编译时将生成一个名为`layers-Foo-A.sv`的文件。

```scala
// 原始代码块中的标记: mdoc:reset:silent
import chisel3._
import chisel3.layer.{Layer, LayerConfig, block}
import chisel3.ltl.AssertProperty

object A extends Layer(LayerConfig.Extract())

class Foo extends Module {
  val a, b = IO(Input(UInt(4.W)))
  val sum = IO(Output(UInt(4.W)))

  sum :<= a +% b

  block(A) {
    withDisable(Disable.Never) {
      AssertProperty(!(a +& b)(4), "overflow occurred")
    }
  }

}
```

编译后，我们得到以下SystemVerilog。包含`FILE`的注释表示新文件的开始：

```scala
// 原始代码块中的标记: mdoc:verilog
circt.stage.ChiselStage.emitSystemVerilog(
  new Foo,
  firtoolOpts = Array(
    "-strip-debug-info",
    "-disable-all-randomization",
    "-enable-layers=Verification",
    "-enable-layers=Verification.Assert",
    "-enable-layers=Verification.Assume",
    "-enable-layers=Verification.Cover"
  )
)
```

:::info

上面的示例是使用firtool选项`-enable-layers=Verification`、`-enable-layers=Verification.Assert`、`-enable-layers=Verification.Assume`和`-enable-layers=Verification.Cover`编译的，以使输出更简洁。通常，这些内置层的绑定文件会显示。

:::

:::info

注意：生成的模块`Foo_A`及其文件`Foo_A.sv`_不是ABI的一部分_。除了绑定文件`layers-Foo-A.sv`外，您不应依赖任何生成的模块名称或文件。

:::

### 简单内联层

下面的设计与前一个示例相同，但使用内联层。根据FIRRTL ABI，我们可以预期层块的主体将被`` `ifdef ``保护，对预处理器宏`layer_Foo$A`敏感。

```scala
// 原始代码块中的标记: mdoc:reset:silent
import chisel3._
import chisel3.layer.{Layer, LayerConfig, block}
import chisel3.ltl.AssertProperty

object A extends Layer(LayerConfig.Inline)

class Foo extends Module {
  val a, b = IO(Input(UInt(4.W)))
  val sum = IO(Output(UInt(4.W)))

  sum :<= a +% b

  block(A) {
    withDisable(Disable.Never) {
      AssertProperty(!(a +& b)(4), "overflow occurred")
    }
  }

}
```

编译后，我们得到以下SystemVerilog。

```scala
// 原始代码块中的标记: mdoc:verilog
circt.stage.ChiselStage.emitSystemVerilog(
  new Foo,
  firtoolOpts = Array(
    "-strip-debug-info",
    "-disable-all-randomization",
    "-enable-layers=Verification,Verification.Assert,Verification.Assume,Verification.Cover"
  )
)
```

### 设计验证示例

考虑这样一个用例，设计或设计验证工程师希望向模块添加一些断言和调试打印。断言和调试打印所需的逻辑需要额外的计算。所有这些代码应该可以在Verilog生成时（而不是在Chisel生成时）选择性地包含。工程师可以使用三个层来实现这一点。

本示例中使用了三个层：

1. 内置的`Verification`层
1. 内置的`Assert`层，嵌套在内置的`Verification`层下
1. 用户定义的`Debug`层，也嵌套在内置的`Verification`层下

`Verification`层可用于存储`Assert`和`Debug`层共用的常见逻辑。后两个层允许分离断言和打印。

在Scala中编写这个的一种方式如下：

```scala
// 原始代码块中的标记: mdoc:reset:silent
import chisel3._
import chisel3.layer.{Layer, LayerConfig, block}
import chisel3.layers.Verification

// User-defined layers are declared here.  Built-in layers do not need to be declared.
object UserDefined {
  implicit val root: Layer = Verification
  object Debug extends Layer(LayerConfig.Inline)
}

class Foo extends Module {
  val a = IO(Input(UInt(32.W)))
  val b = IO(Output(UInt(32.W)))

  b := a +% 1.U

  // This adds a `Verification` layer block inside Foo.
  block(Verification) {

    // Some common logic added here.  The input port `a` is "captured" and
    // used here.
    val a_d0 = RegNext(a)

    // This adds an `Assert` layer block.
    block(Verification.Assert) {
      chisel3.assert(a >= a_d0, "a must always increment")
    }

    // This adds a `Debug` layer block.
    block(UserDefined.Debug) {
      printf("a: %x, a_d0: %x", a, a_d0)
    }

  }

}

```

编译后，这将生成具有以下文件名的两个层包含文件。为每个提取层创建一个文件：

1. `layers_Foo_Verification.sv`
1. `layers_Foo_Verification_Assert.sv`

此外，由于我们添加的一个内联层，生成的SystemVerilog将对预处理器定义`layer_Foo$Verification$Debug`敏感。

用户然后可以在其设计中包含这些文件的任意组合，以包含由`Verification`或`Verification.Assert`层描述的可选功能，并通过设置预处理器宏启用调试。`Verification.Assert`绑定文件自动为用户包含`Verification`绑定文件。

#### 实现说明

:::warning

本节描述了层如何编译的实现。除了绑定文件名或预处理器宏之外的任何内容都不应该被依赖！FIRRTL编译器可能会以不同方式实现这一点，或者可能会以任何合法方式优化层块。例如，与同一层关联的层块可能会合并，层块可能会在层次结构中上移或下移，只向层块扇出的代码可能会沉入其中，未使用的层块可能会被删除。

以下信息仅供用户理解和兴趣。

:::

在实现中，FIRRTL编译器为上述电路创建三个Verilog模块（一个用于`Foo`，一个用于与模块`Foo`中的提取层关联的每个层块）：

1. `Foo`
1. `Foo_Verification`
1. `Foo_Verification_Assert`

这些通常会在名称与模块匹配的单独文件中创建，即`Foo.sv`、`Foo_Verification.sv`和`Foo_Verification_Assert.sv`。

从层块创建的每个模块的端口将根据该层块从层块外部捕获的内容自动确定。在上面的示例中，`Verification`层块捕获了端口`a`。`Assert`层块捕获了`a`和`a_d0`。

:::info

即使没有使用`Verification.Assume`或`Verification.Cover`层的层块，输出中也会生成没有效果的绑定文件。这是由于ABI要求在FIRRTL中定义的层必须生成这些文件。

:::

#### Verilog输出

此示例的完整Verilog输出如下所示：

```scala
// 原始代码块中的标记: mdoc:verilog
// Use ChiselStage instead of chisel3.docs.emitSystemVerilog because we want layers printed here (obviously)
import circt.stage.ChiselStage
ChiselStage.emitSystemVerilog(new Foo, firtoolOpts=Array("-strip-debug-info", "-disable-all-randomization"))
```
