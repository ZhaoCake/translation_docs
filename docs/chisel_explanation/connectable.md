---
layout: docs
title:  "可连接运算符"
section: "chisel3"
---

## 目录
 * [术语](#术语)
 * [概述](#概述)
 * [对齐：翻转与对齐](#对齐翻转与对齐)
 * [输入/输出](#输入输出)
 * [连接具有完全对齐成员的组件](#连接具有完全对齐成员的组件)
   * [单向连接运算符 (`:=`)](#单向连接运算符-)
 * [连接具有混合对齐成员的组件](#连接具有混合对齐成员的组件)
   * [双向连接运算符 (`:<>=`)](#双向连接运算符-)
   * [端口方向计算与连接方向计算](#端口方向计算与连接方向计算)
   * [对齐连接运算符 (`:<=`)](#对齐连接运算符-)
   * [翻转连接运算符 (`:>=`)](#翻转连接运算符-)
   * [强制单向连接运算符 (`:#=`)](#强制单向连接运算符-)
 * [Connectable](#connectable)
   * [连接Records](#连接records)
   * [带有豁免连接的默认值](#带有豁免连接的默认值)
   * [连接具有可选成员的类型](#连接具有可选成员的类型)
   * [始终忽略额外成员（部分连接运算符）](#始终忽略额外成员造成的错误部分连接运算符)
   * [连接具有不同宽度的组件](#连接具有不同宽度的组件)
 * [连接结构不等价的Chisel类型的技术](#连接结构不等价的chisel类型的技术)
   * [连接同一超类型的不同子类型，具有冲突名称](#连接同一超类型的不同子类型具有冲突名称)
   * [通过豁免额外成员连接子类型到超类型](#通过豁免额外成员连接子类型到超类型)
   * [连接不同的子类型](#连接不同的子类型)
 * [常见问题](#常见问题)

## 术语

 * "Chisel类型" - 一个未绑定到硬件的 `Data`，即不是一个组件。（更多详情[在此](chisel-type-vs-scala-type)）。
   * 例如，`UInt(3.W)`、`new Bundle {..}`、`Vec(3, SInt(2.W))` 都是Chisel类型
 * "组件" - 一个绑定到硬件的 `Data`（`IO`、`Reg`、`Wire` 等）
   * 例如，`Wire(UInt(3.W))` 是一个组件，其Chisel类型是 `UInt(3.W)`
 * `Aggregate` - 包含其他Chisel类型或组件的Chisel类型或组件（即 `Vec`、`Record` 或 `Bundle`）
 * `Element` - 不包含其他Chisel类型或组件的Chisel类型或组件（例如 `UInt`、`SInt`、`Clock`、`Bool` 等）
 * "成员" - Chisel类型或组件，或其任何子项（可以是 `Aggregate` 或 `Element`）
   * 例如，`Vec(3, UInt(2.W))(0)` 是父 `Vec` Chisel类型的成员
   * 例如，`Wire(Vec(3, UInt(2.W)))(0)` 是父 `Wire` 组件的成员
   * 例如，`IO(Decoupled(Bool)).ready` 是父 `IO` 组件的成员
 * "相对对齐" - 同一组件或Chisel类型的两个成员是否相对于彼此对齐/翻转
   * 详细定义见[下文](#对齐翻转与对齐)
 * "结构类型检查" - 如果Chisel类型 `A` 和Chisel类型 `B` 具有匹配的bundle字段名称和类型（`Record` vs `Vector` vs `Element`），探测修饰符（探测vs非探测），向量大小，`Element` 类型（UInt/SInt/Bool/Clock），则 `A` 在结构上等价于 `B`
   * 忽略相对对齐（翻转性）
 * "对齐类型检查" - 如果Chisel类型 `A` 的每个成员相对于 `A` 的相对对齐与Chisel类型 `B` 的结构上对应成员相对于 `B` 的相对对齐相同，则Chisel类型 `A` 与另一个Chisel类型 `B` 在对齐上匹配。

## 概述

`Connectable` 运算符是连接Chisel硬件组件的标准方式。

> 注意：有关先前运算符语义的描述，请参见[`连接运算符`](connection-operators)。

所有连接运算符都要求两个硬件组件（消费者和生产者）在结构上类型等价。

结构类型等价规则的一个例外是使用 `Connectable` 机制，详细说明在本文档末尾的[此部分](#连接结构不等价的chisel类型的技术)。

聚合（`Record`、`Vec`、`Bundle`）Chisel类型可以包含相对于彼此翻转的数据成员。
由于这一点，在两个Chisel组件之间有许多期望的连接行为。
以下是Chisel连接运算符，在消费者 `c` 和生产者 `p` 之间：
 * `c := p`（单向）：将所有 `p` 成员连接到 `c`；要求 `c` 和 `p` 没有任何翻转成员
 * `c :#= p`（强制单向）：将所有 `p` 成员连接到 `c`；无论对齐如何
 * `c :<= p`（对齐方向）：从 `p` 连接所有对齐（非翻转）的 `c` 成员
 * `c :>= p`（翻转方向）：从 `c` 连接所有翻转的 `p` 成员
 * `c :<>= p`（双向运算符）：从 `p` 连接所有对齐的 `c` 成员；从 `c` 连接所有翻转的 `p` 成员

这些运算符可能看起来是一组随机的符号；但是，运算符之间的字符是一致的，并且自描述每个运算符的语义：
 * `:` 始终表示消费者，或运算符的左侧。
 * `=` 始终表示生产者，或运算符的右侧。
   * 因此，`c := p` 连接消费者（`c`）和生产者（`p`）。
 * `<` 始终表示一些成员将从生产者驱动到消费者，或从右到左。
   * 因此，`c :<= p` 将生产者（`p`）中的成员驱动到消费者（`c`）中的成员。
 * `>` 始终表示一些信号将从消费者驱动到生产者，或从左到右。
   * 因此，`c :>= p` 将消费者（`c`）中的成员驱动到生产者（`p`）中的成员。
   * 因此，`c :<>= p` 既将成员从 `p` 驱动到 `c`，又将成员从 `c` 驱动到 `p`。
 * `#` 始终表示忽略成员对齐并从生产者驱动到消费者，或从右到左。
   * 因此，`c :#= p` 始终将成员从 `p` 驱动到 `c` 而忽略方向。

> 注意：此外，以 `=` 结尾的运算符具有赋值优先级，这意味着 `x :<>= y + z` 将转换为 `x :<>= (y + z)`，而不是 `(x :<>= y) + z`。
这对于 `<>` 运算符来说不是真的，这是用户的一个小痛点。


## 对齐：翻转与对齐

成员的对齐是一个相对属性：成员相对于同一组件或Chisel类型的另一个成员是对齐/翻转的。
因此，必须始终说明成员是否相对于该类型的另一个成员（父级、兄弟、子级等）翻转/对齐。

我们使用以下非嵌套bundle `Parent` 的示例，让我们陈述 `p` 成员之间的所有对齐关系。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class Parent extends Bundle {
  val alignedChild = UInt(32.W)
  val flippedChild = Flipped(UInt(32.W))
}
class MyModule0 extends Module {
  val p = Wire(new Parent)
}
```

首先，每个成员总是与自身对齐：
 * `p` 相对于 `p` 是对齐的
 * `p.alignedChild` 相对于 `p.alignedChild` 是对齐的
 * `p.flippedChild` 相对于 `p.flippedChild` 是对齐的

接下来，我们列出所有父/子关系。
因为 `flippedChild` 字段是 `Flipped`，它改变了相对于其父级的对齐方式。
 * `p` 相对于 `p.alignedChild` 是对齐的
 * `p` 相对于 `p.flippedChild` 是翻转的

最后，我们可以列出所有兄弟关系：
 * `p.alignedChild` 相对于 `p.flippedChild` 是翻转的

下一个示例有一个嵌套bundle `GrandParent`，它实例化了一个对齐的 `Parent` 字段和翻转的 `Parent` 字段。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class GrandParent extends Bundle {
  val alignedParent = new Parent
  val flippedParent = Flipped(new Parent)
}
class MyModule1 extends Module {
  val g = Wire(new GrandParent)
}
```

考虑以下祖父母和孙子之间的对齐关系。
奇数个翻转表示翻转关系；偶数个翻转表示对齐关系。
 * `g` 相对于 `g.flippedParent.flippedChild` 是对齐的
 * `g` 相对于 `g.alignedParent.alignedChild` 是对齐的
 * `g` 相对于 `g.flippedParent.alignedChild` 是翻转的
 * `g` 相对于 `g.alignedParent.flippedChild` 是翻转的

考虑以下从 `g.alignedParent` 和 `g.flippedParent` 开始的对齐关系。
*注意，`g.alignedParent` 相对于 `g` 是对齐还是翻转对 `g.alignedParent` 和 `g.alignedParent.alignedChild` 之间的对齐/翻转关系没有影响，因为对齐仅相对于所讨论的两个成员！*：
 * `g.alignedParent` 相对于 `g.alignedParent.alignedChild` 是对齐的
 * `g.flippedParent` 相对于 `g.flippedParent.alignedChild` 是对齐的
 * `g.alignedParent` 相对于 `g.alignedParent.flippedChild` 是翻转的
 * `g.flippedParent` 相对于 `g.flippedParent.flippedChild` 是翻转的

总之，成员相对于硬件组件的另一个成员是对齐或翻转的。
这意味着确定任何运算符行为所需的仅是消费者/生产者的类型。
*消费者/生产者是否是更大bundle的成员无关紧要；你只需要知道消费者/生产者的类型*。

## 输入/输出

`Input(gen)`/`Output(gen)` 是强制运算符。
它们执行两个功能：(1)创建一个新的Chisel类型，其中所有递归子成员的翻转都被移除（仍然在结构上等价于 `gen` 但不再在对齐类型上等价），以及(2)如果是 `Input` 则应用 `Flipped`，如果是 `Output` 则保持对齐（不执行任何操作）。
例如，如果我们想象一个名为 `cloneChiselTypeButStripAllFlips` 的函数，那么 `Input(gen)` 在结构和对齐类型上等价于 `Flipped(cloneChiselTypeButStripAllFlips(gen))`。

请注意，如果 `gen` 是非聚合的，那么 `Input(nonAggregateGen)` 等价于 `Flipped(nonAggregateGen)`。

> 未来的工作将重构这些原语向用户暴露的方式，使Chisel的类型系统更加直观。
见 [https://github.com/chipsalliance/chisel3/issues/2643]。

考虑到这一点，我们可以看看以下示例，并详细说明成员的相对对齐关系。

首先，我们可以使用类似于 `Parent` 的示例，但使用 `Input/Output` 而不是 `Flipped`。
因为 `alignedChild` 和 `flippedChild` 是非聚合的，所以 `Input` 基本上就是一个 `Flipped`，因此对齐方式与之前的 `Parent` 示例相比没有变化。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class ParentWithOutputInput extends Bundle {
  val alignedCoerced = Output(UInt(32.W)) // 等同于 UInt(32.W)
  val flippedCoerced = Input(UInt(32.W))  // 等同于 Flipped(UInt(32.W))
}
class MyModule2 extends Module {
  val p = Wire(new ParentWithOutputInput)
}
```

对齐关系与之前的 `Parent` 示例相同：
 * `p` 相对于 `p` 是对齐的
 * `p.alignedCoerced` 相对于 `p.alignedCoerced` 是对齐的
 * `p.flippedCoerced` 相对于 `p.flippedCoerced` 是对齐的
 * `p` 相对于 `p.alignedCoerced` 是对齐的
 * `p` 相对于 `p.flippedCoerced` 是翻转的
 * `p.alignedCoerced` 相对于 `p.flippedCoerced` 是翻转的

下一个示例有一个嵌套bundle `GrandParent`，它实例化了一个 `Output` 类型的 `ParentWithOutputInput` 字段和一个 `Input` 类型的 `ParentWithOutputInput` 字段。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class GrandParentWithOutputInput extends Bundle {
  val alignedCoerced = Output(new ParentWithOutputInput)
  val flippedCoerced = Input(new ParentWithOutputInput)
}
class MyModule3 extends Module {
  val g = Wire(new GrandParentWithOutputInput)
}
```

请记住，`Output(gen)/Input(gen)` 会递归地去除任何递归子成员的 `Flipped`。
这使得 `gen` 的每个成员都与 `gen` 的其他所有成员对齐。

考虑祖父母和孙子之间的以下对齐关系。
因为 `alignedCoerced` 和 `flippedCoerced` 与它们的所有递归成员对齐，所以它们是完全对齐的。
因此，只有它们与 `g` 的对齐关系影响孙子的对齐关系：
 * `g` 相对于 `g.alignedCoerced.alignedCoerced` 是对齐的
 * `g` 相对于 `g.alignedCoerced.flippedCoerced` 是对齐的
 * `g` 相对于 `g.flippedCoerced.alignedCoerced` 是翻转的
 * `g` 相对于 `g.flippedCoerced.flippedCoerced` 是翻转的

考虑从 `g.alignedCoerced` 和 `g.flippedCoerced` 开始的以下对齐关系。
*请注意，`g.alignedCoerced` 相对于 `g` 是对齐还是翻转对 `g.alignedCoerced` 和 `g.alignedCoerced.alignedCoerced` 或 `g.alignedCoerced.flippedCoerced` 之间的对齐/翻转关系没有影响，因为对齐仅相对于所讨论的两个成员！但是，由于对齐被强制，`g.alignedCoerced`/`g.flippedAligned` 与其子项之间的所有关系都是对齐的*：
 * `g.alignedCoerced` 相对于 `g.alignedCoerced.alignedCoerced` 是对齐的
 * `g.alignedCoerced` 相对于 `g.alignedCoerced.flippedCoerced` 是对齐的
 * `g.flippedCoerced` 相对于 `g.flippedCoerced.alignedCoerced` 是对齐的
 * `g.flippedCoerced` 相对于 `g.flippedCoerced.flippedCoerced` 是对齐的

总之，`Input(gen)` 和 `Output(gen)` 递归地强制子项对齐，并决定 `gen` 相对于其父bundle（如果存在）的对齐方式。

## 连接具有完全对齐成员的组件

### 单向连接运算符 (`:=`)

对于所有成员相互对齐（非翻转）的简单连接，使用 `:=`：


```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class FullyAlignedBundle extends Bundle {
  val a = Bool()
  val b = Bool()
}
class Example0 extends RawModule {
  val incoming = IO(Flipped(new FullyAlignedBundle))
  val outgoing = IO(new FullyAlignedBundle)
  outgoing := incoming
}
```

这会生成以下Verilog代码，其中 `incoming` 的每个成员都驱动 `outgoing` 的每个成员：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example0)
```

> 你可能会想："等等，我困惑了！`incoming` 不是被翻转而 `outgoing` 是对齐的吗？" —— 不是！`incoming` 是否与 `outgoing` 对齐没有意义；记住，你只在同一组件或Chisel类型的成员之间评估对齐关系。
因为组件总是与自身对齐，`outgoing` 与 `outgoing` 对齐，而 `incoming` 与 `incoming` 对齐，所以没有问题。
它们相对于其他任何东西的翻转程度都无关紧要。

## 连接具有混合对齐成员的组件

聚合Chisel类型可以包含相对于彼此翻转的数据成员；在下面的示例中，`alignedChild` 和 `flippedChild` 相对于 `MixedAlignmentBundle` 是对齐/翻转的。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class MixedAlignmentBundle extends Bundle {
  val alignedChild = Bool()
  val flippedChild = Flipped(Bool())
}
```

由于这一点，两个Chisel组件之间有许多期望的连接行为。
首先，我们将介绍最常见的Chisel连接运算符 `:<>=`，它适用于连接具有混合对齐成员的组件，然后花点时间研究端口方向和连接方向之间常见的混淆源。
然后，我们将探索其余的Chisel连接运算符。


### 双向连接运算符 (`:<>=`)

对于希望采用"类批量连接语义"的连接，其中对齐成员从生产者驱动到消费者，翻转成员从消费者驱动到生产者，使用 `:<>=`。

```scala
// 原始代码块中的标记: mdoc:silent
class Example1 extends RawModule {
  val incoming = IO(Flipped(new MixedAlignmentBundle))
  val outgoing = IO(new MixedAlignmentBundle)
  outgoing :<>= incoming
}
```

这会生成以下Verilog代码，其中对齐成员从 `incoming` 驱动到 `outgoing`，翻转成员从 `outgoing` 驱动到 `incoming`：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example1)
```

### 端口方向计算与连接方向计算

一个常见问题是，如果使用混合对齐连接（如 `:<>=`）连接父组件的子成员，子成员与其父组件的对齐关系会影响什么吗？答案是否定的，因为*对齐始终相对于正在连接的对象计算，且成员始终与自身对齐。*

在以下示例中，从 `incoming.alignedChild` 连接到 `outgoing.alignedChild`，`incoming.alignedChild` 是否与 `incoming` 对齐无关紧要，因为 `:<>=` 仅根据正在连接的对象计算对齐关系，而 `incoming.alignedChild` 与 `incoming.alignedChild` 是对齐的。

```scala
// 原始代码块中的标记: mdoc:silent
class Example1a extends RawModule {
  val incoming = IO(Flipped(new MixedAlignmentBundle))
  val outgoing = IO(new MixedAlignmentBundle)
  outgoing.alignedChild :<>= incoming.alignedChild // incoming.alignedChild 是否与 incoming 对齐/翻转与 :<>= 连接的内容无关
}
```

虽然 `incoming.flippedChild` 与 `incoming` 的对齐关系不影响我们的运算符，但它确实影响 `incoming.flippedChild` 是我们模块的输出端口还是输入端口。
一个常见的混淆源是将确定 `incoming.flippedChild` 是否解析为Verilog的 `output`/`input`（端口方向计算）的过程与确定 `:<>=` 如何驱动什么到什么（连接方向计算）的过程混淆。
虽然这两个过程都考虑相对对齐，但它们是不同的。

端口方向计算始终根据标记为 `IO` 的组件计算对齐关系。
`IO(Flipped(gen))` 是一个传入端口，`gen` 的任何与 `gen` 对齐/翻转的成员都是传入/传出端口。
`IO(gen)` 是一个传出端口，`gen` 的任何与 `gen` 对齐/翻转的成员都是传出/传入端口。

连接方向计算始终根据连接引用的显式消费者/生产者计算对齐关系。
如果连接 `incoming :<>= outgoing`，则根据 `incoming` 和 `outgoing` 计算对齐关系。
如果连接 `incoming.alignedChild :<>= outgoing.alignedChild`，则根据 `incoming.alignedChild` 和 `outgoing.alignedChild` 计算对齐关系（`incoming` 与 `incoming.alignedChild` 的对齐关系无关紧要）。

这意味着用户可能会尝试连接到其模块的输入端口！如果我写 `x :<>= y`，而 `x` 是当前模块的输入，那么连接就是试图做到这一点。
然而，由于从当前模块内部无法驱动输入端口，Chisel将抛出错误。
这与使用单向运算符时会得到的错误相同：如果 `x` 是当前模块的输入，`x := y` 将抛出同样的错误。
*组件是否可驱动与尝试驱动它的任何连接运算符的语义无关。*

总之，端口方向计算是相对于标记为 `IO` 的根进行的，但连接方向计算是相对于连接正在进行的消费者/生产者进行的。
这具有积极特性，即连接语义仅基于消费者/生产者的Chisel结构类型及其相对对齐关系（无需更多，无需更少）。

### 对齐连接运算符 (`:<=`)

对于希望采用"类批量连接语义"的对齐半部分的连接，其中对齐成员从生产者驱动到消费者，而忽略翻转成员，使用 `:<=`（"对齐连接"）。

```scala
// 原始代码块中的标记: mdoc:silent
class Example2 extends RawModule {
  val incoming = IO(Flipped(new MixedAlignmentBundle))
  val outgoing = IO(new MixedAlignmentBundle)
  incoming.flippedChild := DontCare // 否则FIRRTL会抛出未初始化错误
  outgoing :<= incoming
}
```

这会生成以下Verilog代码，其中对齐成员从 `incoming` 驱动到 `outgoing`，而忽略翻转成员：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example2)
```

### 翻转连接运算符 (`:>=`)

对于希望采用"类批量连接语义"的翻转半部分的连接，其中对齐成员被忽略而翻转成员从消费者连接到生产者，使用 `:>=`（"翻转连接"或"反压连接"）。

```scala
// 原始代码块中的标记: mdoc:silent
class Example3 extends RawModule {
  val incoming = IO(Flipped(new MixedAlignmentBundle))
  val outgoing = IO(new MixedAlignmentBundle)
  outgoing.alignedChild := DontCare // 否则FIRRTL会抛出未初始化错误
  outgoing :>= incoming
}
```

这会生成以下Verilog代码，其中对齐成员被忽略，翻转成员从 `outgoing` 驱动到 `incoming`：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example3)
```

> 注意：敏锐的观察者会发现 `c :<>= p` 在语义上等同于 `c :<= p` 后跟 `c :>= p`。

### 强制单向连接运算符 (`:#=`)

对于希望每个生产者成员始终驱动每个消费者成员的连接，无论对齐如何，使用 `:#=`（"强制连接"）。
这个运算符对于初始化包含混合对齐成员的类型的wire很有用。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.experimental.BundleLiterals._
class Example4 extends RawModule {
  val w = Wire(new MixedAlignmentBundle)
  dontTouch(w) // 这样我们可以在输出的Verilog中看到它
  w :#= (new MixedAlignmentBundle).Lit(_.alignedChild -> true.B, _.flippedChild -> true.B)
}
```

这会生成以下Verilog代码，其中所有成员都从字面值驱动到 `w`，无论对齐如何：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example4)
```

> 注意：敏锐的观察者会发现 `c :#= p` 在语义上等同于 `c :<= p` 后跟 `p :>= c`（注意在第二个连接中 `p` 和 `c` 交换了位置）。

`:#=` 的另一个用例是将混合方向的bundle连接到完全对齐的监视器。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.experimental.BundleLiterals._
class Example4b extends RawModule {
  val monitor = IO(Output(new MixedAlignmentBundle))
  val w = Wire(new MixedAlignmentBundle)
  dontTouch(w) // 这样我们可以在输出的Verilog中看到它
  w :#= DontCare
  monitor :#= w
}
```

这会生成以下Verilog代码，其中所有成员都从字面值驱动到 `w`，无论对齐如何：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example4b)
```
## Connectable

有时用户希望连接不是类型等价的Chisel组件。
例如，用户可能希望连接匿名的 `Record` 组件，这些组件可能有字段的交集是等价的，但由于结构上不等价而无法连接。
或者，有人可能希望连接具有不同宽度的两种类型。

`Connectable` 是在这些场景中特化连接运算符行为的机制。
对于在连接到的另一个组件中不存在的附加成员，或者对于不匹配的宽度，或者对于始终排除不被连接的成员，可以从 `Connectable` 对象中明确调用它们，而不是触发错误。

此外，还有其他技术可用于解决类似用例，包括 `.viewAsSuperType`、对超类型的静态转换（例如 `(x: T)`）或创建自定义 `DataView`。
关于何时使用每种技术的讨论，请继续[此处](#连接结构不等价的chisel类型的技术)。

本节演示了如何在多种情况下使用 `Connectable`。

### 连接Records

一个用例是尝试连接两个 `Record`；对于匹配的成员，它们应该被连接，但对于不匹配的成员，由于它们不匹配而导致的错误应该被忽略。
为了实现这一点，使用其他运算符初始化所有 `Record` 成员，然后使用 `:<>=` 和 `.waive` 只连接匹配的成员。

> 请注意，`.viewAsSuperType`、静态转换或自定义 `DataView` 都无法帮助解决这种情况，因为Scala类型仍然是 `Record`。

```scala
// 原始代码块中的标记: mdoc:silent
import scala.collection.immutable.SeqMap

class Example9 extends RawModule {
  val abType = new Record { val elements = SeqMap("a" -> Bool(), "b" -> Flipped(Bool())) }
  val bcType = new Record { val elements = SeqMap("b" -> Flipped(Bool()), "c" -> Bool()) }

  val p = IO(Flipped(abType))
  val c = IO(bcType)

  DontCare :>= p
  c :<= DontCare

  c.waive(_.elements("c")):<>= p.waive(_.elements("a"))
}
```

这会生成以下Verilog代码，其中 `p.b` 从 `c.b` 驱动：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example9)
```

### 带有豁免连接的默认值

另一个用例是尝试连接两个 `Record`；对于匹配的成员，它们应该被连接，但对于不匹配的成员，*它们应该被连接到默认值*。
为了实现这一点，使用其他运算符初始化所有 `Record` 成员，然后使用 `:<>=` 和 `.waive` 只连接匹配的成员。


```scala
// 原始代码块中的标记: mdoc:silent
import scala.collection.immutable.SeqMap

class Example10 extends RawModule {
  val abType = new Record { val elements = SeqMap("a" -> Bool(), "b" -> Flipped(Bool())) }
  val bcType = new Record { val elements = SeqMap("b" -> Flipped(Bool()), "c" -> Bool()) }

  val p = Wire(abType)
  val c = Wire(bcType)

  dontTouch(p) // 这样它就不会因为示例而被常量传播掉
  dontTouch(c) // 这样它就不会因为示例而被常量传播掉

  p :#= abType.Lit(_.elements("a") -> true.B, _.elements("b") -> true.B)
  c :#= bcType.Lit(_.elements("b") -> true.B, _.elements("c") -> true.B)

  c.waive(_.elements("c")) :<>= p.waive(_.elements("a"))
}
```

这会生成以下Verilog代码，其中 `p.b` 从 `c.b` 驱动，而 `p.a`、`c.b` 和 `c.c` 被初始化为默认值：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example10)
```

### 连接具有可选成员的类型

在以下示例中，我们可以使用 `:<>=` 和 `.waive` 连接两个 `MyDecoupledOpt`，其中只有一个有 `bits` 成员。

```scala
// 原始代码块中的标记: mdoc:silent
class MyDecoupledOpt(hasBits: Boolean) extends Bundle {
  val valid = Bool()
  val ready = Flipped(Bool())
  val bits = if (hasBits) Some(UInt(32.W)) else None
}
class Example6 extends RawModule {
  val in  = IO(Flipped(new MyDecoupledOpt(true)))
  val out = IO(new MyDecoupledOpt(false))
  out :<>= in.waive(_.bits.get) // 我们可以知道调用 .get 是因为我们可以检查 in.bits.isEmpty
}
```

这会生成以下Verilog代码，其中 `ready` 和 `valid` 被连接，而 `bits` 被忽略：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example6)
```

### 始终忽略额外成员造成的错误（部分连接运算符）

最不安全的连接是只连接消费者和生产者中都存在的成员，并忽略所有其他成员。
这是不安全的，因为这种连接在任何Chisel类型上都不会出错。

要做到这一点，你可以使用 `.waiveAll` 和静态转换到 `Data`：

```scala
// 原始代码块中的标记: mdoc:silent
class OnlyA extends Bundle {
  val a = UInt(32.W)
}
class OnlyB extends Bundle {
  val b = UInt(32.W)
}
class Example11 extends RawModule {
  val in  = IO(Flipped(new OnlyA))
  val out = IO(new OnlyB)

  out := DontCare

  (out: Data).waiveAll :<>= (in: Data).waiveAll
}
```

这会生成以下Verilog代码，其中没有任何连接：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example11)
```

### 连接具有不同宽度的组件

非 `Connectable` 运算符会在将具有较大宽度的组件连接到具有较小宽度的组件时隐式截断。
`Connectable` 运算符不允许这种隐式截断行为，并要求被驱动的组件的宽度等于或大于源组件的宽度。

如果需要隐式截断行为，那么 `Connectable` 提供了一个 `squeeze` 机制，它将允许连接继续进行隐式截断。

```scala
// 原始代码块中的标记: mdoc:silent
import scala.collection.immutable.SeqMap

class Example14 extends RawModule {
  val p = IO(Flipped(UInt(4.W)))
  val c = IO(UInt(3.W))

  c :<>= p.squeeze
}
```

这会生成以下Verilog代码，其中 `p` 在驱动 `c` 之前被截断：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example14)
```

### 从Connectable上的任何运算符中排除成员

如果用户希望始终从连接中排除某个字段，请使用 `.exclude` 机制，它永远不会连接该字段（就好像它对连接不存在一样）。

请注意，如果字段在生产者和消费者中都匹配，但只有一个被排除，另一个未排除的字段仍会触发错误；要解决此问题，请使用 `.waive` 或 `.exclude`。

```scala
// 原始代码块中的标记: mdoc:silent
import scala.collection.immutable.SeqMap

class BundleWithSpecialField extends Bundle {
  val foo = UInt(3.W)
  val special = Bool()
}
class Example15 extends RawModule {
  val p = IO(Flipped(new BundleWithSpecialField()))
  val c = IO(new BundleWithSpecialField())

  c.special := true.B // 必须初始化它

  c.exclude(_.special) :<>= p.exclude(_.special)
}
```

This generates the following Verilog, where the `special` field is not connected:

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example15)
```

## 连接结构不等价的Chisel类型的技术

`DataView` 和 `.viewAsSupertype` 创建一个具有不同Chisel类型的组件视图。
这意味着用户可以首先创建消费者或生产者（或两者）的 `DataView`，使Chisel类型在结构上等价。
当消费者和生产者之间的差异不是超级嵌套，并且它们具有编码其结构的丰富Scala类型时，这种方法很有用。
一般来说，`DataView` 是首选机制（如果可以使用的话），因为它在Scala类型中保留了最多的Chisel信息，但在许多情况下它不起作用，因此必须回退到使用 `Connectable`。

`Connectable` 不改变Chisel类型，而是改变运算符的语义，使其在豁免成员悬空或未连接时不报错。
当消费者和生产者之间的差异在Scala类型系统中不显示（例如，类型为 `Option[Data]` 的存在/缺失字段，或匿名 `Record`），或者深度嵌套在创建 `DataView` 特别繁重的bundle中时，这种方法很有用。

静态转换（例如 `(x: T)`）允许连接具有不同Scala类型的组件，但保持Chisel类型不变。
即使Scala类型不同，也可以使用它来强制进行连接。

> 有人可能会疑惑，如果运算符要求相同的Scala类型可以轻易绕过，为什么一开始就要求它们相同？
原因是鼓励用户使用Scala类型系统来编码Chisel信息，因为这可以使他们的代码更加健壮；然而，我们不想过于严格，因为有时候我们希望允许用户"就是要连接这个东西"。

当其他方法都失败时，始终可以手动展开连接，成员逐个地实现他们想要的行为。
这种方法的缺点是冗长，并且向组件添加新成员将需要更新手动连接。

关于 `Connectable` 与 `.viewAsSupertype`/`DataView` 与静态转换（例如 `(x: T)`）需要记住的事项：

- `DataView` 和 `.viewAsSupertype` 会预先移除新视图中不存在的成员，而新视图具有不同的Chisel类型，因此 `DataView` *确实*影响连接的内容
- `Connectable` 可用于豁免最终悬空或未连接的成员上的错误。
重要的是，`Connectable` 豁免*不会*影响连接的内容
- 静态转换不会移除额外的成员，因此静态转换*不会*影响连接的内容

### 连接同一超类型的不同子类型，具有冲突的名称

在这些示例中，我们将连接 `MyDecoupled` 和 `MyDecoupledOtherBits`。
两者都是 `MyReadyValid` 的子类型，且都有一个 `UInt(32.W)` 类型的 `bits` 字段。

第一个示例将使用 `.viewAsSupertype` 将它们作为 `MyReadyValid` 连接。
因为它改变了Chisel类型以省略两个 `bits` 字段，所以 `bits` 字段未连接。

```scala
// 原始代码块中的标记: mdoc:silent
import experimental.dataview._
class MyDecoupledOtherBits extends MyReadyValid {
  val bits = UInt(32.W)
}
class Example12 extends RawModule {
  val in  = IO(Flipped(new MyDecoupled))
  val out = IO(new MyDecoupledOtherBits)

  out := DontCare

  out.viewAsSupertype(new MyReadyValid) :<>= in.viewAsSupertype(new MyReadyValid)
}
```

注意 `bits` 字段未连接。

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example12)
```

第二个示例将使用静态转换和 `.waive(_.bits)` 将它们作为 `MyReadyValid` 连接。
注意，由于静态转换不改变Chisel类型，连接发现消费者和生产者都有一个 `bits` 字段。
这意味着由于它们在结构上等价，它们匹配并被连接。
`waive(_.bits)` 不起作用，因为 `bits` 既不悬空也不是未连接的。



```scala
// 原始代码块中的标记: mdoc:silent
import experimental.dataview._
class Example13 extends RawModule {
  val in  = IO(Flipped(new MyDecoupled))
  val out = IO(new MyDecoupledOtherBits)

  out := DontCare

  out.waiveAs[MyReadyValid](_.bits) :<>= in.waiveAs[MyReadyValid](_.bits)
}
```

注意，`bits` 字段确实被连接了，即使它们被豁免，因为 `.waive` 只是改变了当它们缺失时是否应该抛出错误，而不是在它们结构等价时不连接它们。
要始终省略连接，请在一侧使用 `.exclude`，在另一侧使用 `.exclude` 或 `.waive`。

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example13)
```

### 通过豁免额外成员连接子类型到超类型

> 注意，在此示例中，最好使用 `.viewAsSupertype`。

在以下示例中，我们可以使用 `:<>=` 通过豁免 `bits` 成员将 `MyReadyValid` 连接到 `MyDecoupled`。

```scala
// 原始代码块中的标记: mdoc:silent
class MyReadyValid extends Bundle {
  val valid = Bool()
  val ready = Flipped(Bool())
}
class MyDecoupled extends MyReadyValid {
  val bits = UInt(32.W)
}
class Example5 extends RawModule {
  val in  = IO(Flipped(new MyDecoupled))
  val out = IO(new MyReadyValid)
  out :<>= in.waiveAs[MyReadyValid](_.bits)
}
```

这会生成以下Verilog代码，其中 `ready` 和 `valid` 被连接，而 `bits` 被忽略：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example5)
```

### 连接不同的子类型

> 注意，在此示例中，最好使用 `.viewAsSupertype`。

注意，连接运算符要求 `consumer` 和 `producer` 具有相同的Scala类型，以鼓励静态捕获更多信息，但它们总是可以在连接之前转换为 `Data` 或其他共同的超类型。

在以下示例中，我们可以使用 `:<>=` 和 `.waiveAs` 连接 `MyReadyValid` 的两个不同子类型。

```scala
// 原始代码块中的标记: mdoc:silent
class HasBits extends MyReadyValid {
  val bits = UInt(32.W)
}
class HasEcho extends MyReadyValid {
  val echo = Flipped(UInt(32.W))
}
class Example7 extends RawModule {
  val in  = IO(Flipped(new HasBits))
  val out = IO(new HasEcho)
  out.waiveAs[MyReadyValid](_.echo) :<>= in.waiveAs[MyReadyValid](_.bits)
}
```

这会生成以下Verilog代码，其中 `ready` 和 `valid` 被连接，而 `bits` 和 `echo` 被忽略：

```scala
// 原始代码块中的标记: mdoc:verilog
chisel3.docs.emitSystemVerilog(new Example7)
```

## 常见问题

### 如何尽可能灵活地连接两个项目（尽力而为但永不报错）

使用 `.unsafe`（豁免并允许挤压所有字段）。

```scala
// 原始代码块中的标记: mdoc:silent
class ExampleUnsafe extends RawModule {
  val in  = IO(Flipped(new Bundle { val foo = Bool(); val bar = Bool() }))
  val out = IO(new Bundle { val baz = Bool(); val bar = Bool() })
  out.unsafe :<>= in.unsafe // bar被连接，且没有错误
}
```

### 如何连接两个项目但不关心Scala类型是否等价？

使用 `.as`（向上转换Scala类型）。

```scala
// 原始代码块中的标记: mdoc:silent
class ExampleAs extends RawModule {
  val in  = IO(Flipped(new Bundle { val foo = Bool(); val bar = Bool() }))
  val out = IO(new Bundle { val foo = Bool(); val bar = Bool() })
  // foo和bar被连接，尽管Scala类型不相同
  out.as[Data] :<>= in.as[Data]
}
```
