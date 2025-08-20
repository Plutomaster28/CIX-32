#!/usr/bin/env bash
# tapeout_openlane.sh - Automated OpenLane tapeout wrapper for CIX-32
# Usage: ./tapeout_openlane.sh [--pdk skywater130|custom] [--openlane /home/miyamii/OpenLane] [--no-docker]
# Runs OpenLane (Docker or local) to produce a GDS for the design `cix32`.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(cd "$SCRIPT_DIR/.." && pwd)"  # project root (CIX-32)

# Defaults
PDK_DEFAULT="skywater130"
PDK="${PDK_DEFAULT}"
OPENLANE_DIR="/home/miyamii/OpenLane"
DESIGN="cix32"
USE_DOCKER=1
ARTIFACTS_DIR="$WORKDIR/artifacts"
RTL_DIR="$WORKDIR/rtl"
VERBOSE=0

# Helper
log() { echo "[tapeout] $*"; }
usage() {
    cat <<EOF
Usage: $0 [--pdk <name|custom>] [--openlane <path>] [--no-docker] [--help]

Options:
  --pdk        PDK to use (default: ${PDK_DEFAULT}). Use 'custom' to assume you've installed a PDK in OpenLane/pdks.
  --openlane   Path to your OpenLane repo (default: ${OPENLANE_DIR}).
  --no-docker  Run OpenLane natively in this environment instead of using Docker container.
  --help       Show this help.

Example (WSL):
    ./tapeout_openlane.sh --pdk skywater130 --openlane ~/OpenLane

EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pdk)
            PDK="$2"; shift 2;;
        --openlane)
            OPENLANE_DIR="$2"; shift 2;;
        --no-docker)
            USE_DOCKER=0; shift;;
        -v|--verbose)
            VERBOSE=1; shift;;
        -h|--help)
            usage; exit 0;;
        *)
            echo "Unknown arg: $1"; usage; exit 1;;
    esac
done

log "Project root: $WORKDIR"
log "OpenLane dir: $OPENLANE_DIR"
log "PDK: $PDK"
log "Use Docker: $USE_DOCKER"

# Ensure artifacts dir
mkdir -p "$ARTIFACTS_DIR"

# For Docker mode, we'll create the design skeleton inside the container
# For local mode, we still need to prepare the host OpenLane directory
if [[ $USE_DOCKER -eq 0 ]]; then
    # Prepare OpenLane design skeleton for local mode only
    DESIGN_DIR="$OPENLANE_DIR/designs/$DESIGN"
    SRC_DIR="$DESIGN_DIR/src"
    log "Creating design skeleton in $DESIGN_DIR"
    mkdir -p "$SRC_DIR"

    # Copy synthesizable RTL files from project rtl into design src
    log "Copying synthesizable RTL from $RTL_DIR to $SRC_DIR"
    find "$RTL_DIR" -type f \( -name "*.v" -o -name "*.sv" \) \
        | grep -Ev '/(tb|demo|sim)/' \
        | while read -r f; do
        cp -v -- "$f" "$SRC_DIR/"
    done

    # Create minimal config.tcl if not present
    CFG_FILE="$DESIGN_DIR/config.tcl"
    if [[ ! -f "$CFG_FILE" ]]; then
        log "Creating basic config.tcl at $CFG_FILE"
        cat > "$CFG_FILE" <<TCL
