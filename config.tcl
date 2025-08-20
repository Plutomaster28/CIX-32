# OpenLane Configuration for CIX-32 CPU
# Target: 400MHz operation on SkyWater 130nm PDK
# Design: 32-bit x86-compatible processor with FPU, SIMD, and advanced features

# === DESIGN IDENTIFICATION ===
set ::env(DESIGN_NAME) "CIX32"

# Top-level module name
set ::env(DESIGN_IS_CORE) 0

# Verilog source files - CIX-32 full x86 processor with all advanced features
set ::env(VERILOG_FILES) "$::env(DESIGN_DIR)/cix32_full_processor.v"

# Clock configuration - targeting 400MHz (2.5ns period)
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "2.5"  ;# 400 MHz - aggressive for x86 processor on 130nm

# Reset configuration
set ::env(RESET_PORT) "rst_n"

# Core utilization and density - optimized for high-performance x86
set ::env(FP_CORE_UTIL) 40      ;# Higher utilization for performance density
set ::env(PL_TARGET_DENSITY) 0.60   ;# Denser placement for shorter interconnects

# Die size constraints - larger area for complex x86 processor
set ::env(DIE_AREA) "0 0 3000 3000"   ;# 3000µm x 3000µm die for x86 complexity
set ::env(FP_SIZING) "absolute"     ;# Use absolute die size
set ::env(CORE_AREA) "50 50 2950 2950" ;# Core area with margin for power/IO
set ::env(BOTTOM_MARGIN_MULT) 1     ;# Disable auto-scaling margins
set ::env(TOP_MARGIN_MULT) 1
set ::env(LEFT_MARGIN_MULT) 1
set ::env(RIGHT_MARGIN_MULT) 1

# Power grid settings - robust grid for high-frequency operation
set ::env(FP_PDN_VPITCH) 25.0       ;# Tighter vertical power grid for 400MHz
set ::env(FP_PDN_HPITCH) 25.0       ;# Tighter horizontal power grid  
set ::env(FP_PDN_VWIDTH) 3.1        ;# Vertical power rail width  
set ::env(FP_PDN_HWIDTH) 3.1        ;# Horizontal power rail width

# Pin configuration - let OpenLane auto-assign for now
# set ::env(FP_PIN_ORDER_CFG) "$::env(DESIGN_DIR)/pin_order.cfg"

# Routing configuration - fix layer issues
set ::env(RT_MAX_LAYER) "met5"  ;# Use up to metal5 for routing (safer)
set ::env(RT_MIN_LAYER) "met1"  ;# Minimum routing layer
set ::env(ROUTING_CORES) 4      ;# Parallel routing
set ::env(GLB_RT_MINLAYER) 1    ;# Global routing min layer (met1)
set ::env(GLB_RT_MAXLAYER) 5    ;# Global routing max layer (met5)

# Clock routing constraints - optimized for 400MHz
set ::env(CTS_CLK_MIN_LAYER) 3  ;# Clock minimum layer (met3)
set ::env(CTS_CLK_MAX_LAYER) 5  ;# Clock maximum layer (met5)
set ::env(CTS_CLK_BUFFER_LIST) "sky130_fd_sc_hd__clkbuf_1 sky130_fd_sc_hd__clkbuf_2 sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8"
set ::env(CTS_ROOT_BUFFER) "sky130_fd_sc_hd__clkbuf_16"
set ::env(CTS_TOLERANCE) 100  ;# 100ps clock skew tolerance

# IO-specific configurations for high pin count designs
set ::env(FP_IO_MODE) 1         ;# Random IO placement mode
set ::env(FP_IO_MIN_DISTANCE) 3 ;# Minimum distance between IO pins

# Power configuration - SkyWater 130nm standard nets
set ::env(VDD_NETS) "VPWR"     ;# Standard SkyWater VDD
set ::env(GND_NETS) "VGND"     ;# Standard SkyWater GND

# Additional power grid settings
set ::env(FP_PDN_CORE_RING) 1          ;# Enable core ring
set ::env(FP_PDN_CORE_RING_VWIDTH) 3.1 ;# Core ring vertical width
set ::env(FP_PDN_CORE_RING_HWIDTH) 3.1 ;# Core ring horizontal width

# Synthesis configuration - optimized for 400MHz timing
set ::env(SYNTH_STRATEGY) "DELAY 0"  ;# Prioritize timing over area
set ::env(SYNTH_BUFFERING) 1
set ::env(SYNTH_SIZING) 1
set ::env(SYNTH_DRIVING_CELL) "sky130_fd_sc_hd__inv_2"
set ::env(SYNTH_DRIVING_CELL_PIN) "Y"
set ::env(OUTPUT_CAP_LOAD) "17.65"  ;# Output load capacitance (updated variable name)
set ::env(MAX_FANOUT_CONSTRAINT) 6      ;# Limit fanout for timing (updated variable name)

# Timing constraints
set ::env(BASE_SDC_FILE) "$::env(DESIGN_DIR)/cix32.sdc"

# Placement configuration - aggressive timing optimization
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 1
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 1

# Layer configuration - prevent substrate layer usage  
set ::env(GRT_ALLOW_CONGESTION) 1       ;# Allow some congestion to avoid bad layers
set ::env(GRT_LAYER_ADJUSTMENTS) "0.99,0,0,0,0,0"  ;# Avoid nwell layer (li1 adjustment)

# Timing configuration
set ::env(STA_WRITE_LIB) 1      ;# Write timing libraries
set ::env(RUN_KLAYOUT_XOR) 0    ;# Skip XOR check for now (can be slow)

# DRC/LVS configuration
set ::env(MAGIC_DRC_USE_GDS) 0  ;# Use faster DRC checking
set ::env(RUN_MAGIC_DRC) 1      ;# Run DRC checks
set ::env(RUN_KLAYOUT_DRC) 0    ;# Skip KLayout DRC for now

# Output configuration
set ::env(PRIMARY_SIGNOFF_TOOL) "magic"  ;# Use Magic for final signoff

# Extra settings for complex designs
set ::env(SYNTH_READ_BLACKBOX_LIB) 1     ;# Handle any blackbox modules
set ::env(QUIT_ON_TIMING_VIOLATIONS) 0   ;# Don't quit on timing violations (first pass)
set ::env(QUIT_ON_MAGIC_DRC) 0          ;# Don't quit on DRC violations (first pass)
set ::env(QUIT_ON_SYNTH_CHECKS) 0       ;# Don't quit on synthesis check warnings

# Memory configuration (if you have memory macros)
# set ::env(EXTRA_LEFS) "$::env(PDK_ROOT)/$::env(PDK)/libs.ref/sky130_sram_macros/lef/sky130_sram_2kbyte_1rw1r_32x512_8.lef"
# set ::env(EXTRA_GDS_FILES) "$::env(PDK_ROOT)/$::env(PDK)/libs.ref/sky130_sram_macros/gds/sky130_sram_2kbyte_1rw1r_32x512_8.gds"

# Debugging (enable for detailed logs)
set ::env(SYNTH_NO_FLAT) 0      ;# Allow flattening for better optimization