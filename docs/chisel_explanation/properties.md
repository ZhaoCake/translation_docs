---
layout: docs
title:  "Properties"
section: "chisel3"
---

# 属性

Chisel *属性* 表示设计中非硬件的信息。这对于在同一生成器中捕获领域特定知识和设计意图，并与硬件描述一起使用非常有用。

:::warning

属性功能正在积极开发中，尚未被视为稳定。

:::

## 属性类型

使用属性的核心原语是 `Property` 类型。

`Property` 类型的工作方式类似于其他 Chisel [数据类型](../explanations/data-types)，但与指定电路中状态元素或流经电路的线上的值类型不同，属性永远不会流经或影响生成的硬件。相反，它们作为可以连接的端口在层次结构中流动。

`Property` 类型的有用之处在于它们能够表达生成的层次结构中存在的非硬件信息，并且可以组合以创建与设计紧密耦合的特定领域数据模型。具有 `Property` 类型的输入端口表示在实例化其模块时必须提供的数据模型的一部分。具有 `Property` 类型的输出端口表示在实例化其模块时可以访问的数据模型的一部分。随着完整设计的生成，可以同时生成任意数据模型。

以下是合法的 `Property` 类型：

* `Property[Int]`
* `Property[Long]`
* `Property[BigInt]`
* `Property[String]`
* `Property[Boolean]`
* `Property[Seq[A]]` (其中 `A` 本身是一个 `Property`)

## 使用属性

可以通过以下导入语句使用 `Property` 功能：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
import chisel3.properties.Property
```

下面的小节展示了在各种 Chisel 构造中使用 `Property` 类型的示例。

### 属性端口

合法的 `Property` 类型可以用在端口中。例如：

```scala
// 原始代码块中的标记: mdoc:silent
class PortsExample extends RawModule {
  // 一个 Int Property 类型的端口
  val myPort = IO(Input(Property[Int]()))
}
```

### 属性连接

合法的 `Property` 类型可以使用 `:=` 运算符进行连接。例如，一个输入 `Property` 类型的端口可以连接到一个输出 `Property` 类型的端口：

```scala
// 原始代码块中的标记: mdoc:silent
class ConnectExample extends RawModule {
  val inPort = IO(Input(Property[Int]()))
  val outPort = IO(Output(Property[Int]()))
  outPort := inPort
}
```

连接只支持相同的 `Property` 类型之间。例如，一个 `Property[Int]` 只能连接到一个 `Property[Int]`。这由 Scala 编译器强制执行。

### 属性值

合法的 `Property` 类型可以通过将 `Property` 对象应用于 `Property` 类型的值来构造。例如，一个 `Property` 值可以连接到一个输出 `Property` 类型的端口：

```scala
// 原始代码块中的标记: mdoc:silent
class LiteralExample extends RawModule {
  val outPort = IO(Output(Property[Int]()))
  outPort := Property(123)
}
```

### 属性序列

与原始 `Property` 类型类似，`Properties` 的序列也可以用于创建端口和值，它们也可以被连接：

```scala
// 原始代码块中的标记: mdoc:silent
class SequenceExample extends RawModule {
  val inPort = IO(Input(Property[Int]()))
  val outPort1 = IO(Output(Property[Seq[Int]]()))
  val outPort2 = IO(Output(Property[Seq[Int]]()))
  // 字面值序列可以转换为 Property
  outPort1 := Property(Seq(123, 456))
  // Property 端口和字面值可以混合在一起形成序列
  outPort2 := Property(Seq(inPort, Property(789)))
}
```

### 属性表达式

对于某些 `Property` 类型，可以使用 `Property` 值构建表达式。这对于表达由输入 `Property` 值参数化的设计意图很有用。

#### 整数运算

整数 `Property` 类型，如 `Property[Int]`、`Property[Long]` 和 `Property[BigInt]`，可以用于根据 `Property` 值构建算术表达式。

在下面的示例中，`Property[Int]` 类型的输出 `address` 端口通过将 `offset` `Property[Int]` 值相对于输入 `base` `Property[Int]` 值相加来计算。

```scala
// 原始代码块中的标记: mdoc:silent
class IntegerArithmeticExample extends RawModule {
  val base = IO(Input(Property[Int]()))
  val address = IO(Output(Property[Int]()))
  val offset = Property(1024)
  address := base + offset
}
```

下表列出了在整型 `Property` 类型值上支持的算术运算符。

| 运算符 | 描述 |
| ----- | ---- |
| `+`   | 执行加法，如 FIRRTL 规范的整数加法运算部分所定义 |
| `*`   | 执行乘法，如 FIRRTL 规范的整数乘法运算部分所定义 |
| `>>`  | 执行右移，如 FIRRTL 规范的整数右移运算部分所定义 |
| `<<`  | 执行左移，如 FIRRTL 规范的整数左移运算部分所定义 |

#### 序列运算

序列 `Property` 类型，如 `Property[Seq[Int]]`，支持一些基本操作来从现有序列创建新序列。

在下面的示例中，`Property[Seq[Int]]` 类型的输出 `c` 端口是通过连接 `Property[Seq[Int]]` 类型的 `a` 和 `b` 端口计算得出的。

```scala
// 原始代码块中的标记: mdoc:silent
class SequenceOperationExample extends RawModule {
  val a = IO(Input(Property[Seq[Int]]()))
  val b = IO(Input(Property[Seq[Int]]()))
  val c = IO(Output(Property[Seq[Int]]()))
  c := a ++ b
}
```

下表列出了在序列 `Property` 类型值上支持的序列运算符。

| 运算符 | 描述 |
| ----- | ---- |
| `++`  | 执行连接操作，如 FIRRTL 规范的列表连接运算部分所定义 |

### 类和对象

对于 `Property` 类型来说，类和对象就像模块和实例对于硬件类型一样。也就是说，它们提供了一种声明层次结构的方式，通过这些层次结构可以流动 `Property` 类型的值。`Class` 声明了一个层次容器，具有输入和输出 `Property` 端口，以及包含 `Property` 连接和 `Object` 的主体。`Object` 表示 `Class` 的实例化，它要求必须分配任何输入 `Property` 端口，并允许读取任何输出 `Property` 端口。

这允许使用面向对象编程语言的基本原语来构建特定领域的数据模型，并将其直接嵌入到 Chisel 正在构建的实例图中。直观地说，`Class` 的输入就像构造函数参数，在创建 `Object` 时必须提供。类似地，`Class` 的输出就像字段，可以从 `Object` 访问。这种分离允许 `Class` 声明抽象出其主体中创建的任何 `Object` - 从外部来看，必须提供输入，并且只能访问输出。

由 `Class` 声明和 `Object` 实例化表示的图与硬件实例图共存。`Object` 实例可以存在于硬件模块中，提供特定领域的信息，但硬件实例不能存在于 `Class` 声明中。

`Object` 可以被引用，对 `Object` 的引用是一种特殊的 `Property[ClassType]` 类型。这允许由 `Class` 声明和 `Object` 实例捕获的数据模型形成任意图。

为了理解 `Object` 图是如何表示的，以及最终如何被查询，考虑一下硬件实例图是如何展开的。为了构建 `Object` 图，我们首先选择一个入口模块来开始展开。展开过程按照 Verilog 规范对展开的定义进行工作 - 模块和 `Object` 的实例在内存中实例化，连接到它们的输入和输出。输入被提供，输出可以被读取。展开完成后，`Object` 图通过输出端口暴露，这些端口可以包含任何 `Property` 类型，包括对 `Object` 的引用。

为了说明这些部分是如何结合在一起的，考虑以下示例：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.properties.Class
import chisel3.experimental.hierarchy.{instantiable, public, Definition, Instance}

// An abstract description of a CSR, represented as a Class.
@instantiable
class CSRDescription extends Class {
  // An output Property indicating the CSR name.
  val identifier = IO(Output(Property[String]()))
  // An output Property describing the CSR.
  val description = IO(Output(Property[String]()))
  // An output Property indicating the CSR width.
  val width = IO(Output(Property[Int]()))

  // Input Properties to be passed to Objects representing instances of the Class.
  @public val identifierIn = IO(Input(Property[String]()))
  @public val descriptionIn = IO(Input(Property[String]()))
  @public val widthIn = IO(Input(Property[Int]()))

  // Simply connect the inputs to the outputs to expose the values.
  identifier := identifierIn
  description := descriptionIn
  width := widthIn
}
```

