# 实例选择

`Instance Choice`（实例选择）是模块的实例，其目标可在生成后配置。
它们允许通过ABI中的选项或通过编译器中的专门化，在生成后从预定义集合中选择实例的目标。

实例选择依赖于选项组来指定附加到每个选项的可用目标：

```scala mdoc:silent
import chisel3.choice.{Case, Group}

object Platform extends Group {
  object FPGA extends Case
  object ASIC extends Case
}
```

`Platform`选项组枚举了设计可以专门化的平台列表，例如`ASIC`或`FPGA`。专门化不是强制性的：如果未指定选项，则选择默认变体。

实例选择引用的模块必须都通过从`FixedIOBaseModule`派生来指定相同的IO接口。`ModuleChoice`运算符接受默认选项和案例-模块映射列表，并返回对模块IO的绑定。

```scala mdoc:silent
import chisel3._
import chisel3.choice.ModuleChoice

class TargetIO extends Bundle {
  val in = Flipped(UInt(8.W))
  val out = UInt(8.W)
}

class FPGATarget extends FixedIOExtModule[TargetIO](new TargetIO)

class ASICTarget extends FixedIOExtModule[TargetIO](new TargetIO)

class VerifTarget extends FixedIORawModule[TargetIO](new TargetIO)

class SomeModule extends RawModule {
  val inst = ModuleChoice(new VerifTarget)(Seq(
    Platform.FPGA -> new FPGATarget,
    Platform.ASIC -> new ASICTarget
  ))
}
```
