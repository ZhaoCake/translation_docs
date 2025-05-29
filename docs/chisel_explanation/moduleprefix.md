# 模块前缀

Chisel支持一种称为模块前缀的功能。
模块前缀允许您在设计的Verilog输出中创建命名空间。
它们特别适用于当您想要命名设计的特定子系统时，
并且您希望通过文件名轻松识别文件属于哪个子系统。

## withModulePrefix

我们可以使用`withModulePrefix`打开一个模块前缀块：

```scala mdoc:silent
import chisel3._

class Top extends Module {
  withModulePrefix("Foo") {
    // ...
  }
}
```

此块内定义的所有模块，无论是直接子模块还是后代，都将被赋予前缀`Foo`。
（前缀用下划线`_`分隔）。

例如，假设我们编写以下内容：

```scala mdoc:silent:reset
import chisel3._

class Top extends Module {
  val sub = withModulePrefix("Foo") {
    Module(new Sub)
  }
}

class Sub extends Module {
  // ..
}
```

结果将是一个包含两个模块定义的设计：`Top`和`Foo_Sub`。

请注意，`val sub =`部分必须放在`withModulePrefix`块之外，
否则模块将无法被`Top`模块的其余部分访问。

您可以通过将第二个参数传递为`false`来省略前缀分隔符（`_`）：

```scala mdoc:silent:reset
import chisel3._

class Top extends Module {
  val sub = withModulePrefix("Foo", false) {
    Module(new Sub)
  }
}

class Sub extends Module {
  // ..
}
```

这将产生两个模块定义：`Top`和`FooSub`。

## localModulePrefix

我们还可以通过重写`localModulePrefix`方法来设置模块的前缀。
如果您想为模块的所有实例设置前缀，这很有用。

```scala mdoc:silent:reset
import chisel3._

class Top extends Module {
  override def localModulePrefix = Some("Foo")
  val sub = Module(new Sub)
}

class Sub extends Module {
  // ..
}
```

这将产生两个模块定义：`Foo_Top`和`Foo_Sub`。

您还可以将`localModulePrefixAppliesToSelf`重写为`false`，使前缀仅应用于子模块。

```scala mdoc:silent:reset
import chisel3._

class Top extends Module {
  override def localModulePrefix = Some("Foo")
  override def localModulePrefixAppliesToSelf = false
  val sub = Module(new Sub)
}

class Sub extends Module {
  // ..
}
```

这将产生两个模块定义：`Top`和`Foo_Sub`。

您还可以将`localModulePrefixUseSeparator`重写为`false`以省略分隔符。

```scala mdoc:silent:reset
import chisel3._

class Top extends Module {
  override def localModulePrefix = Some("Foo")
  override def localModulePrefixUseSeparator = false
  val sub = Module(new Sub)
}

class Sub extends Module {
  // ..
}
```

这将产生两个模块定义：`FooTop`和`FooSub`。

## 多个前缀

如果在多个前缀块中运行生成器，结果是多个相同的模块定义副本，
每个都有自己的不同前缀。
例如，考虑如果我们像这样创建`Sub`的两个实例：

```scala mdoc:silent:reset
import chisel3._

class Top extends Module {
  val foo_sub = withModulePrefix("Foo") {
    Module(new Sub)
  }

  val bar_sub = withModulePrefix("Bar") {
    Module(new Sub)
  }
}

class Sub extends Module {
  // ..
}
```

那么，生成的Verilog将有三个模块定义：`Top`、`Foo_Sub`和`Bar_Sub`。
`Foo_Sub`和`Bar_Sub`将彼此完全相同。

## 嵌套前缀

模块前缀也可以嵌套。

```scala mdoc:silent:reset
import chisel3._

class Top extends Module {
  val mid = withModulePrefix("Foo") {
    Module(new Mid)
  }
}

class Mid extends Module {
  // You can mix withModulePrefix and localModulePrefix.
  override def localModulePrefix = Some("Bar")
  override def localModulePrefixAppliesToSelf = false
  val sub = Module(new Sub)
}

class Sub extends Module {
  // ..
}
```

这将产生三个模块定义：`Top`、`Foo_Mid`和`Foo_Bar_Sub`。

## Instantiate

`withModulePrefix`块也适用于`Instantiate` API。

```scala mdoc:silent:reset
import chisel3._
import chisel3.experimental.hierarchy.{instantiable, Instantiate}

@instantiable
class Sub extends Module {
  // ...
}

class Top extends Module {
  val foo_sub = withModulePrefix("Foo") {
    Instantiate(new Sub)
  }

  val bar_sub = withModulePrefix("Bar") {
    Instantiate(new Sub)
  }

  val noprefix_sub = Instantiate(new Sub)
}
```

在这个例子中，我们最终得到四个模块：`Top`、`Foo_Sub`、`Bar_Sub`和`Sub`。

使用`Definition`和`Instance`时，所有`Definition`调用都将受到`withModulePrefix`的影响。
然而，`Instance`不会受到影响，因为它总是创建捕获定义的实例。

## 外部模块

`BlackBox`和`ExtModule`不受`withModulePrefix`的影响。
如果您希望有一个对模块前缀敏感的模块，
您可以像这样显式命名模块：

```scala mdoc:silent:reset
import chisel3._
import chisel3.experimental.hierarchy.{instantiable, Instantiate}
import chisel3.experimental.ExtModule

class Sub extends ExtModule {
  override def desiredName = modulePrefix + "Sub"
}
```
