#!/bin/bash

# 将所有mdoc:silent:reset标记转换为普通scala代码块，并保留原始标记为注释
find docs -name "*.md" -exec sed -i 's/```scala mdoc:silent:reset/```scala\n\/\/ 原始代码块中的标记: mdoc:silent:reset/g' {} \;

# 将所有mdoc:invisible标记转换为普通scala代码块，并保留原始标记为注释
find docs -name "*.md" -exec sed -i 's/```scala mdoc:invisible/```scala\n\/\/ 原始代码块中的标记: mdoc:invisible/g' {} \;

# 将所有mdoc:crash标记转换为普通scala代码块，并保留原始标记为注释
find docs -name "*.md" -exec sed -i 's/```scala mdoc:crash/```scala\n\/\/ 原始代码块中的标记: mdoc:crash/g' {} \;

# 将所有mdoc:verilog标记转换为普通scala代码块，并保留原始标记为注释
find docs -name "*.md" -exec sed -i 's/```scala mdoc:verilog/```scala\n\/\/ 原始代码块中的标记: mdoc:verilog/g' {} \;

# 将所有简单mdoc标记转换为普通scala代码块，并保留原始标记为注释
find docs -name "*.md" -exec sed -i 's/```scala mdoc$/```scala\n\/\/ 原始代码块中的标记: mdoc/g' {} \;

# 处理带参数的mdoc标记，如mdoc:silent
find docs -name "*.md" -exec sed -i 's/```scala mdoc:\([a-z]*\)/```scala\n\/\/ 原始代码块中的标记: mdoc:\1/g' {} \;

echo "转换完成！mdoc标记已被替换为普通代码块，并保留原始标记作为注释。"