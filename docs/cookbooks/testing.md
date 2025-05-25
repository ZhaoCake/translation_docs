# 测试手册


## 如何更改默认测试目录？

重写`buildDir`方法。

下面的例子将测试目录更改为`test/`：

``` scala mdoc:reset:silent
import chisel3._
import chisel3.simulator.scalatest.ChiselSim
import java.nio.file.Paths
import org.scalatest.funspec.AnyFunSpec

class FooSpec extends FunSpec with ChiselSim {

  override def buildDir: Path = Paths.get("test")

}

```

## 如何为仿真启用波形？

如果使用Scalatest和ChiselSim，向Scalatest传递`-DemitVcd=1`参数，例如：

``` shell
./mill 'chisel[2.13.16].test.testOnly' chiselTests.ShiftRegistersSpec -- -DemitVcd=1
```

## 如何查看ChiselSim Scalatest测试支持哪些选项？

向Scalatest传递`-Dhelp=1`，例如：

``` shell
./mill 'chisel[2.13.16].test.testOnly' chiselTests.ShiftRegistersSpec -- -Dhelp=1
```
