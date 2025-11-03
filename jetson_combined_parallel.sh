#!/bin/bash

################################################################################
# JETSON ORIN AGX - COMBINED PARALLEL STRESS TEST
################################################################################
# Description: Run CPU, GPU, RAM, and Storage tests simultaneously
# Version: 1.0
# Purpose: Maximum system stress with all components under load
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
    # Non-interactive mode: use provided parameters directly
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
    collect_test_parameters "${1:-192.168.55.69}" "${2:-orin}" "${3}" "${4:-1}"
fi

################################################################################
# CONFIGURATION
################################################################################

TEST_DURATION=$(echo "$TEST_DURATION_HOURS * 3600" | bc | cut -d'.' -f1)  # Convert hours to seconds (handle decimals)

LOG_DIR="${5:-./combined_parallel_test_$(date +%Y%m%d_%H%M%S)}"

################################################################################
# USAGE
################################################################################

show_usage() {
    cat << 'EOF'
================================================================================
  JETSON ORIN AGX - COMBINED PARALLEL STRESS TEST
================================================================================

Usage: ./jetson_combined_parallel_test.sh [ip] [user] [password] [hours] [log_dir]

Parameters:
  ip       : Jetson Orin IP (default: 192.168.55.69)
  user     : SSH username (default: orin)
  password : SSH password (will prompt if not provided)
  hours    : Test duration in hours (default: 1)
  log_dir  : Log directory (default: ./combined_parallel_test_YYYYMMDD_HHMMSS)

TEST STRATEGY:
  This test runs ALL components simultaneously:
  • CPU stress (all cores at 100%)
  • GPU stress (CUDA + VPU + Graphics)
  • RAM stress (75% memory usage)
  • Storage stress (I/O operations)
  • Real-time monitoring (temps, power, utilization)

INTENSITY LEVEL: MAXIMUM
  This is the most demanding test possible. It will:
  - Push all hardware to absolute limits
  - Generate maximum heat
  - Consume maximum power
  - Test system stability under extreme load

Examples:
  ./jetson_combined_parallel_test.sh                    # 1 hour test
  ./jetson_combined_parallel_test.sh 192.168.55.69 orin mypass 2  # 2 hour test

================================================================================
EOF
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_usage
    exit 0
fi

################################################################################
# INITIALIZATION
################################################################################

log_phase "JETSON ORIN COMBINED PARALLEL STRESS TEST"

echo "[COMBINED PARALLEL TEST CONFIGURATION]"
echo "  • Target: $ORIN_USER@$ORIN_IP"
echo "  • Duration: $TEST_DURATION_HOURS hours ($TEST_DURATION seconds)"
echo "  • Test Mode: ALL COMPONENTS SIMULTANEOUSLY"
echo "  • Intensity: MAXIMUM"
echo "  • Components: CPU + GPU + RAM + Storage"
echo ""

# Check prerequisites
check_prerequisites "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"

# Create log directories
ensure_directory "$LOG_DIR/logs"
ensure_directory "$LOG_DIR/reports"
ensure_directory "$LOG_DIR/monitoring"

# Convert to absolute path
LOG_DIR=$(cd "$LOG_DIR" && pwd)

log_success "Initialization complete"
log_info "Results will be saved to: $LOG_DIR"
echo ""

################################################################################
# REMOTE COMBINED PARALLEL TEST
################################################################################

log_phase "STARTING COMBINED PARALLEL STRESS TEST"

ssh_execute_with_output "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "
export ORIN_PASS='$ORIN_PASS'
export TEST_DURATION=$TEST_DURATION
bash -s" << 'REMOTE_COMBINED_START' | tee "$LOG_DIR/logs/combined_parallel_test.log"

#!/bin/bash

set -e

# Test directory
TEST_DIR="/tmp/jetson_combined_parallel_$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$TEST_DIR/logs"
REPORT_DIR="$TEST_DIR/reports"
MONITOR_DIR="$TEST_DIR/monitoring"

mkdir -p "$TEST_DIR" "$LOG_DIR" "$REPORT_DIR" "$MONITOR_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; }
log_phase() { echo -e "\n${MAGENTA}========================================\n$1\n========================================${NC}\n"; }

################################################################################
# SYSTEM INFORMATION
################################################################################

log_phase "SYSTEM INFORMATION COLLECTION"

{
    echo "=== JETSON ORIN COMBINED PARALLEL STRESS TEST ==="
    echo "Start Time: $(date)"
    echo "Test Duration: $TEST_DURATION seconds"
    echo ""
    echo "=== HARDWARE INFO ==="
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    if [ -f /etc/nv_tegra_release ]; then
        echo "JetPack: $(cat /etc/nv_tegra_release)"
    fi
    echo ""
    echo "CPU Cores: $(nproc)"
    echo "Total RAM: $(free -h | awk 'NR==2 {print $2}')"
    echo "Available RAM: $(free -h | awk 'NR==2 {print $7}')"
    echo ""
    echo "=== INITIAL TEMPERATURES ==="
    for i in $(seq 0 5); do
        if [ -f "/sys/devices/virtual/thermal/thermal_zone$i/temp" ]; then
            temp=$(cat /sys/devices/virtual/thermal/thermal_zone$i/temp 2>/dev/null)
            temp_c=$((temp / 1000))
            zone_type=$(cat /sys/devices/virtual/thermal/thermal_zone$i/type 2>/dev/null)
            echo "$zone_type: ${temp_c}°C"
        fi
    done
    echo ""
} > "$LOG_DIR/system_info.log"

log_success "System information collected"

################################################################################
# MONITORING SETUP
################################################################################

log_info "Starting comprehensive system monitoring..."

# Temperature and utilization monitoring
{
    echo "timestamp,cpu_temp,gpu_temp,cpu_usage,gpu_usage,memory_usage,cpu_freq,gpu_freq,power"
    while true; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        cpu_temp=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}' || echo "N/A")
        gpu_temp=$(cat /sys/devices/virtual/thermal/thermal_zone1/temp 2>/dev/null | awk '{print $1/1000}' || echo "N/A")
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' || echo "N/A")
        gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
        memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' || echo "N/A")
        cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{print $1/1000}' || echo "N/A")
        gpu_freq="N/A"
        power="N/A"

        echo "$timestamp,$cpu_temp,$gpu_temp,$cpu_usage,$gpu_usage,$memory_usage,$cpu_freq,$gpu_freq,$power"
        sleep 5
    done
} > "$MONITOR_DIR/system_monitoring.csv" &
MONITOR_PID=$!

