---
layout: docs
title:  "内存"
section: "chisel3"
---

# 内存

Chisel提供了创建只读和读写内存的功能。

## ROM

用户可以通过使用`VecInit`构造`Vec`来定义只读内存。
`VecInit`可以接受可变数量的`Data`字面量参数或`Seq[Data]`字面量来初始化ROM。

例如，用户可以创建一个初始化为1、2、4、8的小型ROM，并使用计数器作为地址生成器遍历所有值，如下所示：

```scala
// 原始代码块中的标记: mdoc:compile-only
import chisel3._
import chisel3.util.Counter
val m = VecInit(1.U, 2.U, 4.U, 8.U)
val c = Counter(m.length)
c.inc()
val r = m(c.value)
```

我们可以创建一个*n*值正弦查找表生成器，使用如下方式初始化ROM：

```scala
// 原始代码块中的标记: mdoc:compile-only
import chisel3._

val Pi = math.Pi
def sinTable(amp: Double, n: Int) = {
  val times =
    (0 until n).map(i => (i*2*Pi)/(n.toDouble-1) - Pi)
  val inits =
    times.map(t => Math.round(amp * math.sin(t)).asSInt(32.W))
  VecInit(inits)
}
```

其中`amp`用于缩放存储在ROM中的定点值。

## 读写内存

由于硬件内存的实现差异很大，Chisel中对内存进行了特殊处理。例如，FPGA内存的实例化方式与ASIC内存完全不同。Chisel定义了一种内存抽象，可以映射到简单的Verilog行为描述，或者映射到可从晶圆厂或IP供应商提供的外部内存生成器获得的内存模块实例。

### `SyncReadMem`：顺序/同步读取，顺序/同步写入

Chisel有一个称为`SyncReadMem`的构造，用于顺序/同步读取、顺序/同步写入的内存。这些`SyncReadMem`可能会被合成为技术SRAM（而不是寄存器组）。

如果在同一时钟边沿上对同一内存地址进行写入和顺序读取，或者如果顺序读取使能被清除，则读取数据是未定义的。

读数据端口上的值不保证保持到下一个读取周期。如果需要这种行为，必须添加外部逻辑来保持最后读取的值。

#### 读端口/写端口

通过应用`UInt`索引创建`SyncReadMem`的端口。具有一个写端口和一个读端口的1024条目SRAM可能表示如下：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class ReadWriteSmem extends Module {
  val width: Int = 32
  val io = IO(new Bundle {
    val enable = Input(Bool())
    val write = Input(Bool())
    val addr = Input(UInt(10.W))
    val dataIn = Input(UInt(width.W))
    val dataOut = Output(UInt(width.W))
  })

  val mem = SyncReadMem(1024, UInt(width.W))
  // Create one write port and one read port
  mem.write(io.addr, io.dataIn)
  io.dataOut := mem.read(io.addr, io.enable)
}
```

下面是带有[掩码](#masks)的一个写端口/一个读端口`SyncReadMem`的示例波形。请注意，信号名称与为`SyncReadMem`生成的确切线名称不同。使用掩码时，也可能生成具有以下行为的多个RTL数组。

![读/写端口示例波形](https://svg.wavedrom.com/github/freechipsproject/www.chisel-lang.org/master/docs/src/main/resources/json/smem_read_write.json)    

#### 单端口

当读取和写入条件在同一个`when`链中互斥时，可以推断单端口SRAM：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class RWSmem extends Module {
  val width: Int = 32
  val io = IO(new Bundle {
    val enable = Input(Bool())
    val write = Input(Bool())
    val addr = Input(UInt(10.W))
    val dataIn = Input(UInt(width.W))
    val dataOut = Output(UInt(width.W))
  })

  val mem = SyncReadMem(1024, UInt(width.W))
  io.dataOut := DontCare
  when(io.enable) {
    val rdwrPort = mem(io.addr)
    when (io.write) { rdwrPort := io.dataIn }
      .otherwise    { io.dataOut := rdwrPort }
  }
}
```

（这里的`DontCare`是为了让Chisel的[未连接线检测](unconnected-wires)意识到在写入时读取是未定义的。）

