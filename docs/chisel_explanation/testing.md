---
layout: docs
title:  "Testing"
section: "chisel3"
---

# 测试

Chisel 提供了几个包，用于使用不同的策略测试生成器。

主要的测试策略是仿真。这是通过 _ChiselSim_ 完成的，它是一个库，用于在不同的仿真器上仿真 Chisel 生成的 SystemVerilog。

另一种互补的测试策略是直接检查 Chisel 生成器产生的 SystemVerilog 或 FIRRTL 文本。这是使用 [FileCheck](https://llvm.org/docs/CommandGuide/FileCheck.html) 完成的。

:::tip

适当的测试策略将取决于你要测试什么。你可能需要混合使用不同的策略。

:::

ChiselSim 和 FileCheck 都作为 Chisel 内部的包提供。
下面的小节描述了这些包及其用法。

## ChiselSim

ChiselSim 提供了多种方法，你可以用它们来运行仿真并为被测试的 Chisel 模块提供激励。

:::info

ChiselSim 需要安装兼容的仿真器工具，如 Verilator 或 VCS。

:::

要使用 ChiselSim，将以下两个特质之一混入到类中：

- `chisel3.simulator.ChiselSim`
- `chisel3.simulator.scalatest.ChiselSim`

两个特质提供相同的方法。后一个特质提供了与 [ScalaTest](https://www.scalatest.org/) 的更紧密集成，它会将测试结果放在由 ScalaTest 测试名称派生的目录结构中，便于用户检查。

### 仿真 API

ChiselSim 提供了两个仿真 API 用于运行仿真。它们是：

- `simulate`
- `simulateRaw`

前者只能用于 `Module` 或其子类型。后者只能用于 `RawModule` 或其子类型。

它们之间的区别是 `simulate` 会在应用用户激励之前对模块进行初始化过程。

相反，`simulateRaw` 不会应用任何初始化过程，由用户负责提供适当的复位激励。

:::info

`simulate` 之所以可以定义复位过程是因为 `Module` 有已定义的时钟和复位端口。正因为如此，在使用 ChiselSim 时，一个常见的模式是将你的被测设计包装在一个测试线束中，这个线束是一个 `Module`。测试线束将接收初始化激励，任何更复杂的激励（例如多个时钟）都可以在测试线束内部派生。

:::

有关更多信息，请参见 [Chisel API 文档](https://www.chisel-lang.org/api)中的 `chisel3.simulator.SimulatorAPI`。

### 激励

仿真 API 接收用户提供的激励并将其应用于被测设计（DUT）。提供了两种应用激励的机制：(1) Peek/Poke API 和 (2) 可重用激励模式。前者提供简单、自由格式的方式来应用简单的定向激励。后者提供适用于广泛模块的常见激励。

#### Peek/Poke API

ChiselSim 提供了基本的"peek"、"poke"和"expect" API，用于向 Chisel 模块提供简单激励。这个 API 是作为 Chisel 类型（如 `Data`）的[扩展方法](https://en.wikipedia.org/wiki/Extension_method)实现的。这意味着你的被测设计的端口有_新的_方法被定义，这些方法可以用来驱动激励。

这些 API 总结如下：

- `poke` 在端口上设置一个值
- `peek` 读取端口上的值
- `expect` 读取端口上的值并断言它等于另一个值
- `step` 在多个周期内切换时钟
- `stepUntil` 切换时钟直到另一个端口上出现某个条件

有关更多信息，请参见 [Chisel API 文档](https://www.chisel-lang.org/api)中的 `chisel3.simulator.PeekPokeAPI`。

#### 可重用激励模式

虽然 Peek/Poke API 对于自由格式的测试很有用，但在测试过程中经常应用一些常见的激励模式。例如，使模块退出复位状态或运行仿真直到完成。这些模式在 `chisel3.simulator.stimulus` 包中提供。目前，可以使用以下激励：

- `ResetProcedure` 将以可预测的方式复位模块。这提供了足够的间隔，使初始块在时间零点执行，寄存器/内存的数量复位周期。（这与 `simulate` API 使用的激励相同。）
- `RunUntilFinished` 运行模块指定的周期数，期望仿真会干净地结束（通过 `chisel3.stop`）或如果没有断言或结束，将抛出仿真断言。
- `RunUntilSuccess` 运行模块指定的周期数，期望模块将断言成功端口（表示成功）或刺激作为参数。

这些激励旨在通过它们的工厂方法使用。大多数激励为不同的模块类型提供不同的工厂。例如，`ResetProcedure` 工厂有两个方法：`any` 可以为_任何_ Chisel 模块生成激励，而 `module` 只能为 `Module` 的子类型生成激励。之所以有这种分离，是因为这个特定的激励需要知道时钟和复位端口是什么，以便向它们应用复位激励。Chisel `Module` 有已知的时钟和复位端口，这允许 `module` 激励只有一个参数 —— 应用复位的周期数。然而，Chisel `RawModule` 没有已知的时钟和复位端口，用户需要向工厂提供更多参数 —— 复位周期数_和_获取时钟和复位端口的函数。

有关更多信息，请参见 [Chisel API 文档](https://www.chisel-lang.org/api)中的 `chisel3.simulator.stimulus`。

### 示例

下面的示例展示了如何在 ScalaTest 中基本使用 ChiselSim。这显示了一个单独的测试套件 `ChiselSimExample`。为了获得 ChiselSim 方法的访问权限，混入了 `ChiselSim` 特质。还选择了一个[测试风格](https://www.scalatest.org/user_guide/selecting_a_style) `AnyFunSpec`。

在测试中，模块 `Foo` 使用自定义激励进行测试。模块 `Bar` 使用可重用的 `RunUntilFinished` 激励进行测试。模块 `Baz` 使用可重用的 `RunUntilSuccess` 激励进行测试。所有测试在当前形式下均会通过。

```scala mdoc:silent:reset
import chisel3._
import chisel3.simulator.scalatest.ChiselSim
import chisel3.simulator.stimulus.{RunUntilFinished, RunUntilSuccess}
import chisel3.util.Counter
import org.scalatest.funspec.AnyFunSpec

class ChiselSimExample extends AnyFunSpec with ChiselSim {

  class Foo extends Module {
    val a, b = IO(Input(UInt(8.W)))
    val c = IO(Output(chiselTypeOf(a)))

    private val r = Reg(chiselTypeOf(a))

    r :<= a +% b
    c :<= r
  }

  describe("Baz") {

    it("adds two numbers") {

      simulate(new Foo) { foo =>
        // Poke different values on the two input ports.
        foo.a.poke(1)
        foo.b.poke(2)

        // Step the clock by one cycle.
        foo.clock.step(1)

        // Expect that the sum of the two inputs is on the output port.
        foo.c.expect(3)
      }

    }

  }

  class Bar extends Module {

    val (_, done) = Counter(true.B, 10)

    when (done) {
      stop()
    }

  }

  describe("Bar") {

    it("terminates cleanly before 11 cycles have elapsed") {

      simulate(new Bar)(RunUntilFinished(11))

    }

  }

  class Baz extends Module {

    val success = IO(Output(Bool()))

    val (_, done) = Counter(true.B, 20)

    success :<= done

  }

  describe("Baz") {

    it("asserts success before 21 cycles have elapsed") {

      simulate(new Baz)(RunUntilSuccess(21, _.success))

    }

  }

}

```

### Scalatest 支持

ChiselSim 提供了许多与 Scalatest 协同工作的特性，以改善测试体验。

#### 目录命名

在 Scalatest 环境中使用 ChiselSim 时，默认情况下将创建一个与 Scalatest 测试"范围"匹配的测试目录结构。实际上，这导致你的测试根据你在 Scalatest 中的组织方式进行组织。

测试目录的根目录默认是 `build/chiselsim/`。你可以通过重写 `buildDir` 方法来更改此设置。

在测试目录下，你将获得一个针对每个测试套件的目录。在其下，你将获得一个针对每个测试"范围"的目录。例如，对于上面示例中显示的测试，这将产生以下目录结构：

```
build/chiselsim
└── ChiselSimExample
    ├── Foo
    │   └── adds-two-numbers
    ├── Bar
    │   └── terminates-cleanly-before-11-cycles-have-elapsed
    └── Baz
        └── asserts-success-before-21-cycles-have-elapsed
```

#### 命令行参数

Scalatest 支持通过其 `ConfigMap` 特性向 Scalatest 传递命令行参数。ChiselSim 用改进的 API 封装了此功能，以便向测试添加命令行参数、显示帮助文本以及检查仅传递合法参数。

默认情况下，ChiselSim 测试已经为 Scalatest 提供了几个命令行选项。你可以通过向 Scalatest 传递 `-Dhelp=1` 参数来查看这些选项。例如，这是上面示例中测试的帮助文本：

```
Usage: <ScalaTest> [-D<name>=<value>...]

This ChiselSim ScalaTest test supports passing command line arguments via
ScalaTest's "config map" feature.  To access this, append `-D<name>=<value>` for
a legal option listed below.

Options:

  chiselOpts
      additional options to pass to the Chisel elaboration
  emitVcd
      compile with VCD waveform support and start dumping waves at time zero
  firtoolOpts
      additional options to pass to the firtool compiler
  help
      display this help text
```

这些选项中最常用的是 `-DemitVcd=1`。这将导致你的测试在执行时转储值变化转储（VCD）波形。如果测试失败，这对于调试为什么失败非常有用。

你还可以选择性地将其他命令行选项混入到 ChiselSim Scalatest 测试套件中，这些选项在 ChiselSim 中是_不可用_的。它们在 `chisel3.simulator.scalatest.Cli` 对象中可用：

- `EmitFsdb` 添加一个 `-DemitFsdb=1` 选项，如果仿真器支持，将导致生成 FSDB 波形。
- `EmitVpd` 添加一个 `-DemitFsdb=1` 选项，如果仿真器支持，将导致生成 FSDB 波形。
- `Scale` 添加一个 `-Dscale=<float>` 选项。这为用户提供了一种在测试时放大或缩小测试的方式，例如，延长测试运行时间。此特性通过该特质提供的 `scaled` 方法访问。
- `Simulator` 添加一个 `-Dsimulator=<simulator-name>` 参数。这允许在测试时选择 VCS 或 verilator 作为仿真后端。

如果你想添加的命令行选项尚不可用，你可以使用 `chisel3.simulator.scalatest.HasCliOptions` 中提供的几种方法之一向测试添加自定义选项。最灵活的方法是 `addOption`。这允许你添加一个选项，该选项可以在仿真中更改任何内容，包括 Chisel 阐明、FIRRTL 编译或通用或后端特定设置。

更常见的是，你只想向测试添加一个整数、双精度、字符串或类似标志的选项。为此，提供了更简单的选项_工厂_(`chisel3.simulator.scalatest.CliOption.{simple, double, int, string, flag}`)。选项声明后，可以在测试_内部_使用 `getOption` 方法访问。

:::warning

`getOption` 方法只能在_测试内部_使用。如果在测试外部使用，将导致运行时异常。

:::

下面的示例展示了如何使用 `int` 选项设置测试时可配置的种子：

```scala mdoc:reset:silent
import chisel3._
import chisel3.simulator.scalatest.ChiselSim
import chisel3.simulator.scalatest.HasCliOptions.CliOption
import chisel3.util.random.LFSR
import circt.stage.ChiselStage
import org.scalatest.funspec.AnyFunSpec

class ChiselSimExample extends AnyFunSpec with ChiselSim {

  CliOption.int("seed", "the seed to use for the test")

  class Foo(seed: Int) extends Module {
    private val lfsr = LFSR(64, seed = Some(seed))
  }

  describe("Foo") {
    it("generates FIRRTL for a module with a test-time configurable seed") {
      ChiselStage.emitCHIRRTL(new Foo(getOption[Int]("seed").getOrElse(42)))
    }
  }

}
```

:::warning

对测试选项要节俭。虽然它们可能很有用，但它们可能表明测试中的一种反模式。如果你的测试是测试时参数化的，你就不再总是测试相同的内容。这可能在测试你的 Chisel 生成器时产生漏洞，如果没有测试正确的参数。

考虑在_测试内部_或通过编写多个 Scalatest 测试来遍历测试参数。

:::

## FileCheck

有时，直接检查生成器的结果是足够的。这种测试策略在你试图创建非常特定的 FIRRTL 或 SystemVerilog 结构或保证特定构造的确切命名时特别相关。

虽然简单的测试可以通过字符串比较来完成，但这通常是不够的，因为需要对特定行的正则表达式捕获和排序混合使用。为此，Chisel 提供了一种原生方式来编写 [FileCheck](https://llvm.org/docs/CommandGuide/FileCheck.html) 测试。

:::info

使用 FileCheck 测试需要安装 FileCheck 二进制文件。FileCheck 通常作为 LLVM 的一部分打包。

:::

像 ChiselSim 一样，提供了两种不同的特质用于编写 FileCheck 测试：

- `chisel3.testing.FileCheck`
- `chisel3.testing.scalatest.FileCheck`

两者提供相同的 API，但后者会将中间文件写入派生自 ScalaTest 套件和范围名称的目录中。

目前，仅提供一个 FileCheck API：`fileCheck`。该 API 实现为 `String` 的扩展方法，并接受两个参数：(1) FileCheck 的参数列表和 (2) 包含内联 FileCheck 测试的字符串。输入字符串和检查字符串都将被写入磁盘，并在失败时保留，以便在需要时可以手动重新运行。

如果 `fileCheck` 方法成功，则不返回任何内容。如果失败，将抛出异常，指示失败原因和期望字符串未匹配的详细信息。

有关 API 的更多信息，请参见 [Chisel API 文档](https://www.chisel-lang.org/api)中的 `chisel3.testing.FileCheck`。有关 FileCheck 及其用法的更多信息，请参见 [FileCheck 文档](https://llvm.org/docs/CommandGuide/FileCheck.html)。

:::note

FileCheck 是 LLVM 生态系统中广泛用于编译器测试的工具。[CIRCT](https://github.com/llvm/circt)，将 Chisel 生成的 FIRRTL 转换为 SystemVerilog 的编译器，重度使用 FileCheck 进行自身测试。

:::

在编写 FileCheck 测试时，你通常会使用 Chisel API 将 Chisel 电路转换为 FIRRTL 或 SystemVerilog。这在 `circt.stage.ChiselStage` 对象中有两种方法可供选择：

- `emitCHIRRTL` 生成带有少量 Chisel 扩展的 FIRRTL
- `emitSystemVerilog` 生成 SystemVerilog

这两种方法都接受一个可选的 `args` 参数，用于设置 Chisel 阐明选项。后一种方法还有一个额外的可选 `firtoolOpts` 参数，用于控制 `firtool`（FIRRTL 编译器）选项。

在未向 `emitSystemVerilog` 提供任何 `firtoolOpts` 的情况下，生成的 SystemVerilog 可能由于 `firtool` 的默认 SystemVerilog 降级、发射和美化而难以与 FileCheck 一起使用。为了更容易地编写测试，我们建议使用以下选项：

- `-loweringOptions=emittedLineLength=160` 增加允许的行长度。默认情况下，`firtool` 会换行超过 80 个字符的行。你可以考虑使用一个_非常长_的行长度（例如，8192）来完全避免这个问题。

- `-loweringOptions=disallowLocalVariables` 禁用在 always 块中生成 `automatic logic` 临时变量。这可能导致临时变量在 always 块中溢出，这可能会稍微出乎意料。

有关 `firtool` 及其降级选项的更多信息，请参见 [CIRCT 的 Verilog 生成文档](https://circt.llvm.org/docs/VerilogGeneration/#controlling-output-style-with-loweringoptions)或调用 `firtool -help` 获取所有支持选项的完整列表。

### 示例

下面的示例展示了一个 FileCheck 测试，检查一个模块具有特定名称，并且在其内部具有一些预期的内容。具体来说，此测试检查常量传播是否按预期发生。按当前方式编写的测试将会通过。

```scala mdoc:silent:reset
import chisel3._
import chisel3.testing.scalatest.FileCheck
import circt.stage.ChiselStage
import org.scalatest.funspec.AnyFunSpec

class FileCheckExample extends AnyFunSpec with FileCheck {

  class Baz extends RawModule {

    val out = IO(Output(UInt(32.W)))

    out :<= 1.U(32.W) + 3.U(32.W)

  }

  describe("Foo") {

    it("should simplify the constant computation in its body") {

      ChiselStage.emitSystemVerilog(new Baz).fileCheck()(
        """|CHECK:      module Baz(
           |CHECK-NEXT:   output [31:0] out
           |CHECK:        assign out = 32'h4;
           |CHECK:      endmodule
           |""".stripMargin
        )

    }

  }

}

```

:::note

FileCheck 有_很多_有用的特性在此示例中未显示。

`CHECK-SAME` 允许检查同一行上的匹配。`CHECK-NOT` 确保不发生匹配。`CHECK-COUNT-<n>` 将检查 `n` 次匹配。`CHECK-DAG` 将允许一系列匹配以任何顺序发生。

最强大的，FileCheck 允许内联正则表达式并将结果保存在字符串替换块中，稍后可以使用。这在你关心捕获一个名称但不关心实际名称时很有用。

有关更详细的文档，请参见 FileCheck 文档。

:::
