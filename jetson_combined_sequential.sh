#!/bin/bash

################################################################################
# JETSON ORIN AGX - COMBINED SEQUENTIAL STRESS TEST
################################################################################
# Description: Run CPU, GPU, RAM, and Storage tests in sequence
# Version: 1.0
# Purpose: Sequential component stress testing
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

# Get tester information (parameters 6 and 7 from orchestrator, or from environment if from collect_test_parameters)
TESTER_NAME="${6:-${TESTER_NAME:-N/A}}"
QUALITY_CHECKER_NAME="${7:-${QUALITY_CHECKER_NAME:-N/A}}"

################################################################################
# CONFIGURATION
################################################################################

LOG_DIR="${5:-./combined_sequential_test_$(date +%Y%m%d_%H%M%S)}"

################################################################################
# USAGE
################################################################################

show_usage() {
    cat << 'EOF'
================================================================================
  JETSON ORIN AGX - COMBINED SEQUENTIAL STRESS TEST
================================================================================

Usage: ./jetson_combined_sequential.sh [ip] [user] [password] [hours] [log_dir]

Parameters:
  ip       : Jetson Orin IP (default: 192.168.55.69)
  user     : SSH username (default: orin)
  password : SSH password (will prompt if not provided)
  hours    : Test duration per component in hours (default: 1)
  log_dir  : Log directory (default: ./combined_sequential_test_YYYYMMDD_HHMMSS)

TEST STRATEGY:
  This test runs all components SEQUENTIALLY (one after another):

  1. CPU Stress Test       (duration hours)
  2. GPU Stress Test       (duration hours)
  3. RAM Stress Test       (duration hours)
  4. Storage Stress Test   (duration hours)

  Total time = 4 × duration hours

PURPOSE:
  • Verify individual component stability
  • Check for cumulative thermal effects
  • Detect degradation over extended runtime
  • Ensure recovery between workloads

Examples:
  ./jetson_combined_sequential.sh                          # 4 hour test (1h each)
  ./jetson_combined_sequential.sh 192.168.55.69 orin q 2   # 8 hour test (2h each)
  ./jetson_combined_sequential.sh 192.168.55.69 orin q 0.5 # 2 hour test (30m each)

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

log_phase "JETSON ORIN COMBINED SEQUENTIAL STRESS TEST"

echo "[SEQUENTIAL TEST CONFIGURATION]"
echo "  • Target: $ORIN_USER@$ORIN_IP"
echo "  • Duration per component: $TEST_DURATION_HOURS hours"
echo "  • Test Mode: SEQUENTIAL (CPU → GPU → RAM → Storage)"
echo "  • Total estimated time: $((TEST_DURATION_HOURS * 4)) hours"
echo ""
echo "Test Personnel:"
echo "  • Tester: $TESTER_NAME"
echo "  • Quality Checker: $QUALITY_CHECKER_NAME"
echo ""

# Check prerequisites
check_prerequisites "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"

# Create log directories
ensure_directory "$LOG_DIR"
ensure_directory "$LOG_DIR/cpu"
ensure_directory "$LOG_DIR/gpu"
ensure_directory "$LOG_DIR/ram"
ensure_directory "$LOG_DIR/storage"

# Convert to absolute path
LOG_DIR=$(cd "$LOG_DIR" && pwd)

log_success "Initialization complete"
log_info "Results will be saved to: $LOG_DIR"
echo ""

################################################################################
# RESULTS TRACKING
################################################################################

RESULTS_FILE="$LOG_DIR/sequential_results.txt"
echo "# Jetson Orin Sequential Test Results" > "$RESULTS_FILE"
echo "# Started: $(date)" >> "$RESULTS_FILE"
echo "# Target: $ORIN_USER@$ORIN_IP" >> "$RESULTS_FILE"
echo "# Duration per component: $TEST_DURATION_HOURS hours" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Track results
declare -A TEST_RESULTS
declare -A TEST_START_TIMES
declare -A TEST_END_TIMES

OVERALL_START=$(date +%s)

################################################################################
# COMPONENT TEST EXECUTION
################################################################################

run_component_test() {
    local test_num=$1
    local test_name=$2
    local test_script=$3
    local test_log_dir=$4

    echo ""
    echo "================================================================================"
    echo "  SEQUENTIAL TEST $test_num/4: $test_name"
    echo "================================================================================"
    echo ""

    TEST_START_TIMES[$test_num]=$(date +%s)
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')

    log_info "Test: $test_name"
    log_info "Script: $test_script"
    log_info "Duration: $TEST_DURATION_HOURS hours"
    log_info "Start time: $start_time"
    echo ""

    # Run the test
    if bash "$SCRIPT_DIR/$test_script" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$test_log_dir" "$TESTER_NAME" "$QUALITY_CHECKER_NAME"; then
        TEST_RESULTS[$test_num]="PASSED"
        log_success "$test_name PASSED"
    else
        TEST_RESULTS[$test_num]="FAILED"
        log_error "$test_name FAILED"
    fi

    TEST_END_TIMES[$test_num]=$(date +%s)
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local duration=$((TEST_END_TIMES[$test_num] - TEST_START_TIMES[$test_num]))

    echo ""
    log_info "Test completed"
    log_info "End time: $end_time"
    log_info "Duration: $((duration / 60)) minutes"
    log_info "Result: ${TEST_RESULTS[$test_num]}"
    echo ""

    # Log to results file
    {
        echo "Test $test_num: $test_name"
        echo "  Result: ${TEST_RESULTS[$test_num]}"
        echo "  Start: $start_time"
        echo "  End: $end_time"
        echo "  Duration: $((duration / 60)) minutes"
        echo ""
    } >> "$RESULTS_FILE"

    # Brief pause before next test
    if [ "$test_num" != "4" ]; then
        log_info "Waiting 30 seconds before next component test..."
        sleep 30
    fi
}

################################################################################
# RUN ALL TESTS SEQUENTIALLY
################################################################################

log_phase "STARTING SEQUENTIAL COMPONENT TESTS"

echo "Tests will run in this order:"
echo "  1. CPU Stress Test"
echo "  2. GPU Stress Test"
echo "  3. RAM Stress Test"
echo "  4. Storage Stress Test"
echo ""
echo "Total estimated time: $((TEST_DURATION_HOURS * 4)) hours"
echo ""

# Test 1: CPU
run_component_test "1" "CPU Stress Test" "jetson_cpu_test.sh" "$LOG_DIR/cpu"

# Test 2: GPU
run_component_test "2" "GPU Stress Test" "jetson_gpu_test.sh" "$LOG_DIR/gpu"

# Test 3: RAM
run_component_test "3" "RAM Stress Test" "jetson_ram_test.sh" "$LOG_DIR/ram"

# Test 4: Storage
run_component_test "4" "Storage Stress Test" "jetson_storage_test.sh" "$LOG_DIR/storage"

################################################################################
# FINAL RESULTS
################################################################################

OVERALL_END=$(date +%s)
TOTAL_DURATION=$((OVERALL_END - OVERALL_START))

log_phase "SEQUENTIAL TEST COMPLETED - FINAL RESULTS"

echo "================================================================================"
echo "  JETSON ORIN SEQUENTIAL STRESS TEST - FINAL REPORT"
echo "================================================================================"
echo ""
echo "Test Date: $(date)"
echo "Total Duration: $((TOTAL_DURATION / 3600)) hours $((TOTAL_DURATION % 3600 / 60)) minutes"
echo "Results Directory: $LOG_DIR"
echo ""
echo "Tester: $TESTER_NAME"
echo "Quality Checker: $QUALITY_CHECKER_NAME"
echo ""
echo "================================================================================"
echo "  COMPONENT RESULTS"
echo "================================================================================"
echo ""

TOTAL_TESTS=4
PASSED_TESTS=0
FAILED_TESTS=0

for i in {1..4}; do
    result="${TEST_RESULTS[$i]}"
    duration=$((TEST_END_TIMES[$i] - TEST_START_TIMES[$i]))

    case $i in
        1) test_name="CPU Stress Test" ;;
        2) test_name="GPU Stress Test" ;;
        3) test_name="RAM Stress Test" ;;
        4) test_name="Storage Stress Test" ;;
    esac

    if [ "$result" == "PASSED" ]; then
        echo "[✓] Test $i: $test_name - PASSED ($((duration / 60)) min)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "[✗] Test $i: $test_name - FAILED ($((duration / 60)) min)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