`CSRDescription` 是一个 `Class`，它表示有关 CSR 的领域特定信息。它使用 `@instantiable` 和 `@public` 以便 `Class` 可以与 `Definition` 和 `Instance` API 一起使用。

我们希望在 `CSRDescription` 类的 `Object` 上公开的可读字段是一个字符串标识符、一个字符串描述和一个整数位宽，因此这些都是 `Class` 上的输出 `Property` 类型端口。

为了在每个 `Object` 实例化时捕获具体值，我们有相应的输入 `Property` 类型端口，直接连接到输出。这就是我们如何使用 `Class` 表示类似 Scala 的 `case class` 的方式。

```scala
// 原始代码块中的标记: mdoc:silent
// A hardware module representing a CSR and its description.
class CSRModule(
  csrDescDef:     Definition[CSRDescription],
  width:          Int,
  identifierStr:  String,
  descriptionStr: String)
    extends Module {
  override def desiredName = identifierStr

  // Create a hardware port for the CSR value.
  val value = IO(Output(UInt(width.W)))

  // Create a property port for a reference to the CSR description object.
  val description = IO(Output(csrDescDef.getPropertyType))

  // Instantiate a CSR description object, and connect its input properties.
  val csrDescription = Instance(csrDescDef)
  csrDescription.identifierIn := Property(identifierStr)
  csrDescription.descriptionIn := Property(descriptionStr)
  csrDescription.widthIn := Property(width)

  // Create a register for the hardware CSR. A real implementation would be more involved.
  val csr = RegInit(0.U(width.W))

  // Assign the CSR value to the hardware port.
  value := csr

  // Assign a reference to the CSR description object to the property port.
  description := csrDescription.getPropertyReference
}
```

