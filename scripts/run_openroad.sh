#!/bin/bash
# CIX-32 OpenROAD Flow Script for ASIC Implementation

set -e

# Source configuration
source config/config.mk

# Create results directory
mkdir -p $RESULTS_DIR

echo "Starting CIX-32 ASIC flow for 180nm process..."

# Step 1: Read design
echo "Reading design files..."
yosys -ql $RESULTS_DIR/synth.log -p "
    read_verilog -sv +incdir+rtl/core $VERILOG_FILES
    hierarchy -top $TOP_LEVEL_MODULE
    synth -top $TOP_LEVEL_MODULE
    dfflibmap -liberty $TECH_LIB
    abc -liberty $TECH_LIB
    clean
    write_verilog $RESULTS_DIR/${DESIGN_NAME}_synth.v
    stat
"

# Step 2: Initialize OpenROAD
echo "Starting OpenROAD flow..."
openroad -no_init -exit << EOF
    # Read libraries
    read_liberty $TECH_LIB
    read_lef $TECH_LEF
    
    # Read synthesized netlist
    read_verilog $RESULTS_DIR/${DESIGN_NAME}_synth.v
    link_design $TOP_LEVEL_MODULE
    
    # Read constraints
    read_sdc $SDC_FILE
    
    # Initialize floorplan
    initialize_floorplan \\
        -utilization $CORE_UTILIZATION \\
        -aspect_ratio $ASPECT_RATIO \\
        -core_space $CORE_MARGIN
    
    # Place standard cells
    place_pins -hor_layer metal2 -ver_layer metal3
    global_placement -routability_driven
    detailed_placement
    
    # Clock tree synthesis
    clock_tree_synthesis -buf_list {CLKBUF_X1 CLKBUF_X2 CLKBUF_X4}
    
    # Routing
    global_route -guide_file $RESULTS_DIR/route.guide
    detailed_route
    
    # Write results
    write_def $RESULTS_DIR/${DESIGN_NAME}_final.def
    write_verilog $RESULTS_DIR/${DESIGN_NAME}_final.v
    write_spef $RESULTS_DIR/${DESIGN_NAME}.spef
    
    # Generate reports
    report_checks -path_delay min_max -format full_clock_expanded \\
                  > $RESULTS_DIR/timing_report.txt
    report_power > $RESULTS_DIR/power_report.txt
    report_design_area > $RESULTS_DIR/area_report.txt
    
    # Generate GDS (if tools available)
    # write_gds $RESULTS_DIR/${DESIGN_NAME}.gds
    
    exit
EOF

echo "OpenROAD flow completed. Results in $RESULTS_DIR/"

# Summary
echo "=== Implementation Summary ==="
echo "Design: $DESIGN_NAME"
echo "Technology: 180nm"
echo "Target Frequency: $(echo "scale=1; 1000/$CLOCK_PERIOD" | bc) MHz"
echo "Results directory: $RESULTS_DIR"
echo ""
echo "Check timing_report.txt for timing closure"
echo "Check area_report.txt for area utilization"
echo "Check power_report.txt for power consumption"
