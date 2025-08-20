# CIX-32 OpenROAD Flow Configuration
# 180nm process target

# Design name
export DESIGN_NAME = cix32_core_top

# Verilog files
export VERILOG_FILES = $(shell find rtl -name "*.sv")

# Top level module
export TOP_LEVEL_MODULE = cix32_core_top

# Target frequency (50 MHz for 180nm conservative)
export CLOCK_PERIOD = 20.0

# Technology files (user must provide PDK)
# export TECH_LEF = /path/to/180nm/tech.lef
# export TECH_LIB = /path/to/180nm/lib/*.lib

# Design constraints
export SDC_FILE = config/cix32_constraints.sdc

# Pin mapping (if needed)
export PIN_CONSTRAINTS = config/pin_constraints.tcl

# Floorplan settings
export CORE_UTILIZATION = 60
export ASPECT_RATIO = 1.0
export CORE_MARGIN = 5

# Placement settings
export PLACEMENT_DENSITY = 0.7

# Routing settings
export MAX_ROUTING_LAYER = metal3

# Power grid
export PDN_CFG = config/pdn.cfg

# Output directory
export RESULTS_DIR = results

# Additional synthesis options
export SYNTH_FLAGS = -abc9

# Memory compilation (if using memory compiler)
export PLATFORM = generic180nm

# Critical path optimization
export MAX_FANOUT = 32
export MAX_TRANSITION = 1.5

# Hold time fixing
export HOLD_SLACK_MARGIN = 0.1

# Setup time margin  
export SETUP_SLACK_MARGIN = 0.1
