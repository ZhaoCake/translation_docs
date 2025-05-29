---
layout: docs
title:  "组合电路"
section: "chisel3"
---

# 组合电路

在Chisel中，电路表示为节点图。每个节点是一个硬件运算符，具有零个或多个输入并驱动一个输出。前面介绍的字面量是一种简化的节点，它没有输入并在其输出上驱动一个常量值。创建和连接节点的一种方式是使用文本表达式。例如，我们可以使用以下表达式表示一个简单的组合逻辑电路：

```scala
(a & b) | (~c & d)
```

这种语法应该看起来很熟悉，其中`&`和`|`分别代表按位与和或，而`~`代表按位非。名称`a`到`d`代表某种（未指定）宽度的命名线网。

任何简单的表达式都可以直接转换为电路树，命名线网位于叶子上，运算符形成内部节点。表达式的最终电路输出取自树根处的运算符，在这个例子中，是按位或。

简单表达式可以构建树形电路，但要构建任意有向无环图（DAG）形状的电路，我们需要描述扇出。在Chisel中，我们通过命名一个保存子表达式的线网来做到这一点，然后我们可以在后续表达式中多次引用这个线网。我们通过声明一个变量来在Chisel中命名一个线网。例如，考虑选择表达式，它在下面的多路复用器描述中被使用了两次：
```scala
val sel = a | b
val out = (sel & in1) | (~sel & in0)
```

关键字`val`是Scala的一部分，用于命名不会改变值的变量。这里用它来命名Chisel线网`sel`，它保存第一个按位或运算符的输出，以便在第二个表达式中多次使用这个输出。

### 线网

Chisel还支持线网作为硬件节点，可以给它们赋值或连接其他节点。

```scala
val myNode = Wire(UInt(8.W))
when (isReady) {
  myNode := 255.U
} .otherwise {
  myNode := 0.U
}
```

```scala
val myNode = Wire(UInt(8.W))
when (input > 128.U) {
  myNode := 255.U
} .elsewhen (input > 64.U) {
  myNode := 1.U
} .otherwise {
  myNode := 0.U
}
```

注意，对Wire的最后一次连接会生效。例如，以下两个Chisel电路是等效的：

```scala
val myNode = Wire(UInt(8.W))
myNode := 10.U
myNode := 0.U
```

```scala
val myNode = Wire(UInt(8.W))
myNode := 0.U
```