`CSRModule` 是一个 `Module`，它表示 CSR 的（虚拟）硬件以及 `CSRDescription`。使用 `CSRDescription` 的 `Definition`，创建一个 `Object` 并从 `CSRModule` 构造函数参数提供输入。然后，将对 `Object` 的引用连接到 `CSRModule` 输出，以便引用将暴露给外部。

```scala
// 原始代码块中的标记: mdoc:silent
// The entrypoint module.
class Top extends Module {
  // Create a Definition for the CSRDescription Class.
  val csrDescDef = Definition(new CSRDescription)

  // Get the CSRDescription ClassType.
  val csrDescType = csrDescDef.getClassType

  // Create a property port to collect all the CSRDescription object references.
  val descriptions = IO(Output(Property[Seq[csrDescType.Type]]()))

  // Instantiate a couple CSR modules.
  val mcycle = Module(new CSRModule(csrDescDef, 64, "mcycle", "Machine cycle counter."))
  val minstret = Module(new CSRModule(csrDescDef, 64, "minstret", "Machine instructions-retired counter."))

  // Assign references to the CSR description objects to the property port.
  descriptions := Property(Seq(mcycle.description.as(csrDescType), minstret.description.as(csrDescType)))
}
```

`Top` 模块表示入口点。它创建 `CSRDescription` 的 `Definition`，并创建一些 `CSRModule`。然后，它获取描述引用，将它们收集到一个列表中，并输出该列表，以便将其暴露给外部。

虽然不需要使用 `Definition` API 来定义 `Class`，但这是 "安全" 的 API，Chisel 支持与 `Class` 的 `Definition` 和 `Instance` 一起使用。还有一个 "不安全" 的 API。有关更多信息，请参见 `DynamicObject`。

为了说明此示例生成的内容，这里列出了 FIRRTL：

```
FIRRTL version 4.0.0
circuit Top :
  class CSRDescription :
    output identifier : String
    output description : String
    output width : Integer
    input identifierIn : String
    input descriptionIn : String
    input widthIn : Integer

    propassign identifier, identifierIn
    propassign description, descriptionIn
    propassign width, widthIn

  module mcycle :
    input clock : Clock
    input reset : Reset
    output value : UInt<64>
    output description : Inst<CSRDescription>

    object csrDescription of CSRDescription
    propassign csrDescription.identifierIn, String("mcycle")
    propassign csrDescription.descriptionIn, String("Machine cycle counter.")
    propassign csrDescription.widthIn, Integer(64)
    regreset csr : UInt<64>, clock, reset, UInt<64>(0h0)
    connect value, csr
    propassign description, csrDescription

  module minstret :
    input clock : Clock
    input reset : Reset
    output value : UInt<64>
    output description : Inst<CSRDescription>

    object csrDescription of CSRDescription
    propassign csrDescription.identifierIn, String("minstret")
    propassign csrDescription.descriptionIn, String("Machine instructions-retired counter.")
    propassign csrDescription.widthIn, Integer(64)
    regreset csr : UInt<64>, clock, reset, UInt<64>(0h0)
    connect value, csr
    propassign description, csrDescription

  public module Top :
    input clock : Clock
    input reset : UInt<1>
    output descriptions : List<Inst<CSRDescription>>

    inst mcycle of mcycle
    connect mcycle.clock, clock
    connect mcycle.reset, reset
    inst minstret of minstret
    connect minstret.clock, clock
    connect minstret.reset, reset
    propassign descriptions, List<Inst<CSRDescription>>(mcycle.description, minstret.description)
```

为了理解构造的 `Object` 图，我们将考虑一个展开的入口点，然后显示 `Object` 图的假设 JSON 表示。我们从 IR 到 `Object` 图的详细信息超出了本文档的范围，由相关工具实现。

如果我们展开 `Top`，`descriptions` 输出 `Property` 是我们进入 `Object` 图的入口点。在其中，有两个 `Object`，分别是 `mcycle` 和 `minstret` 模块的 `CSRDescription`：

```json mdoc:silent
{
  "descriptions": [
    {
      "identifier": "mcycle",
      "description": "Machine cycle counter.",
      "width": 64
    },
    {
      "identifier": "minstret",
      "description": "Machine instructions-retired counter.",
      "width": 64
    }
  ]
}
```

如果相反地，我们展开其中一个 `CSRModule`，例如 `minstret`，`description` 输出 `Property` 是我们进入 `Object` 图的入口点，其中包含单个 `CSRDescription` 对象：

```json mdoc:silent
{
  "description": {
    "identifier": "minstret",
    "description": "Machine instructions-retired counter.",
    "width": 64
  }
}
```

通过这种方式，输出 `Property` 端口、`Object` 引用和选择的展开入口点允许我们从层次结构中的不同点查看表示特定领域数据模型的 `Object` 图。
