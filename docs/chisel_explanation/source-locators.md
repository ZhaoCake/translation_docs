---
layout: docs
title:  "源代码定位器"
section: "chisel3"
---

# 源代码定位器

在生成 Chisel 设计并生成 FIRRTL 文件或 Verilog 文件时，Chisel 会自动添加源代码定位器，这些定位器指向包含相应 Chisel 代码的 Scala 文件。

在 FIRRTL 文件中，它看起来像这样：

```
wire w : UInt<3> @[src/main/scala/MyProject/MyFile.scala 1210:21]
```

在 Verilog 文件中，它看起来像这样：

```verilog
wire [2:0] w; // @[src/main/scala/MyProject/MyFile.scala 1210:21]
```

默认情况下，包含了文件相对于 JVM 调用位置的相对路径。
要改变相对路径的计算位置，请设置 Java 系统属性 `-Dchisel.project.root=/absolute/path/to/root`。
这个选项可以直接传递给 sbt（`sbt -Dchisel.project.root=/absolute/path/to/root`）。
在 `build.sbt` 文件中设置这个值是不起作用的，因为它需要传递给调用 sbt 的 JVM（而不是相反）。
我们认为这只与可能需要更多自定义的发布版本相关。