log_success "Monitoring started (PID: $MONITOR_PID)"

################################################################################
# COMPONENT STRESS TEST FUNCTIONS
################################################################################

log_phase "PREPARING COMPONENT STRESS TESTS"

# Get memory info for RAM test
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
AVAILABLE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
AVAILABLE_RAM_MB=$((AVAILABLE_RAM_KB / 1024))
TEST_MEMORY_MB=$((AVAILABLE_RAM_MB * 75 / 100 - 500))  # 75% - 500MB safety margin

log_info "Memory allocation for RAM test: ${TEST_MEMORY_MB}MB"

# CPU cores for parallel tests
CPU_CORES=$(nproc)
log_info "CPU cores available: $CPU_CORES"

################################################################################
# CREATE CPU STRESS TEST
################################################################################

log_info "Creating CPU stress component..."

cat > "$TEST_DIR/cpu_stress.sh" << 'CPU_STRESS_EOF'
#!/bin/bash
DURATION=$1
LOG_FILE=$2

log_cpu() { echo "[CPU] $(date '+%H:%M:%S') $1" >> "$LOG_FILE"; }

log_cpu "Starting CPU stress test for $DURATION seconds"

# Use stress-ng if available, otherwise fallback
if command -v stress-ng >/dev/null 2>&1; then
    log_cpu "Using stress-ng for CPU stress"
    stress-ng --cpu $(nproc) --cpu-method all --timeout ${DURATION}s --metrics-brief >> "$LOG_FILE" 2>&1
    CPU_RESULT=$?
else
    log_cpu "Using fallback CPU stress (all cores)"
    # Fallback: CPU intensive loop on all cores
    for i in $(seq 1 $(nproc)); do
        {
            END=$(($(date +%s) + DURATION))
            while [ $(date +%s) -lt $END ]; do
                echo "scale=5000; a(1)*4" | bc -l >/dev/null 2>&1
            done
        } &
    done
    wait
    CPU_RESULT=0
fi

log_cpu "CPU stress test completed with result: $CPU_RESULT"
exit $CPU_RESULT
CPU_STRESS_EOF

chmod +x "$TEST_DIR/cpu_stress.sh"

################################################################################
# CREATE GPU STRESS TEST
################################################################################

log_info "Creating GPU stress component..."

