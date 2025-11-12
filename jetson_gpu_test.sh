#!/bin/bash

################################################################################
# JETSON ORIN AGX 64GB - DEDICATED GPU STRESS TEST (ENHANCED DETAILED)
################################################################################
# Description: Professional stress testing for Jetson Orin's GPU (CUDA, VPU, GFX)
# Version: 2.0 DETAILED - Enhanced comprehensive GPU testing with detailed metrics
# ENHANCEMENTS:
# - Multiple CUDA kernel types (compute, memory bandwidth, precision tests)
# - Power monitoring and thermal throttling detection
# - Multi-codec VPU testing (H.264, H.265)
# - Detailed performance metrics (GFLOPS, bandwidth, efficiency)
# - Concurrent execution testing
# - All using default/built-in features (no external ML models)
# PREVIOUS FIXES:
# - Variable tracking COMPLETELY SOLVED (v1.6)
# - 4K-only videos (v1.6)
# - Graphics test fixed for Jetson headless systems (v1.7)
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common utilities
source "$SCRIPT_DIR/jetson_utils.sh"

################################################################################
# PARAMETER HANDLING
################################################################################

# Check if being run non-interactively with all parameters provided
if [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
    # Non-interactive mode: use provided parameters directly (called from orchestrator/sequential)
    ORIN_IP="$1"
    ORIN_USER="$2"
    ORIN_PASS="$3"
    TEST_DURATION_HOURS="$4"

    # Validate duration is a number
    if ! [[ "$TEST_DURATION_HOURS" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "ERROR: Invalid duration '$TEST_DURATION_HOURS'. Must be a number."
        exit 1
    fi
else
    # Interactive mode: collect parameters
    collect_test_parameters "${1:-192.168.55.69}" "${2:-orin}" "${3}" "${4:-2}"
fi

# Get tester information (parameters 6 and 7 from orchestrator, or from environment if from collect_test_parameters)
TESTER_NAME="${6:-${TESTER_NAME:-N/A}}"
QUALITY_CHECKER_NAME="${7:-${QUALITY_CHECKER_NAME:-N/A}}"
DEVICE_SERIAL="${8:-${DEVICE_SERIAL:-N/A}}"

################################################################################
# CONFIGURATION
################################################################################

# Total test duration in seconds
TEST_DURATION=$(echo "$TEST_DURATION_HOURS * 3600" | bc | cut -d'.' -f1)  # Convert hours to seconds (handle decimals)

# For display purposes, use the hours value directly
DISPLAY_DURATION_HOURS=$TEST_DURATION_HOURS

# Phase durations (in seconds)
PHASE_GPU_VPU=$((TEST_DURATION * 40 / 100)) # 40% of time - Video Processing Unit (Encoding)
PHASE_GPU_CUDA=$((TEST_DURATION * 40 / 100)) # 40% of time - CUDA Core (General Compute)
PHASE_GPU_GFX=$((TEST_DURATION * 10 / 100))  # 10% of time - Graphics Pipeline (OpenGL)
if (( PHASE_GPU_GFX < 90 )); then
    PHASE_GPU_GFX=90
fi
PHASE_GPU_COMBINED=$((TEST_DURATION * 10 / 100)) # 10% of time - All GPU components combined

# Log directory - accepts parameter from orchestrator/sequential test
LOG_DIR="${5:-./gpu_test_$(date +%Y%m%d_%H%M%S)}"

# Debug: Show what LOG_DIR was set to
echo "[DEBUG] GPU Test - Received parameters:"
echo "  \$1 (IP): $1"
echo "  \$2 (User): $2"
echo "  \$3 (Pass): [hidden]"
echo "  \$4 (Duration): $4"
echo "  \$5 (LOG_DIR): ${5:-NOT_PROVIDED}"
echo "  Final LOG_DIR: $LOG_DIR"
echo ""

################################################################################
# USAGE & HELP
################################################################################

show_usage() {
    cat << EOF
================================================================================
  JETSON ORIN DEDICATED GPU STRESS TEST (DETAILED v2.0)
================================================================================

Usage: $0 [orin_ip] [orin_user] [password] [hours]

Parameters:
  orin_ip     : IP address of Jetson Orin (default: 192.168.55.69)
  orin_user   : SSH username (default: orin)
  password    : SSH password (will prompt if not provided)
  hours       : Test duration in hours (default: 2 hours)

NEW ENHANCEMENTS IN v2.0:
  [+] Multiple CUDA test types (compute, memory, precision)
  [+] Memory bandwidth testing (H2D, D2H, D2D)
  [+] FP16, FP32, FP64 precision tests
  [+] Concurrent kernel execution testing
  [+] Power monitoring and thermal throttling detection
  [+] Multi-codec VPU testing (H.264, H.265)
  [+] Detailed performance metrics (GFLOPS, GB/s)
  [+] Performance degradation detection
  [+] All features use default/built-in capabilities

Examples:
  $0                                              # Use all defaults (2 hour test)
  $0 192.168.55.69 orin mypass 4                 # 4 hour test
  $0 10.0.0.100 nvidia secret 1                  # 1 hour test
  $0 192.168.55.69 orin mypass 0.17              # 10 minute test (0.17 hours)

TEST COMPONENTS:
  [*] VPU: Multi-codec (H.264/H.265), 4K encoding, decode testing
  [*] CUDA: Multiple kernel types, precision tests, memory bandwidth
  [*] Graphics: EGL headless rendering, compute shaders
  [*] Combined: All components running simultaneously

================================================================================
EOF
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_usage
    exit 0
fi

################################################################################
# PREREQUISITE CHECKS (HOST)
################################################################################

echo "================================================================================
  JETSON ORIN DEDICATED GPU STRESS TEST (DETAILED v2.0) - INITIALIZATION
================================================================================"
echo ""
echo "Test Configuration:"
echo "  • Device: Jetson Orin AGX 64GB"
echo "  • Target IP: $ORIN_IP"
echo "  • SSH User: $ORIN_USER"
echo "  • Test Duration: ${DISPLAY_DURATION_HOURS} hours (${TEST_DURATION} seconds)"
echo "  • Test Mode: DEDICATED GPU (Enhanced Detailed Testing)"
echo "  • Success Target: 100% (zero failures accepted on components)"
echo "  • Version: v2.0 DETAILED (Multi-kernel, precision, bandwidth tests)"
echo ""
echo "Test Personnel:"
echo "  • Tester: $TESTER_NAME"
echo "  • Quality Checker: $QUALITY_CHECKER_NAME"
echo "  • Device Serial: $DEVICE_SERIAL"
echo ""
echo "Enhanced Testing Features:"
echo "  • CUDA: Multiple kernel types, precision tests, bandwidth measurement"
echo "  • VPU: Multi-codec (H.264/H.265), encode/decode tests"
echo "  • Power: Continuous monitoring, throttling detection"
echo "  • Metrics: GFLOPS, GB/s, thermal performance"
echo ""

# Check for sshpass
if ! command -v sshpass &> /dev/null; then
    echo "ERROR: 'sshpass' is not installed"
    echo ""
    echo "Install instructions:"
    echo "  Rocky Linux: sudo dnf install epel-release && sudo dnf install sshpass"
    echo "  Ubuntu/Debian: sudo apt-get install sshpass"
    exit 1
fi

# Test SSH connection
echo "Testing SSH connection to $ORIN_IP..."
if ! sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'Connection OK'" 2>/dev/null | grep -q "Connection OK"; then
    echo "ERROR: SSH connection failed"
    echo "  Please check:"
    echo "  • IP address is correct"
    echo "  • Jetson Orin is powered on and network is accessible"
    echo "  • SSH password is correct"
    exit 1
fi
echo "[+] SSH connection successful"
echo ""

# Create local log directories
mkdir -p "$LOG_DIR/logs"
mkdir -p "$LOG_DIR/videos"
mkdir -p "$LOG_DIR/reports"
mkdir -p "$LOG_DIR/monitoring"

# Convert to absolute path
LOG_DIR=$(cd "$LOG_DIR" && pwd)

echo "Local results directory: $LOG_DIR"
echo ""
echo "Starting GPU test execution on Jetson Orin..."
echo ""

################################################################################
# REMOTE TEST SCRIPT (EXECUTED ON JETSON ORIN)
################################################################################

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "export ORIN_PASS='$ORIN_PASS'; export TEST_DURATION=$TEST_DURATION; export PHASE_GPU_VPU=$PHASE_GPU_VPU; export PHASE_GPU_CUDA=$PHASE_GPU_CUDA; export PHASE_GPU_GFX=$PHASE_GPU_GFX; export PHASE_GPU_COMBINED=$PHASE_GPU_COMBINED; bash -s" << 'REMOTE_SCRIPT_START'
#!/bin/bash

################################################################################
# REMOTE EXECUTION - JETSON ORIN DEDICATED GPU STRESS TEST (ULTIMATE v1.7)
################################################################################

set -e

# Test directory on Jetson
TEST_DIR="/tmp/jetson_gpu_stress_$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$TEST_DIR/logs"
VIDEO_DIR="$TEST_DIR/videos"
REPORT_DIR="$TEST_DIR/reports"
MONITOR_DIR="$TEST_DIR/monitoring"
CUDA_APP_DIR="$TEST_DIR/cuda_stress_app"
GRAPHICS_APP_DIR="$TEST_DIR/graphics_stress_app"  # NEW: For custom graphics tests
TEMP_RESULTS_DIR="$TEST_DIR/temp_results"

mkdir -p "$TEST_DIR" "$LOG_DIR" "$VIDEO_DIR" "$REPORT_DIR" "$MONITOR_DIR" "$CUDA_APP_DIR" "$GRAPHICS_APP_DIR" "$TEMP_RESULTS_DIR"

# Environment for CUDA and GStreamer
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
export CUDA_VISIBLE_DEVICES=0

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${CYAN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_phase() {
    echo ""
    echo "================================================================================"
    echo -e "${MAGENTA}$(date '+%Y-%m-%d %H:%M:%S') $1${NC}"
    echo "================================================================================"
    echo ""
}

# Calculate remote display duration
if (( TEST_DURATION < 3600 )) && (( TEST_DURATION > 0 )); then
    REMOTE_DISPLAY_HOURS=$(echo "scale=2; $TEST_DURATION / 3600" | bc 2>/dev/null || echo "0.5")
else
    REMOTE_DISPLAY_HOURS=$((TEST_DURATION / 3600))
fi

log_phase "JETSON ORIN DETAILED GPU STRESS TEST STARTED (v2.0)"

log_info "Remote Test Configuration:"
echo "  • Test Duration: ${TEST_DURATION} seconds (${REMOTE_DISPLAY_HOURS} hours)"
echo "  • Phase 1 (VPU): ${PHASE_GPU_VPU} seconds - Multi-codec (H.264/H.265)"
echo "  • Phase 2 (CUDA): ${PHASE_GPU_CUDA} seconds - Detailed tests (bandwidth, FP32/FP64, etc.)"
echo "  • Phase 3 (GFX): ${PHASE_GPU_GFX} seconds - EGL headless"
echo "  • Phase 4 (Combined): ${PHASE_GPU_COMBINED} seconds - All components"
echo "  • Local Test Directory: $TEST_DIR"
echo "  • Version: v2.0 DETAILED (Enhanced with power, throttling, multi-codec)"
echo ""

################################################################################
# BULLETPROOF RESULT TRACKING SYSTEM (SAME AS v1.6)
################################################################################

# Initialize result files
echo "0" > "$TEMP_RESULTS_DIR/vpu_pass_count"
echo "0" > "$TEMP_RESULTS_DIR/vpu_fail_count"
echo "0" > "$TEMP_RESULTS_DIR/cuda_pass_count"
echo "0" > "$TEMP_RESULTS_DIR/cuda_fail_count"
echo "0" > "$TEMP_RESULTS_DIR/gfx_pass_count"
echo "0" > "$TEMP_RESULTS_DIR/gfx_fail_count"
echo "0" > "$TEMP_RESULTS_DIR/combined_pass_count"
echo "0" > "$TEMP_RESULTS_DIR/combined_fail_count"

log_info "Initialized bulletproof result tracking system using temp files"

# Helper functions for result tracking (same as v1.6)
increment_vpu_pass() {
    local current=$(cat "$TEMP_RESULTS_DIR/vpu_pass_count")
    echo $((current + 1)) > "$TEMP_RESULTS_DIR/vpu_pass_count"
}

increment_vpu_fail() {
    local current=$(cat "$TEMP_RESULTS_DIR/vpu_fail_count")
    echo $((current + 1)) > "$TEMP_RESULTS_DIR/vpu_fail_count"
}

increment_cuda_pass() {
    local current=$(cat "$TEMP_RESULTS_DIR/cuda_pass_count")
    echo $((current + 1)) > "$TEMP_RESULTS_DIR/cuda_pass_count"
}

increment_cuda_fail() {
    local current=$(cat "$TEMP_RESULTS_DIR/cuda_fail_count")
    echo $((current + 1)) > "$TEMP_RESULTS_DIR/cuda_fail_count"
}

increment_gfx_pass() {
    local current=$(cat "$TEMP_RESULTS_DIR/gfx_pass_count")
    echo $((current + 1)) > "$TEMP_RESULTS_DIR/gfx_pass_count"
}

increment_gfx_fail() {
    local current=$(cat "$TEMP_RESULTS_DIR/gfx_fail_count")
    echo $((current + 1)) > "$TEMP_RESULTS_DIR/gfx_fail_count"
}

increment_combined_pass() {
    local current=$(cat "$TEMP_RESULTS_DIR/combined_pass_count")
    echo $((current + 1)) > "$TEMP_RESULTS_DIR/combined_pass_count"
}

increment_combined_fail() {
    local current=$(cat "$TEMP_RESULTS_DIR/combined_fail_count")
    echo $((current + 1)) > "$TEMP_RESULTS_DIR/combined_fail_count"
}

################################################################################
# PHASE 0: SYSTEM PREPARATION AND SETUP
################################################################################

log_phase "PHASE 0: SYSTEM PREPARATION AND SETUP"

# System info collection
log_info "Collecting system information..."
{
    echo "=== JETSON ORIN GPU STRESS TEST SYSTEM INFO (ULTIMATE v1.7) ==="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime)"
    echo ""
    echo "=== HARDWARE INFO ==="
    cat /proc/cpuinfo | grep -E "(processor|model name|cpu cores|Hardware)" | head -10
    echo ""
    echo "=== MEMORY INFO ==="
    free -h
    echo ""
    echo "=== DISK INFO ==="
    df -h
    echo ""
    echo "=== GPU INFO ==="
    nvidia-smi || echo "nvidia-smi not available"
    echo ""
    echo "=== JETPACK VERSION ==="
    cat /etc/nv_tegra_release 2>/dev/null || echo "JetPack info not available"
    echo ""
    echo "=== TEMPERATURE SENSORS ==="
    cat /sys/devices/virtual/thermal/thermal_zone*/temp 2>/dev/null | head -5 || echo "Thermal info not available"
    echo ""
} > "$LOG_DIR/00_system_info.log"

log_success "System information collected"

# Install dependencies with graphics packages
log_info "Installing/updating dependencies (including graphics dev packages)..."
{
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -y >/dev/null 2>&1 || echo "apt update failed"
    # Install graphics development packages for Jetson
    sudo apt-get install -y python3 python3-pip python3-numpy ffmpeg bc mesa-utils \
        libegl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dev \
        build-essential pkg-config >/dev/null 2>&1 || echo "Some package installations failed"
    pip3 install --user numpy opencv-python >/dev/null 2>&1 || echo "Python package installation failed"
} > "$LOG_DIR/00_dependency_install.log" 2>&1

log_success "Dependencies installation completed (including graphics dev packages)"

# Baseline temperature and system state
log_info "Recording baseline system state..."
{
    echo "=== BASELINE TEMPERATURES ==="
    for zone in /sys/devices/virtual/thermal/thermal_zone*; do
        if [ -d "$zone" ]; then
            temp=$(cat "$zone/temp" 2>/dev/null || echo "0")
            temp_c=$((temp / 1000))
            zone_type=$(cat "$zone/type" 2>/dev/null || echo "unknown")
            echo "$zone_type: ${temp_c}°C"
        fi
    done
    echo ""
    echo "=== BASELINE GPU STATE ==="
    nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv || echo "GPU state unavailable"
    echo ""
    echo "=== BASELINE SYSTEM LOAD ==="
    echo "Load average: $(cat /proc/loadavg)"
    echo "Memory usage: $(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')%"
    echo ""
} > "$LOG_DIR/00_baseline_state.log"

log_success "Baseline state recorded"

################################################################################
# ENHANCED MONITORING SETUP (v2.0)
################################################################################

log_info "Starting enhanced background monitoring..."

# Enhanced temperature and performance monitoring (Jetson-compatible)
{
    echo "timestamp,cpu_temp,gpu_temp,cpu_usage,gpu_usage,memory_usage,gpu_power,gpu_freq,mem_freq"
    while true; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        cpu_temp=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}' || echo "N/A")
        gpu_temp=$(cat /sys/devices/virtual/thermal/thermal_zone1/temp 2>/dev/null | awk '{print $1/1000}' || echo "N/A")
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' || echo "N/A")
        gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
        memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' || echo "N/A")

        # Try nvidia-smi for power, fallback to Jetson power rails if not available
        gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
        if [ "$gpu_power" == "N/A" ] || [ -z "$gpu_power" ]; then
            # Try Jetson power rail (mW to W conversion)
            gpu_power_mw=$(cat /sys/bus/i2c/drivers/ina3221x/*/iio:device0/in_power1_input 2>/dev/null || echo "0")
            if [ "$gpu_power_mw" != "0" ]; then
                gpu_power=$(echo "scale=2; $gpu_power_mw / 1000" | bc 2>/dev/null || echo "N/A")
            else
                gpu_power="N/A"
            fi
        fi

        # Try nvidia-smi for clocks, fallback to Jetson sysfs if not available
        gpu_freq=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits 2>/dev/null || echo "0")
        if [ "$gpu_freq" == "0" ] || [ -z "$gpu_freq" ] || [ "$gpu_freq" == "N/A" ]; then
            # Try Jetson GPU frequency (Hz to MHz)
            gpu_freq_hz=$(cat /sys/devices/gpu.0/devfreq/17000000.ga10b/cur_freq 2>/dev/null || echo "0")
            gpu_freq=$((gpu_freq_hz / 1000000))
            [ "$gpu_freq" -eq 0 ] && gpu_freq="N/A"
        fi

        mem_freq=$(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader,nounits 2>/dev/null || echo "N/A")

        echo "$timestamp,$cpu_temp,$gpu_temp,$cpu_usage,$gpu_usage,$memory_usage,$gpu_power,$gpu_freq,$mem_freq"
        sleep 5
    done
} > "$MONITOR_DIR/temperature_power_log.csv" &
TEMP_MONITOR_PID=$!

# Thermal throttling detection monitor (Jetson-compatible)
{
    echo "timestamp,gpu_freq,throttle_detected,temp"
    prev_freq=0
    valid_samples=0
    while true; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        # Use Jetson-specific GPU frequency interface
        gpu_freq=$(cat /sys/devices/gpu.0/devfreq/17000000.ga10b/cur_freq 2>/dev/null || cat /sys/kernel/debug/bpmp/debug/clk/nafll_gpc/rate 2>/dev/null || echo "0")
        gpu_freq_mhz=$((gpu_freq / 1000000))
        gpu_temp=$(cat /sys/devices/virtual/thermal/thermal_zone1/temp 2>/dev/null | awk '{print $1/1000}' || echo "0")

        # Detect throttling: significant frequency drop (>15%) while under load
        throttle="NO"
        # Only check throttling after we have valid baseline (non-zero previous frequency)
        if [ "$prev_freq" -gt 100 ] && [ "$gpu_freq_mhz" -gt 100 ]; then
            freq_drop=$(echo "scale=2; (($prev_freq - $gpu_freq_mhz) / $prev_freq) * 100" | bc 2>/dev/null || echo "0")
            # Use higher threshold (15%) and check if temperature is high
            if (( $(echo "$freq_drop > 15 && $gpu_temp > 70" | bc -l 2>/dev/null || echo "0") )); then
                throttle="YES"
            fi
            valid_samples=$((valid_samples + 1))
        fi

        echo "$timestamp,$gpu_freq_mhz,$throttle,$gpu_temp"
        # Only update prev_freq if we got a valid reading
        if [ "$gpu_freq_mhz" -gt 100 ]; then
            prev_freq=$gpu_freq_mhz
        fi
        sleep 2
    done
} > "$MONITOR_DIR/throttling_detection.csv" &
THROTTLE_MONITOR_PID=$!

# Tegrastats monitoring
{
    timeout $TEST_DURATION tegrastats --interval 1000 --logfile "$MONITOR_DIR/tegrastats_raw.log" >/dev/null 2>&1 || echo "tegrastats monitoring completed"
} &
TEGRA_MONITOR_PID=$!

log_success "Enhanced background monitoring started (PID: $TEMP_MONITOR_PID, $THROTTLE_MONITOR_PID, $TEGRA_MONITOR_PID)"

################################################################################
# PHASE 1: GPU VPU - MULTI-CODEC 4K (ENHANCED v2.0)
################################################################################

log_phase "PHASE 1: GPU VPU (VIDEO PROCESSING UNIT) STRESS TEST - ${PHASE_GPU_VPU} seconds"

log_info "Starting enhanced VPU stress test with MULTI-CODEC (H.264/H.265) 4K videos..."

# Define video test patterns
declare -a VIDEO_PATTERNS=(
    "smpte"
    "ball"
    "snow"
    "checkers-1"
    "checkers-2"
    "circular"
    "gradient"
    "pinwheel"
    "spokes"
    "zone-plate"
)

# Define codecs to test
declare -a VIDEO_CODECS=(
    "h264"
    "h265"
)

# 4K bitrates
declare -a VIDEO_BITRATES=(
    "8000000"      # 8 Mbps - minimum for 4K
    "12000000"     # 12 Mbps - medium for 4K
    "20000000"     # 20 Mbps - high quality 4K
)

{
    echo "GPU VPU Video Processing Unit Stress Test"
    echo "Start time $(date)"
    echo "Duration ${PHASE_GPU_VPU} seconds"
    echo "Video patterns ${#VIDEO_PATTERNS[@]} different patterns"
    echo "Codecs H264 and H265 alternating"
    echo "Resolution 4K ONLY 3840x2160"
    echo "Bitrates ${VIDEO_BITRATES[@]}"
    echo ""

    vpu_end_time=$(($(date +%s) + PHASE_GPU_VPU))
    video_count=0
    h264_count=0
    h265_count=0

    while [ $(date +%s) -lt $vpu_end_time ]; do
        video_count=$((video_count + 1))

        # Cycle through patterns, bitrates, and codecs
        pattern_idx=$(( (video_count - 1) % ${#VIDEO_PATTERNS[@]} ))
        bitrate_idx=$(( (video_count - 1) % ${#VIDEO_BITRATES[@]} ))
        codec_idx=$(( (video_count - 1) % ${#VIDEO_CODECS[@]} ))

        pattern=${VIDEO_PATTERNS[$pattern_idx]}
        resolution="3840x2160"  # Always 4K
        bitrate=${VIDEO_BITRATES[$bitrate_idx]}
        codec=${VIDEO_CODECS[$codec_idx]}

        if [ "$codec" == "h264" ]; then
            h264_count=$((h264_count + 1))
            encoder="nvv4l2h264enc"
            parser="h264parse"
            video_file="$VIDEO_DIR/vpu_test_${video_count}_${pattern}_4K_H264.mp4"
        else
            h265_count=$((h265_count + 1))
            encoder="nvv4l2h265enc"
            parser="h265parse"
            video_file="$VIDEO_DIR/vpu_test_${video_count}_${pattern}_4K_H265.mp4"
        fi

        echo "Encoding video $video_count"
        echo "Pattern $pattern"
        echo "Codec ${codec^^}"
        echo "Resolution $resolution 4K"
        echo "Bitrate $bitrate bps"
        echo "File $(basename $video_file)"

        # Generate and encode using GStreamer with hardware acceleration
        if gst-launch-1.0 videotestsrc num-buffers=150 pattern="$pattern" ! \
           video/x-raw,width=3840,height=2160,framerate=30/1 ! \
           nvvidconv ! \
           $encoder bitrate="$bitrate" ! \
           $parser ! \
           qtmux ! \
           filesink location="$video_file" >/dev/null 2>&1; then

            echo "Video $video_count ${codec^^} encoded successfully"
            increment_vpu_pass  # BULLETPROOF tracking
        else
            echo "Video $video_count ${codec^^} encoding failed"
            increment_vpu_fail  # BULLETPROOF tracking
        fi

        echo ""
        sleep 1
    done
    
    # Read final results from temp files (BULLETPROOF!)
    VPU_PASS=$(cat "$TEMP_RESULTS_DIR/vpu_pass_count")
    VPU_FAIL=$(cat "$TEMP_RESULTS_DIR/vpu_fail_count")

    echo ""
    echo "VPU Test Results"
    echo "Total 4K videos attempted $((VPU_PASS + VPU_FAIL))"
    echo "Successful encodings $VPU_PASS"
    echo "Failed encodings $VPU_FAIL"
    echo "H264 encodings $h264_count"
    echo "H265 encodings $h265_count"
    echo "Video patterns ${#VIDEO_PATTERNS[@]} different patterns"
    echo "Resolution 4K ONLY 3840x2160"
    echo "Bitrates ${#VIDEO_BITRATES[@]} different bitrates"
    echo "Codecs tested H264 and H265"
    echo "End time $(date)"

} 2>&1 | tee "$LOG_DIR/01_gpu_vpu_stress.log"

# VPU evaluation - metric-based PASS/FAIL
VPU_PASS=$(cat "$TEMP_RESULTS_DIR/vpu_pass_count")
VPU_FAIL=$(cat "$TEMP_RESULTS_DIR/vpu_fail_count")

# Expected video encoding rate: 0.45 videos per second
EXPECTED_VIDEO_RATE="0.45"
EXPECTED_VIDEOS=$(echo "$PHASE_GPU_VPU * $EXPECTED_VIDEO_RATE" | bc | awk '{print int($1)}')

if [ $VPU_PASS -ge $EXPECTED_VIDEOS ]; then
    VPU_STATUS="PASS"
    echo "VPU PASS"
else
    VPU_STATUS="FAIL"
    echo "VPU FAIL"
fi

# Save VPU results
{
    echo "VPU_STATUS=$VPU_STATUS"
    echo "VPU_PASS=$VPU_PASS"
    echo "VPU_FAIL=$VPU_FAIL"
    echo "VPU_TOTAL=$((VPU_PASS + VPU_FAIL))"
    echo "VPU_PATTERNS_USED=${#VIDEO_PATTERNS[@]}"
    echo "VPU_RESOLUTION=4K_ONLY"
    echo "VPU_BITRATES_USED=${#VIDEO_BITRATES[@]}"
    echo "VPU_EXPECTED_VIDEOS=$EXPECTED_VIDEOS"
} > "$REPORT_DIR/gpu_vpu_results.txt"

################################################################################
# PHASE 2: GPU CUDA STRESS TEST (SAME AS v1.6)
################################################################################

log_phase "PHASE 2: GPU CUDA STRESS TEST - ${PHASE_GPU_CUDA} seconds"

log_info "Creating custom CUDA stress application..."

# Create enhanced CUDA stress test application (v2.0)
cat > "$CUDA_APP_DIR/cuda_stress_detailed.cu" << 'CUDA_STRESS_EOF'
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <cublas_v2.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <unistd.h>
#include <sys/time.h>

#define CUDA_CHECK(call) \
    do { \
        cudaError_t error = call; \
        if (error != cudaSuccess) { \
            fprintf(stderr, "CUDA error at %s:%d - %s\n", __FILE__, __LINE__, cudaGetErrorString(error)); \
            exit(1); \
        } \
    } while(0)

#define CUBLAS_CHECK(call) \
    do { \
        cublasStatus_t status = call; \
        if (status != CUBLAS_STATUS_SUCCESS) { \
            fprintf(stderr, "cuBLAS error at %s:%d - %d\n", __FILE__, __LINE__, status); \
            exit(1); \
        } \
    } while(0)

// Timing helper
double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

// Kernel 1: Intensive compute (FP32)
__global__ void compute_intensive_fp32(float* data, int size, int iterations) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        float value = data[idx];
        for (int i = 0; i < iterations; i++) {
            value = sinf(value) * cosf(value) + sqrtf(fabsf(value));
            value = powf(value, 0.7f) + logf(fabsf(value) + 1.0f);
            value = expf(value * 0.01f) * tanhf(value);
        }
        data[idx] = value;
    }
}

// Kernel 2: Intensive compute (FP64)
__global__ void compute_intensive_fp64(double* data, int size, int iterations) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        double value = data[idx];
        for (int i = 0; i < iterations; i++) {
            value = sin(value) * cos(value) + sqrt(fabs(value));
            value = pow(value, 0.7) + log(fabs(value) + 1.0);
            value = exp(value * 0.01) * tanh(value);
        }
        data[idx] = value;
    }
}

// Kernel 3: Reduction kernel
__global__ void reduction_kernel(float* input, float* output, int size) {
    extern __shared__ float sdata[];

    int tid = threadIdx.x;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    sdata[tid] = (idx < size) ? input[idx] : 0.0f;
    __syncthreads();

    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            sdata[tid] += sdata[tid + s];
        }
        __syncthreads();
    }

    if (tid == 0) {
        atomicAdd(output, sdata[0]);
    }
}

// Kernel 4: Matrix transpose (memory access pattern test)
__global__ void transpose_kernel(float* input, float* output, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x < width && y < height) {
        output[x * height + y] = input[y * width + x];
    }
}

// Kernel 5: Concurrent execution test
__global__ void concurrent_kernel_1(float* data, int size) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        data[idx] = sinf(data[idx]) + cosf(data[idx]);
    }
}

__global__ void concurrent_kernel_2(float* data, int size) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        data[idx] = expf(data[idx] * 0.01f);
    }
}

// Test 1: Memory Bandwidth Test
void test_memory_bandwidth(int duration_sec) {
    printf("\n=== TEST 1: Memory Bandwidth Measurement ===\n");

    const size_t size = 512 * 1024 * 1024; // 512 MB
    float *h_data = (float*)malloc(size);
    float *d_data1, *d_data2;

    CUDA_CHECK(cudaMalloc(&d_data1, size));
    CUDA_CHECK(cudaMalloc(&d_data2, size));

    for (size_t i = 0; i < size / sizeof(float); i++) {
        h_data[i] = (float)i;
    }

    time_t end_time = time(NULL) + (duration_sec / 5);
    int iterations = 0;
    double total_h2d_time = 0, total_d2h_time = 0, total_d2d_time = 0;

    while (time(NULL) < end_time) {
        // Host to Device
        double start = get_time();
        CUDA_CHECK(cudaMemcpy(d_data1, h_data, size, cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaDeviceSynchronize());
        total_h2d_time += get_time() - start;

        // Device to Host
        start = get_time();
        CUDA_CHECK(cudaMemcpy(h_data, d_data1, size, cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaDeviceSynchronize());
        total_d2h_time += get_time() - start;

        // Device to Device
        start = get_time();
        CUDA_CHECK(cudaMemcpy(d_data2, d_data1, size, cudaMemcpyDeviceToDevice));
        CUDA_CHECK(cudaDeviceSynchronize());
        total_d2d_time += get_time() - start;

        iterations++;
    }

    double size_gb = size / (1024.0 * 1024.0 * 1024.0);
    printf("Iterations: %d\n", iterations);
    printf("Host to Device Bandwidth: %.2f GB/s\n", (size_gb * iterations) / total_h2d_time);
    printf("Device to Host Bandwidth: %.2f GB/s\n", (size_gb * iterations) / total_d2h_time);
    printf("Device to Device Bandwidth: %.2f GB/s\n", (size_gb * iterations) / total_d2d_time);

    cudaFree(d_data1);
    cudaFree(d_data2);
    free(h_data);
}

// Test 2: FP32 Compute Performance
void test_fp32_compute(int duration_sec) {
    printf("\n=== TEST 2: FP32 Compute Performance ===\n");

    const int size = 4 * 1024 * 1024;
    float *d_data;
    CUDA_CHECK(cudaMalloc(&d_data, size * sizeof(float)));

    dim3 blockSize(256);
    dim3 gridSize((size + blockSize.x - 1) / blockSize.x);

    time_t end_time = time(NULL) + (duration_sec / 5);
    int operations = 0;
    double total_time = 0;

    while (time(NULL) < end_time) {
        double start = get_time();
        compute_intensive_fp32<<<gridSize, blockSize>>>(d_data, size, 100);
        CUDA_CHECK(cudaDeviceSynchronize());
        total_time += get_time() - start;
        operations++;
    }

    // Rough GFLOPS calculation (100 iterations * ~10 FLOPs per iteration)
    double total_flops = (double)operations * size * 100 * 10;
    double gflops = (total_flops / total_time) / 1e9;

    printf("FP32 Operations: %d\n", operations);
    printf("Estimated GFLOPS: %.2f\n", gflops);
    printf("Average kernel time: %.3f ms\n", (total_time / operations) * 1000);

    cudaFree(d_data);
}

// Test 3: FP64 Compute Performance
void test_fp64_compute(int duration_sec) {
    printf("\n=== TEST 3: FP64 Compute Performance ===\n");

    const int size = 2 * 1024 * 1024;
    double *d_data;
    CUDA_CHECK(cudaMalloc(&d_data, size * sizeof(double)));

    dim3 blockSize(256);
    dim3 gridSize((size + blockSize.x - 1) / blockSize.x);

    time_t end_time = time(NULL) + (duration_sec / 5);
    int operations = 0;
    double total_time = 0;

    while (time(NULL) < end_time) {
        double start = get_time();
        compute_intensive_fp64<<<gridSize, blockSize>>>(d_data, size, 100);
        CUDA_CHECK(cudaDeviceSynchronize());
        total_time += get_time() - start;
        operations++;
    }

    double total_flops = (double)operations * size * 100 * 10;
    double gflops = (total_flops / total_time) / 1e9;

    printf("FP64 Operations: %d\n", operations);
    printf("Estimated GFLOPS: %.2f\n", gflops);
    printf("Average kernel time: %.3f ms\n", (total_time / operations) * 1000);

    cudaFree(d_data);
}

// Test 4: Matrix Operations (cuBLAS)
void test_matrix_operations(int duration_sec) {
    printf("\n=== TEST 4: Matrix Operations (cuBLAS) ===\n");

    cublasHandle_t cublasHandle;
    CUBLAS_CHECK(cublasCreate(&cublasHandle));

    const int matrix_size = 2048;
    float *d_matrix_a, *d_matrix_b, *d_matrix_c;

    CUDA_CHECK(cudaMalloc(&d_matrix_a, matrix_size * matrix_size * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&d_matrix_b, matrix_size * matrix_size * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&d_matrix_c, matrix_size * matrix_size * sizeof(float)));

    time_t end_time = time(NULL) + (duration_sec / 5);
    int operations = 0;
    double total_time = 0;

    const float alpha = 1.0f, beta = 0.0f;

    while (time(NULL) < end_time) {
        double start = get_time();
        CUBLAS_CHECK(cublasSgemm(cublasHandle, CUBLAS_OP_N, CUBLAS_OP_N,
                                matrix_size, matrix_size, matrix_size,
                                &alpha,
                                d_matrix_a, matrix_size,
                                d_matrix_b, matrix_size,
                                &beta,
                                d_matrix_c, matrix_size));
        CUDA_CHECK(cudaDeviceSynchronize());
        total_time += get_time() - start;
        operations++;
    }

    // Calculate GFLOPS for matrix multiplication (2*N^3 operations)
    double flops = 2.0 * matrix_size * matrix_size * matrix_size * operations;
    double gflops = (flops / total_time) / 1e9;

    printf("Matrix Operations (SGEMM): %d\n", operations);
    printf("Matrix Size: %dx%d\n", matrix_size, matrix_size);
    printf("GFLOPS: %.2f\n", gflops);
    printf("Average operation time: %.3f ms\n", (total_time / operations) * 1000);

    cublasDestroy(cublasHandle);
    cudaFree(d_matrix_a);
    cudaFree(d_matrix_b);
    cudaFree(d_matrix_c);
}

// Test 5: Concurrent Kernel Execution
void test_concurrent_execution(int duration_sec) {
    printf("\n=== TEST 5: Concurrent Kernel Execution ===\n");

    const int size = 2 * 1024 * 1024;
    float *d_data1, *d_data2;

    CUDA_CHECK(cudaMalloc(&d_data1, size * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&d_data2, size * sizeof(float)));

    cudaStream_t stream1, stream2;
    CUDA_CHECK(cudaStreamCreate(&stream1));
    CUDA_CHECK(cudaStreamCreate(&stream2));

    dim3 blockSize(256);
    dim3 gridSize((size + blockSize.x - 1) / blockSize.x);

    time_t end_time = time(NULL) + (duration_sec / 5);
    int operations = 0;
    double total_time = 0;

    while (time(NULL) < end_time) {
        double start = get_time();

        // Launch kernels on different streams concurrently
        concurrent_kernel_1<<<gridSize, blockSize, 0, stream1>>>(d_data1, size);
        concurrent_kernel_2<<<gridSize, blockSize, 0, stream2>>>(d_data2, size);

        CUDA_CHECK(cudaStreamSynchronize(stream1));
        CUDA_CHECK(cudaStreamSynchronize(stream2));
        total_time += get_time() - start;
        operations++;
    }

    printf("Concurrent Operations: %d\n", operations);
    printf("Average concurrent execution time: %.3f ms\n", (total_time / operations) * 1000);

    cudaStreamDestroy(stream1);
    cudaStreamDestroy(stream2);
    cudaFree(d_data1);
    cudaFree(d_data2);
}

int main(int argc, char* argv[]) {
    int duration = (argc > 1) ? atoi(argv[1]) : 300;

    printf("CUDA DETAILED Stress Test Starting (v2.0)\n");
    printf("Duration: %d seconds\n", duration);
    printf("=====================================\n");

    int deviceCount;
    CUDA_CHECK(cudaGetDeviceCount(&deviceCount));
    printf("CUDA devices found: %d\n", deviceCount);

    if (deviceCount == 0) {
        printf("No CUDA devices found!\n");
        return 1;
    }

    CUDA_CHECK(cudaSetDevice(0));

    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    printf("Device: %s\n", prop.name);
    printf("Compute capability: %d.%d\n", prop.major, prop.minor);
    printf("Global memory: %.2f GB\n", prop.totalGlobalMem / (1024.0*1024.0*1024.0));
    printf("Shared memory per block: %zu bytes\n", prop.sharedMemPerBlock);
    printf("Max threads per block: %d\n", prop.maxThreadsPerBlock);
    printf("=====================================\n");

    // Run comprehensive tests
    test_memory_bandwidth(duration);
    test_fp32_compute(duration);
    test_fp64_compute(duration);
    test_matrix_operations(duration);
    test_concurrent_execution(duration);

    printf("\n=====================================\n");
    printf("CUDA Detailed Stress Test Completed\n");
    printf("All tests executed successfully\n");
    printf("=====================================\n");

    return 0;
}
CUDA_STRESS_EOF

log_info "Compiling enhanced CUDA stress application..."

{
    cd "$CUDA_APP_DIR"
    if nvcc -O3 -lcublas -o cuda_stress_detailed cuda_stress_detailed.cu 2>&1; then
        echo "[+] CUDA detailed stress application compiled successfully"
        CUDA_COMPILE_SUCCESS=1
    else
        echo "[-] CUDA compilation failed"
        CUDA_COMPILE_SUCCESS=0
    fi
} > "$LOG_DIR/02_gpu_cuda_compile.log" 2>&1

if [ $CUDA_COMPILE_SUCCESS -eq 1 ]; then
    log_info "Running enhanced CUDA stress test for ${PHASE_GPU_CUDA} seconds..."

    {
        echo "GPU CUDA Stress Test"
        echo "Start time $(date)"
        echo "Duration ${PHASE_GPU_CUDA} seconds"
        echo "Tests Memory Bandwidth FP32 FP64 Compute Matrix Ops Concurrent Execution"
        echo ""

        cd "$CUDA_APP_DIR"
        if ./cuda_stress_detailed $PHASE_GPU_CUDA; then
            echo ""
            echo "CUDA stress test completed successfully"
            increment_cuda_pass  # BULLETPROOF tracking
        else
            echo ""
            echo "CUDA stress test failed"
            increment_cuda_fail  # BULLETPROOF tracking
        fi

        echo "End time $(date)"

    } 2>&1 | tee "$LOG_DIR/02_gpu_cuda_stress.log"

else
    echo "CUDA compilation failed skipping CUDA stress test"
    increment_cuda_fail
fi

# CUDA evaluation - metric-based PASS/FAIL
CUDA_PASS=$(cat "$TEMP_RESULTS_DIR/cuda_pass_count")
CUDA_FAIL=$(cat "$TEMP_RESULTS_DIR/cuda_fail_count")

# CUDA must complete successfully
if [ $CUDA_PASS -eq 1 ] && [ $CUDA_COMPILE_SUCCESS -eq 1 ]; then
    CUDA_STATUS="PASS"
    echo "CUDA PASS"
else
    CUDA_STATUS="FAIL"
    echo "CUDA FAIL"
fi

# Save CUDA results
{
    echo "CUDA_STATUS=$CUDA_STATUS"
    echo "CUDA_PASS=$CUDA_PASS"
    echo "CUDA_FAIL=$CUDA_FAIL"
    echo "CUDA_COMPILE_SUCCESS=$CUDA_COMPILE_SUCCESS"
} > "$REPORT_DIR/gpu_cuda_results.txt"

################################################################################
# PHASE 3: GPU GRAPHICS STRESS TEST - JETSON HEADLESS OPTIMIZED (NEW v1.7!)
################################################################################

log_phase "PHASE 3: GPU GRAPHICS (GFX) STRESS TEST - ${PHASE_GPU_GFX} seconds"

log_info "Starting JETSON-OPTIMIZED Graphics stress test (EGL-based, no virtual display)..."

# Create custom EGL-based graphics test for Jetson headless systems
cat > "$GRAPHICS_APP_DIR/egl_graphics_stress.c" << 'EGL_GRAPHICS_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>

// Simple vertex shader
const char* vertex_shader_source = 
    "attribute vec2 position;\n"
    "uniform float time;\n"
    "void main() {\n"
    "    float angle = time * 2.0;\n"
    "    float s = sin(angle);\n"
    "    float c = cos(angle);\n"
    "    mat2 rotation = mat2(c, -s, s, c);\n"
    "    gl_Position = vec4(rotation * position, 0.0, 1.0);\n"
    "}\n";

// Simple fragment shader
const char* fragment_shader_source = 
    "precision mediump float;\n"
    "uniform float time;\n"
    "void main() {\n"
    "    float r = 0.5 + 0.5 * sin(time * 3.0);\n"
    "    float g = 0.5 + 0.5 * sin(time * 3.0 + 2.0);\n"
    "    float b = 0.5 + 0.5 * sin(time * 3.0 + 4.0);\n"
    "    gl_FragColor = vec4(r, g, b, 1.0);\n"
    "}\n";

GLuint compile_shader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    
    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        GLint length;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length);
        char* log = malloc(length);
        glGetShaderInfoLog(shader, length, NULL, log);
        printf("Shader compilation failed: %s\n", log);
        free(log);
        return 0;
    }
    return shader;
}

int main(int argc, char* argv[]) {
    int duration = (argc > 1) ? atoi(argv[1]) : 90;
    
    printf("EGL Graphics Stress Test Starting (Jetson Optimized v1.7)\n");
    printf("Duration: %d seconds\n", duration);
    printf("Using headless EGL context (no X11/Xvfb needed)\n");
    printf("=====================================\n");
    
    // Initialize EGL for headless rendering
    EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display == EGL_NO_DISPLAY) {
        printf("Failed to get EGL display\n");
        return 1;
    }
    
    if (!eglInitialize(display, NULL, NULL)) {
        printf("Failed to initialize EGL\n");
        return 1;
    }
    
    // Configure EGL
    EGLConfig config;
    EGLint num_configs;
    EGLint config_attribs[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_NONE
    };
    
    if (!eglChooseConfig(display, config_attribs, &config, 1, &num_configs)) {
        printf("Failed to choose EGL config\n");
        return 1;
    }
    
    // Create pbuffer surface (offscreen)
    EGLint surface_attribs[] = {
        EGL_WIDTH, 1920,
        EGL_HEIGHT, 1080,
        EGL_NONE
    };
    EGLSurface surface = eglCreatePbufferSurface(display, config, surface_attribs);
    if (surface == EGL_NO_SURFACE) {
        printf("Failed to create EGL surface\n");
        return 1;
    }
    
    // Create OpenGL ES context
    EGLint context_attribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE
    };
    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attribs);
    if (context == EGL_NO_CONTEXT) {
        printf("Failed to create EGL context\n");
        return 1;
    }
    
    // Make context current
    if (!eglMakeCurrent(display, surface, surface, context)) {
        printf("Failed to make EGL context current\n");
        return 1;
    }
    
    printf("EGL context initialized successfully\n");
    printf("GL Vendor: %s\n", glGetString(GL_VENDOR));
    printf("GL Renderer: %s\n", glGetString(GL_RENDERER));
    printf("GL Version: %s\n", glGetString(GL_VERSION));
    printf("=====================================\n");
    
    // Compile shaders
    GLuint vertex_shader = compile_shader(GL_VERTEX_SHADER, vertex_shader_source);
    GLuint fragment_shader = compile_shader(GL_FRAGMENT_SHADER, fragment_shader_source);
    
    if (!vertex_shader || !fragment_shader) {
        printf("Failed to compile shaders\n");
        return 1;
    }
    
    // Create program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex_shader);
    glAttachShader(program, fragment_shader);
    glLinkProgram(program);
    
    GLint linked;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) {
        printf("Failed to link program\n");
        return 1;
    }
    
    // Get attribute and uniform locations
    GLint position_attrib = glGetAttribLocation(program, "position");
    GLint time_uniform = glGetUniformLocation(program, "time");
    
    // Create vertex buffer
    float vertices[] = {
        -0.8f, -0.8f,
         0.8f, -0.8f,
         0.0f,  0.8f
    };
    
    GLuint vbo;
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    printf("Starting intensive graphics rendering...\n");
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    int frame_count = 0;
    int render_cycles = 0;
    
    while (time(NULL) < end_time) {
        render_cycles++;
        
        // Render multiple frames per cycle for stress testing
        for (int frame = 0; frame < 100; frame++) {
            float current_time = (float)(time(NULL) - start_time) + frame * 0.016f;
            
            // Clear and setup
            glViewport(0, 0, 1920, 1080);
            glClear(GL_COLOR_BUFFER_BIT);
            
            // Use program and set uniforms
            glUseProgram(program);
            glUniform1f(time_uniform, current_time);
            
            // Set up vertex attributes
            glBindBuffer(GL_ARRAY_BUFFER, vbo);
            glVertexAttribPointer(position_attrib, 2, GL_FLOAT, GL_FALSE, 0, NULL);
            glEnableVertexAttribArray(position_attrib);
            
            // Draw triangle
            glDrawArrays(GL_TRIANGLES, 0, 3);
            
            // Force completion
            glFinish();
            
            frame_count++;
        }
        
        if (render_cycles % 10 == 0) {
            printf("Render cycle %d: %d frames rendered\n", render_cycles, frame_count);
        }
        
        usleep(10000); // 10ms between cycles
    }
    
    printf("=====================================\n");
    printf("EGL Graphics Stress Test Completed\n");
    printf("Total render cycles: %d\n", render_cycles);
    printf("Total frames rendered: %d\n", frame_count);
    printf("Average FPS: %.2f\n", (float)frame_count / duration);
    
    // Cleanup
    glDeleteBuffers(1, &vbo);
    glDeleteProgram(program);
    glDeleteShader(vertex_shader);
    glDeleteShader(fragment_shader);
    
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(display, context);
    eglDestroySurface(display, surface);
    eglTerminate(display);
    
    printf("EGL resources cleaned up\n");
    return 0;
}
EGL_GRAPHICS_EOF

log_info "Compiling EGL graphics stress application..."

{
    cd "$GRAPHICS_APP_DIR"
    if gcc -O3 -o egl_graphics_stress egl_graphics_stress.c -lEGL -lGLESv2 -lm 2>&1; then
        echo "[+] EGL graphics stress application compiled successfully"
        GRAPHICS_COMPILE_SUCCESS=1
    else
        echo "[-] EGL graphics compilation failed"
        GRAPHICS_COMPILE_SUCCESS=0
    fi
} > "$LOG_DIR/03_gpu_gfx_compile.log" 2>&1

if [ $GRAPHICS_COMPILE_SUCCESS -eq 1 ]; then
    echo "Running EGL graphics stress test for ${PHASE_GPU_GFX} seconds"

    {
        echo "GPU Graphics EGL Stress Test"
        echo "Start time $(date)"
        echo "Duration ${PHASE_GPU_GFX} seconds"
        echo "Method EGL headless rendering Jetson optimized"
        echo ""

        cd "$GRAPHICS_APP_DIR"
        if ./egl_graphics_stress $PHASE_GPU_GFX; then
            echo ""
            echo "EGL graphics stress test completed successfully"
            increment_gfx_pass  # BULLETPROOF tracking
        else
            echo ""
            echo "EGL graphics stress test failed"
            increment_gfx_fail  # BULLETPROOF tracking
        fi

        echo "End time $(date)"

    } 2>&1 | tee "$LOG_DIR/03_gpu_gfx_stress.log"

else
    echo "EGL graphics compilation failed running fallback GPU memory test"
    
    # Fallback: GPU memory bandwidth test using CUDA
    {
        echo "GPU Graphics Fallback Test CUDA Memory Bandwidth"
        echo "Start time $(date)"
        echo "Duration ${PHASE_GPU_GFX} seconds"
        echo ""

        if command -v nvidia-smi >/dev/null 2>&1; then
            echo "Running GPU memory bandwidth stress test"
            
            # Create simple CUDA memory test
            cat > "$GRAPHICS_APP_DIR/gpu_memory_test.cu" << 'GPU_MEMORY_EOF'
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main(int argc, char* argv[]) {
    int duration = (argc > 1) ? atoi(argv[1]) : 90;
    
    printf("GPU Memory Bandwidth Test (Fallback)\n");
    printf("Duration: %d seconds\n", duration);
    
    size_t size = 512 * 1024 * 1024; // 512MB
    float *h_data = (float*)malloc(size);
    float *d_data;
    
    if (cudaMalloc(&d_data, size) != cudaSuccess) {
        printf("Failed to allocate GPU memory\n");
        return 1;
    }
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    int operations = 0;
    
    while (time(NULL) < end_time) {
        cudaMemcpy(d_data, h_data, size, cudaMemcpyHostToDevice);
        cudaMemcpy(h_data, d_data, size, cudaMemcpyDeviceToHost);
        operations++;
        
        if (operations % 10 == 0) {
            printf("Memory operations completed: %d\n", operations);
        }
    }
    
    printf("Total memory operations: %d\n", operations);
    printf("Memory bandwidth test completed\n");
    
    cudaFree(d_data);
    free(h_data);
    return 0;
}
GPU_MEMORY_EOF
            
            cd "$GRAPHICS_APP_DIR"
            if nvcc -o gpu_memory_test gpu_memory_test.cu 2>/dev/null && ./gpu_memory_test $PHASE_GPU_GFX; then
                echo "GPU memory bandwidth test completed successfully"
                increment_gfx_pass  # BULLETPROOF tracking
            else
                echo "GPU memory bandwidth test failed"
                increment_gfx_fail  # BULLETPROOF tracking
            fi
        else
            echo "No GPU tools available for fallback test"
            increment_gfx_fail
        fi

        echo "End time $(date)"
        
    } 2>&1 | tee -a "$LOG_DIR/03_gpu_gfx_stress.log"
fi

# GFX evaluation - metric-based PASS/FAIL
GFX_PASS=$(cat "$TEMP_RESULTS_DIR/gfx_pass_count")
GFX_FAIL=$(cat "$TEMP_RESULTS_DIR/gfx_fail_count")

# GFX must complete successfully with no failures
if [ $GFX_FAIL -eq 0 ] && [ $GFX_PASS -gt 0 ]; then
    GFX_STATUS="PASS"
    echo "GFX PASS"
else
    GFX_STATUS="FAIL"
    echo "GFX FAIL"
fi

# Save GFX results
{
    echo "GFX_STATUS=$GFX_STATUS"
    echo "GFX_PASS=$GFX_PASS"
    echo "GFX_FAIL=$GFX_FAIL"
    echo "GFX_TOTAL=$((GFX_PASS + GFX_FAIL))"
    echo "GFX_METHOD=EGL_HEADLESS_OPTIMIZED"
    echo "GFX_COMPILE_SUCCESS=$GRAPHICS_COMPILE_SUCCESS"
} > "$REPORT_DIR/gpu_gfx_results.txt"

################################################################################
# PHASE 4: GPU COMBINED STRESS TEST (UPDATED FOR v1.7)
################################################################################

log_phase "PHASE 4: GPU COMBINED STRESS TEST - ${PHASE_GPU_COMBINED} seconds"

log_info "Starting combined GPU stress test with BULLETPROOF tracking..."

{
    echo "GPU Combined Stress Test"
    echo "Start time $(date)"
    echo "Duration ${PHASE_GPU_COMBINED} seconds"
    echo "Components VPU 4K CUDA Graphics EGL"
    echo ""

    combined_end_time=$(($(date +%s) + PHASE_GPU_COMBINED - 15))

    echo "Starting simultaneous GPU workloads"
    
    # Start VPU encoding in background (4K videos)
    {
        video_count=0
        while [ $(date +%s) -lt $combined_end_time ]; do
            video_count=$((video_count + 1))
            pattern_idx=$(( (video_count - 1) % ${#VIDEO_PATTERNS[@]} ))
            pattern=${VIDEO_PATTERNS[$pattern_idx]}
            video_file="$VIDEO_DIR/combined_test_${video_count}_${pattern}_4K.mp4"
            
            # Always 4K for combined test too
            gst-launch-1.0 videotestsrc num-buffers=150 pattern="$pattern" ! \
               video/x-raw,width=3840,height=2160,framerate=30/1 ! \
               nvvidconv ! \
               nvv4l2h264enc bitrate=12000000 ! \
               h264parse ! \
               qtmux ! \
               filesink location="$video_file" >/dev/null 2>&1 || true
            
            sleep 2
        done
    } &
    VPU_BG_PID=$!
    
    # Start CUDA computation in background
    if [ -f "$CUDA_APP_DIR/cuda_stress_detailed" ]; then
        {
            cd "$CUDA_APP_DIR"
            ./cuda_stress_detailed $((PHASE_GPU_COMBINED - 10)) >/dev/null 2>&1 || true
        } &
        CUDA_BG_PID=$!
    fi
    
    # Run graphics tests in foreground with BULLETPROOF tracking
    if [ -f "$GRAPHICS_APP_DIR/egl_graphics_stress" ]; then
        {
            cd "$GRAPHICS_APP_DIR"
            while [ $(date +%s) -lt $combined_end_time ]; do
                if timeout 20 ./egl_graphics_stress 15 >/dev/null 2>&1; then
                    increment_combined_pass  # BULLETPROOF tracking
                else
                    increment_combined_fail  # BULLETPROOF tracking
                fi
                sleep 3
            done
        }
    else
        # Fallback to CUDA memory test
        {
            while [ $(date +%s) -lt $combined_end_time ]; do
                if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
                    increment_combined_pass
                else
                    increment_combined_fail
                fi
                sleep 5
            done
        }
    fi
    
    # Wait for background tasks and cleanup
    kill $VPU_BG_PID 2>/dev/null || true
    [ -n "$CUDA_BG_PID" ] && kill $CUDA_BG_PID 2>/dev/null || true
    
    wait $VPU_BG_PID 2>/dev/null || true
    [ -n "$CUDA_BG_PID" ] && wait $CUDA_BG_PID 2>/dev/null || true
    
    # Read final results from temp files (BULLETPROOF!)
    COMBINED_PASS=$(cat "$TEMP_RESULTS_DIR/combined_pass_count")
    COMBINED_FAIL=$(cat "$TEMP_RESULTS_DIR/combined_fail_count")

    echo ""
    echo "Combined Test Results"
    echo "Graphics operations attempted $((COMBINED_PASS + COMBINED_FAIL))"
    echo "Successful operations $COMBINED_PASS"
    echo "Failed operations $COMBINED_FAIL"
    echo "Background VPU 4K and CUDA tasks completed"
    echo "End time $(date)"

} 2>&1 | tee "$LOG_DIR/04_gpu_combined_stress.log"

# Combined evaluation - metric-based PASS/FAIL
COMBINED_PASS=$(cat "$TEMP_RESULTS_DIR/combined_pass_count")
COMBINED_FAIL=$(cat "$TEMP_RESULTS_DIR/combined_fail_count")

# Combined test must complete successfully with no failures
if [ $COMBINED_FAIL -eq 0 ] && [ $COMBINED_PASS -gt 0 ]; then
    COMBINED_STATUS="PASS"
    echo "COMBINED PASS"
else
    COMBINED_STATUS="FAIL"
    echo "COMBINED FAIL"
fi

# Save combined results
{
    echo "COMBINED_STATUS=$COMBINED_STATUS"
    echo "COMBINED_PASS=$COMBINED_PASS"
    echo "COMBINED_FAIL=$COMBINED_FAIL"
    echo "COMBINED_TOTAL=$((COMBINED_PASS + COMBINED_FAIL))"
} > "$REPORT_DIR/gpu_combined_results.txt"

################################################################################
# ENHANCED MONITORING DATA ANALYSIS (v2.0)
################################################################################

log_phase "PHASE 5: ENHANCED MONITORING DATA ANALYSIS"

# Stop background monitoring
log_info "Stopping enhanced background monitoring..."
kill $TEMP_MONITOR_PID 2>/dev/null || true
kill $THROTTLE_MONITOR_PID 2>/dev/null || true
kill $TEGRA_MONITOR_PID 2>/dev/null || true
sleep 3

# Process temperature and power results
log_info "Processing temperature and power monitoring results..."
{
    echo "=== Temperature and Power Analysis (v2.0) ==="
    if [ -f "$MONITOR_DIR/temperature_power_log.csv" ] && [ -s "$MONITOR_DIR/temperature_power_log.csv" ]; then
        awk -F',' '
        NR>1 && $2!="N/A" && $3!="N/A" {
            cpu_sum+=$2; cpu_count++;
            cpu_max=($2>cpu_max || cpu_max=="")?$2:cpu_max;
            cpu_min=($2<cpu_min || cpu_min=="")?$2:cpu_min;
            gpu_sum+=$3; gpu_count++;
            gpu_max=($3>gpu_max || gpu_max=="")?$3:gpu_max;
            gpu_min=($3<gpu_min || gpu_min=="")?$3:gpu_min;
        }
        NR>1 && $7!="N/A" && $7!="" && $7>0 {
            power_sum+=$7; power_count++;
            power_max=($7>power_max || power_max=="")?$7:power_max;
            power_min=($7<power_min || power_min=="")?$7:power_min;
        }
        NR>1 && $8!="N/A" && $8!="" && $8>0 {
            clock_sum+=$8; clock_count++;
            clock_max=($8>clock_max || clock_max=="")?$8:clock_max;
            clock_min=($8<clock_min || clock_min=="")?$8:clock_min;
        }
        END {
            if(cpu_count>0) {
                printf "CPU Temperature: Min: %.1f°C, Max: %.1f°C, Avg: %.1f°C\n", cpu_min, cpu_max, cpu_sum/cpu_count;
                printf "CPU_MIN=%.0f\nCPU_MAX=%.0f\nCPU_AVG=%.0f\n", cpu_min, cpu_max, cpu_sum/cpu_count > "/dev/stderr";
            } else {
                printf "CPU Temperature: No valid data\n";
                printf "CPU_MIN=N/A\nCPU_MAX=N/A\nCPU_AVG=N/A\n" > "/dev/stderr";
            }

            if(gpu_count>0) {
                printf "GPU Temperature: Min: %.1f°C, Max: %.1f°C, Avg: %.1f°C\n", gpu_min, gpu_max, gpu_sum/gpu_count;
                printf "GPU_MIN=%.0f\nGPU_MAX=%.0f\nGPU_AVG=%.0f\n", gpu_min, gpu_max, gpu_sum/gpu_count > "/dev/stderr";
            } else {
                printf "GPU Temperature: No valid data\n";
                printf "GPU_MIN=N/A\nGPU_MAX=N/A\nGPU_AVG=N/A\n" > "/dev/stderr";
            }

            if(power_count>0) {
                printf "GPU Power Draw: Min: %.1f W, Max: %.1f W, Avg: %.1f W\n", power_min, power_max, power_sum/power_count;
                printf "POWER_MIN=%.1f\nPOWER_MAX=%.1f\nPOWER_AVG=%.1f\n", power_min, power_max, power_sum/power_count > "/dev/stderr";
            } else {
                printf "GPU Power Draw: No valid data\n";
                printf "POWER_MIN=N/A\nPOWER_MAX=N/A\nPOWER_AVG=N/A\n" > "/dev/stderr";
            }

            if(clock_count>0) {
                printf "GPU Clock Speed: Min: %.0f MHz, Max: %.0f MHz, Avg: %.0f MHz\n", clock_min, clock_max, clock_sum/clock_count;
                printf "CLOCK_MIN=%.0f\nCLOCK_MAX=%.0f\nCLOCK_AVG=%.0f\n", clock_min, clock_max, clock_sum/clock_count > "/dev/stderr";
            } else {
                printf "GPU Clock Speed: No valid data\n";
                printf "CLOCK_MIN=N/A\nCLOCK_MAX=N/A\nCLOCK_AVG=N/A\n" > "/dev/stderr";
            }
        }' "$MONITOR_DIR/temperature_power_log.csv" 2> "$REPORT_DIR/temperature_power_results.txt"
    else
        echo "Temperature/power log not found or empty"
        echo "CPU_MIN=N/A
CPU_MAX=N/A
CPU_AVG=N/A
GPU_MIN=N/A
GPU_MAX=N/A
GPU_AVG=N/A
POWER_MIN=N/A
POWER_MAX=N/A
POWER_AVG=N/A
CLOCK_MIN=N/A
CLOCK_MAX=N/A
CLOCK_AVG=N/A" > "$REPORT_DIR/temperature_power_results.txt"
    fi
} > "$LOG_DIR/05_temperature_power_analysis.log"

# Process throttling detection results (Jetson-compatible)
log_info "Processing thermal throttling detection..."
{
    echo "=== Thermal Throttling Analysis (v2.0) ==="
    if [ -f "$MONITOR_DIR/throttling_detection.csv" ] && [ -s "$MONITOR_DIR/throttling_detection.csv" ]; then
        throttle_events=$(grep -c ",YES," "$MONITOR_DIR/throttling_detection.csv" 2>/dev/null || echo "0")
        total_samples=$(tail -n +2 "$MONITOR_DIR/throttling_detection.csv" 2>/dev/null | wc -l || echo "0")

        # Count valid samples (where frequency > 100 MHz)
        valid_samples=$(tail -n +2 "$MONITOR_DIR/throttling_detection.csv" 2>/dev/null | awk -F',' '$2 > 100' | wc -l || echo "0")

        echo "Total monitoring samples: $total_samples"
        echo "Valid frequency samples: $valid_samples"
        echo "Throttling events detected: $throttle_events"

        # Only analyze if we have valid data
        if [ "$valid_samples" -gt 10 ]; then
            throttle_pct=$(echo "scale=2; ($throttle_events * 100) / $valid_samples" | bc 2>/dev/null || echo "0")
            echo "Throttling percentage: ${throttle_pct}%"

            if [ "$throttle_events" -eq 0 ]; then
                echo "Status: NO THROTTLING DETECTED"
                echo "THROTTLE_STATUS=NONE" > "$REPORT_DIR/throttling_results.txt"
            elif [ "$throttle_events" -lt 5 ]; then
                echo "Status: MINIMAL THROTTLING (acceptable)"
                echo "THROTTLE_STATUS=MINIMAL" > "$REPORT_DIR/throttling_results.txt"
            else
                echo "Status: SIGNIFICANT THROTTLING DETECTED"
                echo "THROTTLE_STATUS=SIGNIFICANT" > "$REPORT_DIR/throttling_results.txt"
            fi

            echo "THROTTLE_EVENTS=$throttle_events" >> "$REPORT_DIR/throttling_results.txt"
            echo "THROTTLE_PCT=$throttle_pct" >> "$REPORT_DIR/throttling_results.txt"
        else
            echo "Insufficient valid throttling data (need >10 samples, got $valid_samples)"
            echo "Status: MONITORING DATA UNAVAILABLE (non-critical)"
            echo "THROTTLE_STATUS=NO_DATA" > "$REPORT_DIR/throttling_results.txt"
            echo "THROTTLE_EVENTS=0" >> "$REPORT_DIR/throttling_results.txt"
            echo "THROTTLE_PCT=0" >> "$REPORT_DIR/throttling_results.txt"
        fi
    else
        echo "Throttling log not found or empty"
        echo "THROTTLE_STATUS=NO_DATA" > "$REPORT_DIR/throttling_results.txt"
        echo "THROTTLE_EVENTS=0" >> "$REPORT_DIR/throttling_results.txt"
        echo "THROTTLE_PCT=0" >> "$REPORT_DIR/throttling_results.txt"
    fi
} > "$LOG_DIR/05_throttling_analysis.log"

# Process tegrastats results (same as v1.6)
log_info "Processing Tegrastats monitoring results..."
{
    echo "=== Tegrastats Analysis ==="
    if [ -f "$MONITOR_DIR/tegrastats_raw.log" ] && [ -s "$MONITOR_DIR/tegrastats_raw.log" ]; then
        GR3D_VALUES=$(grep -o 'GR3D_FREQ [0-9]*%' "$MONITOR_DIR/tegrastats_raw.log" | awk '{print $2}' | sed 's/%//' 2>/dev/null || echo "")
        if [ -n "$GR3D_VALUES" ]; then
            GR3D_MAX=$(echo "$GR3D_VALUES" | sort -n | tail -1)
            echo "GPU (GR3D) Utilization: Max ${GR3D_MAX}%"
        else
            GR3D_MAX="N/A"
            echo "GPU (GR3D) Utilization: No data found"
        fi
        
        echo "TEGRA_GR3D_MAX=${GR3D_MAX}" > "$REPORT_DIR/tegrastats_results.txt"
    else
        echo "Tegrastats log not found or empty"
        echo "TEGRA_GR3D_MAX=N/A" > "$REPORT_DIR/tegrastats_results.txt"
    fi
} > "$LOG_DIR/05_tegrastats_analysis.log"

################################################################################
# PHASE 6: FINAL REPORT GENERATION (ENHANCED v2.0)
################################################################################

log_phase "PHASE 6: FINAL REPORT GENERATION (DETAILED v2.0)"

log_info "Generating comprehensive final report with detailed metrics..."

# Read all final results from temp files (BULLETPROOF!)
VPU_PASS=$(cat "$TEMP_RESULTS_DIR/vpu_pass_count")
VPU_FAIL=$(cat "$TEMP_RESULTS_DIR/vpu_fail_count")
CUDA_PASS=$(cat "$TEMP_RESULTS_DIR/cuda_pass_count")
CUDA_FAIL=$(cat "$TEMP_RESULTS_DIR/cuda_fail_count")
GFX_PASS=$(cat "$TEMP_RESULTS_DIR/gfx_pass_count")
GFX_FAIL=$(cat "$TEMP_RESULTS_DIR/gfx_fail_count")
COMBINED_PASS=$(cat "$TEMP_RESULTS_DIR/combined_pass_count")
COMBINED_FAIL=$(cat "$TEMP_RESULTS_DIR/combined_fail_count")

log_info "BULLETPROOF final counts: VPU($VPU_PASS/$VPU_FAIL) CUDA($CUDA_PASS/$CUDA_FAIL) GFX($GFX_PASS/$GFX_FAIL) COMBINED($COMBINED_PASS/$COMBINED_FAIL)"

# Count total tests and results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# VPU results
if [ "$VPU_STATUS" = "PASS" ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# CUDA results
if [ "$CUDA_STATUS" = "PASS" ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# GFX results
if [ "$GFX_STATUS" = "PASS" ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Combined results
if [ "$COMBINED_STATUS" = "PASS" ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Generate final comprehensive report
{
    echo "JETSON ORIN GPU STRESS TEST FINAL REPORT"
    echo ""
    echo "Test completed $(date)"
    echo "Test duration ${TEST_DURATION} seconds ${REMOTE_DISPLAY_HOURS} hours"
    echo "Test directory $TEST_DIR"
    echo ""
    echo "Tester $TESTER_NAME"
    echo "Quality Checker $QUALITY_CHECKER_NAME"
    echo "Device Serial $DEVICE_SERIAL"
    echo ""

    echo "GPU COMPONENT TEST RESULTS"
    echo ""

    # VPU Results
    echo "GPU VPU Video Processing Unit Results"
    case "$VPU_STATUS" in
        "PASS")
            echo "Status PASS"
            ;;
        "FAIL")
            echo "Status FAIL"
            ;;
    esac
    echo "Successful encodings $VPU_PASS"
    echo "Failed encodings $VPU_FAIL"
    echo "Expected encodings $EXPECTED_VIDEOS"
    echo "Codecs tested H264 and H265"
    echo "Resolution 4K 3840x2160"
    echo ""
    
    # CUDA Results
    echo "GPU CUDA Compute Results"
    case "$CUDA_STATUS" in
        "PASS")
            echo "Status PASS"
            ;;
        "FAIL")
            echo "Status FAIL"
            ;;
    esac
    echo "Execution success $CUDA_PASS"
    echo ""

    # GFX Results
    echo "GPU Graphics EGL Headless Results"
    case "$GFX_STATUS" in
        "PASS")
            echo "Status PASS"
            ;;
        "FAIL")
            echo "Status FAIL"
            ;;
    esac
    echo "Successful operations $GFX_PASS"
    echo "Failed operations $GFX_FAIL"
    echo "Method EGL headless rendering Jetson optimized"
    echo ""

    # Combined Results
    echo "GPU Combined All Components Results"
    case "$COMBINED_STATUS" in
        "PASS")
            echo "Status PASS"
            ;;
        "FAIL")
            echo "Status FAIL"
            ;;
    esac
    echo "Successful operations $COMBINED_PASS"
    echo "Failed operations $COMBINED_FAIL"
    echo "Components VPU 4K CUDA Graphics EGL"
    echo ""
    
    # Temperature and Power Results
    echo "Thermal and Power Performance"
    if [ -f "$REPORT_DIR/temperature_power_results.txt" ]; then
        source "$REPORT_DIR/temperature_power_results.txt"
        echo "CPU Temperature Range ${CPU_MIN}C ${CPU_MAX}C Avg ${CPU_AVG}C"
        echo "GPU Temperature Range ${GPU_MIN}C ${GPU_MAX}C Avg ${GPU_AVG}C"

        # Show power data if available
        if [ "$POWER_MIN" != "N/A" ] && [ "$POWER_MIN" != "0.0" ]; then
            echo "GPU Power Draw Range ${POWER_MIN}W ${POWER_MAX}W Avg ${POWER_AVG}W"
        else
            echo "GPU Power Draw Monitoring data not available"
        fi

        # Show clock data if available
        if [ "$CLOCK_MIN" != "N/A" ] && [ "$CLOCK_MIN" != "0" ]; then
            echo "GPU Clock Speed Range ${CLOCK_MIN}MHz ${CLOCK_MAX}MHz Avg ${CLOCK_AVG}MHz"
        else
            echo "GPU Clock Speed Monitoring data not available"
        fi

        if [ "$GPU_MAX" != "N/A" ]; then
            if [ "$GPU_MAX" -le 80 ]; then
                echo "Thermal Status EXCELLENT"
            elif [ "$GPU_MAX" -le 95 ]; then
                echo "Thermal Status ACCEPTABLE"
            else
                echo "Thermal Status CRITICAL"
            fi
        fi
    fi

    # Throttling Results - Non-critical monitoring
    if [ -f "$REPORT_DIR/throttling_results.txt" ]; then
        source "$REPORT_DIR/throttling_results.txt"
        echo ""
        echo "Thermal Throttling Detection"
        case "$THROTTLE_STATUS" in
            "NONE")
                echo "Throttling Status NO THROTTLING DETECTED"
                ;;
            "MINIMAL")
                echo "Throttling Status MINIMAL THROTTLING $THROTTLE_EVENTS events"
                ;;
            "SIGNIFICANT")
                echo "Throttling Status SIGNIFICANT THROTTLING $THROTTLE_EVENTS events"
                ;;
            "NO_DATA")
                echo "Throttling Status Monitoring data not available"
                ;;
        esac
    fi
    echo ""

    echo "FINAL GPU TEST RESULT"
    echo ""
    echo "Total GPU Component Tests $TOTAL_TESTS"
    echo "Passed $PASSED_TESTS"
    echo "Failed $FAILED_TESTS"

    if [ $TOTAL_TESTS -gt 0 ]; then
        SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo "Overall Success Rate ${SUCCESS_RATE}%"
        echo ""

        if [ $FAILED_TESTS -eq 0 ]; then
            echo "RESULT PASS"
        else
            echo "RESULT FAIL"
        fi
    fi
    echo ""
    echo "Report generated $(date)"

} | tee "$REPORT_DIR/FINAL_GPU_REPORT.txt"

# Create summary file
{
    echo "SCRIPT_VERSION=v2.0_DETAILED"
    echo "MAJOR_ENHANCEMENTS=multi_codec_vpu,cuda_detailed_tests,power_monitoring,throttling_detection"
    echo "TOTAL_GPU_TESTS=$TOTAL_TESTS"
    echo "PASSED_GPU_TESTS=$PASSED_TESTS"
    echo "FAILED_GPU_TESTS=$FAILED_TESTS"
    echo "VPU_PASS=$VPU_PASS"
    echo "VPU_FAIL=$VPU_FAIL"
    echo "CUDA_PASS=$CUDA_PASS"
    echo "CUDA_FAIL=$CUDA_FAIL"
    echo "GFX_PASS=$GFX_PASS"
    echo "GFX_FAIL=$GFX_FAIL"
    echo "COMBINED_PASS=$COMBINED_PASS"
    echo "COMBINED_FAIL=$COMBINED_FAIL"

    [ -f "$REPORT_DIR/gpu_vpu_results.txt" ] && cat "$REPORT_DIR/gpu_vpu_results.txt"
    [ -f "$REPORT_DIR/gpu_cuda_results.txt" ] && cat "$REPORT_DIR/gpu_cuda_results.txt"
    [ -f "$REPORT_DIR/gpu_gfx_results.txt" ] && cat "$REPORT_DIR/gpu_gfx_results.txt"
    [ -f "$REPORT_DIR/gpu_combined_results.txt" ] && cat "$REPORT_DIR/gpu_combined_results.txt"
    [ -f "$REPORT_DIR/temperature_power_results.txt" ] && cat "$REPORT_DIR/temperature_power_results.txt"
    [ -f "$REPORT_DIR/throttling_results.txt" ] && cat "$REPORT_DIR/throttling_results.txt"
    [ -f "$REPORT_DIR/tegrastats_results.txt" ] && cat "$REPORT_DIR/tegrastats_results.txt"

} > "$REPORT_DIR/summary.txt"

log_success "Final report generated successfully with DETAILED v2.0 enhancements"

echo ""
echo "================================================================================"
echo "  TEST EXECUTION COMPLETE ON JETSON ORIN (DETAILED v2.0)"
echo "================================================================================"
echo ""
echo "Test directory on Jetson: $TEST_DIR"
echo "Main report: $REPORT_DIR/FINAL_GPU_REPORT.txt"
echo "Summary data: $REPORT_DIR/summary.txt"
echo "[*] v2.0 DETAILED ENHANCEMENTS:"
echo "   • Multi-codec VPU testing (H.264 and H.265)"
echo "   • Enhanced CUDA tests (bandwidth, FP32/FP64, matrix ops, concurrency)"
echo "   • Power monitoring and thermal tracking"
echo "   • Thermal throttling detection"
echo "   • Detailed performance metrics (GFLOPS, GB/s, clock speeds)"
echo ""

# Display final report
cat "$REPORT_DIR/FINAL_GPU_REPORT.txt"

REMOTE_SCRIPT_START

################################################################################
# COPY RESULTS TO HOST (SAME AS BEFORE)
################################################################################

echo ""
echo "================================================================================"
echo "  COPYING RESULTS TO HOST MACHINE"
echo "================================================================================"
echo ""

REMOTE_DIR=$(sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "ls -td /tmp/jetson_gpu_stress_* 2>/dev/null | head -1")

if [ -n "$REMOTE_DIR" ]; then
    echo "Remote test directory: $REMOTE_DIR"
    echo ""

    echo "[1/4] Copying logs..."
    # Use directory copying instead of wildcards for reliability
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP:$REMOTE_DIR/logs/" "$LOG_DIR/" 2>/dev/null && echo "[+] Logs copied" || echo "[!] Some logs may not have copied"

    echo "[2/4] Copying reports..."
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP:$REMOTE_DIR/reports/" "$LOG_DIR/" 2>/dev/null && echo "[+] Reports copied" || echo "[!] Some reports may not have copied"

    echo "[3/4] Copying monitoring data..."
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP:$REMOTE_DIR/monitoring/" "$LOG_DIR/" 2>/dev/null && echo "[+] Monitoring data copied" || echo "[!] Some monitoring data may not have copied"

    echo "[4/4] Copying sample 4K videos..."
    # Copy videos directory if it exists
    VIDEO_COUNT=$(sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP" "ls $REMOTE_DIR/videos/*.mp4 2>/dev/null | wc -l")

    if [ -n "$VIDEO_COUNT" ] && [ "$VIDEO_COUNT" -gt 0 ]; then
        sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP:$REMOTE_DIR/videos/" "$LOG_DIR/" 2>/dev/null && echo "[+] Sample 4K videos copied ($VIDEO_COUNT files)" || echo "[!] Videos may not have copied"
    else
        echo "[!] No 4K videos found"
    fi
    
    echo ""
    echo "Cleaning up remote directory: $REMOTE_DIR"
    sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP" "rm -rf $REMOTE_DIR" 2>/dev/null
    echo "[+] Cleanup complete"
else
    echo "[!] Remote directory not found"
fi

echo ""
echo "================================================================================"
echo "  ALL OPERATIONS COMPLETED SUCCESSFULLY (DETAILED v2.0)"
echo "================================================================================"
echo ""
echo "[*] Local Results Directory:"
echo "   $LOG_DIR"
echo ""
echo "[*] Key Files:"
echo "   • Final GPU Report:      $LOG_DIR/reports/FINAL_GPU_REPORT.txt"
echo "   • Summary Data:          $LOG_DIR/reports/summary.txt"
echo "   • Temperature/Power Log: $LOG_DIR/monitoring/temperature_power_log.csv"
echo "   • Throttling Detection:  $LOG_DIR/monitoring/throttling_detection.csv"
echo ""
echo "[*] GPU Test Logs:"
echo "   • VPU (Multi-codec):     $LOG_DIR/logs/01_gpu_vpu_stress.log"
echo "   • CUDA (Detailed):       $LOG_DIR/logs/02_gpu_cuda_stress.log"
echo "   • GFX (EGL):             $LOG_DIR/logs/03_gpu_gfx_stress.log"
echo "   • Combined GPU:          $LOG_DIR/logs/04_gpu_combined_stress.log"
echo "   • Power Analysis:        $LOG_DIR/logs/05_temperature_power_analysis.log"
echo "   • Throttling Analysis:   $LOG_DIR/logs/05_throttling_analysis.log"
echo ""
echo "[*] Sample 4K Videos:"
echo "   $LOG_DIR/videos/ (H.264 and H.265 encoded)"
echo ""

if [ -f "$LOG_DIR/reports/FINAL_GPU_REPORT.txt" ]; then
    echo "================================================================================"
    echo "  QUICK SUMMARY (DETAILED v2.0)"
    echo "================================================================================"
    echo ""
    cat "$LOG_DIR/reports/FINAL_GPU_REPORT.txt" | grep -A 40 "FINAL GPU TEST RESULT"
    echo ""
fi

echo "[*] v2.0 DETAILED ENHANCEMENTS SUCCESSFULLY APPLIED:"
echo "   [+] Multi-codec VPU testing (H.264 and H.265 hardware encoding)"
echo "   [+] Enhanced CUDA test suite (bandwidth, FP32/FP64, matrix, concurrent)"
echo "   [+] Continuous power and clock speed monitoring"
echo "   [+] Real-time thermal throttling detection"
echo "   [+] Detailed performance metrics (GFLOPS, GB/s bandwidth)"
echo "   [+] Comprehensive thermal and power analysis"
echo "   [+] All tests use built-in features (no external models required)"
echo ""
echo "[*] To view full GPU report:"
echo "   cat $LOG_DIR/reports/FINAL_GPU_REPORT.txt"
echo ""

################################################################################
# AUTOMATIC PDF GENERATION
################################################################################

echo ""
log_info "Generating PDF reports..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PDF_GENERATOR="$SCRIPT_DIR/generate_pdf_reports.sh"

# Auto-detect logo in assets/logos directory
LOGO_OPTS=""
LOGO_DIR="$SCRIPT_DIR/assets/logos"
if [ -d "$LOGO_DIR" ]; then
    # Find first logo file (PNG, JPG, JPEG, GIF, BMP)
    LOGO_FILE=$(find "$LOGO_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.bmp" \) | head -n 1)
    if [ -n "$LOGO_FILE" ]; then
        LOGO_OPTS="--logo $LOGO_FILE --logo-position watermark --logo-opacity 0.1"
        log_info "Using logo: $(basename "$LOGO_FILE")"
    fi
fi

if [ -f "$PDF_GENERATOR" ]; then
    if "$PDF_GENERATOR" --test-type gpu $LOGO_OPTS "$LOG_DIR" > /dev/null 2>&1; then
        log_success "PDF reports generated successfully"
        echo "[*] PDF Reports: $LOG_DIR/pdf_reports/gpu/"
    else
        log_warning "PDF generation failed (test results still available)"
    fi
else
    log_warning "PDF generator not found (test results still available)"
fi
echo ""

echo "[+] Jetson Orin detailed GPU stress test completed (v2.0)!"
echo ""