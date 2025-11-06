#!/bin/bash

################################################################################
# JETSON ORIN - COMBINED PARALLEL STRESS TEST
################################################################################
# Description: Run CPU, GPU, RAM, and Storage tests simultaneously
# Features: Parallel execution, real-time monitoring, comprehensive reporting
# Version: 1.0 - Initial Release
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
    collect_test_parameters "${1:-192.168.55.69}" "${2:-orin}" "${3}" "${4:-2}"
fi

# Get tester information (parameters 6 and 7 from orchestrator, or from environment if from collect_test_parameters)
TESTER_NAME="${6:-${TESTER_NAME:-N/A}}"
QUALITY_CHECKER_NAME="${7:-${QUALITY_CHECKER_NAME:-N/A}}"

################################################################################
# CONFIGURATION
################################################################################

TEST_DURATION=$(echo "$TEST_DURATION_HOURS * 3600" | bc | cut -d'.' -f1)

# Master log directory
LOG_DIR="./combined_parallel_test_$(date +%Y%m%d_%H%M%S)"

################################################################################
# USAGE & HELP
################################################################################

show_usage() {
    cat << 'EOF'
================================================================================
  JETSON ORIN COMBINED PARALLEL STRESS TEST
================================================================================

Usage: ./jetson_combined_parallel_test.sh [orin_ip] [orin_user] [password] [hours]

Parameters:
  orin_ip     : IP address of Jetson Orin (default: 192.168.55.69)
  orin_user   : SSH username (default: orin)
  password    : SSH password (will prompt if not provided)
  hours       : Test duration in hours (default: 2, supports decimals like 0.5)

What This Test Does:
  Runs ALL stress tests SIMULTANEOUSLY:
  • CPU Test      - Multi-core stress, thermal monitoring
  • GPU Test      - CUDA, VPU, Graphics workloads
  • RAM Test      - Memory integrity and pattern tests
  • Storage Test  - I/O performance and health checks

Why Parallel Testing:
  • Simulates real-world heavy workload scenarios
  • Tests system under maximum combined stress
  • Validates thermal management under full load
  • Identifies interaction issues between components
  • Ensures system stability under extreme conditions

Examples:
  ./jetson_combined_parallel_test.sh                      # 2 hour combined test
  ./jetson_combined_parallel_test.sh 192.168.55.69 orin q 1  # 1 hour test
  ./jetson_combined_parallel_test.sh 192.168.55.69 orin q 0.5  # 30 minute test

Output:
  • Individual test results in separate directories
  • Combined system health report
  • Performance analysis across all components
  • Recommendations based on overall system behavior

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

echo "================================================================================"
echo "  JETSON ORIN COMBINED PARALLEL STRESS TEST"
echo "================================================================================"
echo ""
echo "Test Configuration:"
echo "  • Target Device: $ORIN_IP"
echo "  • SSH User: $ORIN_USER"
echo "  • Test Duration: ${TEST_DURATION_HOURS} hours ($TEST_DURATION seconds)"
echo "  • Test Mode: PARALLEL (All components simultaneously)"
echo ""
echo "Test Personnel:"
echo "  • Tester: $TESTER_NAME"
echo "  • Quality Checker: $QUALITY_CHECKER_NAME"
echo ""
echo "Tests to Run:"
echo "  [1] CPU Stress Test    - Multi-core performance"
echo "  [2] GPU Stress Test    - CUDA/VPU/Graphics"
echo "  [3] RAM Stress Test    - Memory integrity"
echo "  [4] Storage Test       - I/O and health"
echo ""

# Check for sshpass
if ! command -v sshpass &> /dev/null; then
    log_error "sshpass not found. Install with: sudo apt install sshpass"
    exit 1
fi

# Test SSH connection
log_info "Testing SSH connection..."
if ! sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'OK'" 2>/dev/null | grep -q "OK"; then
    log_error "SSH connection failed"
    exit 1
fi
log_success "SSH connection established"
echo ""

# Create directory structure
mkdir -p "$LOG_DIR/cpu_test"
mkdir -p "$LOG_DIR/gpu_test"
mkdir -p "$LOG_DIR/ram_test"
mkdir -p "$LOG_DIR/storage_test"
mkdir -p "$LOG_DIR/monitoring"
mkdir -p "$LOG_DIR/logs"
mkdir -p "$LOG_DIR/reports"

# Convert to absolute path
LOG_DIR=$(cd "$LOG_DIR" && pwd)

log_info "Master results directory: $LOG_DIR"
echo ""

################################################################################
# SYSTEM BASELINE CAPTURE
################################################################################

log_phase "PHASE 0: CAPTURING SYSTEM BASELINE"

log_info "Capturing system state before stress tests..."

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "bash -s" << 'BASELINE_SCRIPT' > "$LOG_DIR/logs/baseline.log" 2>&1
#!/bin/bash

echo "=== SYSTEM BASELINE BEFORE PARALLEL STRESS TEST ==="
echo "Timestamp: $(date)"
echo ""

echo "=== CPU INFO ==="
lscpu | grep -E "Model name|CPU\(s\)|Thread|Core|Socket|MHz"
echo ""

echo "=== MEMORY INFO ==="
free -h
echo ""

echo "=== GPU INFO ==="
nvidia-smi 2>/dev/null || echo "nvidia-smi not available"
echo ""

echo "=== THERMAL BASELINE ==="
cat /sys/devices/virtual/thermal/thermal_zone*/temp 2>/dev/null | awk '{print "Thermal Zone: " $1/1000 "°C"}' || echo "Temperature sensors not available"
echo ""

echo "=== STORAGE INFO ==="
df -h
echo ""

echo "=== LOAD AVERAGE ==="
uptime
echo ""

BASELINE_SCRIPT

log_success "Baseline captured"
echo ""

################################################################################
# LAUNCH PARALLEL TESTS
################################################################################

log_phase "PHASE 1: LAUNCHING PARALLEL STRESS TESTS"

TEST_START_TIME=$(date +%s)

# CPU Test
log_info "[1/4] Launching CPU stress test..."
"$SCRIPT_DIR/jetson_cpu_test.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$LOG_DIR/cpu_test" "$TESTER_NAME" "$QUALITY_CHECKER_NAME" > "$LOG_DIR/logs/cpu_test.log" 2>&1 &
CPU_PID=$!
log_success "CPU test launched (PID: $CPU_PID)"

sleep 2

# GPU Test
log_info "[2/4] Launching GPU stress test..."
"$SCRIPT_DIR/jetson_gpu_test.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$LOG_DIR/gpu_test" "$TESTER_NAME" "$QUALITY_CHECKER_NAME" > "$LOG_DIR/logs/gpu_test.log" 2>&1 &
GPU_PID=$!
log_success "GPU test launched (PID: $GPU_PID)"

sleep 2

# RAM Test
log_info "[3/4] Launching RAM stress test..."
"$SCRIPT_DIR/jetson_ram_test.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$LOG_DIR/ram_test" "$TESTER_NAME" "$QUALITY_CHECKER_NAME" > "$LOG_DIR/logs/ram_test.log" 2>&1 &
RAM_PID=$!
log_success "RAM test launched (PID: $RAM_PID)"

sleep 2

# Storage Test
log_info "[4/4] Launching Storage stress test..."
"$SCRIPT_DIR/jetson_storage_test.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$LOG_DIR/storage_test" "$TESTER_NAME" "$QUALITY_CHECKER_NAME" > "$LOG_DIR/logs/storage_test.log" 2>&1 &
STORAGE_PID=$!
log_success "Storage test launched (PID: $STORAGE_PID)"

echo ""
log_success "All tests launched successfully!"
echo ""
echo "Process IDs:"
echo "  • CPU Test:     $CPU_PID"
echo "  • GPU Test:     $GPU_PID"
echo "  • RAM Test:     $RAM_PID"
echo "  • Storage Test: $STORAGE_PID"
echo ""

################################################################################
# MONITORING LOOP
################################################################################

log_phase "PHASE 2: MONITORING PARALLEL EXECUTION"

log_info "Monitoring all tests in real-time..."
log_info "Test duration: ${TEST_DURATION_HOURS} hours ($TEST_DURATION seconds)"
echo ""

# Create monitoring script
MONITOR_LOG="$LOG_DIR/monitoring/system_monitor.log"

# Start system monitoring in background
(
    echo "=== SYSTEM MONITORING DURING PARALLEL STRESS TEST ==="
    echo "Start Time: $(date)"
    echo ""

    MONITOR_INTERVAL=30  # Monitor every 30 seconds
    MONITOR_COUNT=0

    while kill -0 $CPU_PID 2>/dev/null || kill -0 $GPU_PID 2>/dev/null || kill -0 $RAM_PID 2>/dev/null || kill -0 $STORAGE_PID 2>/dev/null; do
        MONITOR_COUNT=$((MONITOR_COUNT + 1))

        echo "=== MONITOR SAMPLE #$MONITOR_COUNT - $(date) ==="

        # Get system stats from remote
        sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "bash -s" << 'MONITOR_REMOTE'
#!/bin/bash

echo "--- CPU Load ---"
uptime | awk '{print "Load Average: " $(NF-2) " " $(NF-1) " " $NF}'
echo ""

echo "--- Memory Usage ---"
free -h | grep -E "Mem:|Swap:"
echo ""

echo "--- Temperature ---"
cat /sys/devices/virtual/thermal/thermal_zone*/temp 2>/dev/null | awk '{printf "Zone: %.1f°C\n", $1/1000}' || echo "N/A"
echo ""

echo "--- GPU Status ---"
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null || echo "N/A"
echo ""

echo "--- Storage I/O ---"
iostat -x 1 2 2>/dev/null | tail -n +4 | head -5 || echo "N/A"
echo ""

MONITOR_REMOTE

        echo "----------------------------------------"
        echo ""

        sleep $MONITOR_INTERVAL
    done

    echo "=== MONITORING COMPLETED ==="
    echo "End Time: $(date)"

) > "$MONITOR_LOG" 2>&1 &

MONITOR_PID=$!

# Status checking loop
CHECK_INTERVAL=60  # Check status every 60 seconds
LAST_STATUS_TIME=$(date +%s)

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - TEST_START_TIME))
    REMAINING=$((TEST_DURATION - ELAPSED))

    # Check if all tests are still running
    CPU_RUNNING=false
    GPU_RUNNING=false
    RAM_RUNNING=false
    STORAGE_RUNNING=false

    kill -0 $CPU_PID 2>/dev/null && CPU_RUNNING=true
    kill -0 $GPU_PID 2>/dev/null && GPU_RUNNING=true
    kill -0 $RAM_PID 2>/dev/null && RAM_RUNNING=true
    kill -0 $STORAGE_PID 2>/dev/null && STORAGE_RUNNING=true

    # If all tests completed, break
    if ! $CPU_RUNNING && ! $GPU_RUNNING && ! $RAM_RUNNING && ! $STORAGE_RUNNING; then
        log_success "All tests completed!"
        break
    fi

    # Print status update every CHECK_INTERVAL seconds
    if [ $((CURRENT_TIME - LAST_STATUS_TIME)) -ge $CHECK_INTERVAL ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Status Update:"
        echo "  Time Elapsed: $(($ELAPSED / 60)) minutes / $(($TEST_DURATION / 60)) minutes"
        echo "  Time Remaining: $(($REMAINING / 60)) minutes"
        echo "  CPU Test:     $($CPU_RUNNING && echo "RUNNING" || echo "COMPLETED")"
        echo "  GPU Test:     $($GPU_RUNNING && echo "RUNNING" || echo "COMPLETED")"
        echo "  RAM Test:     $($RAM_RUNNING && echo "RUNNING" || echo "COMPLETED")"
        echo "  Storage Test: $($STORAGE_RUNNING && echo "RUNNING" || echo "COMPLETED")"
        echo ""

        LAST_STATUS_TIME=$CURRENT_TIME
    fi

    sleep 5
done

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

echo ""

################################################################################
# WAIT FOR ALL TESTS TO COMPLETE
################################################################################

log_phase "PHASE 3: COLLECTING TEST RESULTS"

log_info "Waiting for all tests to complete..."

# Wait for each test and capture exit codes
wait $CPU_PID 2>/dev/null
CPU_EXIT=$?
log_info "CPU test finished with exit code: $CPU_EXIT"

wait $GPU_PID 2>/dev/null
GPU_EXIT=$?
log_info "GPU test finished with exit code: $GPU_EXIT"

wait $RAM_PID 2>/dev/null
RAM_EXIT=$?
log_info "RAM test finished with exit code: $RAM_EXIT"

wait $STORAGE_PID 2>/dev/null
STORAGE_EXIT=$?
log_info "Storage test finished with exit code: $STORAGE_EXIT"

TEST_END_TIME=$(date +%s)
TOTAL_DURATION=$((TEST_END_TIME - TEST_START_TIME))

echo ""
log_success "All tests have completed!"
echo ""

################################################################################
# CAPTURE FINAL SYSTEM STATE
################################################################################

log_info "Capturing final system state..."

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "bash -s" << 'FINAL_SCRIPT' > "$LOG_DIR/logs/final_state.log" 2>&1
#!/bin/bash

echo "=== SYSTEM STATE AFTER PARALLEL STRESS TEST ==="
echo "Timestamp: $(date)"
echo ""

echo "=== THERMAL STATE ==="
cat /sys/devices/virtual/thermal/thermal_zone*/temp 2>/dev/null | awk '{print "Thermal Zone: " $1/1000 "°C"}' || echo "Temperature sensors not available"
echo ""

echo "=== MEMORY STATE ==="
free -h
echo ""

echo "=== GPU STATE ==="
nvidia-smi 2>/dev/null || echo "nvidia-smi not available"
echo ""

echo "=== SYSTEM ERRORS ==="
dmesg | tail -100 | grep -i "error\|fail\|warn" | tail -20 || echo "No recent errors"
echo ""

echo "=== LOAD AVERAGE ==="
uptime
echo ""

FINAL_SCRIPT

log_success "Final state captured"
echo ""

################################################################################
# GENERATE COMBINED REPORT
################################################################################

log_phase "PHASE 4: GENERATING COMBINED REPORT"

REPORT_FILE="$LOG_DIR/reports/COMBINED_TEST_REPORT.txt"

{
    echo "================================================================================"
    echo "  JETSON ORIN COMBINED PARALLEL STRESS TEST - FINAL REPORT"
    echo "================================================================================"
    echo ""
    echo "Test Information:"
    echo "  • Device IP: $ORIN_IP"
    echo "  • Test Duration: ${TEST_DURATION_HOURS} hours ($TEST_DURATION seconds)"
    echo "  • Actual Duration: $(($TOTAL_DURATION / 60)) minutes"
    echo "  • Start Time: $(date -d @$TEST_START_TIME '+%Y-%m-%d %H:%M:%S')"
    echo "  • End Time: $(date -d @$TEST_END_TIME '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Personnel:"
    echo "  • Tester: $TESTER_NAME"
    echo "  • Quality Checker: $QUALITY_CHECKER_NAME"
    echo ""

    echo "================================================================================"
    echo "  TEST RESULTS SUMMARY"
    echo "================================================================================"
    echo ""

    # CPU Test Results
    echo "--- CPU STRESS TEST ---"
    if [ $CPU_EXIT -eq 0 ]; then
        echo "  Status: ✓ PASSED"
    else
        echo "  Status: ✗ FAILED (Exit Code: $CPU_EXIT)"
    fi

    if [ -f "$LOG_DIR/cpu_test/reports/CPU_PERFORMANCE_REPORT.txt" ]; then
        echo "  Report: Available at cpu_test/reports/CPU_PERFORMANCE_REPORT.txt"
        # Extract key metrics if available
        grep -A 5 "OVERALL CPU HEALTH" "$LOG_DIR/cpu_test/reports/CPU_PERFORMANCE_REPORT.txt" 2>/dev/null | head -10 || echo "  Details in full report"
    else
        echo "  Report: Not generated (test may have failed early)"
    fi
    echo ""

    # GPU Test Results
    echo "--- GPU STRESS TEST ---"
    if [ $GPU_EXIT -eq 0 ]; then
        echo "  Status: ✓ PASSED"
    else
        echo "  Status: ✗ FAILED (Exit Code: $GPU_EXIT)"
    fi

    if [ -f "$LOG_DIR/gpu_test/reports/GPU_TEST_REPORT.txt" ]; then
        echo "  Report: Available at gpu_test/reports/GPU_TEST_REPORT.txt"
        grep -A 5 "FINAL VERDICT" "$LOG_DIR/gpu_test/reports/GPU_TEST_REPORT.txt" 2>/dev/null | head -10 || echo "  Details in full report"
    else
        echo "  Report: Not generated (test may have failed early)"
    fi
    echo ""

    # RAM Test Results
    echo "--- RAM STRESS TEST ---"
    if [ $RAM_EXIT -eq 0 ]; then
        echo "  Status: ✓ PASSED"
    else
        echo "  Status: ✗ FAILED (Exit Code: $RAM_EXIT)"
    fi

    if [ -f "$LOG_DIR/ram_test/reports/ram_test_summary.txt" ]; then
        echo "  Report: Available at ram_test/reports/ram_test_summary.txt"
        grep -A 3 "VERDICT" "$LOG_DIR/ram_test/reports/ram_test_summary.txt" 2>/dev/null || echo "  Details in full report"
    else
        echo "  Report: Not generated (test may have failed early)"
    fi
    echo ""

    # Storage Test Results
    echo "--- STORAGE STRESS TEST ---"
    if [ $STORAGE_EXIT -eq 0 ]; then
        echo "  Status: ✓ PASSED"
    else
        echo "  Status: ✗ FAILED (Exit Code: $STORAGE_EXIT)"
    fi

    if [ -f "$LOG_DIR/storage_test/reports/DISK_PERFORMANCE_REPORT.txt" ]; then
        echo "  Report: Available at storage_test/reports/DISK_PERFORMANCE_REPORT.txt"
        grep -A 5 "PERFORMANCE RATING" "$LOG_DIR/storage_test/reports/DISK_PERFORMANCE_REPORT.txt" 2>/dev/null | head -10 || echo "  Details in full report"
    else
        echo "  Report: Not generated (test may have failed early)"
    fi
    echo ""

    echo "================================================================================"
    echo "  OVERALL SYSTEM ASSESSMENT"
    echo "================================================================================"
    echo ""

    # Calculate overall pass/fail
    TOTAL_TESTS=4
    PASSED_TESTS=0
    [ $CPU_EXIT -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
    [ $GPU_EXIT -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
    [ $RAM_EXIT -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
    [ $STORAGE_EXIT -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))

    PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

    echo "Test Pass Rate: $PASSED_TESTS/$TOTAL_TESTS tests passed ($PASS_RATE%)"
    echo ""

    if [ $PASS_RATE -eq 100 ]; then
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "  ✓✓✓ OVERALL VERDICT: EXCELLENT ✓✓✓"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "All stress tests passed successfully under parallel load!"
        echo ""
        echo "System Capabilities:"
        echo "  ✓ CPU can handle intensive multi-core workloads"
        echo "  ✓ GPU performs well under combined CUDA/VPU/Graphics stress"
        echo "  ✓ RAM maintains integrity under memory-intensive operations"
        echo "  ✓ Storage I/O remains stable under sustained load"
        echo ""
        echo "Conclusion:"
        echo "  This Jetson Orin system demonstrates excellent stability and performance"
        echo "  under maximum combined stress conditions. It is suitable for demanding"
        echo "  production workloads that require simultaneous CPU, GPU, RAM, and I/O"
        echo "  intensive operations."
        echo ""
    elif [ $PASS_RATE -ge 75 ]; then
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "  ⚠ OVERALL VERDICT: ACCEPTABLE WITH CONCERNS ⚠"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Most tests passed, but some components showed issues under parallel load."
        echo ""
        echo "Recommendations:"
        echo "  • Review individual test reports for failed components"
        echo "  • Run individual tests to isolate issues"
        echo "  • Check thermal management and cooling"
        echo "  • Monitor system during production workloads"
        echo ""
    else
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "  ✗✗✗ OVERALL VERDICT: SYSTEM ISSUES DETECTED ✗✗✗"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Multiple components failed under parallel stress conditions."
        echo ""
        echo "Critical Actions Required:"
        echo "  • Review all individual test reports immediately"
        echo "  • Check system logs for hardware errors"
        echo "  • Verify thermal management and cooling systems"
        echo "  • Consider hardware diagnostics or replacement"
        echo "  • Do not use for critical production workloads until issues are resolved"
        echo ""
    fi

    echo "================================================================================"
    echo "  DETAILED RESULTS LOCATION"
    echo "================================================================================"
    echo ""
    echo "All test results are available in: $LOG_DIR"
    echo ""
    echo "Directory Structure:"
    echo "  • cpu_test/      - CPU stress test results"
    echo "  • gpu_test/      - GPU stress test results"
    echo "  • ram_test/      - RAM stress test results"
    echo "  • storage_test/  - Storage test results"
    echo "  • monitoring/    - System monitoring logs during parallel execution"
    echo "  • logs/          - Orchestration and baseline logs"
    echo "  • reports/       - This combined report"
    echo ""

    echo "================================================================================"
    echo "  SYSTEM MONITORING SUMMARY"
    echo "================================================================================"
    echo ""

    if [ -f "$LOG_DIR/monitoring/system_monitor.log" ]; then
        echo "System was monitored throughout the test. Key observations:"
        echo ""

        # Extract thermal data
        MAX_TEMP=$(grep "Zone:" "$LOG_DIR/monitoring/system_monitor.log" | grep -oP '\d+\.\d+' | sort -n | tail -1)
        if [ -n "$MAX_TEMP" ]; then
            echo "  • Maximum Temperature: ${MAX_TEMP}°C"

            if (( $(echo "$MAX_TEMP > 90" | bc -l) )); then
                echo "    ⚠ WARNING: High temperature detected! Check cooling."
            elif (( $(echo "$MAX_TEMP > 80" | bc -l) )); then
                echo "    Note: Elevated temperature, consider improved cooling."
            else
                echo "    ✓ Temperature remained within normal range."
            fi
        fi
        echo ""

        echo "  Full monitoring log: monitoring/system_monitor.log"
    else
        echo "  Monitoring data not available"
    fi
    echo ""

    echo "================================================================================"
    echo "  RECOMMENDATIONS"
    echo "================================================================================"
    echo ""

    if [ $PASS_RATE -eq 100 ]; then
        echo "General Best Practices:"
        echo "  • Run combined parallel tests monthly for production systems"
        echo "  • Monitor temperatures during heavy workloads"
        echo "  • Keep system firmware and drivers updated"
        echo "  • Ensure adequate cooling for sustained operations"
        echo "  • Consider thermal pads/heatsinks for intensive 24/7 workloads"
    else
        echo "Troubleshooting Steps:"
        echo "  1. Review individual test reports to identify failing components"
        echo "  2. Run tests individually to isolate issues"
        echo "  3. Check system logs: dmesg, syslog for hardware errors"
        echo "  4. Verify thermal management (fans, heatsinks, thermal paste)"
        echo "  5. Test with reduced workload to see if issues persist"
        echo "  6. Contact NVIDIA support if hardware issues suspected"
    fi
    echo ""

    echo "================================================================================"
    echo ""
    echo "Report Generated: $(date)"
    echo "Test System: Jetson Orin @ $ORIN_IP"
    echo ""
    echo "================================================================================"

} > "$REPORT_FILE"

log_success "Combined report generated: $REPORT_FILE"
echo ""

################################################################################
# DISPLAY FINAL SUMMARY
################################################################################

echo "================================================================================"
echo "  COMBINED PARALLEL STRESS TEST - COMPLETED"
echo "================================================================================"
echo ""
echo "Test Results:"
echo "  • CPU Test:     $([ $CPU_EXIT -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
echo "  • GPU Test:     $([ $GPU_EXIT -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
echo "  • RAM Test:     $([ $RAM_EXIT -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
echo "  • Storage Test: $([ $STORAGE_EXIT -eq 0 ] && echo "✓ PASSED" || echo "✗ FAILED")"
echo ""

TOTAL_TESTS=4
PASSED_TESTS=0
[ $CPU_EXIT -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ $GPU_EXIT -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ $RAM_EXIT -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))
[ $STORAGE_EXIT -eq 0 ] && PASSED_TESTS=$((PASSED_TESTS + 1))

PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

echo "Overall: $PASSED_TESTS/$TOTAL_TESTS tests passed ($PASS_RATE%)"
echo ""
echo "Results Directory: $LOG_DIR"
echo ""
echo "Key Files:"
echo "  • Combined Report:   $LOG_DIR/reports/COMBINED_TEST_REPORT.txt"
echo "  • System Monitoring: $LOG_DIR/monitoring/system_monitor.log"
echo "  • Baseline State:    $LOG_DIR/logs/baseline.log"
echo "  • Final State:       $LOG_DIR/logs/final_state.log"
echo ""
echo "Individual Test Reports:"
echo "  • CPU:     $LOG_DIR/cpu_test/reports/"
echo "  • GPU:     $LOG_DIR/gpu_test/reports/"
echo "  • RAM:     $LOG_DIR/ram_test/reports/"
echo "  • Storage: $LOG_DIR/storage_test/reports/"
echo ""

# Display excerpt from combined report
echo "================================================================================"
cat "$REPORT_FILE" | grep -A 30 "OVERALL SYSTEM ASSESSMENT"
echo "================================================================================"
echo ""

################################################################################
# AUTOMATIC PDF GENERATION
################################################################################

echo ""
log_info "Generating PDF reports for each test..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PDF_GENERATOR="$SCRIPT_DIR/generate_pdf_reports.sh"

if [ -f "$PDF_GENERATOR" ]; then
    PDF_SUCCESS=0

    # Generate PDFs for each test type
    for TEST_TYPE in cpu gpu ram storage; do
        TEST_DIR="$LOG_DIR/${TEST_TYPE}_test"
        if [ -d "$TEST_DIR" ]; then
            if "$PDF_GENERATOR" --test-type "$TEST_TYPE" "$TEST_DIR" > /dev/null 2>&1; then
                log_info "Generated PDFs for $TEST_TYPE test"
                PDF_SUCCESS=$((PDF_SUCCESS + 1))
            fi
        fi
    done

    # Generate combined PDF for main directory
    if "$PDF_GENERATOR" --test-type combined "$LOG_DIR" > /dev/null 2>&1; then
        PDF_SUCCESS=$((PDF_SUCCESS + 1))
    fi

    if [ $PDF_SUCCESS -gt 0 ]; then
        log_success "PDF reports generated successfully"
        echo "[*] PDF Reports organized by test type in: $LOG_DIR/pdf_reports/"
    else
        log_warning "PDF generation failed (test results still available)"
    fi
else
    log_warning "PDF generator not found (test results still available)"
fi
echo ""

if [ $PASS_RATE -eq 100 ]; then
    log_success "All tests passed! System is performing excellently under combined load."
    exit 0
elif [ $PASS_RATE -ge 75 ]; then
    log_warning "Most tests passed, but some issues detected. Review individual reports."
    exit 1
else
    log_error "Multiple tests failed. System requires attention."
    exit 1
fi