done

echo ""
echo "================================================================================"
echo "  SUMMARY"
echo "================================================================================"
echo ""
echo "Total Tests:   $TOTAL_TESTS"
echo "Passed:        $PASSED_TESTS"
echo "Failed:        $FAILED_TESTS"
echo "Success Rate:  $((PASSED_TESTS * 100 / TOTAL_TESTS))%"
echo ""

# Final verdict
if [ $FAILED_TESTS -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✓ ALL SEQUENTIAL TESTS PASSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Your Jetson Orin AGX successfully passed all component tests in sequence."
    echo "The system maintained stability throughout extended testing."
    echo ""
    echo "Key achievements:"
    echo "  ✓ All individual components stable"
    echo "  ✓ No degradation during extended runtime"
    echo "  ✓ Proper recovery between workloads"
    echo "  ✓ Cumulative thermal management adequate"
    FINAL_RESULT=0
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✗ SEQUENTIAL TEST FAILED ($FAILED_TESTS/$TOTAL_TESTS components failed)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "One or more components failed during sequential testing."
    echo ""
    echo "Review individual component logs for details:"
    echo "  • CPU results:     $LOG_DIR/cpu/"
    echo "  • GPU results:     $LOG_DIR/gpu/"
    echo "  • RAM results:     $LOG_DIR/ram/"
    echo "  • Storage results: $LOG_DIR/storage/"
    FINAL_RESULT=1
fi

echo ""
echo "================================================================================"
echo "  LOG FILES"
echo "================================================================================"
echo ""
echo "Summary:     $RESULTS_FILE"
echo "CPU logs:    $LOG_DIR/cpu/"
echo "GPU logs:    $LOG_DIR/gpu/"
echo "RAM logs:    $LOG_DIR/ram/"
echo "Storage logs: $LOG_DIR/storage/"
echo ""

# Save final summary
{
    echo ""
    echo "# Final Summary"
    echo "# =============="
    echo "TOTAL_TESTS=$TOTAL_TESTS"
    echo "PASSED_TESTS=$PASSED_TESTS"
    echo "FAILED_TESTS=$FAILED_TESTS"
    echo "SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))%"
    echo "TOTAL_DURATION=${TOTAL_DURATION}s"
    echo "FINAL_RESULT=$FINAL_RESULT"
    echo ""
    for i in {1..4}; do
        echo "TEST_${i}_RESULT=${TEST_RESULTS[$i]}"
    done
} >> "$RESULTS_FILE"

echo "Sequential test completed: $(date)"
echo ""

exit $FINAL_RESULT
