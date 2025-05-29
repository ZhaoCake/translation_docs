---
layout: docs
title:  "多路复用器和输入选择"
section: "chisel3"
---

# 多路复用器和输入选择

在硬件描述中选择输入非常有用，因此 Chisel 提供了几个内置的通用输入选择实现。

### Mux
第一个是 `Mux`。这是一个 2 输入选择器。与之前介绍的 `Mux2` 示例不同，内置的 `Mux` 允许输入（`in0` 和 `in1`）是任何数据类型，只要它们是 `Data` 的相同子类。

通过使用前一节介绍的函数式模块创建特性，我们可以以简单的方式创建多输入选择器：

```scala
Mux(c1, a, Mux(c2, b, Mux(..., default)))
```

### MuxCase

嵌套的 `Mux` 并非必要，因为 Chisel 还提供了内置的 `MuxCase`，它实现了完全相同的功能。
`MuxCase` 是一个 n 路 `Mux`，可以如下使用：

```scala
MuxCase(default, Array(c1 -> a, c2 -> b, ...))
```

其中每个选择依赖项在 Scala 数组中表示为一个元组 [ 条件 -> 选择的输入端口 ]。

### MuxLookup
Chisel 还提供了 `MuxLookup`，这是一个 n 路索引多路复用器：

```scala
MuxLookup(idx, default)(Seq(0.U -> a, 1.U -> b, ...))
```

这与 `MuxCase` 相同，其中条件都是基于索引的选择：

```scala
MuxCase(default,
        Array((idx === 0.U) -> a,
              (idx === 1.U) -> b, ...))
```

注意，条件/情况/选择器（例如 c1, c2）必须放在括号中。

### Mux1H
另一个 ```Mux``` 工具是单热码多路复用器 ```Mux1H```。它接受一个选择器序列和值序列，并返回与设置的那个选择器相关联的值。如果有零个或多个选择器被设置，则行为未定义。例如：

```scala
  val hotValue = chisel3.util.Mux1H(Seq(
    io.selector(0) -> 2.U,
    io.selector(1) -> 4.U,
    io.selector(2) -> 8.U,
    io.selector(4) -> 11.U,
  ))
```
`Mux1H` 在可能的情况下会生成容易优化为低深度和/或树形结构的 *Firrtl* 代码。
