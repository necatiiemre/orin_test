#!/bin/bash

################################################################################
# JETSON ORIN AGX - TEST SELECTOR
################################################################################
# Description: Interactive menu to select and run specific tests
# Version: 1.0
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

################################################################################
# CONFIGURATION
################################################################################

ORIN_IP="${1:-192.168.55.69}"
ORIN_USER="${2:-orin}"
ORIN_PASS="${3}"
TEST_DURATION_HOURS="${4:-1}"

################################################################################
# FUNCTIONS
################################################################################

show_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "================================================================================"
    echo "  JETSON ORIN AGX - TEST SELECTOR"
    echo "================================================================================"
    echo -e "${NC}"
    echo "Target: $ORIN_USER@$ORIN_IP"
    echo "Duration per test: $TEST_DURATION_HOURS hours"
    echo ""
}

show_menu() {
    echo -e "${BOLD}Select tests to run:${NC}"
    echo ""
    echo "  ${BOLD}[INDIVIDUAL COMPONENT TESTS]${NC}"
    echo "  1) CPU Stress Test                    (~$TEST_DURATION_HOURS hour)"
    echo "  2) GPU Stress Test                    (~$TEST_DURATION_HOURS hour)"
    echo "  3) RAM Stress Test                    (~$TEST_DURATION_HOURS hour)"
    echo "  4) Storage Stress Test                (~$TEST_DURATION_HOURS hour)"
    echo ""
    echo "  ${BOLD}[COMBINED TESTS]${NC}"
    echo "  5) Sequential Combined Test           (~$((TEST_DURATION_HOURS * 4)) hours - all tests in sequence)"
    echo "  6) Parallel Combined Test             (~$TEST_DURATION_HOURS hour - all simultaneously)"
    echo ""
    echo "  ${BOLD}[QUICK COMBINATIONS]${NC}"
    echo "  7) CPU + GPU Tests                    (~$((TEST_DURATION_HOURS * 2)) hours)"
    echo "  8) RAM + Storage Tests                (~$((TEST_DURATION_HOURS * 2)) hours)"
    echo "  9) All Individual Tests (1-4)         (~$((TEST_DURATION_HOURS * 4)) hours)"
    echo ""
    echo "  ${BOLD}[FULL SUITE]${NC}"
    echo "  10) Full Orchestrator (All 6 Phases)  (~$((TEST_DURATION_HOURS * 6 + TEST_DURATION_HOURS * 2)) hours)"
    echo ""
    echo "  ${BOLD}[OTHER]${NC}"
    echo "  11) System Preparation Only           (~10 minutes)"
    echo ""
    echo "  0) Exit"
    echo ""
}

