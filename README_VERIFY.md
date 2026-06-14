简易验证准备说明
=================

准备（依赖）
- `iverilog` / `vvp`：用于编译与运行仿真
- `gtkwave`（可选）：查看 VCD 波形
- `python3`：若没有 RISC-V 工具链，使用仓内的简单汇编器

快速步骤
1. 生成 hex 文件（使用仓内脚本；若安装了 RISC-V 工具链会自动使用它）
```bash
./tools/assemble.sh tests/asm/program.s tests/hex/program.hex
```

2. 编译仿真（若已存在 sim/cpu_tb.vvp 可跳过）
```bash
iverilog -o sim/cpu_tb.vvp tb/22_CPU_tb.v rtl/*.v
```

3. 运行仿真，指定 hex 文件
```bash
vvp sim/cpu_tb.vvp +hexfile=tests/hex/program.hex
```

4. 查看波形（可选）
```bash
gtkwave sim/cpu.vcd
```

关于汇编文件 `tests/asm/*.s`
- 每行一条指令，例如: `add x5,x3,x2`
- 寄存器使用 `x0`..`x31`
- 立即数支持十进制和 `0x` 十六进制
- 注释使用 `#` 或 `//`
- 伪指令（以 `.` 开头）和标签（`label:`）会被当前简单汇编器忽略
- 分支/跳转目前需要写出字节偏移立即数（例如 `beq x1,x2,8` 表示跳到 PC+8），可根据需求后续添加标签解析

文件说明（仓内）
- `rtl/02_IF.v`：指令存储，已修改为支持 `$readmemh` 加载 `+hexfile` 或默认 `tests/hex/program.hex`
- `tools/assemble_simple.py`：仓内 Python 汇编器，支持常用 RV32I 子集
- `tools/assemble.sh`：汇编脚本，优先使用 riscv 工具链，缺失时回退到 Python 汇编器
- `tests/asm/program.s`：示例汇编
- `tests/hex/program.hex`：示例已生成的 hex

如果你希望我为你做的下一步（任选其一）
- 支持标签与两遍组装（自动计算分支/跳转偏移）
- 在 Verilog `IF` 内实现仿真时内联汇编解析（无需外部脚本）
- 扩展汇编器支持更多指令集
