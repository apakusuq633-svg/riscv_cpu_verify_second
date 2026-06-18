#!/usr/bin/env bash
# ============================================================================
# RISC-V RV32I 5-Stage Pipeline CPU — One-Click Build & Run Script
#
# This script handles: assemble → compile → simulate in one invocation.
# Use this if you don't have `make` installed. Otherwise use the Makefile.
#
# Usage:
#   ./tools/build.sh                    # Full flow: assemble all + compile
#   ./tools/build.sh asm                # Assemble all .s → .hex
#   ./tools/build.sh compile            # Compile Verilog → sim/cpu_tb.vvp
#   ./tools/build.sh run <test>         # Build all, then run a single test
#   ./tools/build.sh test               # Build all, run full test suite
#   ./tools/build.sh clean              # Remove all build artifacts
#   ./tools/build.sh list               # List available test programs
#   ./tools/build.sh help               # Show this help
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# ---- directories ------------------------------------------------------------
RTL_DIR="rtl"
TB_DIR="tb"
SIM_DIR="sim"
ASM_DIR="tests/asm"
HEX_DIR="tests/hex"
ELF_DIR="tests/elf"
BIN_DIR="tests/bin"
LOG_DIR="sim/logs"

# ---- tool paths (set these if tools are not in PATH) ------------------------
IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
PYTHON="${PYTHON:-python3}"
RISCV_GCC="${RISCV_GCC:-riscv32-unknown-elf-gcc}"
RISCV_OBJCP="${RISCV_OBJCP:-riscv32-unknown-elf-objcopy}"

# ---- compile settings -------------------------------------------------------
TIMEOUT_CYCLES="${TIMEOUT_CYCLES:-3000}"
VVP_BIN="$SIM_DIR/cpu_tb.vvp"
TB_SRC="$TB_DIR/22_CPU_tb.v"

# ---- colors -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# Helper functions
# ============================================================================
die() {
    echo -e "${RED}[FATAL]${NC} $*" >&2
    exit 1
}

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

check_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        die "$1 not found. Please install it and add to PATH."
    fi
}

# ============================================================================
# Sub-commands
# ============================================================================