这是一个带有[掩码](#masks)的单一读/写端口波形示例（同样，生成的信号名称和数组数量可能不同）：

![读/写端口示例波形](https://svg.wavedrom.com/github/freechipsproject/www.chisel-lang.org/master/docs/src/main/resources/json/smem_rw.json)

也可以通过使用`readWrite`调用来显式生成单端口SRAM，该调用会生成单个读/写访问器，如下所示：

```scala
// 原始代码块中的标记: mdoc:silent
class RDWR_Smem extends Module {
  val width: Int = 32
  val io = IO(new Bundle {
    val enable = Input(Bool())
    val write = Input(Bool())
    val addr = Input(UInt(10.W))
    val dataIn = Input(UInt(width.W))
    val dataOut = Output(UInt(width.W))
  })

  val mem = SyncReadMem(1024, UInt(width.W))
  io.dataOut := mem.readWrite(io.addr, io.dataIn, io.enable, io.write)
}
```

### `Mem`：组合/异步读取，顺序/同步写入

Chisel通过`Mem`构造支持随机访问内存。对`Mem`的写入是组合/异步读取，顺序/同步写入的。这些`Mem`可能会被合成为寄存器组，因为现代技术（FPGA、ASIC）中的大多数SRAM已不再支持组合（异步）读取。

创建上述示例的异步读取版本只需将`SyncReadMem`替换为`Mem`即可。

### 掩码

Chisel内存还支持用于子字写入的写掩码。如果内存的数据类型是向量，Chisel将推断掩码。要推断掩码，请指定创建写端口的`write`函数的`mask`参数。如果相应的掩码位被设置，则写入给定的掩码长度。例如，在下面的示例中，如果掩码的第0位为真，它将在相应地址写入数据的低位字节。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class MaskedReadWriteSmem extends Module {
  val width: Int = 8
  val io = IO(new Bundle {
    val enable = Input(Bool())
    val write = Input(Bool())
    val addr = Input(UInt(10.W))
    val mask = Input(Vec(4, Bool()))
    val dataIn = Input(Vec(4, UInt(width.W)))
    val dataOut = Output(Vec(4, UInt(width.W)))
  })

  // Create a 32-bit wide memory that is byte-masked
  val mem = SyncReadMem(1024, Vec(4, UInt(width.W)))
  // Write with mask
  mem.write(io.addr, io.dataIn, io.mask)
  io.dataOut := mem.read(io.addr, io.enable)
}
```

这是一个带有读写端口的掩码示例：

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._
class MaskedRWSmem extends Module {
  val width: Int = 32
  val io = IO(new Bundle {
    val enable = Input(Bool())
    val write = Input(Bool())
    val mask = Input(Vec(2, Bool()))
    val addr = Input(UInt(10.W))
    val dataIn = Input(Vec(2, UInt(width.W)))
    val dataOut = Output(Vec(2, UInt(width.W)))
  })

  val mem = SyncReadMem(1024, Vec(2, UInt(width.W)))
  io.dataOut := DontCare
  when(io.enable) {
    val rdwrPort = mem(io.addr)
    when (io.write) {
      when(io.mask(0)) {
        rdwrPort(0) := io.dataIn(0)
      }
      when(io.mask(1)) {
        rdwrPort(1) := io.dataIn(1)
      }
    }.otherwise { io.dataOut := rdwrPort }
  }
}
```

### 内存初始化

Chisel内存可以从外部`binary`或`hex`文件初始化，为合成或仿真生成适当的Verilog。有多种初始化模式。

有关更多信息，请查看[加载内存](../appendix/experimental-features#loading-memories-for-simulation-or-fpga-initialization)功能的实验性文档。

## SRAM

Chisel提供了一个API来生成`SRAM`，这是`SyncReadMem`的另一种API。

`SRAM`和`SyncReadMem` API之间的关键区别在于前者能够声明特定数量的读、写和读写内存端口，这些端口通过显式束进行交互。

```scala
// 原始代码块中的标记: mdoc:silent
import chisel3.util._

class ModuleWithSRAM(numReadPorts: Int, numWritePorts: Int, numReadwritePorts: Int) extends Module {
  val width: Int = 8

  val io = IO(new SRAMInterface(1024, UInt(width.W), numReadPorts, numWritePorts, numReadwritePorts))

  // Generate a SyncReadMem representing an SRAM with an explicit number of read, write, and read-write ports
  io :<>= SRAM(1024, UInt(width.W), numReadPorts, numWritePorts, numReadwritePorts)
}
```

要与所需的端口交互，请使用`readPorts`、`writePorts`和`readwritePorts`字段：

```scala
// 原始代码块中的标记: mdoc:silent
class TopModule extends Module {
  // Declare a 2 read, 2 write, 2 read-write ported SRAM with 8-bit UInt data members
  val mem = SRAM(1024, UInt(8.W), 2, 2, 2)

  // Whenever we want to read from the first read port
  mem.readPorts(0).address := 100.U
  mem.readPorts(0).enable := true.B

  // Read data is returned one cycle after enable is driven
  val foo = WireInit(UInt(8.W), mem.readPorts(0).data)

  // Whenever we want to write to the second write port
  mem.writePorts(1).address := 5.U
  mem.writePorts(1).enable := true.B
  mem.writePorts(1).data := 12.U

  // Whenever we want to read or write to the third read-write port
  // Write:
  mem.readwritePorts(2).address := 5.U
  mem.readwritePorts(2).enable := true.B
  mem.readwritePorts(2).isWrite := true.B
  mem.readwritePorts(2).writeData := 100.U

  // Read:
  mem.readwritePorts(2).address := 5.U
  mem.readwritePorts(2).enable := true.B
  mem.readwritePorts(2).isWrite := false.B
  val bar = WireInit(UInt(8.W), mem.readwritePorts(2).readData)
}
```
