---
layout: docs
title:  "黑盒"
section: "chisel3"
---

# 黑盒（BlackBoxes）

Chisel的*黑盒*（BlackBoxes）用于实例化外部定义的模块。这一构造对于无法用Chisel描述的硬件结构以及连接到FPGA或其他非Chisel定义的IP非常有用。

定义为`BlackBox`的模块将在生成的Verilog中被实例化，但不会生成定义模块行为的代码。

与Module不同，`BlackBox`没有隐式的时钟和复位信号。
`BlackBox`的时钟和复位端口必须被显式声明并连接到输入信号。
在IO Bundle中声明的端口将使用请求的名称生成（即没有前缀`io_`）。

### 参数化

Verilog参数可以作为参数传递给BlackBox构造函数。

例如，考虑在Chisel设计中实例化一个Xilinx差分时钟缓冲器（IBUFDS）：

```scala mdoc:silent
import chisel3._
import chisel3.util._
import chisel3.experimental._ // 启用实验性功能

class IBUFDS extends BlackBox(Map("DIFF_TERM" -> "TRUE",
                                  "IOSTANDARD" -> "DEFAULT")) {
  val io = IO(new Bundle {
    val O = Output(Clock())
    val I = Input(Clock())
    val IB = Input(Clock())
  })
}

class Top extends Module {
  val io = IO(new Bundle {})
  val ibufds = Module(new IBUFDS)
  // 将IBUFDS的一个输入时钟端口连接到Top的时钟信号
  ibufds.io.I := clock
}
```

在Chisel生成的Verilog代码中，`IBUFDS`将被实例化为：

```verilog
IBUFDS #(.DIFF_TERM("TRUE"), .IOSTANDARD("DEFAULT")) ibufds (
  .IB(ibufds_IB),
  .I(ibufds_I),
  .O(ibufds_O)
);
```

### 为黑盒提供实现

Chisel提供以下方式来提供黑盒底层的代码。考虑以下将两个实数相加的黑盒。这些数字在chisel3中表示为64位无符号整数。

```scala mdoc:silent:reset
import chisel3._
class BlackBoxRealAdd extends BlackBox {
  val io = IO(new Bundle {
    val in1 = Input(UInt(64.W))
    val in2 = Input(UInt(64.W))
    val out = Output(UInt(64.W))
  })
}
```

实现由以下verilog描述：

```verilog
module BlackBoxRealAdd(
    input  [63:0] in1,
    input  [63:0] in2,
    output reg [63:0] out
);
  always @* begin
    out <= $realtobits($bitstoreal(in1) + $bitstoreal(in2));
  end
endmodule
```

### 使用资源文件中的Verilog的黑盒

为了将上面的verilog片段提供给后端模拟器，chisel3基于chisel/firrtl的[注解系统](../explanations/annotations)提供了以下工具。将特性`HasBlackBoxResource`添加到声明中，然后在主体中调用函数来告诉系统在哪里可以找到verilog代码。模块现在看起来像这样：

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.HasBlackBoxResource

class BlackBoxRealAdd extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val in1 = Input(UInt(64.W))
    val in2 = Input(UInt(64.W))
    val out = Output(UInt(64.W))
  })
  addResource("/real_math.v")
}
```

上面的verilog片段被放入名为`real_math.v`的资源文件中。什么是资源文件？它源自Java的惯例，在项目中保存一些文件，这些文件会自动包含在库的发行版中。在典型的Chisel项目中，参见[chisel-template](https://github.com/chipsalliance/chisel-template)，这将是源代码层次结构中的一个目录：`src/main/resources/real_math.v`。

### 带有内联Verilog的黑盒
也可以直接在scala源代码中放置这个verilog。不使用`HasBlackBoxResource`而使用`HasBlackBoxInline`，不使用`setResource`而使用`setInline`。代码看起来像这样：

```scala mdoc:silent:reset
import chisel3._
import chisel3.util.HasBlackBoxInline
class BlackBoxRealAdd extends BlackBox with HasBlackBoxInline {
  val io = IO(new Bundle {
    val in1 = Input(UInt(64.W))
    val in2 = Input(UInt(64.W))
    val out = Output(UInt(64.W))
  })
  setInline("BlackBoxRealAdd.v",
    """module BlackBoxRealAdd(
      |    input  [15:0] in1,
      |    input  [15:0] in2,
      |    output [15:0] out
      |);
      |always @* begin
      |  out <= $realtobits($bitstoreal(in1) + $bitstoreal(in2));
      |end
      |endmodule
    """.stripMargin)
}
```

这种技术将内联的verilog复制到目标目录下，名为`BlackBoxRealAdd.v`

### 内部原理
这种将verilog内容传递给测试后端的机制是通过chisel/firrtl注解实现的。内联和资源这两种方法是通过`setInline`和`setResource`方法调用创建的两种注解。这些注解通过chisel-testers传递给firrtl。默认的firrtl verilog编译器有一个检测注解并将文件或内联文本移入构建目录的过程。对于添加的每个唯一文件，该转换会向文件`black_box_verilog_files.f`添加一行，这个文件会被添加到为verilator或vcs构造的命令行中，以告诉它们在哪里查找。
[dsptools项目](https://github.com/ucb-bar/dsptools)是使用这个功能基于黑盒构建实数模拟测试器的一个很好的例子。

