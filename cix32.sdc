# Timing Constraints for CIX-32 CPU @ 400MHz
# SkyWater 130nm PDK
# Target clock period: 2.5ns

# === PRIMARY CLOCK DEFINITION ===
create_clock -name clk -period 2.5 [get_ports clk]

# === CLOCK UNCERTAINTY ===
# Account for PLL jitter, clock tree skew, and process variation
set_clock_uncertainty -setup 0.25 [get_clocks clk]
set_clock_uncertainty -hold 0.15 [get_clocks clk]

# === CLOCK TRANSITION ===
set_clock_transition 0.15 [get_clocks clk]

# === INPUT CONSTRAINTS ===
# Assume inputs arrive with some setup/hold margin relative to clock
# Apply input delays only to data inputs (not clock)
set_input_delay -clock clk -min 0.2 [get_ports "mem_rdata*"]
set_input_delay -clock clk -max 0.8 [get_ports "mem_rdata*"]
set_input_delay -clock clk -min 0.2 [get_ports "mem_ready"]
set_input_delay -clock clk -max 0.8 [get_ports "mem_ready"]

# === OUTPUT CONSTRAINTS ===
# Outputs should be stable well before next clock edge
set_output_delay -clock clk -min 0.1 [get_ports "mem_addr*"]
set_output_delay -clock clk -max 1.0 [get_ports "mem_addr*"]
set_output_delay -clock clk -min 0.1 [get_ports "mem_wdata*"]
set_output_delay -clock clk -max 1.0 [get_ports "mem_wdata*"]
set_output_delay -clock clk -min 0.1 [get_ports "mem_we"]
set_output_delay -clock clk -max 1.0 [get_ports "mem_we"]
set_output_delay -clock clk -min 0.1 [get_ports "mem_re"]
set_output_delay -clock clk -max 1.0 [get_ports "mem_re"]
set_output_delay -clock clk -min 0.1 [get_ports "pc_out*"]
set_output_delay -clock clk -max 1.0 [get_ports "pc_out*"]
set_output_delay -clock clk -min 0.1 [get_ports "*_out*"]
set_output_delay -clock clk -max 1.0 [get_ports "*_out*"]
set_output_delay -clock clk -min 0.1 [get_ports "halted"]
set_output_delay -clock clk -max 1.0 [get_ports "halted"]
set_output_delay -clock clk -min 0.1 [get_ports "exception"]
set_output_delay -clock clk -max 1.0 [get_ports "exception"]

# === RESET CONSTRAINTS ===
# Reset is typically asynchronous - simplified version
set_false_path -from [get_ports rst_n]

# === CRITICAL PATH TIMING ===
# Set max delay for critical CPU paths - simplified for OpenSTA compatibility
# Clock-to-output paths for main processor outputs
set_max_delay 2.0 -from [get_ports clk] -to [get_ports {eax_out* ebx_out* ecx_out* edx_out*}]
set_max_delay 2.0 -from [get_ports clk] -to [get_ports {mem_addr* mem_wdata*}]

# === MULTICYCLE PATHS ===
# Some CPU operations may take multiple cycles - simplified for OpenSTA
# Multi-cycle constraints for complex operations
set_multicycle_path -setup 4 -from [get_ports clk] -to [get_ports {eax_out* ebx_out*}]
set_multicycle_path -hold 3 -from [get_ports clk] -to [get_ports {eax_out* ebx_out*}]

# === LOAD CONSTRAINTS ===
# Set reasonable load assumptions for outputs
set_load 0.05 [get_ports {mem_rdata* mem_ready mem_addr* mem_wdata* mem_we mem_re halted exception eax_out* ebx_out* ecx_out* edx_out* esp_out* ebp_out* esi_out* edi_out* flags_out* pc_out*}]

# === DRIVE STRENGTH ===
# Set drive strength for inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [get_ports {clk rst_n mem_rdata* mem_ready}]

# === CASE ANALYSIS ===
# Set constants for test/debug signals - simplified for OpenSTA
# Most designs don't have test_mode ports in this implementation

# === TIMING EXCEPTIONS ===
# Clock domain crossing paths (if any async interfaces exist)
# set_false_path -from [get_clocks clk] -to [get_clocks async_clk]

# === HIGH-PERFORMANCE CONSTRAINTS ===
# Tighten timing on critical datapaths
set_max_transition 0.5 [current_design]
set_max_capacitance 0.2 [current_design]
set_max_fanout 16 [current_design]

# === POWER OPTIMIZATION ===
# Enable clock gating checks
set_clock_gating_check -setup 0.2 -hold 0.1

# === AREA CONSTRAINTS ===
# Optional: set area constraints to encourage optimization
# set_max_area 2500000

# === OPERATING CONDITIONS ===
# Define operating corners for robust timing
# This will be handled by the PDK corner definitions

# === DFT CONSTRAINTS ===
# If scan chains are inserted, define scan constraints
# set_scan_configuration -style multiplexed_flip_flop

# === TIMING DERATE ===
# Apply timing derates for OCV (On-Chip Variation)
set_timing_derate -early 0.95
set_timing_derate -late 1.05

# === FINAL VERIFICATION CONSTRAINTS ===
# Ensure no timing violations in final netlist
set_max_delay 2.4 -from [get_ports {clk rst_n mem_rdata* mem_ready}] -to [get_ports {mem_addr* mem_wdata* mem_we mem_re halted exception eax_out* ebx_out* ecx_out* edx_out*}]
set_min_delay 0.1 -from [get_ports {clk rst_n mem_rdata* mem_ready}] -to [get_ports {mem_addr* mem_wdata* mem_we mem_re halted exception eax_out* ebx_out* ecx_out* edx_out*}]
