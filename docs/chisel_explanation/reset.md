---
layout: docs
title:  "Reset"
section: "chisel3"
---

# 复位

```scala mdoc:invisible
import chisel3._

class Submodule extends Module
```

从 Chisel 3.2.0 开始，Chisel 3 同时支持同步和异步复位，这意味着它可以原生地生成同步复位和异步复位的寄存器。

生成的寄存器类型取决于与寄存器相关联的复位信号的类型。

有三种类型的复位实现了一个公共的 `Reset` 特质：
* `Bool` - 通过 `Bool()` 构造。也称为"同步复位"。
* `AsyncReset` - 通过 `AsyncReset()` 构造。也称为"异步复位"。
* `Reset` - 通过 `Reset()` 构造。也称为"抽象复位"。

由于实现原因，具体的 Scala 类型是 `ResetType`。从风格上来说，我们避免使用 `ResetType`，而是使用公共特质 `Reset`。

具有 `Bool` 类型复位信号的寄存器被生成为同步复位触发器。
具有 `AsyncReset` 类型复位信号的寄存器被生成为异步复位触发器。
具有 `Reset` 类型复位信号的寄存器将在 FIRRTL 编译期间 _推断_ 其复位类型。

### 复位推断

FIRRTL 将为任何抽象 `Reset` 类型的信号推断一个具体类型。
规则如下：
1. 如果一个抽象 `Reset` 在其输入和输出扇出中只有 `AsyncReset`、抽象 `Reset` 和 `DontCare` 类型的信号，则推断为 `AsyncReset` 类型
2. 如果一个抽象 `Reset` 在其输入和输出扇出中同时包含 `Bool` 和 `AsyncReset` 类型的信号，这是一个错误。
3. 否则，抽象 `Reset` 将推断为 `Bool` 类型。

你可以把 (3) 看作是 (1) 的镜像，用 `Bool` 替换 `AsyncReset`，并增加了一条额外的规则：
如果抽象 `Reset` 在其输入和输出扇出中既没有 `AsyncReset` 也没有 `Bool`，则默认为 `Bool` 类型。
这种"默认"情况很少见，意味着复位信号最终由 `DontCare` 驱动。

### 隐式复位

`Module` 的 `reset` 是抽象 `Reset` 类型。
在 Chisel 3.2.0 之前，该字段的类型是 `Bool`。
为了向后兼容，如果顶层模块有一个隐式复位，其类型将默认为 `Bool`。

#### 设置隐式复位类型

_Chisel 3.3.0 新功能_

如果你想从模块内部设置复位类型（包括顶层 `Module`），而不是依赖 _复位推断_，你可以混入以下特质之一：
* `RequireSyncReset` - 将 `reset` 的类型设置为 `Bool`
* `RequireAsyncReset` - 将 `reset` 的类型设置为 `AsyncReset`

例如：

```scala mdoc:silent
class MyAlwaysSyncResetModule extends Module with RequireSyncReset {
  val mySyncResetReg = RegInit(false.B) // reset 的类型是 Bool
}
```

```scala mdoc:silent
class MyAlwaysAsyncResetModule extends Module with RequireAsyncReset {
  val myAsyncResetReg = RegInit(false.B) // reset 的类型是 AsyncReset
}
```

**注意：**这设置了具体类型，但 Scala 类型仍然保持为 `Reset`，所以可能仍然需要类型转换。
这在逻辑中使用 `Bool` 类型的复位时最常见。

### 复位无关代码

抽象 `Reset` 的目的是使得可以设计与所使用的复位规则无关的硬件。
这使得工具和设计可以重用，只要复位规则对于块的功能来说并不重要。

考虑以下两个示例模块，它们与其中使用的复位类型无关：

```scala mdoc:silent
class ResetAgnosticModule extends Module {
  val io = IO(new Bundle {
    val out = UInt(4.W)
  })
  val resetAgnosticReg = RegInit(0.U(4.W))
  resetAgnosticReg := resetAgnosticReg + 1.U
  io.out := resetAgnosticReg
}

class ResetAgnosticRawModule extends RawModule {
  val clk = IO(Input(Clock()))
  val rst = IO(Input(Reset()))
  val out = IO(Output(UInt(8.W)))

  val resetAgnosticReg = withClockAndReset(clk, rst)(RegInit(0.U(8.W)))
  resetAgnosticReg := resetAgnosticReg + 1.U
  out := resetAgnosticReg
}
```

这些模块可以在同步和异步复位域中使用。
它们的复位类型将根据它们使用的上下文进行推断。

### 强制复位类型

你可以按照[上文](#设置隐式复位类型)所述设置模块的隐式复位类型。

你也可以通过转换来强制复位的具体类型。
* `.asBool` 会将 `Reset` 重新解释为 `Bool`
* `.asAsyncReset` 会将 `Reset` 重新解释为 `AsyncReset`

然后你可以使用 `withReset` 将转换后的复位用作隐式复位。
有关 `withReset` 的更多信息，请参见["多时钟域"](../explanations/multi-clock)。

以下代码将使 `myReg` 以及两个 `resetAgnosticReg` 都同步复位：

```scala mdoc:silent
class ForcedSyncReset extends Module {
  // withReset 的参数在其作用域内成为隐式复位
  withReset (reset.asBool) {
    val myReg = RegInit(0.U)
    val myModule = Module(new ResetAgnosticModule)

    // RawModule 没有隐式复位，所以 withReset 无效
    val myRawModule = Module(new ResetAgnosticRawModule)
    // 我们必须手动驱动复位端口
    myRawModule.rst := Module.reset // Module.reset 获取当前的隐式复位
  }
}
```

以下代码将使 `myReg` 以及两个 `resetAgnosticReg` 都异步复位：

```scala mdoc:silent
class ForcedAysncReset extends Module {
  // withReset 的参数在其作用域内成为隐式复位
  withReset (reset.asAsyncReset){
    val myReg = RegInit(0.U)
    val myModule = Module(new ResetAgnosticModule) // myModule.reset 隐式连接

    // RawModule 没有隐式复位，所以 withReset 无效
    val myRawModule = Module(new ResetAgnosticRawModule)
    // 我们必须手动驱动复位端口
    myRawModule.rst := Module.reset // Module.reset 获取当前的隐式复位
  }
}
```

**注意：**这样的转换（`asBool` 和 `asAsyncReset`）不会被 FIRRTL 检查。
在进行这样的转换时，作为设计者的你实际上是在告诉编译器你知道你在做什么，要强制使用转换后的类型。

### 最后连接语义

使用最后连接语义来覆盖复位类型是 **不合法的**，除非你是在覆盖一个 `DontCare`：

```scala mdoc:silent
class MyModule extends Module {
  val resetBool = Wire(Reset())
  resetBool := DontCare
  resetBool := false.B // 这是可以的
  withReset(resetBool) {
    val mySubmodule = Module(new Submodule())
  }
  resetBool := true.B // 这是可以的
  resetBool := false.B.asAsyncReset // 这会在 FIRRTL 中报错
}
```
