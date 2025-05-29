---
layout: docs
title:  "Sequential Circuits"
section: "chisel3"
---

# 时序电路

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
val in = Bool()
```

Chisel 支持的最简单的状态元素是一个正边沿触发的寄存器，可以这样实例化：

```scala
// 原始代码块中的标记: mdoc:compile-only
val reg = RegNext(in)
```

这个电路的输出是输入信号 `in` 延迟一个时钟周期的副本。注意，我们不必指定 Reg 的类型，因为它会在实例化时自动从其输入推断出来。在当前版本的 Chisel 中，时钟和复位是全局信号，在需要的地方会隐式包含。

注意，未指定初始值的寄存器在复位信号触发时不会改变值。

使用寄存器，我们可以快速定义许多有用的电路结构。例如，上升沿检测器接收一个布尔信号并在当前值为真而前一个值为假时输出真：

```scala
// 原始代码块中的标记: mdoc:silent
def risingedge(x: Bool) = x && !RegNext(x)
```

计数器是一个重要的时序电路。要构造一个向上计数到最大值 max 然后绕回到零（即模 max+1）的上计数器，我们可以这样写：

```scala
// 原始代码块中的标记: mdoc:silent
def counter(max: UInt) = {
  val x = RegInit(0.asUInt(max.getWidth.W))
  x := Mux(x === max, 0.U, x + 1.U)
  x
}
```

计数器寄存器在计数器函数中创建时初始值为 0（位宽足够大以容纳 max），当电路的全局复位被断言时寄存器将被初始化为这个值。在计数器中对 x 的 := 赋值连接了一个更新组合电路，该电路递增计数器值，除非它达到最大值，此时它回绕到零。注意，当 x 出现在赋值的右侧时，引用的是它的输出，而当在左侧时，引用的是它的输入。

计数器可以用来构建许多有用的时序电路。例如，我们可以通过在计数器达到零时输出真值来构建一个脉冲生成器：

```scala
// 原始代码块中的标记: mdoc:silent
// 每 n 个周期产生一个脉冲
def pulse(n: UInt) = counter(n - 1.U) === 0.U
```

然后可以用脉冲序列来触发一个方波生成器，在每个脉冲之间在真和假之间切换：

```scala
// 原始代码块中的标记: mdoc:silent
// 当输入为真时翻转内部状态
def toggle(p: Bool) = {
  val x = RegInit(false.B)
  x := Mux(p, !x, x)
  x
}
// 生成给定周期的方波
def squareWave(period: UInt) = toggle(pulse(period >> 1))
```
