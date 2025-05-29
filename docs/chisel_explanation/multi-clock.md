---
layout: docs
title:  "多时钟域"
section: "chisel3"
---
# 多时钟域

Chisel 3 支持多时钟域，具体如下。

注意，为了安全地跨时钟域，你需要适当的同步逻辑（比如异步 FIFO）。你可以使用 [AsyncQueue 库](https://github.com/ucb-bar/asyncqueue)来轻松实现这一点。

```scala mdoc:silent:reset
import chisel3._

class MultiClockModule extends Module {
  val io = IO(new Bundle {
    val clockB = Input(Clock())
    val resetB = Input(Bool())
    val stuff = Input(Bool())
  })

  // 这个寄存器使用模块时钟
  val regClock = RegNext(io.stuff)

  withClockAndReset (io.clockB, io.resetB) {
    // 在这个 withClock 作用域中，所有同步元素都使用 io.clockB 时钟
    // 这个域中触发器的复位使用显式提供的 io.resetB

    // 这个寄存器使用 io.clockB 时钟
    val regClockB = RegNext(io.stuff)
  }

  // 这个寄存器也使用模块时钟
  val regClock2 = RegNext(io.stuff)
}
```

你也可以在另一个时钟域中实例化模块：

```scala mdoc:silent:reset
import chisel3._

class ChildModule extends Module {
  val io = IO(new Bundle{
    val in = Input(Bool())
  })
}
class MultiClockModule extends Module {
  val io = IO(new Bundle {
    val clockB = Input(Clock())
    val resetB = Input(Bool())
    val stuff = Input(Bool())
  })
  val clockB_child = withClockAndReset(io.clockB, io.resetB) { Module(new ChildModule) }
  clockB_child.io.in := io.stuff
}
```

如果你只想将你的时钟连接到新的时钟域并使用常规的隐式复位信号，你可以使用 `withClock(clock)` 替代 `withClockAndReset`。

```scala mdoc:silent:reset
import chisel3._

class MultiClockModule extends Module {
  val io = IO(new Bundle {
    val clockB = Input(Clock())
    val stuff = Input(Bool())
  })

  // 这个寄存器使用模块时钟
  val regClock = RegNext(io.stuff)

  withClock (io.clockB) {
    // 在这个 withClock 作用域中，所有同步元素都使用 io.clockB 时钟

    // 这个寄存器使用 io.clockB 时钟，但使用父上下文中的隐式复位
    val regClockB = RegNext(io.stuff)
  }

  // 这个寄存器也使用模块时钟
  val regClock2 = RegNext(io.stuff)
}

// 在另一个时钟域中使用隐式复位实例化模块
class MultiClockModule2 extends Module {
  val io = IO(new Bundle {
    val clockB = Input(Clock())
    val stuff = Input(Bool())
  })
  val clockB_child = withClock(io.clockB) { Module(new ChildModule) }
  clockB_child.io.in := io.stuff
}

class ChildModule extends Module {
  val io = IO(new Bundle{
    val in = Input(Bool())
  })
}
```