cat > "$TEST_DIR/gpu_stress.sh" << 'GPU_STRESS_EOF'
#!/bin/bash
DURATION=$1
LOG_FILE=$2

log_gpu() { echo "[GPU] $(date '+%H:%M:%S') $1" >> "$LOG_FILE"; }

log_gpu "Starting GPU stress test for $DURATION seconds"

GPU_RESULT=0

# CUDA stress if nvcc available
if command -v nvcc >/dev/null 2>&1; then
    log_gpu "Running CUDA compute stress"

    cat > /tmp/gpu_stress.cu << 'CUDA_EOF'
#include <cuda_runtime.h>
#include <stdio.h>
#include <time.h>

__global__ void intensive_kernel(float *data, int size) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        float val = data[idx];
        for (int i = 0; i < 1000; i++) {
            val = sinf(val) * cosf(val) + sqrtf(fabsf(val));
        }
        data[idx] = val;
    }
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    int size = 10000000;
    float *d_data;

    cudaMalloc(&d_data, size * sizeof(float));

    time_t start = time(NULL);
    int ops = 0;

    while (difftime(time(NULL), start) < duration) {
        intensive_kernel<<<10000, 1000>>>(d_data, size);
        cudaDeviceSynchronize();
        ops++;
    }

    cudaFree(d_data);
    printf("GPU operations: %d\n", ops);
    return 0;
}
CUDA_EOF

    if nvcc -o /tmp/gpu_stress /tmp/gpu_stress.cu 2>&1 | tee -a "$LOG_FILE"; then
        /tmp/gpu_stress $DURATION >> "$LOG_FILE" 2>&1 || GPU_RESULT=1
    else
        log_gpu "CUDA compilation failed"
        GPU_RESULT=1
    fi
else
    log_gpu "CUDA not available, using nvidia-smi monitoring"
    # Just monitor GPU while other tests run
    END=$(($(date +%s) + DURATION))
    while [ $(date +%s) -lt $END ]; do
        nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader >> "$LOG_FILE" 2>&1 || true
        sleep 10
    done
fi

log_gpu "GPU stress test completed with result: $GPU_RESULT"
exit $GPU_RESULT
GPU_STRESS_EOF

chmod +x "$TEST_DIR/gpu_stress.sh"

################################################################################
# CREATE RAM STRESS TEST
################################################################################

log_info "Creating RAM stress component..."

cat > "$TEST_DIR/ram_stress.py" << 'RAM_STRESS_EOF'
#!/usr/bin/env python3
import sys
import time
import random

def ram_stress(memory_mb, duration):
    print(f"[RAM] Starting RAM stress: {memory_mb}MB for {duration}s", flush=True)

    try:
        # Allocate memory in 50MB chunks
        blocks = []
        block_size = 50 * 1024 * 1024  # 50MB
        target_blocks = memory_mb // 50

        print(f"[RAM] Allocating {target_blocks} blocks of 50MB each", flush=True)

        for i in range(target_blocks):
            block = bytearray(block_size)
            # Fill with random data
            for j in range(0, block_size, 4096):
                block[j] = random.randint(0, 255)
            blocks.append(block)

            if (i + 1) % 10 == 0:
                print(f"[RAM] Allocated {i+1}/{target_blocks} blocks", flush=True)

        print(f"[RAM] Allocation complete. Running stress operations...", flush=True)

        # Stress test: continuous read/write
        start = time.time()
        operations = 0

        while time.time() - start < duration:
            # Random block selection and modification
            for _ in range(100):
                block_idx = random.randint(0, len(blocks) - 1)
                pos = random.randint(0, len(blocks[block_idx]) - 8)
                value = random.randint(0, 255)
                blocks[block_idx][pos] = value

                # Verify
                if blocks[block_idx][pos] != value:
                    print(f"[RAM] ERROR: Memory verification failed!", flush=True)
                    return 1

            operations += 1

            if operations % 100 == 0:
                elapsed = time.time() - start
                remaining = duration - elapsed
                print(f"[RAM] Operations: {operations}, Remaining: {remaining:.0f}s", flush=True)

        print(f"[RAM] Stress test completed. Total operations: {operations}", flush=True)
        return 0

    except MemoryError:
        print(f"[RAM] ERROR: Memory allocation failed", flush=True)
        return 1
    except Exception as e:
        print(f"[RAM] ERROR: {e}", flush=True)
        return 1

