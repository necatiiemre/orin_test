#!/bin/bash

################################################################################
# JETSON ORIN AGX - TEST ORCHESTRATOR
################################################################################
# Description: Interactive test mode selector with custom test duration
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
# CONFIGURATION - Will be set by interactive prompts
################################################################################

ORIN_IP=""
ORIN_USER=""
ORIN_PASS=""

################################################################################
# BANNER
################################################################################

show_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat << 'EOF'
================================================================================
      _      _                    ___       _         ___           _
     | |    | |                  / _ \     (_)       / _ \         | |
     | | ___| |_ ___  ___  _ __ | | | |_ __ _ _ __ | | | |_ __ ___| |__  ___
 _   | |/ _ \ __/ __|/ _ \| '_ \| | | | '__| | '_ \| | | | '__/ __| '_ \/ __|
| |__| |  __/ |_\__ \ (_) | | | | |_| | |  | | | | | |_| | | | (__| | | \__ \
 \____/ \___|\__|___/\___/|_| |_|\___/|_|  |_|_| |_|\___/|_|  \___|_| |_|___/

    T E S T   O R C H E S T R A T O R
================================================================================
EOF
    echo -e "${NC}"
    if [ -n "$ORIN_IP" ] && [ -n "$ORIN_USER" ]; then
        echo "Target Device: $ORIN_USER@$ORIN_IP"
        echo ""
    fi
}

################################################################################
# INTERACTIVE CREDENTIAL COLLECTION
################################################################################

collect_credentials() {
    clear
    show_banner

    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  JETSON ORIN CONNECTION SETUP${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Please enter your Jetson Orin connection details:${NC}"
    echo ""

    # Prompt for IP address
    read -p "$(echo -e ${BOLD}Enter IP address${NC}) [192.168.55.69]: " ORIN_IP
    ORIN_IP="${ORIN_IP:-192.168.55.69}"

    # Prompt for username
    read -p "$(echo -e ${BOLD}Enter username${NC}) [orin]: " ORIN_USER
    ORIN_USER="${ORIN_USER:-orin}"

    # Prompt for password
    read -sp "$(echo -e ${BOLD}Enter password${NC}): " ORIN_PASS
    echo ""
    echo ""

    # Prompt for tester name
    read -p "$(echo -e ${BOLD}Enter tester name${NC}): " TESTER_NAME
    while [ -z "$TESTER_NAME" ]; do
        echo -e "${RED}Tester name is required${NC}"
        read -p "$(echo -e ${BOLD}Enter tester name${NC}): " TESTER_NAME
    done

    # Prompt for quality checker name
    read -p "$(echo -e ${BOLD}Enter quality checker name${NC}): " QUALITY_CHECKER_NAME
    while [ -z "$QUALITY_CHECKER_NAME" ]; do
        echo -e "${RED}Quality checker name is required${NC}"
        read -p "$(echo -e ${BOLD}Enter quality checker name${NC}): " QUALITY_CHECKER_NAME
    done
    echo ""

    # Test SSH connection
    echo -e "${CYAN}Testing SSH connection to $ORIN_USER@$ORIN_IP...${NC}"

    if ! command -v sshpass &> /dev/null; then
        echo -e "${RED}ERROR: sshpass is not installed${NC}"
        echo "Install with: sudo apt install sshpass"
        exit 1
    fi

    if ! sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'OK'" 2>/dev/null | grep -q "OK"; then
        echo -e "${RED}✗ SSH connection failed${NC}"
        echo ""
        echo "Please check:"
        echo "  • IP address is correct and reachable"
        echo "  • Username is correct"
        echo "  • Password is correct"
        echo "  • SSH service is running on Jetson Orin"
        echo ""
        read -p "Press Enter to try again or Ctrl+C to exit..."
        collect_credentials
        return
    fi

    echo -e "${GREEN}✓ SSH connection verified${NC}"
    echo ""
    sleep 1
}

################################################################################
# TEST MODE SELECTION
################################################################################

select_test_mode() {
    clear
    show_banner

    echo -e "${BOLD}${MAGENTA}SELECT TEST MODE:${NC}"
    echo ""
    echo -e "  ${BOLD}[INDIVIDUAL COMPONENTS]${NC}"
    echo "  1) CPU Test                    - Test CPU cores only"
    echo "  2) GPU Test                    - Test GPU (CUDA + VPU + Graphics)"
    echo "  3) RAM Test                    - Test memory integrity"
    echo "  4) Storage Test                - Test disk I/O performance"
    echo ""
    echo -e "  ${BOLD}[COMBINED TESTS]${NC}"
    echo "  5) Sequential Combined         - Run all tests in sequence (CPU → GPU → RAM → Storage)"
    echo "  6) Parallel Combined           - Run all tests simultaneously (maximum stress)"
    echo ""
    echo "  0) Exit"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    while true; do
        read -p "Enter your choice [0-6]: " MODE_CHOICE

        case $MODE_CHOICE in
            1)
                TEST_MODE="CPU"
                TEST_SCRIPT="jetson_cpu_test.sh"
                TEST_NAME="CPU Stress Test"
                DURATION_MULTIPLIER=1
                break
                ;;
            2)
                TEST_MODE="GPU"
                TEST_SCRIPT="jetson_gpu_test.sh"
                TEST_NAME="GPU Stress Test"
                DURATION_MULTIPLIER=1
                break
                ;;
            3)
                TEST_MODE="RAM"
                TEST_SCRIPT="jetson_ram_test.sh"
                TEST_NAME="RAM Stress Test"
                DURATION_MULTIPLIER=1
                break
                ;;
            4)
                TEST_MODE="Storage"
                TEST_SCRIPT="jetson_storage_test.sh"
                TEST_NAME="Storage Stress Test"
                DURATION_MULTIPLIER=1
                break
                ;;
            5)
                TEST_MODE="Sequential"
                TEST_SCRIPT="jetson_combined_sequential.sh"
                TEST_NAME="Sequential Combined Test"
                DURATION_MULTIPLIER=4
                break
                ;;
            6)
                TEST_MODE="Parallel"
                TEST_SCRIPT="jetson_combined_parallel.sh"
                TEST_NAME="Parallel Combined Test"
                DURATION_MULTIPLIER=1
                break
                ;;
            0)
                echo ""
                echo -e "${GREEN}Exiting orchestrator. Goodbye!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 0-6.${NC}"
                ;;
        esac
    done
}

