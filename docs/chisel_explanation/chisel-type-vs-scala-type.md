---
layout: docs
title:  "Chisel类型与Scala类型"
section: "chisel3"
---

# Chisel类型与Scala类型

Scala编译器无法区分Chisel对硬件的表示（如`false.B`、`Reg(Bool())`）
和纯Chisel类型（例如`Bool()`）。当期望硬件时传递Chisel类型，或反之，可能会得到运行时错误。

## Scala类型与Chisel类型与硬件

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3._
import circt.stage.ChiselStage
```

Data的*Scala*类型由Scala编译器识别，例如`Bool`、`Decoupled[UInt]`或下面的`MyBundle`
```scala
// 原始代码块中的标记: mdoc:silent
class MyBundle(w: Int) extends Bundle {
  val foo = UInt(w.W)
  val bar = UInt(w.W)
}
```

`Data`的*Chisel*类型是一个Scala对象。它捕获所有实际存在的字段，
按名称和包括宽度在内的类型。
例如，`MyBundle(3)`创建一个具有字段`foo: UInt(3.W), bar: UInt(3.W))`的Chisel类型。

硬件是"绑定"到可合成硬件的`Data`。例如`false.B`或`Reg(Bool())`。
绑定决定了每个字段的实际方向，它不是Chisel类型的属性。

字面量是可以表示为字面值的`Data`，无需包装在Wire、Reg或IO中。

## Chisel类型与硬件与字面量

下面的代码演示了具有相同Scala类型（`MyBundle`）的对象如何具有不同的属性。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.experimental.BundleLiterals._

class MyModule(gen: () => MyBundle) extends Module {
                                                            //   硬件    字面量
    val xType:    MyBundle     = new MyBundle(3)            //    -        -
    val dirXType: MyBundle     = Input(new MyBundle(3))     //    -        -
    val xReg:     MyBundle     = Reg(new MyBundle(3))       //    x        -
    val xIO:      MyBundle     = IO(Input(new MyBundle(3))) //    x        -
    val xRegInit: MyBundle     = RegInit(xIO)               //    x        -
    val xLit:     MyBundle     = xType.Lit(                 //    x        x
      _.foo -> 0.U(3.W),
      _.bar -> 0.U(3.W)
    )
    val y:        MyBundle = gen()                          //      ?          ?

    // 需要初始化所有硬件值
    xReg := DontCare
}
```

```scala
// 原始代码块中的标记: mdoc:invisible
// 仅用于编译检查上面的内容
import circt.stage.ChiselStage.elaborate
elaborate(new MyModule(() => new MyBundle(3)))
```

## Chisel类型与硬件 -- 特定函数和错误

`.asTypeOf`对硬件和Chisel类型都有效：

```scala
// 原始代码块中的标记: mdoc:silent
elaborate(new Module {
  val chiselType = new MyBundle(3)
  val hardware = Wire(new MyBundle(3))
  hardware := DontCare
  val a = 0.U.asTypeOf(chiselType)
  val b = 0.U.asTypeOf(hardware)
})
```

只能对硬件使用`:=`：
```scala
// 原始代码块中的标记: mdoc:silent
// 这样做...
elaborate(new Module {
  val hardware = Wire(new MyBundle(3))
  hardware := DontCare
})
```
```scala
// 原始代码块中的标记: mdoc:crash
// 不要这样做...
elaborate(new Module {
  val chiselType = new MyBundle(3)
  chiselType := DontCare
})
```

只能从硬件`:=`：
```scala
// 原始代码块中的标记: mdoc:silent
// 这样做...
elaborate(new Module {
  val hardware = IO(new MyBundle(3))
  val moarHardware = Wire(new MyBundle(3))
  moarHardware := DontCare
  hardware := moarHardware
})
```
```scala
// 原始代码块中的标记: mdoc:crash
// Not this...
elaborate(new Module {
  val hardware = IO(new MyBundle(3))
  val chiselType = new MyBundle(3)
  hardware := chiselType
})
```

Have to pass hardware to `chiselTypeOf`:
```scala
// 原始代码块中的标记: mdoc:silent
// Do this...
elaborate(new Module {
  val hardware = Wire(new MyBundle(3))
  hardware := DontCare
  val chiselType = chiselTypeOf(hardware)
})
```
```scala
// 原始代码块中的标记: mdoc:crash
// Not this...
elaborate(new Module {
  val chiselType = new MyBundle(3)
  val crash = chiselTypeOf(chiselType)
})
```

Have to pass hardware to `*Init`:
```scala
// 原始代码块中的标记: mdoc:silent
// Do this...
elaborate(new Module {
  val hardware = Wire(new MyBundle(3))
  hardware := DontCare
  val moarHardware = WireInit(hardware)
})
```
```scala
// 原始代码块中的标记: mdoc:crash
// Not this...
elaborate(new Module {
  val crash = WireInit(new MyBundle(3))
})
```

