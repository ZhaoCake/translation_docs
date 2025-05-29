---
layout: docs
title:  "Operators"
section: "chisel3"
---

# Chisel 操作符

Chisel 定义了一组硬件操作符：

| 操作        | 说明 |
| ---------        | ---------           |
| **位操作符**                       | **适用于:** SInt, UInt, Bool    |
| `val invertedX = ~x`                        | 按位取反 |
| `val hiBits = x & "h_ffff_0000".U`          | 按位与                     |
| `val flagsOut = flagsIn \| overflow`         | 按位或                      |
| `val flagsOut = flagsIn ^ toggle`           | 按位异或                     |
| **位归约操作符**                     | **适用于:** SInt 和 UInt。返回 Bool。 |
| `val allSet = x.andR`                       | 与归约                     |
| `val anySet = x.orR`                        | 或归约                      |
| `val parity = x.xorR`                       | 异或归约                     |
| **相等比较**                    | **适用于:** SInt、UInt 和 Bool。返回 Bool。 |
| `val equ = x === y`                         | 相等                          |
| `val neq = x =/= y`                         | 不相等                        |
| **移位**                                  | **适用于:** SInt 和 UInt       |
| `val twoToTheX = 1.S << x`                  | 逻辑左移                |
| `val hiBits = x >> 16.U`                    | 右移(UInt 为逻辑右移，SInt 为算术右移) |
| **位域操作**                   | **适用于:** SInt、UInt 和 Bool |
| `val xLSB = x(0)`                           | 提取单个位，LSB 的索引为 0     |
| `val xTopNibble = x(15, 12)`                | 从结束位到起始位提取位域     |
| `val usDebt = Fill(3, "hA".U)`              | 将位串重复多次     |
| `val float = Cat(sign, exponent, mantissa)` | 连接位域，第一个参数在左边     |
| **逻辑操作**                      | **适用于:** Bool
| `val sleep = !busy`                         | 逻辑非                       |
| `val hit = tagMatch && valid`               | 逻辑与                       |
| `val stall = src1busy \|\| src2busy`        | 逻辑或                        |
| `val out = Mux(sel, inTrue, inFalse)`       | 二输入复用器，sel 是一个 Bool 类型 |
| **算术运算**                   | **适用于数字类型:** SInt 和 UInt  |
| `val sum = a + b` *或* `val sum = a +% b`   | 加法(不扩展位宽) |
| `val sum = a +& b`                          | 加法(扩展位宽)    |
| `val diff = a - b` *或* `val diff = a -% b` | 减法(不扩展位宽) |
| `val diff = a -& b`                         | 减法(扩展位宽) |
| `val prod = a * b`                          | 乘法                     |
| `val div = a / b`                           | 除法                     |
| `val mod = a % b`                           | 取模                     |
| **算术比较**                  | **适用于数字类型:** SInt 和 UInt。返回 Bool。 |
| `val gt = a > b`                            | 大于                       |
| `val gte = a >= b`                          | 大于等于              |
| `val lt = a < b`                            | 小于                       |
| `val lte = a <= b`                          | 小于等于                 |

> 我们对操作符名称的选择受 Scala 语言的限制。我们不得不使用三重等号```===```来表示相等，使用```=/=```来表示不相等，以保持原生 Scala 相等操作符的可用性。

Chisel 操作符的优先级不是直接定义在 Chisel 语言中的。实际上，它是由电路的求值顺序决定的，这自然遵循了 [Scala 操作符优先级](https://docs.scala-lang.org/tour/operators.html)。如果对操作符优先级有疑问，请使用括号。

> Chisel/Scala 的操作符优先级与 Java 或 C 的优先级相似但不完全相同。Verilog 的操作符优先级与 C 相同，但 VHDL 则不同。Verilog 对逻辑运算有优先级顺序，但在 VHDL 中这些运算符具有相同的优先级，从左到右求值。
