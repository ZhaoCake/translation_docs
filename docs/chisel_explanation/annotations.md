---
layout: docs
title:  "注解"
section: "chisel3"
---

# 注解

`Annotation`（注解）是与FIRRTL电路中的零个或多个"事物"相关联的元数据容器。
通常，`Annotation`用于将信息从Chisel传递给特定的、已知的FIRRTL `Transform`（转换）。
在这种方式下，`Annotation`可以被视为特定`Transform`消费的"参数"。

`Annotation`被设计为Chisel的实现细节，并不意味着由用户手动构造或直接交互。
相反，它们旨在通过现有或新的Chisel API来使用。例如，
`dontTouch` API提供了一种方式，使用户能够指示某个线网或端口不应被优化。
这个API背后由`DontTouchAnnotation`支持，但这对Chisel用户是隐藏的。

所有支持的`Annotation`列表作为[FIRRTL Dialect文档的一部分维护在
circt.llvm.org上](https://circt.llvm.org/docs/Dialects/FIRRTL/FIRRTLAnnotations/)。
