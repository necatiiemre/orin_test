#!/bin/bash

################################################################################
# JETSON ORIN AGX - MASTER TEST ORCHESTRATOR
################################################################################
# Description: Comprehensive test suite orchestrator for Jetson Orin AGX
# Version: 1.0
# Purpose: Run all stress tests in optimal sequence
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# CONFIGURATION
################################################################################

ORIN_IP="${1:-192.168.55.69}"
ORIN_USER="${2:-orin}"
ORIN_PASS="${3}"
TEST_DURATION_HOURS="${4:-1}"  # Default 1 hour per test

# Master log directory
MASTER_LOG_DIR="./jetson_orchestrator_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$MASTER_LOG_DIR"
MASTER_LOG_DIR=$(cd "$MASTER_LOG_DIR" && pwd)

################################################################################
# COLOR OUTPUT
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

################################################################################
# LOGGING FUNCTIONS
################################################################################

log_phase() {
    echo ""
    echo "================================================================================"
    echo -e "${MAGENTA}${BOLD}$1${NC}"
    echo "================================================================================"
    echo ""
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $(date '+%H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"
}

log_test_start() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  TEST $1: $2${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

################################################################################
# USAGE
################################################################################

show_usage() {
    cat << 'EOF'
================================================================================
  JETSON ORIN AGX - MASTER TEST ORCHESTRATOR
================================================================================

Usage: ./jetson_test_orchestrator.sh [ip] [user] [password] [hours_per_test]

Parameters:
  ip              : Jetson Orin IP (default: 192.168.55.69)
  user            : SSH username (default: orin)
  password        : SSH password (will prompt if not provided)
  hours_per_test  : Duration per test in hours (default: 1)

TEST SEQUENCE:
  This orchestrator runs a comprehensive test suite in 6 phases:

  Phase 1: CPU Stress Test
    • Single-core and multi-core stress
    • Memory/cache torture
    • Health scoring

  Phase 2: GPU Stress Test
    • VPU (Video Processing Unit) stress
    • CUDA compute stress
    • Graphics pipeline stress

  Phase 3: RAM Stress Test
    • Pattern verification
    • Integrity checking
    • Multi-threaded stress

  Phase 4: Storage Stress Test
    • Sequential and random I/O
    • Filesystem metadata stress
    • Health monitoring

  Phase 5: Sequential Combined Test
    • All tests run in sequence
    • Verifies individual component stability
    • Total time = 4 × test_duration

  Phase 6: Parallel Combined Test
    • All components stressed SIMULTANEOUSLY
    • Maximum system stress
    • Tests power, thermal, and stability limits

TOTAL ESTIMATED TIME:
  With 1 hour per test: ~6 hours total
  With 2 hours per test: ~12 hours total

INTENSITY LEVELS:
  Individual Tests (1-4): Component-specific stress
  Sequential (5):         Cumulative component stress
  Parallel (6):           MAXIMUM simultaneous stress

Examples:
  ./jetson_test_orchestrator.sh                         # 6 hour test suite
  ./jetson_test_orchestrator.sh 192.168.55.69 orin q 2  # 12 hour test suite
  ./jetson_test_orchestrator.sh 192.168.55.69 orin q 0.5 # 3 hour quick test

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

log_phase "JETSON ORIN TEST ORCHESTRATOR - INITIALIZATION"

echo "Test Configuration:"
echo "  • Target: $ORIN_USER@$ORIN_IP"
echo "  • Duration per test: $TEST_DURATION_HOURS hours"
echo "  • Master log directory: $MASTER_LOG_DIR"
echo "  • Script directory: $SCRIPT_DIR"
echo ""

# Password check
if [ -z "$ORIN_PASS" ]; then
    read -sp "Enter SSH password for $ORIN_USER@$ORIN_IP: " ORIN_PASS
    echo ""
fi

# Verify scripts exist
log_info "Verifying test scripts..."

REQUIRED_SCRIPTS=(
    "jetson_system_prep.sh"
    "jetson_cpu_test.sh"
    "jetson_gpu_test.sh"
    "jetson_storage_test.sh"
    "jetson_combined_parallel_test.sh"
    "ram/complete_ram_test.sh"
)

MISSING_SCRIPTS=0
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        log_error "Missing required script: $script"
        MISSING_SCRIPTS=$((MISSING_SCRIPTS + 1))
    else
        log_success "Found: $script"
    fi
done

if [ $MISSING_SCRIPTS -gt 0 ]; then
    log_error "$MISSING_SCRIPTS required scripts are missing!"
    exit 1
fi

log_success "All required scripts found"
echo ""

# Test SSH connection
log_info "Testing SSH connection to $ORIN_IP..."
if ! command -v sshpass &> /dev/null; then
    log_error "sshpass is not installed. Please install it first."
    exit 1
fi

if ! sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'OK'" 2>/dev/null | grep -q "OK"; then
    log_error "SSH connection failed. Check IP, username, and password."
    exit 1
fi

log_success "SSH connection verified"
echo ""

# Initialize results tracking
RESULTS_FILE="$MASTER_LOG_DIR/orchestrator_results.txt"
echo "# Jetson Orin Test Orchestrator Results" > "$RESULTS_FILE"
echo "# Started: $(date)" >> "$RESULTS_FILE"
echo "# Target: $ORIN_USER@$ORIN_IP" >> "$RESULTS_FILE"
echo "# Duration per test: $TEST_DURATION_HOURS hours" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Track test results
declare -A TEST_RESULTS
declare -A TEST_START_TIMES
declare -A TEST_END_TIMES

OVERALL_START_TIME=$(date +%s)

################################################################################
# TEST EXECUTION FUNCTION
################################################################################

run_test() {
    local test_num=$1
    local test_name=$2
    local test_script=$3
    local test_duration=$4
    local extra_args="${5:-}"

    log_test_start "$test_num" "$test_name"

    TEST_START_TIMES[$test_num]=$(date +%s)
    local start_time_formatted=$(date '+%Y-%m-%d %H:%M:%S')

    log_info "Test: $test_name"
    log_info "Script: $test_script"
    log_info "Duration: $test_duration hours"
    log_info "Start time: $start_time_formatted"
    echo ""

    # Create test-specific log directory
    local test_log_dir="$MASTER_LOG_DIR/test${test_num}_${test_name// /_}"
    mkdir -p "$test_log_dir"

    log_info "Executing test..."
    echo ""

    # Run the test
    if bash "$SCRIPT_DIR/$test_script" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$test_duration" "$test_log_dir" $extra_args; then
        TEST_RESULTS[$test_num]="PASSED"
        log_success "Test $test_num ($test_name) PASSED"
    else
        TEST_RESULTS[$test_num]="FAILED"
        log_error "Test $test_num ($test_name) FAILED"
    fi

    TEST_END_TIMES[$test_num]=$(date +%s)
    local end_time_formatted=$(date '+%Y-%m-%d %H:%M:%S')
    local duration=$((TEST_END_TIMES[$test_num] - TEST_START_TIMES[$test_num]))

    echo ""
    log_info "Test completed"
    log_info "End time: $end_time_formatted"
    log_info "Actual duration: $((duration / 60)) minutes"
    log_info "Result: ${TEST_RESULTS[$test_num]}"
    echo ""

    # Log to results file
    {
        echo "Test $test_num: $test_name"
        echo "  Result: ${TEST_RESULTS[$test_num]}"
        echo "  Start: $start_time_formatted"
        echo "  End: $end_time_formatted"
        echo "  Duration: $((duration / 60)) minutes"
        echo "  Log Directory: $test_log_dir"
        echo ""
    } >> "$RESULTS_FILE"

    # Brief pause between tests
    if [ "$test_num" != "6" ]; then
        log_info "Waiting 30 seconds before next test..."
        sleep 30
    fi
}

################################################################################
# SYSTEM PREPARATION
################################################################################

log_phase "PHASE 0: SYSTEM PREPARATION"

log_info "Running system preparation to ensure all dependencies are installed..."
echo ""

if bash "$SCRIPT_DIR/jetson_system_prep.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$MASTER_LOG_DIR/system_prep"; then
    log_success "System preparation completed successfully"
else
    log_warning "System preparation completed with warnings (check logs)"
fi

echo ""
log_info "Waiting 60 seconds for system to stabilize..."
sleep 60

################################################################################
# TEST PHASE 1: CPU STRESS TEST
################################################################################

run_test "1" "CPU Stress Test" "jetson_cpu_test.sh" "$TEST_DURATION_HOURS"

################################################################################
# TEST PHASE 2: GPU STRESS TEST
################################################################################

run_test "2" "GPU Stress Test" "jetson_gpu_test.sh" "$TEST_DURATION_HOURS"

################################################################################
# TEST PHASE 3: RAM STRESS TEST
################################################################################

run_test "3" "RAM Stress Test" "ram/complete_ram_test.sh" "$TEST_DURATION_HOURS"

################################################################################
# TEST PHASE 4: STORAGE STRESS TEST
################################################################################

run_test "4" "Storage Stress Test" "jetson_storage_test.sh" "$TEST_DURATION_HOURS"

################################################################################
# TEST PHASE 5: SEQUENTIAL COMBINED TEST
################################################################################

log_test_start "5" "Sequential Combined Test (All Components in Sequence)"

log_info "This phase re-runs all component tests in sequence to verify cumulative stability."
log_info "Total duration: $((TEST_DURATION_HOURS * 4)) hours"
echo ""

SEQUENTIAL_START=$(date +%s)
SEQUENTIAL_PASSED=0
SEQUENTIAL_FAILED=0

log_info "[Sequential 1/4] Running CPU test..."
if bash "$SCRIPT_DIR/jetson_cpu_test.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$MASTER_LOG_DIR/test5_sequential/cpu"; then
    SEQUENTIAL_PASSED=$((SEQUENTIAL_PASSED + 1))
    log_success "Sequential CPU test PASSED"
else
    SEQUENTIAL_FAILED=$((SEQUENTIAL_FAILED + 1))
    log_error "Sequential CPU test FAILED"
fi

log_info "[Sequential 2/4] Running GPU test..."
if bash "$SCRIPT_DIR/jetson_gpu_test.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$MASTER_LOG_DIR/test5_sequential/gpu"; then
    SEQUENTIAL_PASSED=$((SEQUENTIAL_PASSED + 1))
    log_success "Sequential GPU test PASSED"
else
    SEQUENTIAL_FAILED=$((SEQUENTIAL_FAILED + 1))
    log_error "Sequential GPU test FAILED"
fi

log_info "[Sequential 3/4] Running RAM test..."
if bash "$SCRIPT_DIR/ram/complete_ram_test.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$MASTER_LOG_DIR/test5_sequential/ram"; then
    SEQUENTIAL_PASSED=$((SEQUENTIAL_PASSED + 1))
    log_success "Sequential RAM test PASSED"
else
    SEQUENTIAL_FAILED=$((SEQUENTIAL_FAILED + 1))
    log_error "Sequential RAM test FAILED"
fi

log_info "[Sequential 4/4] Running Storage test..."
if bash "$SCRIPT_DIR/jetson_storage_test.sh" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$MASTER_LOG_DIR/test5_sequential/storage"; then
    SEQUENTIAL_PASSED=$((SEQUENTIAL_PASSED + 1))
    log_success "Sequential Storage test PASSED"
else
    SEQUENTIAL_FAILED=$((SEQUENTIAL_FAILED + 1))
    log_error "Sequential Storage test FAILED"
fi

SEQUENTIAL_END=$(date +%s)
SEQUENTIAL_DURATION=$((SEQUENTIAL_END - SEQUENTIAL_START))

if [ $SEQUENTIAL_FAILED -eq 0 ]; then
    TEST_RESULTS[5]="PASSED"
    log_success "Sequential Combined Test PASSED ($SEQUENTIAL_PASSED/4 components)"
else
    TEST_RESULTS[5]="FAILED"
    log_error "Sequential Combined Test FAILED ($SEQUENTIAL_PASSED/4 passed, $SEQUENTIAL_FAILED/4 failed)"
fi

TEST_START_TIMES[5]=$SEQUENTIAL_START
TEST_END_TIMES[5]=$SEQUENTIAL_END

{
    echo "Test 5: Sequential Combined Test"
    echo "  Result: ${TEST_RESULTS[5]}"
    echo "  Duration: $((SEQUENTIAL_DURATION / 60)) minutes"
    echo "  Components Passed: $SEQUENTIAL_PASSED/4"
    echo "  Components Failed: $SEQUENTIAL_FAILED/4"
    echo ""
} >> "$RESULTS_FILE"

################################################################################
# TEST PHASE 6: PARALLEL COMBINED TEST
################################################################################

run_test "6" "Parallel Combined Test (All Components Simultaneously)" "jetson_combined_parallel_test.sh" "$TEST_DURATION_HOURS"

################################################################################
# FINAL RESULTS SUMMARY
################################################################################

OVERALL_END_TIME=$(date +%s)
TOTAL_DURATION=$((OVERALL_END_TIME - OVERALL_START_TIME))

log_phase "TEST ORCHESTRATOR COMPLETED - FINAL RESULTS"

echo "================================================================================"
echo "  JETSON ORIN TEST ORCHESTRATOR - COMPREHENSIVE RESULTS"
echo "================================================================================"
echo ""
echo "Test Date: $(date)"
echo "Total Duration: $((TOTAL_DURATION / 3600)) hours $((TOTAL_DURATION % 3600 / 60)) minutes"
echo "Results Directory: $MASTER_LOG_DIR"
echo ""
echo "================================================================================"
echo "  INDIVIDUAL TEST RESULTS"
echo "================================================================================"
echo ""

TOTAL_TESTS=6
PASSED_TESTS=0
FAILED_TESTS=0

for i in {1..6}; do
    result="${TEST_RESULTS[$i]}"
    duration=$((TEST_END_TIMES[$i] - TEST_START_TIMES[$i]))

    case $i in
        1) test_name="CPU Stress Test" ;;
        2) test_name="GPU Stress Test" ;;
        3) test_name="RAM Stress Test" ;;
        4) test_name="Storage Stress Test" ;;
        5) test_name="Sequential Combined Test" ;;
        6) test_name="Parallel Combined Test" ;;
    esac

    if [ "$result" == "PASSED" ]; then
        echo -e "${GREEN}[✓]${NC} Test $i: $test_name - ${GREEN}PASSED${NC} ($((duration / 60)) min)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}[✗]${NC} Test $i: $test_name - ${RED}FAILED${NC} ($((duration / 60)) min)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
