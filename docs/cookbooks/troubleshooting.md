
# 故障排除


本页面是记录使用Chisel3开发时常见和不常见问题的起点。特别是那些有解决方法可以让你继续前进的情况。

### 指定`UInt`/`SInt`的宽度/值时出现`type mismatch`

*我有一些旧代码，在chisel2中曾经正常工作（如果我使用`import Chisel._`兼容层，现在仍然可以工作），
但在直接使用chisel3时会导致`type mismatch`错误：*

```scala
// 原始代码块中的标记: mdoc:silent:fail
class TestBlock extends Module {
	val io = IO(new Bundle {
		val output = Output(UInt(width=3))
	})
}
```
*产生*
```bash
type mismatch;
[error]  found   : Int(3)
[error]  required: chisel3.internal.firrtl.Width
[error] 		val output = Output(UInt(width=3))
```

chisel2中的单参数多功能对象/构造函数已从chisel3中移除。
人们认为这些太容易出错，使得在chisel3代码中难以诊断错误条件。

在chisel3中，`UInt`/`SInt`对象/构造函数的单个参数指定*宽度*，必须是`Width`类型。
虽然没有从`Int`到`Width`的自动转换，但可以通过对`Int`应用`W`方法将`Int`转换为`Width`。
在chisel3中，上述代码变为：
```scala
// 原始代码块中的标记: mdoc:silent
import chisel3._

class TestBlock extends Module {
	val io = IO(new Bundle {
		val output = Output(UInt(3.W))
	})
}
```
可以通过应用`U`或`S`方法从`Int`创建`UInt`/`SInt`字面量。

```scala mdoc:fail
UInt(42)
```

在chisel2中，变为
```scala
// 原始代码块中的标记: mdoc:silent
42.U
```
在chisel3中

通过使用带有`W`参数的`U`或`S`方法可以创建具有特定宽度的字面量。
使用：
```scala
// 原始代码块中的标记: mdoc:silent
1.S(8.W)
```
创建一个8位宽的（有符号）值为1的字面量。
