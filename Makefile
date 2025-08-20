# Enhanced Makefile for CIX-32 Core Simulation

# Project directories
RTL_DIRS = rtl/core rtl/decode rtl/execute rtl/memory rtl/frontend rtl/pipeline rtl/control
RTL_FILES = $(wildcard $(addsuffix /*.sv,$(RTL_DIRS)))
TB_FILES = sim/tb/tb_minimal_core.sv

# Include path for SystemVerilog includes
INCLUDE_PATH = +incdir+rtl/core

# Simulator options
IVERILOG_OPTS = -g2012 $(INCLUDE_PATH) -Wall
VVP_OPTS = 

# Default target
all: build sim

# Create build directory
build:
	@if not exist build mkdir build

# Compile with Icarus Verilog
compile: build
	@echo Compiling CIX-32 Core...
	iverilog $(IVERILOG_OPTS) -o build/cix32_tb.vvp $(RTL_FILES) $(TB_FILES)

# Run simulation
sim: compile
	@echo Running simulation...
	vvp $(VVP_OPTS) build/cix32_tb.vvp

# Alternative: Verilator compilation (if available)
verilator: build
	@echo Compiling with Verilator...
	verilator --binary --timing --trace --top-module cix32_core_top \
		$(INCLUDE_PATH) -Wno-UNUSED -Wno-UNDRIVEN -Wno-PINMISSING \
		-o build/cix32_verilator $(RTL_FILES)

# Synthesis test with Yosys (if available)
synth: build
	@echo Running synthesis check with Yosys...
	yosys -p "read_verilog -sv $(INCLUDE_PATH) $(RTL_FILES); synth -top cix32_core_top; write_json build/cix32_synth.json"

# Clean build artifacts
clean:
	@if exist build rmdir /s /q build
	@if exist cix32_core.vcd del cix32_core.vcd

# Help target
help:
	@echo Available targets:
	@echo   all      - Build and run simulation (default)
	@echo   compile  - Compile only
	@echo   sim      - Run simulation (requires compile)
	@echo   verilator- Compile with Verilator
	@echo   synth    - Run synthesis check with Yosys
	@echo   clean    - Clean build artifacts
	@echo   help     - Show this help

# Generate file list for other tools
filelist:
	@echo # CIX-32 RTL File List > build/filelist.f
	@for %%f in ($(RTL_FILES)) do @echo %%f >> build/filelist.f

.PHONY: all build compile sim verilator synth clean help filelist
