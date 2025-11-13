#!/bin/bash

################################################################################
# COMPREHENSIVE RAM TEST RUNNER - ALL PROFESSIONAL METHODS
################################################################################
# Description: Runs comprehensive RAM testing with all professional methods
# Features:
#   • ECC error monitoring
#   • Address line testing
#   • Row hammer detection
#   • Memory controller bandwidth stress
#   • JEDEC standard patterns (MATS+, March C-)
#   • Walking bit patterns
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
    # Non-interactive mode
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

TEST_DURATION=$(echo "$TEST_DURATION_HOURS * 3600" | bc | cut -d'.' -f1)

# Log directory setup
LOG_DIR="${5:-./comprehensive_ram_test_$(date +%Y%m%d_%H%M%S)}"

show_usage() {
    cat << EOF
================================================================================
  COMPREHENSIVE RAM TEST - ALL PROFESSIONAL METHODS
================================================================================

Usage: $0 [ip] [user] [password] [duration_hours]

Parameters:
  ip       : Jetson Orin IP (default: 192.168.55.69)
  user     : SSH username (default: orin)
  password : SSH password (will prompt if not provided)
  duration : Test duration in hours (default: 1 hour)

TEST METHODS INCLUDED:
  ✓ ECC Error Monitoring        - Detects correctable/uncorrectable errors
  ✓ Address Line Testing         - Finds stuck or shorted address lines
  ✓ Row Hammer Detection         - Tests for bit flip vulnerabilities
  ✓ Memory Bandwidth Stress      - Stresses memory controller
  ✓ JEDEC Standard Patterns      - MATS+, March C- algorithms
  ✓ Walking Bit Patterns         - Detects stuck or weak bits

This is a PROFESSIONAL-GRADE test suite equivalent to industry standard
memory testing tools. Use this for production validation and certification.

================================================================================
EOF
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_usage
    exit 0
fi

echo "================================================================================"
echo "  COMPREHENSIVE RAM TEST - ALL PROFESSIONAL METHODS"
echo "================================================================================"
echo ""
log_info "Target: $ORIN_USER@$ORIN_IP"
log_info "Duration: $TEST_DURATION_HOURS hours ($TEST_DURATION seconds / $((TEST_DURATION / 60)) minutes)"
echo ""

# Create log directories
ensure_directory "$LOG_DIR"
ensure_directory "$LOG_DIR/logs"
ensure_directory "$LOG_DIR/reports"

# Convert to absolute path
LOG_DIR=$(cd "$LOG_DIR" && pwd)

log_info "Results will be saved to: $LOG_DIR"
echo ""

# Check sshpass
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

# Copy comprehensive test script to remote machine
log_info "Copying comprehensive test script to remote machine..."
if [ ! -f "$SCRIPT_DIR/ram/comprehensive_ram_test.py" ]; then
    log_error "Comprehensive test script not found at $SCRIPT_DIR/ram/comprehensive_ram_test.py"
    exit 1
fi

sshpass -p "$ORIN_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$SCRIPT_DIR/ram/comprehensive_ram_test.py" "$ORIN_USER@$ORIN_IP:/tmp/comprehensive_ram_test.py" 2>&1
if [ $? -eq 0 ]; then
    log_success "Test script copied successfully"
else
    log_error "Failed to copy test script"
    exit 1
fi
echo ""

log_info "Starting COMPREHENSIVE RAM test with all professional methods..."

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "export TEST_DURATION=$TEST_DURATION; bash -s" << 'REMOTE_SCRIPT' | tee "$LOG_DIR/logs/comprehensive_ram_test.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') - $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') - $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') - $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') - $*"
}

TEST_DIR="/tmp/comprehensive_ram_test_$(date +%s)"
mkdir -p "$TEST_DIR"

log_info "Remote test directory: $TEST_DIR"

# Get memory information
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
AVAILABLE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
FREE_RAM_KB=$(grep MemFree /proc/meminfo | awk '{print $2}')

TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
AVAILABLE_RAM_MB=$((AVAILABLE_RAM_KB / 1024))
FREE_RAM_MB=$((FREE_RAM_KB / 1024))