done

echo ""
echo "================================================================================"
echo "  OVERALL SUMMARY"
echo "================================================================================"
echo ""
echo "Total Tests:   $TOTAL_TESTS"
echo "Passed:        $PASSED_TESTS"
echo "Failed:        $FAILED_TESTS"
echo "Success Rate:  $((PASSED_TESTS * 100 / TOTAL_TESTS))%"
echo ""

# Final verdict
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  ✓ ALL TESTS PASSED - SYSTEM VALIDATED${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Your Jetson Orin AGX has successfully passed all comprehensive stress tests:"
    echo "  ✓ CPU stability under extreme load"
    echo "  ✓ GPU performance (CUDA, VPU, Graphics)"
    echo "  ✓ RAM integrity and reliability"
    echo "  ✓ Storage performance and health"
    echo "  ✓ Sequential component stability"
    echo "  ✓ Parallel multi-component stress"
    echo ""
    echo "The system is ready for demanding production workloads!"
    FINAL_RESULT=0
elif [ $FAILED_TESTS -le 2 ]; then
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}${BOLD}  ⚠ PARTIAL PASS - SOME TESTS FAILED${NC}"
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Your Jetson Orin AGX passed most tests but has some issues:"
    echo "  • $PASSED_TESTS/$TOTAL_TESTS tests passed"
    echo "  • $FAILED_TESTS/$TOTAL_TESTS tests failed"
    echo ""
    echo "Review failed test logs for details and consider:"
    echo "  • Re-running failed tests individually"
    echo "  • Checking cooling and power supply"
    echo "  • Verifying JetPack installation"
    FINAL_RESULT=1
else
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}  ✗ MULTIPLE FAILURES - SYSTEM NOT VALIDATED${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Your Jetson Orin AGX failed multiple tests ($FAILED_TESTS/$TOTAL_TESTS)."
    echo ""
    echo "This indicates serious hardware or configuration issues:"
    echo "  • Review all test logs in: $MASTER_LOG_DIR"
    echo "  • Check thermal performance"
    echo "  • Verify power supply adequacy"
    echo "  • Consider hardware diagnostics"
    echo "  • Contact support if issues persist"
    FINAL_RESULT=2
fi

echo ""
echo "================================================================================"
echo "  DETAILED RESULTS"
echo "================================================================================"
echo ""
echo "Master Results File: $RESULTS_FILE"
echo "Individual Test Logs: $MASTER_LOG_DIR/test*/"
echo ""
echo "To view full results:"
echo "  cat $RESULTS_FILE"
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
    for i in {1..6}; do
        echo "TEST_${i}_RESULT=${TEST_RESULTS[$i]}"
    done
} >> "$RESULTS_FILE"

echo "Test orchestration completed: $(date)"
echo ""

exit $FINAL_RESULT
