# SDC Constraints for CIX-32 Core

# Create main clock
create_clock -name clk -period 20.0 [get_ports clk]

# Set clock uncertainty (jitter + skew)
set_clock_uncertainty 0.5 [get_clocks clk]

# Set clock transition
set_clock_transition 0.2 [get_clocks clk]

# Input delays (assume external logic provides data)
set_input_delay -clock clk 2.0 [all_inputs]
set_input_delay -clock clk 2.0 [get_ports rst_n]

# Output delays (assume external logic can accept data)
set_output_delay -clock clk 2.0 [all_outputs]

# Don't touch reset
set_dont_touch_network [get_ports rst_n]

# Memory interface timing
set_input_delay -clock clk 3.0 [get_ports imem_rdata*]
set_input_delay -clock clk 3.0 [get_ports imem_ready]
set_input_delay -clock clk 3.0 [get_ports dmem_rdata*]
set_input_delay -clock clk 3.0 [get_ports dmem_ready]

set_output_delay -clock clk 3.0 [get_ports imem_addr*]
set_output_delay -clock clk 3.0 [get_ports imem_req]
set_output_delay -clock clk 3.0 [get_ports dmem_addr*]
set_output_delay -clock clk 3.0 [get_ports dmem_wdata*]
set_output_delay -clock clk 3.0 [get_ports dmem_wstrb*]
set_output_delay -clock clk 3.0 [get_ports dmem_req]
set_output_delay -clock clk 3.0 [get_ports dmem_we]

# Interrupt timing
set_input_delay -clock clk -max 1.0 [get_ports irq*]

# False paths for reset
set_false_path -from [get_ports rst_n]

# Max delay for combinational paths
set_max_delay 15.0 -from [all_inputs] -to [all_outputs]

# Load constraints (estimated)
set_load 0.1 [all_outputs]

# Drive constraints (estimated)
set_driving_cell -lib_cell BUFX2 [all_inputs]

# Multi-cycle paths (if any)
# Example: set_multicycle_path -setup 2 -from [get_pins u_muldiv/*] -to [get_pins u_regfile/*]

# Area constraint
set_max_area 0
