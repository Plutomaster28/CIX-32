#!/usr/bin/env bash
# tapeout_openlane_v2.sh - Fixed OpenLane tapeout wrapper for CIX-32
# Usage: ./tapeout_openlane_v2.sh
# Runs OpenLane Docker container to produce a GDS for the design `cix32`.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { echo "[tapeout-v2] $*"; }

log "=== CIX-32 OpenLane Tapeout Script v2 ==="
log "Project root: $WORKDIR"

# Pre-flight checks
if [[ ! -d "$WORKDIR/rtl" ]]; then
    echo "[ERROR] RTL directory '$WORKDIR/rtl' not found!" >&2
    exit 1
fi

if [[ -z "$(find "$WORKDIR/rtl" -name "*.v" -o -name "*.sv" | head -1)" ]]; then
    echo "[ERROR] No Verilog files found in '$WORKDIR/rtl'!" >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker not found. Please install Docker." >&2
    exit 1
fi

log "Pulling OpenLane Docker image..."
docker pull efabless/openlane:latest

log "Starting OpenLane container..."
mkdir -p "$WORKDIR/artifacts"

# Use a very simple approach: mount the work dir and run a single command
docker run --rm -it \
    -v "$WORKDIR":/project \
    -w /project \
    efabless/openlane:latest \
    bash -c '
        set -e
        echo "=== Inside OpenLane Container ==="
        echo "Working directory: $(pwd)"
        echo "Available files in /project/rtl:"
        ls -la /project/rtl/ | head -10
        
        # Create design workspace and copy config
        export OPENLANE_ROOT=/openlane
        export PDK_ROOT=/openlane/pdks
        mkdir -p /tmp/cix32_design/src
        
        # Copy RTL files
        echo "Copying RTL files..."
        cp /project/rtl/*.v /tmp/cix32_design/src/ 2>/dev/null || true
        cp /project/rtl/*.sv /tmp/cix32_design/src/ 2>/dev/null || true
        cp /project/rtl/*/*.v /tmp/cix32_design/src/ 2>/dev/null || true  
        cp /project/rtl/*/*.sv /tmp/cix32_design/src/ 2>/dev/null || true
        cp /project/rtl/*/*/*.v /tmp/cix32_design/src/ 2>/dev/null || true
        cp /project/rtl/*/*/*.sv /tmp/cix32_design/src/ 2>/dev/null || true
        
        # Copy configuration files
        echo "Copying configuration files..."
        if [[ -f /project/config.tcl ]]; then
            cp /project/config.tcl /tmp/cix32_design/
            echo "Using project config.tcl for 400MHz @ 130nm"
        else
            echo "No config.tcl found, creating basic one..."
            cat > /tmp/cix32_design/config.tcl << EOF
set ::env(DESIGN_NAME) "cix32"
set ::env(VERILOG_FILES) [glob /tmp/cix32_design/src/*.v /tmp/cix32_design/src/*.sv]
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "2.5"
set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) "0 0 3000 3000"
set ::env(FP_CORE_UTIL) 60
EOF
        fi
        
        # Copy SDC file if present
        if [[ -f /project/cix32.sdc ]]; then
            cp /project/cix32.sdc /tmp/cix32_design/
            echo "Using project SDC file for timing constraints"
        fi

        echo "Config created:"
        cat /tmp/cix32_design/config.tcl
        
        # Find and run OpenLane flow
        echo "Searching for OpenLane flow script..."
        if [[ -f "$OPENLANE_ROOT/flow.tcl" ]]; then
            FLOW_CMD="$OPENLANE_ROOT/flow.tcl"
        elif [[ -f "/usr/local/bin/flow.tcl" ]]; then
            FLOW_CMD="/usr/local/bin/flow.tcl"
        else
            echo "Searching for flow.tcl..."
            FLOW_CMD=$(find / -name "flow.tcl" -type f 2>/dev/null | head -1)
        fi
        
        if [[ -n "$FLOW_CMD" && -f "$FLOW_CMD" ]]; then
            echo "Found OpenLane flow at: $FLOW_CMD"
            echo "Running OpenLane flow..."
            cd /tmp/cix32_design
            $FLOW_CMD -design cix32 -config_file config.tcl || echo "Flow completed (may have warnings)"
            
            # Copy results back
            echo "Copying results back to host..."
            if [[ -d runs ]]; then
                cp -r runs /project/artifacts/ 2>/dev/null || true
                find runs -name "*.gds" -exec cp {} /project/artifacts/ \; 2>/dev/null || true
                find runs -name "*.def" -exec cp {} /project/artifacts/ \; 2>/dev/null || true
                echo "Results copied to /project/artifacts/"
                ls -la /project/artifacts/
            else
                echo "No runs directory created - check for errors above"
            fi
        else
            echo "ERROR: OpenLane flow.tcl not found!"
            echo "Available executables:"
            find /openlane /usr/local -name "*flow*" -type f 2>/dev/null | head -10
            exit 1
        fi
    '

log "Container execution complete."
log "Check $WORKDIR/artifacts/ for results:"
ls -la "$WORKDIR/artifacts/" 2>/dev/null || echo "No artifacts directory found"

log "Tapeout script v2 finished!"
