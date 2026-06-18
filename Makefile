# ============================================================================
# RISC-V RV32I 5-Stage Pipeline CPU — Build System
#
# Usage:
#   make                  # Assemble all tests + compile testbench (default)
#   make asm              # Assemble all .s → .hex
#   make compile          # Compile Verilog → sim/cpu_tb.vvp
#   make run TEST=test_alu_r   # Run a single test
#   make test             # Run all tests
#   make test-v           # Run all tests (verbose: keep VCD for first failure)
#   make clean            # Remove all build artifacts
#   make clean-all        # Remove build + simulation artifacts
# ============================================================================

# ---- project directories ----------------------------------------------------
RTL_DIR     := rtl
TB_DIR      := tb
SIM_DIR     := sim
TESTS_DIR   := tests
ASM_DIR     := $(TESTS_DIR)/asm
HEX_DIR     := $(TESTS_DIR)/hex
ELF_DIR     := $(TESTS_DIR)/elf
BIN_DIR     := $(TESTS_DIR)/bin
LOG_DIR     := $(SIM_DIR)/logs
TOOLS_DIR   := tools

# ---- tools ------------------------------------------------------------------
IVERILOG    := iverilog
VVP         := vvp
PYTHON      := python3
RISCV_GCC   := riscv32-unknown-elf-gcc
RISCV_OBJCP := riscv32-unknown-elf-objcopy

