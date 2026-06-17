#!/usr/bin/env bash
# ============================================================================
# RISC-V RV32I 5-Stage Pipeline CPU — Automated Test Suite Runner
#
# Usage:
#   ./tools/run_tests.sh              # Run all tests
#   ./tools/run_tests.sh test_alu_r   # Run a single test
#   ./tools/run_tests.sh -v           # Verbose: keep VCD for first failed test
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# ---- Configuration ----------------------------------------------------------
TIMEOUT_CYCLES=3000
SIM_DIR="sim"
HEX_DIR="tests/hex"
ASM_DIR="tests/asm"
LOG_DIR="sim/logs"
VVP_BIN="$SIM_DIR/cpu_tb.vvp"
TB_FILE="tb/22_CPU_tb.v"
RTL_DIR="rtl"

# Test list (order matters — simpler tests first for fast failure detection)
ALL_TESTS=(
    "test_alu_r"
    "test_alu_i"
    "test_branch"
    "test_load_store"
    "test_jump"
    "test_hazard"
    "test_corner"
)

# ---- Flags ------------------------------------------------------------------
VERBOSE=0
SPECIFIC_TEST=""

for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        -h|--help)
            echo "Usage: $0 [options] [test_name]"
            echo "Options:"
            echo "  -v, --verbose   Keep VCD and logs for failed tests"
            echo "  -h, --help      Show this help"
            echo ""
            echo "Available tests: ${ALL_TESTS[*]}"
            exit 0
            ;;
        *) SPECIFIC_TEST="$arg" ;;
    esac
done

# ---- Setup directories ------------------------------------------------------
mkdir -p "$SIM_DIR" "$HEX_DIR" "$LOG_DIR"

# ---- Colors -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---- Results tracking -------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0
declare -a FAILED_TESTS

# ---- Compile testbench (once) -----------------------------------------------
echo "======================================================================"
echo "  RISC-V RV32I CPU Test Suite"
echo "======================================================================"
echo ""

echo "[1/3] Compiling testbench..."
if iverilog -g2012 -Wall -o "$VVP_BIN" "$TB_FILE" "$RTL_DIR"/*.v 2>"$LOG_DIR/compile.log"; then
    echo "       Compile OK"
else
    echo -e "${RED}       Compile FAILED${NC}"
    cat "$LOG_DIR/compile.log"
    exit 1
fi

# ---- Determine which tests to run -------------------------------------------
if [ -n "$SPECIFIC_TEST" ]; then
    TESTS_TO_RUN=("$SPECIFIC_TEST")
else
    TESTS_TO_RUN=("${ALL_TESTS[@]}")
fi

# ---- Assemble all required tests --------------------------------------------
echo ""
echo "[2/3] Assembling test programs..."
for test in "${TESTS_TO_RUN[@]}"; do
    asm_file="$ASM_DIR/${test}.s"
    hex_file="$HEX_DIR/${test}.hex"
    if [ -f "$asm_file" ]; then
        bash "$SCRIPT_DIR/assemble.sh" "$asm_file" "$hex_file" > /dev/null 2>&1
        echo "       $test → hex OK"
    else
        echo -e "       ${RED}$test → asm file NOT FOUND${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("$test (no .s file)")
    fi
done

# ---- Run tests --------------------------------------------------------------
echo ""
echo "[3/3] Running tests..."
echo ""

for test in "${TESTS_TO_RUN[@]}"; do
    hex_file="$HEX_DIR/${test}.hex"
    log_file="$LOG_DIR/${test}.log"
    vcd_file="$SIM_DIR/${test}.vcd"

    if [ ! -f "$hex_file" ]; then
        continue  # Skip if hex wasn't assembled
    fi

    # Run simulation (no VCD for batch, VCD for verbose single test)
    if [ "$VERBOSE" -eq 1 ] && [ -n "$SPECIFIC_TEST" ]; then
        vvp "$VVP_BIN" \
            +hexfile="$hex_file" \
            +testname="$test" \
            +timeout="$TIMEOUT_CYCLES" \
            > "$log_file" 2>&1
    else
        vvp "$VVP_BIN" \
            +hexfile="$hex_file" \
            +testname="$test" \
            +timeout="$TIMEOUT_CYCLES" \
            +novcd=1 \
            > "$log_file" 2>&1
    fi

    # Parse result
    if grep -q '\[PASS\]' "$log_file"; then
        cycles=$(grep '\[PASS\]' "$log_file" | grep -oP 'cycles=\K\d+')
        echo -e "  ${GREEN}[PASS]${NC} $test (${cycles:-?} cycles)"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif grep -q '\[FAIL\]' "$log_file"; then
        err=$(grep '\[FAIL\]' "$log_file" | grep -oP 'error_code=\K\d+')
        echo -e "  ${RED}[FAIL]${NC} $test (error_code=${err:-?})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("$test (error=$err)")
    elif grep -q '\[TIMEOUT\]' "$log_file"; then
        echo -e "  ${YELLOW}[TIMEOUT]${NC} $test"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("$test (timeout)")
    else
        echo -e "  ${RED}[ERROR]${NC} $test (no result line)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_TESTS+=("$test (no output)")
    fi
done

# ---- Summary ----------------------------------------------------------------
echo ""
echo "======================================================================"
echo "  Results: ${GREEN}$PASS_COUNT passed${NC}, ${RED}$FAIL_COUNT failed${NC}"
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo "  Failed tests:"
    for ft in "${FAILED_TESTS[@]}"; do
        echo "    - $ft"
    done
fi
echo "  Logs: $LOG_DIR/"
echo "======================================================================"

# Exit with failure code if any test failed
if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
