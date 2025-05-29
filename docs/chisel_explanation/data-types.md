---
layout: docs
title:  "Chisel数据类型"
section: "chisel3"
---

# Chisel数据类型

Chisel数据类型用于指定状态元素中保存的值或在线路上流动的值的类型。虽然硬件设计最终操作的是二进制数字向量，但其他更抽象的值表示方式可以让规范更清晰，并帮助工具生成更优的电路。在Chisel中，原始的位集合由```Bits```类型表示。有符号和无符号整数被视为定点数的子集，分别由类型```SInt```和```UInt```表示。有符号定点数（包括整数）使用二进制补码格式表示。布尔值表示为类型```Bool```。请注意，这些类型与Scala的内置类型（如```Int```或```Boolean```）是不同的。

此外，Chisel定义了`Bundles`用于创建具有命名字段的值集合（类似于其他语言中的```structs```），以及```Vecs```用于可索引的值集合。

Bundles和Vecs将在下一节中介绍。

常量或字面值通过传递给类型构造函数的Scala整数或字符串表示：
```scala
1.U       // 从Scala Int得到的十进制1位字面值
"ha".U    // 从字符串得到的十六进制4位字面值
"o12".U   // 从字符串得到的八进制4位字面值
"b1010".U // 从字符串得到的二进制4位字面值

5.S    // 有符号十进制4位字面值，来自Scala Int
-8.S   // 负十进制4位字面值，来自Scala Int
5.U    // 无符号十进制3位字面值，来自Scala Int

8.U(4.W) // 4位无符号十进制，值为8
-152.S(32.W) // 32位有符号十进制，值为-152

true.B // 从Scala字面值得到的Bool字面值
false.B
```
下划线可以用作长字符串字面值中的分隔符以提高可读性，但在创建值时会被忽略，例如：
```scala
"h_dead_beef".U   // 32位UInt类型的字面值
```

默认情况下，Chisel编译器会将每个常量的大小调整为保存该常量所需的最小位数，对于有符号类型还包括一个符号位。位宽也可以在字面值上显式指定，如下所示。注意（`.W`用于将Scala Int转换为Chisel宽度）
```scala
"ha".asUInt(8.W)     // 十六进制8位UInt类型的字面值
"o12".asUInt(6.W)    // 八进制6位UInt类型的字面值
"b1010".asUInt(12.W) // 二进制12位UInt类型的字面值

5.asSInt(7.W) // 有符号十进制7位SInt字面值
5.asUInt(8.W) // 无符号十进制8位UInt字面值
```

对于```UInt```类型的字面值，值会被零扩展到所需的位宽。对于```SInt```类型的字面值，值会被符号扩展以填充所需的位宽。如果给定的位宽太小而无法容纳参数值，则会生成Chisel错误。

>我们正在为Chisel开发一种更简洁的字面值语法，使用符号前缀运算符，但受到Scala运算符重载限制的阻碍，尚未确定一种比接受字符串的构造函数更可读的语法。

>我们还考虑过允许Scala字面值自动转换为Chisel类型，但这可能导致类型歧义，并需要额外的导入。

>SInt和UInt类型以后还将支持可选的指数字段，以允许Chisel自动生成优化的定点算术电路。

## 类型转换

我们也可以在Chisel中进行类型转换：

```scala
val sint = 3.S(4.W)             // 4位SInt

val uint = sint.asUInt          // 将SInt转换为UInt
uint.asSInt                     // 将UInt转换为SInt
```

**注意**：带有显式宽度的`asUInt`/`asSInt`**不能**用于在Chisel数据类型之间进行转换。
不接受宽度参数，因为当对象连接时，Chisel会自动进行填充或截断。

我们也可以对时钟进行转换，不过你应该对此保持谨慎，因为时钟（尤其是在ASIC中）需要特别注意：

```scala
val bool: Bool = false.B        // 始终为低电平的线
val clock = bool.asClock        // 始终为低电平的时钟

clock.asUInt                    // 将时钟转换为UInt（宽度为1）
clock.asUInt.asBool             // 将时钟转换为Bool（Chisel 3.2+）
clock.asUInt.toBool             // 将时钟转换为Bool（仅Chisel 3.0和3.1）
```

## Analog/BlackBox类型

（实验性功能，Chisel 3.1+）

Chisel支持`Analog`类型（等同于Verilog的`inout`），可用于支持Chisel中的任意网络。这包括模拟线路、三态/双向线路和电源网络（使用适当的注解）。

`Analog`是一个无方向类型，因此可以使用`attach`运算符将多个`Analog`网络连接在一起。可以使用`<>`**一次**连接`Analog`，但多次连接是非法的。

```scala
val a = IO(Analog(1.W))
val b = IO(Analog(1.W))
val c = IO(Analog(1.W))

// 合法
attach(a, b)
attach(a, c)

// 合法
a <> b

// 非法 - 多次连接'a'
a <> b
a <> c
```