################################################################################
# TEST DURATION SELECTION
################################################################################

select_test_duration() {
    clear
    show_banner

    echo -e "${BOLD}${CYAN}Selected Test Mode: $TEST_NAME${NC}"
    echo ""
    echo -e "${BOLD}${MAGENTA}SELECT TEST DURATION:${NC}"
    echo ""
    echo -e "  ${BOLD}[QUICK TESTS]${NC}"
    echo "  1) 15 minutes      - Quick smoke test"
    echo "  2) 30 minutes      - Fast validation"
    echo ""
    echo -e "  ${BOLD}[STANDARD TESTS]${NC}"
    echo "  3) 1 hour          - Standard test (recommended)"
    echo "  4) 2 hours         - Extended test"
    echo ""
    echo -e "  ${BOLD}[LONG TESTS]${NC}"
    echo "  5) 4 hours         - Long burn-in test"
    echo "  6) 8 hours         - Overnight test"
    echo ""
    echo -e "  ${BOLD}[CUSTOM]${NC}"
    echo "  7) Custom duration - Enter your own duration"
    echo ""
    echo "  0) Back to test mode selection"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    while true; do
        read -p "Enter your choice [0-7]: " DURATION_CHOICE

        case $DURATION_CHOICE in
            1)
                TEST_DURATION_HOURS="0.25"
                break
                ;;
            2)
                TEST_DURATION_HOURS="0.5"
                break
                ;;
            3)
                TEST_DURATION_HOURS="1"
                break
                ;;
            4)
                TEST_DURATION_HOURS="2"
                break
                ;;
            5)
                TEST_DURATION_HOURS="4"
                break
                ;;
            6)
                TEST_DURATION_HOURS="8"
                break
                ;;
            7)
                echo ""
                read -p "Enter custom duration in hours (e.g., 1.5): " TEST_DURATION_HOURS
                # Validate input
                if ! [[ "$TEST_DURATION_HOURS" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                    echo -e "${RED}Invalid duration. Please enter a number.${NC}"
                    continue
                fi
                break
                ;;
            0)
                select_test_mode
                select_test_duration
                return
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 0-7.${NC}"
                ;;
        esac
    done
}

################################################################################
# TEST CONFIRMATION
################################################################################

