---
layout: docs
title:  "函数抽象"
section: "chisel3"
---

# 函数抽象

我们可以定义函数来提取设计中多次重用的重复逻辑片段。例如，我们可以将简单组合逻辑块的早期示例封装如下：

```scala mdoc:invisible
import chisel3._
```

```scala mdoc:silent
def clb(a: UInt, b: UInt, c: UInt, d: UInt): UInt =
  (a & b) | (~c & d)
```

其中```clb```是一个函数，它接受```a```、```b```、```c```、```d```作为参数，并返回一个连接到布尔电路输出的线。```def```关键字是Scala的一部分，用于引入函数定义，每个参数后面跟着冒号和它的类型，函数返回类型在参数列表后的冒号之后给出。等号（`=`）分隔函数参数列表和函数定义。

然后我们可以在另一个电路中如下使用这个块：
```scala mdoc:silent
val out = clb(a,b,c,d)
```