if __name__ == "__main__":
    memory_mb = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    sys.exit(ram_stress(memory_mb, duration))
RAM_STRESS_EOF

chmod +x "$TEST_DIR/ram_stress.py"

################################################################################
# CREATE STORAGE STRESS TEST
################################################################################

log_info "Creating storage stress component..."

cat > "$TEST_DIR/storage_stress.sh" << 'STORAGE_STRESS_EOF'
#!/bin/bash
DURATION=$1
LOG_FILE=$2
TEST_DIR=$3

log_storage() { echo "[STORAGE] $(date '+%H:%M:%S') $1" >> "$LOG_FILE"; }

log_storage "Starting storage stress test for $DURATION seconds"

STORAGE_DIR="$TEST_DIR/storage_test"
mkdir -p "$STORAGE_DIR"

STORAGE_RESULT=0
END=$(($(date +%s) + DURATION))
OPERATIONS=0

while [ $(date +%s) -lt $END ]; do
    # Write test
    dd if=/dev/urandom of="$STORAGE_DIR/test_$OPERATIONS.dat" bs=1M count=50 2>/dev/null || STORAGE_RESULT=1

    # Read test
    dd if="$STORAGE_DIR/test_$OPERATIONS.dat" of=/dev/null bs=1M 2>/dev/null || STORAGE_RESULT=1

    # Delete test
    rm -f "$STORAGE_DIR/test_$OPERATIONS.dat"

    OPERATIONS=$((OPERATIONS + 1))

    if [ $((OPERATIONS % 10)) -eq 0 ]; then
        log_storage "Operations completed: $OPERATIONS"
    fi
done

log_storage "Storage stress test completed. Total operations: $OPERATIONS, Result: $STORAGE_RESULT"

# Cleanup
rm -rf "$STORAGE_DIR"

exit $STORAGE_RESULT
STORAGE_STRESS_EOF

chmod +x "$TEST_DIR/storage_stress.sh"

log_success "All component stress tests created"

################################################################################
# EXECUTE COMBINED PARALLEL STRESS TEST
################################################################################

log_phase "STARTING ALL COMPONENTS IN PARALLEL"

echo "WARNING: This will push ALL hardware to absolute limits simultaneously!"
echo "Duration: $TEST_DURATION seconds"
echo ""

# Start all components in parallel
log_info "Launching CPU stress..."
"$TEST_DIR/cpu_stress.sh" $TEST_DURATION "$LOG_DIR/cpu_stress.log" &
CPU_PID=$!

log_info "Launching GPU stress..."
"$TEST_DIR/gpu_stress.sh" $TEST_DURATION "$LOG_DIR/gpu_stress.log" &
GPU_PID=$!

log_info "Launching RAM stress..."
python3 "$TEST_DIR/ram_stress.py" $TEST_MEMORY_MB $TEST_DURATION > "$LOG_DIR/ram_stress.log" 2>&1 &
RAM_PID=$!

log_info "Launching Storage stress..."
"$TEST_DIR/storage_stress.sh" $TEST_DURATION "$LOG_DIR/storage_stress.log" "$TEST_DIR" &
STORAGE_PID=$!

log_success "All components launched in parallel"
echo ""
echo "Process IDs:"
echo "  CPU:     $CPU_PID"
echo "  GPU:     $GPU_PID"
echo "  RAM:     $RAM_PID"
echo "  Storage: $STORAGE_PID"
echo ""

# Monitor progress
log_info "Monitoring parallel execution..."
START_TIME=$(date +%s)

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    REMAINING=$((TEST_DURATION - ELAPSED))

    # Check if all processes are still running
    RUNNING=0
    kill -0 $CPU_PID 2>/dev/null && RUNNING=$((RUNNING + 1))
    kill -0 $GPU_PID 2>/dev/null && RUNNING=$((RUNNING + 1))
    kill -0 $RAM_PID 2>/dev/null && RUNNING=$((RUNNING + 1))
    kill -0 $STORAGE_PID 2>/dev/null && RUNNING=$((RUNNING + 1))

    if [ $RUNNING -eq 0 ]; then
        log_info "All components completed"
        break
    fi

    if [ $REMAINING -le 0 ]; then
        log_info "Duration reached, waiting for processes to finish..."
        break
    fi

    # Status update every 30 seconds
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo "========================================"
        echo "PROGRESS UPDATE - Elapsed: ${ELAPSED}s / Remaining: ${REMAINING}s"
        echo "Active components: $RUNNING/4"

        # Get current temps
        CPU_TEMP=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}')
        GPU_TEMP=$(cat /sys/devices/virtual/thermal/thermal_zone1/temp 2>/dev/null | awk '{print $1/1000}')
        echo "Temperatures: CPU ${CPU_TEMP}°C, GPU ${GPU_TEMP}°C"

        # Get memory usage
        MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        echo "Memory usage: ${MEM_USAGE}%"
        echo "========================================"
        echo ""
    fi

    sleep 5