# ---- sources ----------------------------------------------------------------
RTL_SRCS    := $(wildcard $(RTL_DIR)/*.v)
TB_SRC      := $(TB_DIR)/22_CPU_tb.v
VVP_BIN     := $(SIM_DIR)/cpu_tb.vvp
ASM_SRCS    := $(sort $(wildcard $(ASM_DIR)/*.s))
HEX_FILES   := $(patsubst $(ASM_DIR)/%.s,$(HEX_DIR)/%.hex,$(ASM_SRCS))

# ---- test configuration -----------------------------------------------------
TIMEOUT_CYCLES := 3000

# ---- colors -----------------------------------------------------------------
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
NC     := \033[0m

# ---- tool detection ---------------------------------------------------------
HAS_IVERILOG := $(shell command -v $(IVERILOG) 2>/dev/null)
HAS_VVP      := $(shell command -v $(VVP) 2>/dev/null)
HAS_PYTHON   := $(shell command -v $(PYTHON) 2>/dev/null)
HAS_RISCV    := $(shell command -v $(RISCV_GCC) 2>/dev/null)

# ---- phony targets ----------------------------------------------------------
.PHONY: all asm compile run test test-v clean clean-all help list list-tests

# ============================================================================
# Default target
# ============================================================================
all: asm compile
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)  Build complete!$(NC)"
	@echo "$(GREEN)  Run tests: make test$(NC)"
	@echo "$(GREEN)  Run single: make run TEST=<name>$(NC)"
	@echo "$(GREEN)========================================$(NC)"

# ============================================================================
# Assembly: .s → .hex (batch)
# ============================================================================
asm: $(HEX_FILES)
	@echo "$(GREEN)All assembly files up to date.$(NC)"

# Assembly rule for each .hex file
$(HEX_DIR)/%.hex: $(ASM_DIR)/%.s $(TOOLS_DIR)/assemble_simple.py
	@mkdir -p $(HEX_DIR) $(ELF_DIR) $(BIN_DIR)
	@echo "$(CYAN)[ASM]$(NC) $< → $@"
ifeq ($(HAS_RISCV),)
	@# Use Python assembler (riscv toolchain not found)
	$(PYTHON) $(TOOLS_DIR)/assemble_simple.py $< $@
else
	@# Use riscv toolchain
	$(eval BASENAME := $(basename $(notdir $<)))
	$(RISCV_GCC) -march=rv32i -mabi=ilp32 -nostdlib -static -Ttext=0 \
		-o $(ELF_DIR)/$(BASENAME).elf $<
	$(RISCV_OBJCP) -O binary $(ELF_DIR)/$(BASENAME).elf $(BIN_DIR)/$(BASENAME).bin
	xxd -e -g4 $(BIN_DIR)/$(BASENAME).bin | awk '{print "0x"$$2}' > $@
endif

# ============================================================================
# Verilog compilation: RTL + testbench → .vvp
# ============================================================================
compile: $(VVP_BIN)
	@echo "$(GREEN)Testbench up to date.$(NC)"

$(VVP_BIN): $(RTL_SRCS) $(TB_SRC)
	@mkdir -p $(SIM_DIR) $(LOG_DIR)
	@echo "$(CYAN)[IVL]$(NC) Compiling RTL + testbench..."
ifeq ($(HAS_IVERILOG),)
	$(error "iverilog not found. Install Icarus Verilog (http://iverilog.icarus.com/), or add it to PATH.")
endif
	@if $(IVERILOG) -g2012 -Wall -o $@ $(TB_SRC) $(RTL_SRCS) 2>$(LOG_DIR)/compile.log; then \
		echo "       $(GREEN)Compile OK$(NC)"; \
	else \
		echo "$(RED)       Compile FAILED — see $(LOG_DIR)/compile.log$(NC)"; \
		cat $(LOG_DIR)/compile.log; \
		exit 1; \
	fi

# ============================================================================
# Run a single simulation
# ============================================================================
run: $(VVP_BIN)
ifndef TEST
	$(error "Usage: make run TEST=<test_name>  (e.g. make run TEST=program)")
endif
ifeq ($(HAS_VVP),)
	$(error "vvp not found. Install Icarus Verilog (http://iverilog.icarus.com/), or add it to PATH.")
endif
	@test -f $(HEX_DIR)/$(TEST).hex || { \
		echo "$(RED)Hex file $(HEX_DIR)/$(TEST).hex not found. Run: make asm$(NC)"; \
		exit 1; \
	}
	@echo "$(CYAN)[SIM]$(NC) Running test: $(TEST)"
	@mkdir -p $(LOG_DIR)
	@$(VVP) $(VVP_BIN) \
		+hexfile=$(HEX_DIR)/$(TEST).hex \
		+testname=$(TEST) \
		+timeout=$(TIMEOUT_CYCLES) \
		2>&1 | tee $(LOG_DIR)/$(TEST).log; \
	if grep -q '\[PASS\]' $(LOG_DIR)/$(TEST).log; then \
		echo ""; \
		echo "$(GREEN)  ✓ $(TEST) PASSED$(NC)"; \
	elif grep -q '\[FAIL\]' $(LOG_DIR)/$(TEST).log; then \
		echo ""; \
		echo "$(RED)  ✗ $(TEST) FAILED$(NC)"; \
		exit 1; \
	else \
		echo ""; \
		echo "$(YELLOW)  ? $(TEST) TIMEOUT / NO RESULT$(NC)"; \
		exit 2; \
	fi

# ============================================================================
# Run all tests (batch)
# ============================================================================
test: asm compile
	@echo ""
	@echo "$(CYAN)========================================$(NC)"
	@echo "$(CYAN)  Running test suite...$(NC)"
	@echo "$(CYAN)========================================$(NC)"
	@bash $(TOOLS_DIR)/run_tests.sh

test-v: asm compile
	@bash $(TOOLS_DIR)/run_tests.sh -v

# ============================================================================
# Clean
# ============================================================================
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(HEX_DIR)/*.hex
	@rm -rf $(ELF_DIR)/*.elf
	@rm -rf $(BIN_DIR)/*.bin
	@rm -f $(VVP_BIN)
	@echo "$(GREEN)Clean done.$(NC)"

clean-all: clean
	@echo "$(YELLOW)Cleaning simulation artifacts...$(NC)"
	@rm -rf $(LOG_DIR)/*.log
	@rm -rf $(SIM_DIR)/*.vcd
	@echo "$(GREEN)Clean-all done.$(NC)"

# ============================================================================
# List / Help
# ============================================================================
list list-tests:
	@echo "Available test programs:"
	@for f in $(ASM_SRCS); do \
		name=$$(basename $$f .s); \
		hex="$(HEX_DIR)/$$name.hex"; \
		if [ -f "$$hex" ]; then stat="$(GREEN)[assembled]$(NC)"; else stat="$(YELLOW)[pending]$(NC)"; fi; \
		printf "  %-20s %s\n" "$$name" "$$stat"; \
	done

help:
	@echo "RISC-V RV32I CPU Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make                    Build all (asm + compile)"
	@echo "  make asm                Assemble all .s → .hex"
	@echo "  make compile            Compile Verilog → sim/cpu_tb.vvp"
	@echo "  make run TEST=<name>    Run a single test"
	@echo "  make test               Run all tests (batch)"
	@echo "  make test-v             Run all tests (verbose, keep VCD)"
	@echo "  make list               List available test programs"
	@echo "  make clean              Remove build artifacts"
	@echo "  make clean-all          Remove all artifacts"
	@echo "  make help               Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make run TEST=program"
	@echo "  make run TEST=test_alu_r"
	@echo "  make run TEST=test_branch"
	@echo ""
	@echo "Tools detected:"
	@echo "  iverilog:  $(if $(HAS_IVERILOG),$(GREEN)✓$(NC) ($(shell $(IVERILOG) -V 2>&1 | head -1)),$(RED)✗ not found$(NC))"
	@echo "  vvp:       $(if $(HAS_VVP),$(GREEN)✓$(NC),$(RED)✗ not found$(NC))"
	@echo "  python3:   $(if $(HAS_PYTHON),$(GREEN)✓$(NC) ($(shell $(PYTHON) --version 2>&1)),$(RED)✗ not found$(NC))"
	@echo "  riscv-gcc: $(if $(HAS_RISCV),$(GREEN)✓$(NC),$(YELLOW)(using Python assembler instead)$(NC))"