set ::env(DESIGN_NAME) $DESIGN
set ::env(VERILOG_FILES) [glob \$::env(DESIGN_DIR)/src/*.v \$::env(DESIGN_DIR)/src/*.sv]
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "10.0"
TCL
    fi
else
    log "Docker mode: design setup will happen inside container"
fi

# If user asked for skywater, ensure PDK is installed
if [[ "$PDK" == "${PDK_DEFAULT}" ]]; then
    if [[ ! -d "$OPENLANE_DIR/pdks/skywater-pdk" ]]; then
        log "SkyWater pdk not found under $OPENLANE_DIR/pdks — attempting to fetch (make pdk=skywater130A)"
        if [[ $USE_DOCKER -eq 1 ]]; then
            log "PDK fetch will be executed inside Docker container during flow"
        else
            # run make pdk=skywater130A locally if OpenLane is present
            if [[ -d "$OPENLANE_DIR" ]]; then
                log "Running 'make pdk=skywater130A' in $OPENLANE_DIR (this may take a while)"
                (cd "$OPENLANE_DIR" && make pdk=skywater130A)
            else
                log "OpenLane directory $OPENLANE_DIR not found; cannot fetch PDK locally"
            fi
        fi
    else
        log "SkyWater PDK appears installed"
    fi
fi

# Function to run OpenLane flow inside Docker
run_in_docker() {
    log "Starting Docker container and running OpenLane flow"
    docker_image="efabless/openlane:latest"
    if ! docker image inspect "$docker_image" >/dev/null 2>&1; then
        log "Pulling Docker image $docker_image"
        docker pull "$docker_image"
    fi
    # Pre-flight checks: ensure rtl directory exists and is non-empty
    if [[ ! -d "$WORKDIR/rtl" ]]; then
        echo "[tapeout] ERROR: RTL directory '$WORKDIR/rtl' not found. Ensure you're running the script from the project root." >&2
        exit 1
    fi
    if [[ -z "$(ls -A "$WORKDIR/rtl" 2>/dev/null)" ]]; then
        echo "[tapeout] ERROR: RTL directory '$WORKDIR/rtl' appears empty. Nothing to copy into container." >&2
        exit 1
    fi
    # Warn if running as root/sudo - this commonly causes Docker mount permission problems
    if [[ $(id -u) -eq 0 ]]; then
        log "WARNING: running this script with sudo/root may cause Docker to mount host paths unexpectedly. Prefer running without sudo if possible. Proceeding..."
    fi
    # Do NOT mount the host OpenLane repo over the container's /openlane (that overwrites container manifests).
    # Instead, optionally expose the host OpenLane at /host_openlane and use the container's built-in OpenLane.
    DOCKER_UID="$(id -u)"
    DOCKER_GID="$(id -g)"
    if [[ -n "${SUDO_UID-}" ]]; then
        DOCKER_UID="$SUDO_UID"
        DOCKER_GID="${SUDO_GID-$(id -g)}"
    fi

    DOCKER_ARGS=(--rm -it -u "${DOCKER_UID}:${DOCKER_GID}" -v "${WORKDIR}":/work)
    if [[ -d "$OPENLANE_DIR" ]]; then
        DOCKER_ARGS+=( -v "$OPENLANE_DIR":/host_openlane )
    fi
    DOCKER_ARGS+=( -w /work "$docker_image" )

    # Use double-quoted bash -lc so $DESIGN is expanded by the host and globs (like /work/rtl/*)
    # remain unexpanded until inside the container's shell.
    # Create a writable workspace in /tmp instead of trying to write to the system /openlane
    docker run "${DOCKER_ARGS[@]}" bash -lc "set -e; \
        export WORK_DIR=/tmp/openlane_work; \
        mkdir -p \$WORK_DIR/designs/${DESIGN}/src; \
        cp -r /work/rtl/* \$WORK_DIR/designs/${DESIGN}/src/ || true; \
        mkdir -p \$WORK_DIR/designs/${DESIGN}; \
        echo 'set ::env(DESIGN_NAME) ${DESIGN}' > \$WORK_DIR/designs/${DESIGN}/config.tcl; \
        echo 'set ::env(VERILOG_FILES) [glob \\\$::env(DESIGN_DIR)/src/*.v \\\$::env(DESIGN_DIR)/src/*.sv]' >> \$WORK_DIR/designs/${DESIGN}/config.tcl; \
        echo 'set ::env(CLOCK_PORT) \"clk\"' >> \$WORK_DIR/designs/${DESIGN}/config.tcl; \
        echo 'set ::env(CLOCK_PERIOD) \"10.0\"' >> \$WORK_DIR/designs/${DESIGN}/config.tcl; \
        cd \$WORK_DIR; \
        echo 'Searching for OpenLane flow script...'; \
        FLOW_SCRIPT=\\\$(find /openlane /usr/local -name 'flow.tcl' 2>/dev/null | head -1); \
        if [[ -n \\\"\\\$FLOW_SCRIPT\\\" ]]; then \
            echo \\\"Found flow script at: \\\$FLOW_SCRIPT\\\"; \
            \\\$FLOW_SCRIPT -design ${DESIGN}; \
        else \
            echo 'ERROR: OpenLane flow.tcl not found anywhere'; \
            echo 'Available OpenLane-related files:'; \
            find /openlane /usr/local -name '*flow*' 2>/dev/null | head -10; \
            exit 1; \
        fi; \
        echo 'Copying results back to host...'; \
        cp -r \$WORK_DIR/designs/${DESIGN}/runs/* /work/ 2>/dev/null || echo 'No runs directory found to copy'"
}

# Function to run OpenLane flow locally (no Docker)
run_local() {
    if [[ ! -d "$OPENLANE_DIR" ]]; then
        log "OpenLane directory $OPENLANE_DIR not found locally. Aborting local run."
        exit 1
    fi
    log "Running OpenLane flow locally in $OPENLANE_DIR"
    (cd "$OPENLANE_DIR" && \
        # copy design files
        rm -rf "designs/$DESIGN/src" || true && mkdir -p "designs/$DESIGN/src" && \
        cp -r "$WORKDIR/rtl"/* "designs/$DESIGN/src/" && \
        mkdir -p "designs/$DESIGN/synth" "designs/$DESIGN/pnr" && \
        ./flow.tcl -design $DESIGN)
}

# Run the flow
if [[ $USE_DOCKER -eq 1 ]]; then
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker not found. Install Docker or run with --no-docker to run locally." >&2
        exit 1
    fi
    run_in_docker
else
    run_local
fi

# After flow - find final.gds in artifacts or work directory
RESULTS_SEARCH_DIRS=("$ARTIFACTS_DIR" "$WORKDIR")
FINAL_GDS=""
for search_dir in "${RESULTS_SEARCH_DIRS[@]}"; do
    if [[ -d "$search_dir" ]]; then
        while IFS= read -r -d '' gds_file; do
            FINAL_GDS="$gds_file"
            break 2
        done < <(find "$search_dir" -name "*.gds" -o -name "*.gds.gz" -print0 2>/dev/null)
    fi
done

if [[ -n "$FINAL_GDS" ]]; then
    if [[ "$FINAL_GDS" != "$ARTIFACTS_DIR"/* ]]; then
        cp -v "$FINAL_GDS" "$ARTIFACTS_DIR/"
        log "Final GDS copied to $ARTIFACTS_DIR/"
    else
        log "Final GDS already in $ARTIFACTS_DIR/"
    fi
else
    log "WARNING: final.gds not found in artifacts or work directory - check container output above"
fi

log "Tapeout wrapper finished. Artifacts in: $ARTIFACTS_DIR"

exit 0