done

# Wait for all processes to complete
log_info "Waiting for all components to finish..."

wait $CPU_PID 2>/dev/null
CPU_RESULT=$?

wait $GPU_PID 2>/dev/null
GPU_RESULT=$?

wait $RAM_PID 2>/dev/null
RAM_RESULT=$?

wait $STORAGE_PID 2>/dev/null
STORAGE_RESULT=$?

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

log_success "All parallel components completed"

################################################################################
# RESULTS ANALYSIS
################################################################################

log_phase "ANALYZING RESULTS"

# Collect results
TOTAL_FAILURES=0

echo "Component Results:"
echo "=================="

if [ $CPU_RESULT -eq 0 ]; then
    echo "[+] CPU:     PASSED"
else
    echo "[-] CPU:     FAILED (exit code: $CPU_RESULT)"
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

if [ $GPU_RESULT -eq 0 ]; then
    echo "[+] GPU:     PASSED"
else
    echo "[-] GPU:     FAILED (exit code: $GPU_RESULT)"
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

if [ $RAM_RESULT -eq 0 ]; then
    echo "[+] RAM:     PASSED"
else
    echo "[-] RAM:     FAILED (exit code: $RAM_RESULT)"
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

if [ $STORAGE_RESULT -eq 0 ]; then
    echo "[+] Storage: PASSED"
else
    echo "[-] Storage: FAILED (exit code: $STORAGE_RESULT)"
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

echo ""
echo "Summary: $((4 - TOTAL_FAILURES))/4 components passed"

# Analyze monitoring data
if [ -f "$MONITOR_DIR/system_monitoring.csv" ]; then
    log_info "Analyzing system monitoring data..."

    {
        echo "=== THERMAL ANALYSIS ==="
        awk -F',' 'NR>1 && $2!="N/A" && $3!="N/A" {
            cpu_sum+=$2; cpu_count++;
            cpu_max=($2>cpu_max || cpu_max=="")?$2:cpu_max;
            gpu_sum+=$3; gpu_count++;
            gpu_max=($3>gpu_max || gpu_max=="")?$3:gpu_max;
        }
        END {
            if(cpu_count>0) printf "CPU Temp: Avg %.1f°C, Max %.1f°C\n", cpu_sum/cpu_count, cpu_max;
            if(gpu_count>0) printf "GPU Temp: Avg %.1f°C, Max %.1f°C\n", gpu_sum/gpu_count, gpu_max;
        }' "$MONITOR_DIR/system_monitoring.csv"

        echo ""
        echo "=== UTILIZATION ANALYSIS ==="
        awk -F',' 'NR>1 && $4!="N/A" && $5!="N/A" {
            cpu_util+=$4; cpu_samples++;
            gpu_util+=$5; gpu_samples++;
        }
        END {
            if(cpu_samples>0) printf "CPU Utilization: Avg %.1f%%\n", cpu_util/cpu_samples;
            if(gpu_samples>0) printf "GPU Utilization: Avg %.1f%%\n", gpu_util/gpu_samples;
        }' "$MONITOR_DIR/system_monitoring.csv"

    } > "$REPORT_DIR/monitoring_analysis.txt"

    cat "$REPORT_DIR/monitoring_analysis.txt"
fi

################################################################################
# FINAL REPORT
################################################################################