confirm_and_run() {
    clear
    show_banner

    # Calculate total duration
    TOTAL_HOURS=$(echo "$TEST_DURATION_HOURS * $DURATION_MULTIPLIER" | bc)
    TOTAL_MINUTES=$(echo "$TOTAL_HOURS * 60" | bc | cut -d'.' -f1)

    echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}  TEST CONFIGURATION SUMMARY${NC}"
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Test Mode:${NC}           $TEST_NAME"
    echo -e "${BOLD}Target Device:${NC}       $ORIN_USER@$ORIN_IP"
    echo -e "${BOLD}Duration per test:${NC}   $TEST_DURATION_HOURS hours"

    if [ "$DURATION_MULTIPLIER" -gt 1 ]; then
        echo -e "${BOLD}Number of tests:${NC}     $DURATION_MULTIPLIER (sequential)"
        echo -e "${BOLD}Total duration:${NC}      $TOTAL_HOURS hours (approx. $TOTAL_MINUTES minutes)"
    else
        echo -e "${BOLD}Total duration:${NC}      $TEST_DURATION_HOURS hours"
    fi
    echo ""
    echo -e "${BOLD}Tester:${NC}              $TESTER_NAME"
    echo -e "${BOLD}Quality Checker:${NC}     $QUALITY_CHECKER_NAME"

    echo ""
    echo -e "${BOLD}Start time:${NC}          $(date '+%Y-%m-%d %H:%M:%S')"

    # Calculate estimated end time
    END_TIMESTAMP=$(($(date +%s) + TOTAL_MINUTES * 60))
    END_TIME=$(date -d "@$END_TIMESTAMP" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $END_TIMESTAMP '+%Y-%m-%d %H:%M:%S')
    echo -e "${BOLD}Estimated end:${NC}       $END_TIME"
    echo ""

    # Test-specific information
    case $TEST_MODE in
        "CPU")
            echo -e "${CYAN}This test will stress all CPU cores with various workloads.${NC}"
            ;;
        "GPU")
            echo -e "${CYAN}This test will stress GPU (CUDA compute, VPU encoding, Graphics).${NC}"
            ;;
        "RAM")
            echo -e "${CYAN}This test will verify memory integrity with pattern testing.${NC}"
            ;;
        "Storage")
            echo -e "${CYAN}This test will stress disk I/O and check storage health.${NC}"
            ;;
        "Sequential")
            echo -e "${CYAN}This test will run CPU → GPU → RAM → Storage in sequence.${NC}"
            ;;
        "Parallel")
            echo -e "${YELLOW}${BOLD}⚠ WARNING: This will push ALL components to maximum simultaneously!${NC}"
            echo -e "${YELLOW}   Expect high temperatures and maximum power consumption.${NC}"
            ;;
    esac

    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    read -p "Do you want to start this test? (yes/no): " CONFIRM

    case $CONFIRM in
        yes|y|YES|Y)
            run_test
            ;;
        *)
            echo ""
            echo -e "${YELLOW}Test cancelled by user.${NC}"
            echo ""
            read -p "Press Enter to return to main menu..."
            main_menu
            ;;
    esac
}

################################################################################
# RUN TEST
################################################################################

run_test() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  STARTING TEST: $TEST_NAME${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Create clean directory names based on test mode
    case "$TEST_MODE" in
        "Sequential")
            LOG_DIR="./sequential_test_$(date +%Y%m%d_%H%M%S)"
            ;;
        "Parallel")
            LOG_DIR="./parallel_test_$(date +%Y%m%d_%H%M%S)"
            ;;
        "CPU")
            LOG_DIR="./cpu_test_$(date +%Y%m%d_%H%M%S)"
            ;;
        "GPU")
            LOG_DIR="./gpu_test_$(date +%Y%m%d_%H%M%S)"
            ;;
        "RAM")
            LOG_DIR="./ram_test_$(date +%Y%m%d_%H%M%S)"
            ;;
        "Storage")
            LOG_DIR="./storage_test_$(date +%Y%m%d_%H%M%S)"
            ;;
        *)
            LOG_DIR="./${TEST_MODE}_test_$(date +%Y%m%d_%H%M%S)"
            ;;
    esac

    # Run the test
    if bash "$SCRIPT_DIR/$TEST_SCRIPT" "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$TEST_DURATION_HOURS" "$LOG_DIR" "$TESTER_NAME" "$QUALITY_CHECKER_NAME"; then
        echo ""
        echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${GREEN}  ✓ TEST PASSED: $TEST_NAME${NC}"
        echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        TEST_RESULT="PASSED"
        EXIT_CODE=0
    else
        echo ""
        echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${RED}  ✗ TEST FAILED: $TEST_NAME${NC}"
        echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        TEST_RESULT="FAILED"
        EXIT_CODE=1
    fi

    echo ""
    echo -e "${BOLD}Results saved to:${NC} $LOG_DIR"
    echo -e "${BOLD}Test completed:${NC}   $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Press Enter to return to main menu or Ctrl+C to exit..."

    main_menu
}

################################################################################
# MAIN MENU
################################################################################

main_menu() {
    select_test_mode
    select_test_duration
    confirm_and_run
}

################################################################################
# MAIN EXECUTION
################################################################################

# Collect credentials interactively
collect_credentials

# Start the main menu flow
main_menu