Can't pass hardware to a `Wire`, `Reg`, `IO`:
```scala
// 原始代码块中的标记: mdoc:silent
// Do this...
elaborate(new Module {
  val hardware = Wire(new MyBundle(3))
  hardware := DontCare
})
```
```scala
// 原始代码块中的标记: mdoc:crash
// Not this...
elaborate(new Module {
  val hardware = Wire(new MyBundle(3))
  val crash = Wire(hardware)
})
```

`.Lit` can only be called on Chisel type:
```scala
// 原始代码块中的标记: mdoc:silent
// Do this...
elaborate(new Module {
  val hardwareLit = (new MyBundle(3)).Lit(
    _.foo -> 0.U,
    _.bar -> 0.U
  )
})
```
```scala
// 原始代码块中的标记: mdoc:crash
//Not this...
elaborate(new Module {
  val hardware = Wire(new MyBundle(3))
  val crash = hardware.Lit(
    _.foo -> 0.U,
    _.bar -> 0.U
  )
})
```

Can only use a Chisel type within a `Bundle` definition:
```scala
// 原始代码块中的标记: mdoc:silent
// Do this...
elaborate(new Module {
  val hardware = Wire(new Bundle {
    val nested = new MyBundle(3)
  })
  hardware := DontCare
})
```
```scala
// 原始代码块中的标记: mdoc:crash
// Not this...
elaborate(new Module {
  val crash = Wire(new Bundle {
    val nested = Wire(new MyBundle(3))
  })
})
```

Can only call `directionOf` on Hardware:
```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.reflect.DataMirror

class Child extends Module{
  val hardware = IO(new MyBundle(3))
  hardware := DontCare
  val chiselType = new MyBundle(3)
}
```
```scala
// 原始代码块中的标记: mdoc:silent
// Do this...
elaborate(new Module {
  val child = Module(new Child())
  child.hardware := DontCare
  val direction = DataMirror.directionOf(child.hardware)
})
```
```scala
// 原始代码块中的标记: mdoc:crash
// Not this...
elaborate(new Module {
val child = Module(new Child())
  child.hardware := DontCare
  val direction = DataMirror.directionOf(child.chiselType)
})
```

Can call `specifiedDirectionOf` on hardware or Chisel type:
```scala
// 原始代码块中的标记: mdoc:silent
elaborate(new Module {
  val child = Module(new Child())
  child.hardware := DontCare
  val direction0 = DataMirror.specifiedDirectionOf(child.hardware)
  val direction1 = DataMirror.specifiedDirectionOf(child.chiselType)
})
```

## `.asInstanceOf` vs `.asTypeOf` vs `chiselTypeOf`

`.asInstanceOf` is a Scala runtime cast, usually used for telling the compiler
that you have more information than it can infer to convert Scala types:

```scala
// 原始代码块中的标记: mdoc:silent
class ScalaCastingModule(gen: () => Bundle) extends Module {
  val io = IO(Output(gen().asInstanceOf[MyBundle]))
  io.foo := 0.U
}
```

This works if we do indeed have more information than the compiler:
```scala
// 原始代码块中的标记: mdoc:silent
elaborate(new ScalaCastingModule( () => new MyBundle(3)))
```

But if we are wrong, we can get a Scala runtime exception:
```scala
// 原始代码块中的标记: mdoc:crash
class NotMyBundle extends Bundle {val baz = Bool()}
elaborate(new ScalaCastingModule(() => new NotMyBundle()))
```

`.asTypeOf` is a conversion from one `Data` subclass to another.
It is commonly used to assign data to all-zeros, as described in [this cookbook recipe](https://www.chisel-lang.org/chisel3/docs/cookbooks/cookbook.html#how-can-i-tieoff-a-bundlevec-to-0), but it can
also be used (though not really recommended, as there is no checking on
width matches) to convert one Chisel type to another:

```scala
// 原始代码块中的标记: mdoc:invisible
import chisel3.docs.emitSystemVerilog
```

```scala
// 原始代码块中的标记: mdoc
class SimilarToMyBundle(w: Int) extends Bundle{
  val foobar = UInt((2*w).W)
}

emitSystemVerilog(new Module {
  val in = IO(Input(new MyBundle(3)))
  val out = IO(Output(new SimilarToMyBundle(3)))

  out := in.asTypeOf(out)
})
```

In contrast to `asInstanceOf` and `asTypeOf`,
`chiselTypeOf` is not a casting operation. It returns a Scala object which
can be used as shown in the examples above to create more Chisel types and
hardware with the same Chisel type as existing hardware.