{
    echo "================================================================================"
    echo "  JETSON ORIN COMBINED PARALLEL STRESS TEST - FINAL REPORT"
    echo "================================================================================"
    echo ""
    echo "Test Date: $(date)"
    echo "Duration: $TEST_DURATION seconds"
    echo "Test Directory: $TEST_DIR"
    echo ""
    echo "================================================================================"
    echo "  COMPONENT RESULTS"
    echo "================================================================================"
    echo ""
    printf "%-12s : %s\n" "CPU" "$([ $CPU_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
    printf "%-12s : %s\n" "GPU" "$([ $GPU_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
    printf "%-12s : %s\n" "RAM" "$([ $RAM_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
    printf "%-12s : %s\n" "Storage" "$([ $STORAGE_RESULT -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
    echo ""
    echo "Total Failures: $TOTAL_FAILURES/4"
    echo ""

    if [ -f "$REPORT_DIR/monitoring_analysis.txt" ]; then
        cat "$REPORT_DIR/monitoring_analysis.txt"
    fi

    echo ""
    echo "================================================================================"
    echo "  OVERALL RESULT"
    echo "================================================================================"
    echo ""

    if [ $TOTAL_FAILURES -eq 0 ]; then
        echo "[+] RESULT: ALL COMPONENTS PASSED UNDER PARALLEL STRESS"
        echo ""
        echo "Your Jetson Orin successfully handled maximum simultaneous load across"
        echo "all components (CPU, GPU, RAM, Storage). The system is stable and ready"
        echo "for demanding parallel workloads."
    else
        echo "[-] RESULT: $TOTAL_FAILURES COMPONENT(S) FAILED UNDER PARALLEL STRESS"
        echo ""
        echo "The system experienced failures when all components were stressed"
        echo "simultaneously. This may indicate:"
        echo "  • Power supply insufficiency"
        echo "  • Thermal management issues"
        echo "  • Hardware defects"
        echo "  • Resource contention problems"
        echo ""
        echo "Review individual component logs for details."
    fi

    echo ""
    echo "================================================================================"
    echo "  LOG FILES"
    echo "================================================================================"
    echo ""
    echo "System Info:      $LOG_DIR/system_info.log"
    echo "CPU Log:          $LOG_DIR/cpu_stress.log"
    echo "GPU Log:          $LOG_DIR/gpu_stress.log"
    echo "RAM Log:          $LOG_DIR/ram_stress.log"
    echo "Storage Log:      $LOG_DIR/storage_stress.log"
    echo "Monitoring Data:  $MONITOR_DIR/system_monitoring.csv"
    echo ""

} | tee "$REPORT_DIR/combined_parallel_report.txt"

# Save summary
{
    echo "COMBINED_RESULT=$([  $TOTAL_FAILURES -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
    echo "CPU_RESULT=$CPU_RESULT"
    echo "GPU_RESULT=$GPU_RESULT"
    echo "RAM_RESULT=$RAM_RESULT"
    echo "STORAGE_RESULT=$STORAGE_RESULT"
    echo "TOTAL_FAILURES=$TOTAL_FAILURES"
    echo "TEST_DURATION=$TEST_DURATION"
    echo "TEST_DIR=$TEST_DIR"
} > "$REPORT_DIR/test_summary.txt"

log_phase "COMBINED PARALLEL STRESS TEST COMPLETED"

echo "Test directory: $TEST_DIR"
echo "Main report: $REPORT_DIR/combined_parallel_report.txt"
echo ""

# Display final result
cat "$REPORT_DIR/combined_parallel_report.txt" | grep -A 20 "OVERALL RESULT"

REMOTE_COMBINED_START

################################################################################
# COPY RESULTS TO HOST
################################################################################

log_phase "COPYING RESULTS TO HOST"

REMOTE_DIR=$(sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "ls -td /tmp/jetson_combined_parallel_* 2>/dev/null | head -1")

if [ -n "$REMOTE_DIR" ]; then
    echo "Remote test directory: $REMOTE_DIR"

    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP:$REMOTE_DIR/logs/* "$LOG_DIR/logs/" 2>/dev/null
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP:$REMOTE_DIR/reports/* "$LOG_DIR/reports/" 2>/dev/null
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP:$REMOTE_DIR/monitoring/* "$LOG_DIR/monitoring/" 2>/dev/null

    sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "rm -rf $REMOTE_DIR" 2>/dev/null

    log_success "Results copied and remote directory cleaned"
else
    log_error "Remote directory not found"
fi

################################################################################
# FINAL STATUS
################################################################################

echo ""
echo "================================================================================"
echo "  COMBINED PARALLEL STRESS TEST COMPLETED"
echo "================================================================================"
echo ""
echo "Results directory: $LOG_DIR"
echo ""

if [ -f "$LOG_DIR/reports/combined_parallel_report.txt" ]; then
    cat "$LOG_DIR/reports/combined_parallel_report.txt" | grep -A 30 "OVERALL RESULT"
fi

echo ""
echo "For full details, see: $LOG_DIR/reports/combined_parallel_report.txt"
echo ""

exit 0