cmd_asm() {
    check_cmd "$PYTHON"
    mkdir -p "$HEX_DIR" "$ELF_DIR" "$BIN_DIR"

    local asm_files=("$ASM_DIR"/*.s)
    if [ ! -f "${asm_files[0]}" ]; then
        die "No .s files found in $ASM_DIR/"
    fi

    local count=0
    for src in "$ASM_DIR"/*.s; do
        local name="$(basename "$src" .s)"
        local hex="$HEX_DIR/${name}.hex"

        if [ -f "$hex" ] && [ "$hex" -nt "$src" ]; then
            info "Skipping $name (hex up to date)"
            continue
        fi

        info "Assembling $name.s → $name.hex"
        if command -v "$RISCV_GCC" >/dev/null 2>&1; then
            # RISC-V toolchain path
            "$RISCV_GCC" -march=rv32i -mabi=ilp32 -nostdlib -static -Ttext=0 \
                -o "$ELF_DIR/${name}.elf" "$src"
            "$RISCV_OBJCP" -O binary "$ELF_DIR/${name}.elf" "$BIN_DIR/${name}.bin"
            xxd -e -g4 "$BIN_DIR/${name}.bin" | awk '{print "0x"$2}' > "$hex"
        else
            # Python assembler fallback
            "$PYTHON" "$SCRIPT_DIR/assemble_simple.py" "$src" "$hex"
        fi
        count=$((count + 1))
    done

    ok "Assembled $count file(s)"
}

cmd_compile() {
    check_cmd "$IVERILOG"
    mkdir -p "$SIM_DIR" "$LOG_DIR"

    # Check if recompilation is needed
    local need_compile=0
    if [ ! -f "$VVP_BIN" ]; then
        need_compile=1
    else
        for src in "$RTL_DIR"/*.v "$TB_SRC"; do
            if [ "$src" -nt "$VVP_BIN" ]; then
                need_compile=1
                break
            fi
        done
    fi

    if [ "$need_compile" -eq 0 ]; then
        ok "Testbench up to date, skipping compile"
        return 0
    fi

    info "Compiling RTL + testbench..."
    if "$IVERILOG" -g2012 -Wall -o "$VVP_BIN" "$TB_SRC" "$RTL_DIR"/*.v 2>"$LOG_DIR/compile.log"; then
        ok "Compile OK → $VVP_BIN"
    else
        echo -e "${RED}Compile FAILED${NC}"
        cat "$LOG_DIR/compile.log"
        exit 1
    fi
}

cmd_run() {
    local test="${1:-}"
    if [ -z "$test" ]; then
        die "Usage: $0 run <test_name>   (e.g. $0 run program)"
    fi

    check_cmd "$VVP"

    # Ensure dependencies are built
    local hex="$HEX_DIR/${test}.hex"
    local asm="$ASM_DIR/${test}.s"

    if [ -f "$asm" ] && [ ! -f "$hex" ]; then
        info "Assembly needed: $asm"
        "$PYTHON" "$SCRIPT_DIR/assemble_simple.py" "$asm" "$hex"
    fi

    if [ ! -f "$hex" ]; then
        die "Hex file not found: $hex (and no corresponding .s file to assemble)"
    fi

    if [ ! -f "$VVP_BIN" ]; then
        cmd_compile
    fi

    mkdir -p "$LOG_DIR"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Running test: $test${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    "$VVP" "$VVP_BIN" \
        +hexfile="$hex" \
        +testname="$test" \
        +timeout="$TIMEOUT_CYCLES" \
        2>&1 | tee "$LOG_DIR/${test}.log"

    echo ""
    if grep -q '\[PASS\]' "$LOG_DIR/${test}.log"; then
        echo -e "${GREEN}  ✓ $test PASSED${NC}"
    elif grep -q '\[FAIL\]' "$LOG_DIR/${test}.log"; then
        echo -e "${RED}  ✗ $test FAILED${NC}"
        exit 1
    else
        echo -e "${YELLOW}  ? $test TIMEOUT / NO RESULT${NC}"
        exit 2
    fi
}

cmd_test() {
    # Build everything first, then run the test suite
    cmd_asm
    cmd_compile
    echo ""
    bash "$SCRIPT_DIR/run_tests.sh" "$@"
}

cmd_list() {
    echo "Available test programs:"
    echo ""
    for src in "$ASM_DIR"/*.s; do
        [ -f "$src" ] || continue
        local name="$(basename "$src" .s)"
        local hex="$HEX_DIR/${name}.hex"
        if [ -f "$hex" ]; then
            printf "  %-20s ${GREEN}[assembled]${NC}\n" "$name"
        else
            printf "  %-20s ${YELLOW}[pending]${NC}\n" "$name"
        fi
    done
    echo ""
}

cmd_clean() {
    info "Cleaning build artifacts..."
    rm -rf "$HEX_DIR"/*.hex
    rm -rf "$ELF_DIR"/*.elf
    rm -rf "$BIN_DIR"/*.bin
    rm -f "$VVP_BIN"
    ok "Build artifacts removed."

    if [ "${1:-}" = "--all" ] || [ "${1:-}" = "-a" ]; then
        rm -rf "$LOG_DIR"/*.log
        rm -rf "$SIM_DIR"/*.vcd
        ok "Simulation artifacts removed."
    fi
}

cmd_detect() {
    echo "Tool detection:"
    echo "  Project dir: $PROJECT_DIR"
    echo ""
    for tool in "$IVERILOG" "$VVP" "$PYTHON" "$RISCV_GCC" "$RISCV_OBJCP"; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf "  ${GREEN}✓${NC} %s\n" "$tool"
        else
            printf "  ${RED}✗${NC} %s (not found)\n" "$tool"
        fi
    done
}

cmd_help() {
    echo "RISC-V RV32I 5-Stage Pipeline CPU — Build Script"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  (none)              Build all (assemble + compile)"
    echo "  asm                 Assemble all .s → .hex"
    echo "  compile             Compile Verilog → sim/cpu_tb.vvp"
    echo "  run <test>          Build + run a single test"
    echo "  test [test]         Build + run tests (all or single, passes to run_tests.sh)"
    echo "  list                List available test programs"
    echo "  detect              Detect available tools"
    echo "  clean               Remove build artifacts"
    echo "  clean --all         Remove build + simulation artifacts"
    echo "  help                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build everything"
    echo "  $0 run program               # Build + run 'program' test"
    echo "  $0 run test_alu_r            # Build + run 'test_alu_r' test"
    echo "  $0 test                      # Build + run all tests"
    echo "  $0 test test_branch          # Build + run a specific test (via run_tests.sh)"
    echo "  $0 clean --all               # Wipe all artifacts"
    echo ""
    echo "Environment variables (optional):"
    echo "  IVERILOG       Path to iverilog (default: iverilog)"
    echo "  VVP            Path to vvp (default: vvp)"
    echo "  PYTHON         Path to python3 (default: python3)"
    echo "  RISCV_GCC      Path to riscv32-unknown-elf-gcc (optional)"
    echo "  TIMEOUT_CYCLES Max simulation cycles (default: 3000)"
}

# ============================================================================
# Main dispatch
# ============================================================================
case "${1:-}" in
    asm)
        cmd_asm
        ;;
    compile)
        cmd_compile
        ;;
    run)
        cmd_run "${2:-}"
        ;;
    test)
        cmd_asm
        cmd_compile
        shift
        bash "$SCRIPT_DIR/run_tests.sh" "$@"
        ;;
    list|ls)
        cmd_list
        ;;
    clean)
        cmd_clean "${2:-}"
        ;;
    detect|check|tools)
        cmd_detect
        ;;
    help|-h|--help)
        cmd_help
        ;;
    ""|all|build)
        cmd_asm
        cmd_compile
        cmd_detect
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  Build complete!${NC}"
        echo -e "${GREEN}  Next: $0 test  OR  $0 run <name>${NC}"
        echo -e "${GREEN}========================================${NC}"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        cmd_help
        exit 1
        ;;
esac