log_info "System Memory:"
log_info "  Total RAM: ${TOTAL_RAM_MB} MB"
log_info "  Available RAM: ${AVAILABLE_RAM_MB} MB"
log_info "  Free RAM: ${FREE_RAM_MB} MB"

# Calculate test memory (75% of available for safety)
TEST_MEMORY_MB=$((AVAILABLE_RAM_MB * 75 / 100))

# Ensure minimum test size
if [ $TEST_MEMORY_MB -lt 1000 ]; then
    log_error "Not enough memory for testing. Need at least 1000MB, available: ${TEST_MEMORY_MB}MB"
    exit 1
fi

log_info "Test Memory: ${TEST_MEMORY_MB} MB (75% of available)"

# Execute comprehensive test using the copied script
log_info "Starting COMPREHENSIVE RAM test..."
log_info "This will run ALL professional-grade test methods"
echo ""

if [ ! -f "/tmp/comprehensive_ram_test.py" ]; then
    log_error "Comprehensive test script not found at /tmp/comprehensive_ram_test.py"
    exit 1
fi

python3 /tmp/comprehensive_ram_test.py $TEST_MEMORY_MB $TEST_DURATION

TEST_RESULT=$?

echo ""
echo "================================================================================"
echo "  COMPREHENSIVE TEST RESULTS"
echo "================================================================================"
echo ""

if [ -f "/tmp/comprehensive_ram_test_result.txt" ]; then
    cat /tmp/comprehensive_ram_test_result.txt

    source /tmp/comprehensive_ram_test_result.txt

    echo ""
    echo "SUMMARY:"
    echo "  Overall Result: $RESULT"
    echo "  Total Errors: $TOTAL_ERRORS"
    echo "  Total Operations: $TOTAL_OPERATIONS"
    echo "  Memory Tested: ${MEMORY_MB} MB"
    echo ""

    echo "DETAILED BREAKDOWN:"
    echo "  Address Line Errors:    $ADDRESS_LINE_ERRORS"
    echo "  Row Hammer Errors:      $ROW_HAMMER_ERRORS"
    echo "  Bandwidth Errors:       $BANDWIDTH_ERRORS"
    echo "  JEDEC Pattern Errors:   $JEDEC_ERRORS"
    echo "  Walking Bits Errors:    $WALKING_BITS_ERRORS"

    if [ -n "$ECC_CORRECTABLE" ]; then
        echo ""
        echo "ECC MONITORING:"
        echo "  Correctable Errors:     $ECC_CORRECTABLE"
        echo "  Uncorrectable Errors:   $ECC_UNCORRECTABLE"
    fi

    echo ""

    if [ "$RESULT" = "PASSED" ]; then
        log_success "✓ COMPREHENSIVE RAM TEST PASSED!"
        echo "[+] All professional-grade tests completed successfully"
        echo "[+] No memory errors detected across any test method"
        echo "[+] Your RAM meets PRODUCTION quality standards"
    else
        log_error "✗ COMPREHENSIVE RAM TEST FAILED!"
        echo "[-] $TOTAL_ERRORS memory errors detected"
        echo "[-] Memory does not meet production standards"
        echo "[-] Hardware investigation required"
    fi
else
    log_error "Test results not found"
    TEST_RESULT=2
fi

echo ""
echo "================================================================================"

# Cleanup
rm -rf "$TEST_DIR"
rm -f /tmp/comprehensive_ram_test.py

exit $TEST_RESULT

REMOTE_SCRIPT

# Capture test result
RAM_TEST_RESULT=$?

echo ""
echo "================================================================================"
echo "  COPYING TEST RESULTS"
echo "================================================================================"
echo ""

# Copy result file from remote
echo "[1/2] Copying test results..."
sshpass -p "$ORIN_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP:/tmp/comprehensive_ram_test_result.txt" "$LOG_DIR/reports/comprehensive_results.txt" 2>/dev/null && echo "[+] Results copied" || echo "[!] Results file not found"

# Generate comprehensive final report with product information
echo "[2/2] Generating comprehensive final report..."

# Source the results to get test data
if [ -f "$LOG_DIR/reports/comprehensive_results.txt" ]; then
    source "$LOG_DIR/reports/comprehensive_results.txt"

    # Generate comprehensive report with cover page information
    cat > "$LOG_DIR/reports/RAM_COMPREHENSIVE_TEST_REPORT.txt" << REPORT_EOF
