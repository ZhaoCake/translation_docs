---
layout: docs
title:  "警告"
section: "chisel3"
---

# 警告

Chisel 中的警告用于标记旧 API 或语义的弃用，以便后续移除。
作为良好的软件实践，建议 Chisel 用户使用 `--warnings-as-errors` 将警告视为错误；
但是，当升级 Chisel 版本时，这个粗粒度的选项可能会引入大量警告，从而产生问题。
请参阅下面的[警告配置](#警告配置)了解处理大量警告的技巧。

## 警告配置

受 Scala 中 `-Wconf` [的启发](https://www.scala-lang.org/2021/01/12/configuring-and-suppressing-warnings.html)，
Chisel 通过命令行选项 `--warn-conf` 和 `--warn-conf-file` 支持对警告行为进行细粒度控制。

### 基本操作

`--warn-conf` 接受一个由逗号分隔的 `<过滤器>:<动作>` 对序列。
当 Chisel 遇到警告时，会从左到右检查这个序列中的每个对，看看 `过滤器` 是否匹配该警告。
第一个匹配的 `过滤器` 对应的 `动作` 将用于该特定警告。
如果没有 `过滤器` 匹配，则使用默认行为发出警告。

`--warn-conf` 可以指定任意次数。
较早使用的 `--warn-conf` 优先级高于较晚使用的，这与在单个 `--warn-conf` 中检查 `过滤器` 时从左到右递减的优先级相同。
作为一个思维模型，用户可以假装所有的 `--warn-conf` 参数都连接在一起（用逗号分隔）形成一个单独的参数。

### 警告配置文件

`--warn-conf-file` 接受一个包含相同格式的 `<过滤器>:<动作>` 对的文件，这些对用换行符分隔。
以 `#` 开头的行将被视为注释并忽略。
`过滤器` 的检查优先级从文件的上到下递减。

一个命令行可以包含任意数量的 `--warn-conf-file` 和任意数量的 `--warn-conf` 参数。
所有 `--warn-conf*` 参数中的过滤器将按照相同的从左到右递减优先级顺序应用。

### 过滤器

支持的过滤器有：

* `any` - 匹配所有警告
* `id=<整数>` - 匹配具有该整数 id 的警告
* `src=<通配符>` - 当 `<通配符>` 匹配警告发生位置的源定位器文件名时匹配警告

`id` 和 `src` 过滤器可以用 `&` 组合。
任何过滤器最多可以包含一个 `id` 和一个 `src`。
`any` 不能与任何其他过滤器组合。

### 动作

支持的动作有：

* `:s` - 抑制匹配的警告
* `:w` - 将匹配的警告作为警告报告（默认行为）
* `:e` - 将匹配的警告作为错误报告

### 示例

以下示例在正常编译时会发出警告

```scala
// 原始代码块中的标记: mdoc:invisible:reset
// 帮助函数，抛弃返回值使其不在 mdoc 中显示
def compile(gen: => chisel3.RawModule, args: Array[String] = Array()): Unit = {
  circt.stage.ChiselStage.emitCHIRRTL(gen, args = args)
}
```

```scala
// 原始代码块中的标记: mdoc
import chisel3._
class TooWideIndexModule extends RawModule {
  val in = IO(Input(Vec(4, UInt(8.W))))
  val idx = IO(Input(UInt(3.W)))
  val out = IO(Output(UInt(8.W)))
  out := in(idx)
}
compile(new TooWideIndexModule)
```

如警告所示，这是警告 `W004`（可以按照[下文所述](#w004-动态索引太宽)修复），我们可以使用 `id` 过滤器来抑制它，这将抑制此编译运行中该警告的所有实例。

```scala
// 原始代码块中的标记: mdoc
compile(new TooWideIndexModule, args = Array("--warn-conf", "id=4:s"))
```

通常建议使警告抑制尽可能精确，因此我们可以将这个 `id` 过滤器与一个 `src` 通配符过滤器组合，只针对这个文件：

```scala
// 原始代码块中的标记: mdoc
compile(new TooWideIndexModule, args = Array("--warn-conf", "id=4&src=**warnings.md:s"))
```

最后，我们鼓励用户尽可能将警告视为错误，
所以他们应该始终在任何警告配置的末尾添加 `any:e` 以将所有未匹配的警告提升为错误：

```scala
// 原始代码块中的标记: mdoc
compile(new TooWideIndexModule, args = Array("--warn-conf", "id=4&src=**warnings.md:s,any:e"))
// 或
compile(new TooWideIndexModule, args = Array("--warn-conf", "id=4&src=**warnings.md:s", "--warn-conf", "any:e"))
// 或
compile(new TooWideIndexModule, args = Array("--warn-conf", "id=4&src=**warnings.md:s", "--warnings-as-errors"))
```

## 警告词汇表

Chisel 警告都有一个唯一的标识符号，这使它们更容易查找，而且可以按上述方式配置。

### [W001] 不安全的 UInt 到 ChiselEnum 的转换

当将 `UInt` 转换为 `ChiselEnum` 时，如果 `UInt` 可能取到的某些值不是枚举中的合法状态，就会发生此警告。
参见 [ChiselEnum 说明](chisel-enum#casting)获取更多信息和如何修复此警告。

**注意：**这是目前唯一一个没有计划变成错误的警告。

### [W002] 动态位选择太宽

当使用比寻址索引对象的所有位所需宽度更宽的索引动态索引 `UInt` 或 `SInt` 时，会发生此警告。
它表明索引的高位被索引操作忽略了。
可以按照 [Cookbook](../cookbooks/cookbook#how-do-i-resolve-dynamic-index--is-too-widenarrow-for-extractee-) 中的描述修复。

### [W003] 动态位选择太窄

当使用太窄而无法寻址索引对象的所有位的索引动态索引 `UInt` 或 `SInt` 时，会发生此警告。
它表明索引对象的某些位无法通过索引操作访问。
可以按照 [Cookbook](../cookbooks/cookbook#how-do-i-resolve-dynamic-index--is-too-widenarrow-for-extractee-) 中的描述修复。

### [W004] 动态索引太宽

当使用比寻址 `Vec` 的所有元素所需宽度更宽的索引动态索引 `Vec` 时，会发生此警告。
它表明索引的高位被索引操作忽略了。
可以按照 [Cookbook](../cookbooks/cookbook#how-do-i-resolve-dynamic-index--is-too-widenarrow-for-extractee-) 中的描述修复。

### [W005] 动态索引太窄

当使用太小而无法寻址 `Vec` 中所有元素的索引动态索引 `Vec` 时，会发生此警告。
它表明 `Vec` 的某些元素无法通过索引操作访问。
可以按照 [Cookbook](../cookbooks/cookbook#how-do-i-resolve-dynamic-index--is-too-widenarrow-for-extractee-) 中的描述修复。


### [W006] 从大小为 0 的 Vec 中提取

当索引一个没有元素的 `Vec` 时，会发生此警告。
通过删除对大小为零的 `Vec` 的索引操作（可能通过使用 `if-else` 或 `Option.when` 进行保护）来修复。

### [W007] Bundle 字面量值太宽

当创建一个 [Bundle Literal](../appendix/experimental-features#bundle-literals) 时，如果某个字段的字面量值宽度超过了 Bundle 字段的宽度，就会发生此警告。
通过减小字面量的宽度来修复（如果无法在字段宽度内编码该值，则可以选择其他值）。

### [W008] asTypeOf 的返回值将在不久的将来变为只读

:::warning

从 Chisel 7.0.0 开始，这现在是一个错误

:::

此警告表示对 `.asTypeOf(_)` 的调用结果被用作连接的目标。
通过实例化一个线网来修复。

例如，给定以下代码：
```scala
// 原始代码块中的标记: mdoc:compile-only
class MyBundle extends Bundle {
  val foo = UInt(8.W)
  val bar = UInt(8.W)
}
val x = 0.U.asTypeOf(new MyBundle)
x.bar := 123.U
```

可以通过插入一个线网来修复警告：
```scala
// 原始代码块中的标记: mdoc:compile-only
class MyBundle extends Bundle {
  val foo = UInt(8.W)
  val bar = UInt(8.W)
}
val x = WireInit(0.U.asTypeOf(new MyBundle))
x.bar := 123.U
```
