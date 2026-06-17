#!/usr/bin/env bash
set -euo pipefail

# Simple assembler wrapper for this repo.
# Assembles a RISC-V .s file into a hex file usable by $readmemh in Verilog.
# Usage: tools/assemble.sh [src.s] [out.hex]

SRC=${1:-tests/asm/program.s}
BASENAME=$(basename "$SRC" .s)
ELF=tests/elf/${BASENAME}.elf
BIN=tests/bin/${BASENAME}.bin
HEX=${2:-tests/hex/${BASENAME}.hex}

mkdir -p tests/bin tests/elf tests/hex

echo "Assembling $SRC -> $ELF"

if command -v riscv32-unknown-elf-gcc >/dev/null 2>&1; then
  riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -static -Ttext=0 -o "$ELF" "$SRC"
  riscv32-unknown-elf-objcopy -O binary "$ELF" "$BIN"
  # Convert binary to little-endian 32-bit hex words, one per line (0xXXXXXXXX)
  if ! command -v xxd >/dev/null 2>&1; then
    echo "xxd not found. Install vim-common or xxd." >&2
    exit 1
  fi
  xxd -e -g4 "$BIN" | awk '{print "0x"$2}' > "$HEX"
  echo "Wrote hex file: $HEX (via riscv toolchain)"
else
  # Fallback: use simple Python assembler included in repo
  if command -v python3 >/dev/null 2>&1; then
    echo "riscv toolchain not found; using simple Python assembler"
    python3 tools/assemble_simple.py "$SRC" "$HEX"
    echo "Wrote hex file: $HEX (via assemble_simple.py)"
  else
    echo "No assembler available (riscv toolchain or python3)." >&2
    exit 1
  fi
fi