run_test() {
    local test_name="$1"
    local test_script="$2"
    local duration="$3"
    shift 3
    local extra_args="$@"

    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Running: $test_name${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Test script: $test_script"
    echo "Duration: $duration hours"
    echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    read -p "Press Enter to start or Ctrl+C to cancel..."
    echo ""

    local log_dir="./test_selector_${test_name// /_}_$(date +%Y%m%d_%H%M%S)"

    if bash "$SCRIPT_DIR/$test_script" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$duration" "$log_dir" $extra_args; then
        echo ""
        echo -e "${GREEN}${BOLD}✓ $test_name PASSED${NC}"
        echo "Results: $log_dir"
    else
        echo ""
        echo -e "${RED}${BOLD}✗ $test_name FAILED${NC}"
        echo "Results: $log_dir"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

run_multiple_tests() {
    local tests=("$@")
    local total=${#tests[@]}
    local current=0

    echo ""
    echo -e "${BOLD}${MAGENTA}Running $total tests in sequence...${NC}"
    echo ""

    for test_info in "${tests[@]}"; do
        current=$((current + 1))
        IFS='|' read -r test_name test_script duration extra_args <<< "$test_info"

        echo -e "${CYAN}[Test $current/$total]${NC} $test_name"
        run_test "$test_name" "$test_script" "$duration" "$extra_args"
    done

    echo ""
    echo -e "${GREEN}${BOLD}All selected tests completed!${NC}"
    echo ""
    read -p "Press Enter to return to menu..."
}

################################################################################
# MAIN MENU LOOP
################################################################################

# Check if password provided
if [ -z "$ORIN_PASS" ]; then
    show_banner
    read -sp "Enter SSH password for $ORIN_USER@$ORIN_IP: " ORIN_PASS
    echo ""
    echo ""
fi

# Test SSH connection
echo -e "${CYAN}Testing SSH connection...${NC}"
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}ERROR: sshpass is not installed${NC}"
    exit 1
fi

if ! sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'OK'" 2>/dev/null | grep -q "OK"; then
    echo -e "${RED}ERROR: SSH connection failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ SSH connection verified${NC}"
sleep 2

# Main menu loop
while true; do
    show_banner
    show_menu

    read -p "Enter your choice [0-11]: " choice

    case $choice in
        1)
            run_test "CPU Stress Test" "jetson_cpu_test.sh" "$TEST_DURATION_HOURS"
            ;;
        2)
            run_test "GPU Stress Test" "jetson_gpu_test.sh" "$TEST_DURATION_HOURS"
            ;;
        3)
            run_test "RAM Stress Test" "ram/complete_ram_test.sh" "$TEST_DURATION_HOURS"
            ;;
        4)
            run_test "Storage Stress Test" "jetson_storage_test.sh" "$TEST_DURATION_HOURS"
            ;;
        5)
            # Sequential combined - run all tests in sequence
            tests=(
                "CPU Stress Test|jetson_cpu_test.sh|$TEST_DURATION_HOURS|"
                "GPU Stress Test|jetson_gpu_test.sh|$TEST_DURATION_HOURS|"
                "RAM Stress Test|ram/complete_ram_test.sh|$TEST_DURATION_HOURS|"
                "Storage Stress Test|jetson_storage_test.sh|$TEST_DURATION_HOURS|"
            )
            run_multiple_tests "${tests[@]}"
            ;;
        6)
            run_test "Parallel Combined Test" "jetson_combined_parallel_test.sh" "$TEST_DURATION_HOURS"
            ;;
        7)
            # CPU + GPU
            tests=(
                "CPU Stress Test|jetson_cpu_test.sh|$TEST_DURATION_HOURS|"
                "GPU Stress Test|jetson_gpu_test.sh|$TEST_DURATION_HOURS|"
            )
            run_multiple_tests "${tests[@]}"
            ;;
        8)
            # RAM + Storage
            tests=(
                "RAM Stress Test|ram/complete_ram_test.sh|$TEST_DURATION_HOURS|"
                "Storage Stress Test|jetson_storage_test.sh|$TEST_DURATION_HOURS|"
            )
            run_multiple_tests "${tests[@]}"
            ;;
        9)
            # All individual tests
            tests=(
                "CPU Stress Test|jetson_cpu_test.sh|$TEST_DURATION_HOURS|"
                "GPU Stress Test|jetson_gpu_test.sh|$TEST_DURATION_HOURS|"
                "RAM Stress Test|ram/complete_ram_test.sh|$TEST_DURATION_HOURS|"
                "Storage Stress Test|jetson_storage_test.sh|$TEST_DURATION_HOURS|"
            )
            run_multiple_tests "${tests[@]}"
            ;;
        10)
            run_test "Full Orchestrator (All 6 Phases)" "jetson_test_orchestrator.sh" "$TEST_DURATION_HOURS"
            ;;
        11)
            run_test "System Preparation" "jetson_system_prep.sh" "0.17"
            ;;
        0)
            echo ""
            echo -e "${GREEN}Exiting test selector. Goodbye!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo -e "${RED}Invalid choice. Please enter a number between 0 and 11.${NC}"
            sleep 2
            ;;
    esac
done