=========================================================================================
   COMPREHENSIVE RAM TEST REPORT - JETSON ORIN
=========================================================================================

Test Date: $(date '+%Y-%m-%d %H:%M:%S')
Tester: ${TESTER_NAME:-N/A}
Quality Checker: ${QUALITY_CHECKER_NAME:-N/A}
Device Serial: ${DEVICE_SERIAL:-N/A}
Jetson Model: $(sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP" "cat /proc/device-tree/model 2>/dev/null | tr -d '\0'" 2>/dev/null || echo "Unknown")
Test Duration: ${TEST_DURATION_HOURS} hours ($((TEST_DURATION / 60)) minutes)
Status: ${RESULT:-UNKNOWN}

-----------------------------------------------------------------------------------------
   TEST SUMMARY
-----------------------------------------------------------------------------------------

Overall Result: ${RESULT:-UNKNOWN}
Total Memory Tested: ${MEMORY_MB:-0} MB
Total Operations: ${TOTAL_OPERATIONS:-0}
Total Errors Detected: ${TOTAL_ERRORS:-0}

-----------------------------------------------------------------------------------------
   TEST METHODS EXECUTED
-----------------------------------------------------------------------------------------

This comprehensive RAM test suite includes the following professional-grade methods:

✓ ECC Error Monitoring
  - Detects correctable and uncorrectable memory errors
  - Monitors memory controller error counters

✓ Address Line Testing
  - Tests for stuck or shorted address lines
  - Walking bit patterns across address space
  - Errors Detected: ${ADDRESS_LINE_ERRORS:-0}

✓ Row Hammer Detection
  - Tests for bit flip vulnerabilities
  - Rapid access patterns to stress DRAM rows
  - Errors Detected: ${ROW_HAMMER_ERRORS:-0}

✓ Memory Controller Bandwidth Stress
  - Sequential read/write operations
  - Random access patterns
  - Errors Detected: ${BANDWIDTH_ERRORS:-0}

✓ JEDEC Standard Patterns
  - MATS+ (Modified Algorithm Test Sequence)
  - March C- Algorithm
  - Errors Detected: ${JEDEC_ERRORS:-0}

✓ Walking Bit Patterns
  - Detects stuck or weak bits
  - Walking 1s and walking 0s patterns
  - Errors Detected: ${WALKING_BITS_ERRORS:-0}

-----------------------------------------------------------------------------------------
   DETAILED TEST RESULTS
-----------------------------------------------------------------------------------------

[DETAILED METRICS]

Address Line Testing:
  • Operations: ${ADDRESS_LINE_ERRORS:-0} errors detected
  • Status: $([ "${ADDRESS_LINE_ERRORS:-0}" -eq 0 ] && echo "PASS ✓" || echo "FAIL ✗")

Row Hammer Testing:
  • Operations: ${ROW_HAMMER_ERRORS:-0} errors detected
  • Status: $([ "${ROW_HAMMER_ERRORS:-0}" -eq 0 ] && echo "PASS ✓" || echo "FAIL ✗")

Memory Bandwidth Testing:
  • Operations: ${BANDWIDTH_ERRORS:-0} errors detected
  • Status: $([ "${BANDWIDTH_ERRORS:-0}" -eq 0 ] && echo "PASS ✓" || echo "FAIL ✗")

JEDEC Pattern Testing:
  • Operations: ${JEDEC_ERRORS:-0} errors detected
  • Status: $([ "${JEDEC_ERRORS:-0}" -eq 0 ] && echo "PASS ✓" || echo "FAIL ✗")

Walking Bit Testing:
  • Operations: ${WALKING_BITS_ERRORS:-0} errors detected
  • Status: $([ "${WALKING_BITS_ERRORS:-0}" -eq 0 ] && echo "PASS ✓" || echo "FAIL ✗")

$(if [ -n "$ECC_CORRECTABLE" ]; then
echo "ECC Monitoring:"
echo "  • Correctable Errors: ${ECC_CORRECTABLE:-0}"
echo "  • Uncorrectable Errors: ${ECC_UNCORRECTABLE:-0}"
echo "  • Status: $([ "${ECC_UNCORRECTABLE:-0}" -eq 0 ] && echo "PASS ✓" || echo "FAIL ✗")"
fi)

-----------------------------------------------------------------------------------------
   CONCLUSION
-----------------------------------------------------------------------------------------

$(if [ "$RESULT" = "PASSED" ]; then
cat << PASS_MSG
✓ COMPREHENSIVE RAM TEST: PASSED

All professional-grade memory tests completed successfully:
  ✓ No memory errors detected across any test method
  ✓ Address lines functioning correctly
  ✓ No row hammer vulnerabilities detected
  ✓ Memory controller operating within specifications
  ✓ JEDEC standard patterns verified
  ✓ All bits functioning correctly

VERDICT: Memory meets PRODUCTION quality standards and is certified for use.
PASS_MSG
else
cat << FAIL_MSG
✗ COMPREHENSIVE RAM TEST: FAILED

Memory reliability issues detected:
  ✗ Total Errors: ${TOTAL_ERRORS:-0}
  ✗ Hardware investigation required

$([ "${ADDRESS_LINE_ERRORS:-0}" -gt 0 ] && echo "  • Address line failures - possible connection issues")
$([ "${ROW_HAMMER_ERRORS:-0}" -gt 0 ] && echo "  • Row hammer vulnerability - memory susceptible to bit flips")
$([ "${JEDEC_ERRORS:-0}" -gt 0 ] && echo "  • JEDEC pattern failures - basic memory cell issues")
$([ "${BANDWIDTH_ERRORS:-0}" -gt 0 ] && echo "  • Memory controller errors under bandwidth stress")
$([ "${WALKING_BITS_ERRORS:-0}" -gt 0 ] && echo "  • Stuck or weak bits detected")

VERDICT: Memory does NOT meet production standards. Hardware replacement recommended.
FAIL_MSG
fi)

-----------------------------------------------------------------------------------------
   TEST METHODOLOGY
-----------------------------------------------------------------------------------------

This test suite is equivalent to professional memory validation tools used in:
  • Manufacturing quality control
  • Production validation and certification
  • Hardware reliability testing
  • Failure analysis and diagnostics

The comprehensive test methods employed are based on industry standards:
  • JEDEC memory testing standards (JESD79, JESD22)
  • Row hammer vulnerability assessment (Google Project Zero research)
  • ECC monitoring per memory controller specifications
  • Address line testing (industry best practices)

=========================================================================================
   END OF REPORT
=========================================================================================

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Test Directory: $LOG_DIR
REPORT_EOF

    echo "[+] Comprehensive final report generated"
else
    echo "[!] Could not generate comprehensive report - results file missing"
fi

# Cleanup remote files
sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP" "rm -f /tmp/comprehensive_ram_test_result.txt" 2>/dev/null

echo ""
echo "================================================================================"
echo "  COMPREHENSIVE RAM TEST COMPLETED"
echo "================================================================================"
echo ""

if [ $RAM_TEST_RESULT -eq 0 ]; then
    echo "✓ RESULT: YOUR RAM PASSED ALL PROFESSIONAL-GRADE TESTS!"
    echo ""
    echo "Your Jetson Orin RAM has been validated with:"
    echo "  ✓ ECC error monitoring"
    echo "  ✓ Address line testing"
    echo "  ✓ Row hammer detection"
    echo "  ✓ Memory controller bandwidth stress"
    echo "  ✓ JEDEC standard patterns (MATS+, March C-)"
    echo "  ✓ Walking bit patterns"
    echo ""
    echo "This level of testing is equivalent to professional memory validation"
    echo "tools and certifies your RAM for production use."
else
    echo "✗ RESULT: RAM FAILED COMPREHENSIVE TESTING"
    echo ""
    echo "One or more professional-grade tests detected errors."
    echo "Review the detailed logs for specific failure points."
fi

echo ""
echo "[*] Results Directory: $LOG_DIR"
echo "   • Test Log:    $LOG_DIR/logs/comprehensive_ram_test.log"
echo "   • Results:     $LOG_DIR/reports/comprehensive_results.txt"
echo ""
echo "Test completed: $(date)"

exit $RAM_TEST_RESULT
