#!/bin/bash

# Test Orchestrator Script for Jetson Orin
# This script provides an interactive menu to run various hardware tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to get test duration from user
get_test_duration() {
    local test_name=$1
    local default_duration=$2
    local duration

    echo ""
    read -p "Enter test duration in hours (default: $default_duration, press Enter for default): " duration

    # If user just pressed Enter, use default
    if [ -z "$duration" ]; then
        duration=$default_duration
    fi

    # Validate that it's a number (integer or decimal)
    if ! [[ "$duration" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        print_message "$RED" "Invalid duration. Using default: $default_duration hours"
        duration=$default_duration
    fi

    echo "$duration"
}

# Function to display the menu
display_menu() {
    clear
    echo "=============================================="
    echo "    Jetson Orin Test Orchestrator"
    echo "=============================================="
    echo ""
    echo "Select a test to run:"
    echo ""
    echo "  1. CPU Test          (default: 1 hour)"
    echo "  2. GPU Test          (default: 2 hours)"
    echo "  3. RAM Test          (default: 1 hour)"
    echo "  4. Storage Test      (default: 2 hours)"
    echo "  5. Combined Test     (All tests with defaults)"
    echo "  0. Exit"
    echo ""
    echo "Note: You will be prompted for duration when"
    echo "      selecting individual tests (1-4)."
    echo ""
    echo "=============================================="
}

# Function to run CPU test
run_cpu_test() {
    local duration=${1:-$(get_test_duration "CPU" "1")}
    print_message "$BLUE" "\nStarting CPU Test (Duration: $duration hours)..."
    if [ -f "$SCRIPT_DIR/jetson_cpu_test.sh" ]; then
        bash "$SCRIPT_DIR/jetson_cpu_test.sh" "" "" "" "$duration"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            print_message "$GREEN" "CPU Test completed successfully!"
        else
            print_message "$RED" "CPU Test failed with exit code: $exit_code"
        fi
        return $exit_code
    else
        print_message "$RED" "Error: jetson_cpu_test.sh not found!"
        return 1
    fi
}

# Function to run GPU test
run_gpu_test() {
    local duration=${1:-$(get_test_duration "GPU" "2")}
    print_message "$BLUE" "\nStarting GPU Test (Duration: $duration hours)..."
    if [ -f "$SCRIPT_DIR/jetson_gpu_test.sh" ]; then
        bash "$SCRIPT_DIR/jetson_gpu_test.sh" "" "" "" "$duration"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            print_message "$GREEN" "GPU Test completed successfully!"
        else
            print_message "$RED" "GPU Test failed with exit code: $exit_code"
        fi
        return $exit_code
    else
        print_message "$RED" "Error: jetson_gpu_test.sh not found!"
        return 1
    fi
}

# Function to run RAM test
run_ram_test() {
    local duration=${1:-$(get_test_duration "RAM" "1")}
    print_message "$BLUE" "\nStarting RAM Test (Duration: $duration hours)..."
    if [ -f "$SCRIPT_DIR/ram/complete_ram_test.sh" ]; then
        bash "$SCRIPT_DIR/ram/complete_ram_test.sh" "" "" "" "$duration"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            print_message "$GREEN" "RAM Test completed successfully!"
        else
            print_message "$RED" "RAM Test failed with exit code: $exit_code"
        fi
        return $exit_code
    else
        print_message "$RED" "Error: ram/complete_ram_test.sh not found!"
        return 1
    fi
}

# Function to run Storage test
run_storage_test() {
    local duration=${1:-$(get_test_duration "Storage" "2")}
    print_message "$BLUE" "\nStarting Storage Test (Duration: $duration hours)..."
    if [ -f "$SCRIPT_DIR/jetson_storage_test.sh" ]; then
        bash "$SCRIPT_DIR/jetson_storage_test.sh" "" "" "" "$duration"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            print_message "$GREEN" "Storage Test completed successfully!"
        else
            print_message "$RED" "Storage Test failed with exit code: $exit_code"
        fi
        return $exit_code
    else
        print_message "$RED" "Error: jetson_storage_test.sh not found!"
        return 1
    fi
}

# Function to run combined test
run_combined_test() {
    print_message "$BLUE" "\n=========================================="
    print_message "$BLUE" "Starting Combined Test (All Tests)"
    print_message "$BLUE" "=========================================="
    print_message "$YELLOW" "Using default durations for all tests:"
    print_message "$YELLOW" "  • CPU: 1 hour"
    print_message "$YELLOW" "  • GPU: 2 hours"
    print_message "$YELLOW" "  • RAM: 1 hour"
    print_message "$YELLOW" "  • Storage: 2 hours"

    local failed_tests=()
    local passed_tests=()

    # Run CPU Test with default duration
    print_message "$YELLOW" "\n[1/4] Running CPU Test..."
    if run_cpu_test 1; then
        passed_tests+=("CPU")
    else
        failed_tests+=("CPU")
    fi

    # Run GPU Test with default duration
    print_message "$YELLOW" "\n[2/4] Running GPU Test..."
    if run_gpu_test 2; then
        passed_tests+=("GPU")
    else
        failed_tests+=("GPU")
    fi

    # Run RAM Test with default duration
    print_message "$YELLOW" "\n[3/4] Running RAM Test..."
    if run_ram_test 1; then
        passed_tests+=("RAM")
    else
        failed_tests+=("RAM")
    fi

    # Run Storage Test with default duration
    print_message "$YELLOW" "\n[4/4] Running Storage Test..."
    if run_storage_test 2; then
        passed_tests+=("Storage")
    else
        failed_tests+=("Storage")
    fi

    # Display summary
    echo ""
    print_message "$BLUE" "=========================================="
    print_message "$BLUE" "Combined Test Summary"
    print_message "$BLUE" "=========================================="

    if [ ${#passed_tests[@]} -gt 0 ]; then
        print_message "$GREEN" "Passed Tests (${#passed_tests[@]}):"
        for test in "${passed_tests[@]}"; do
            print_message "$GREEN" "  - $test"
        done
    fi

    if [ ${#failed_tests[@]} -gt 0 ]; then
        print_message "$RED" "\nFailed Tests (${#failed_tests[@]}):"
        for test in "${failed_tests[@]}"; do
            print_message "$RED" "  - $test"
        done
        return 1
    else
        print_message "$GREEN" "\nAll tests passed successfully!"
        return 0
    fi
}

# Function to pause and wait for user input
pause() {
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu loop
main() {
    while true; do
        display_menu
        read -p "Enter your choice (0-5): " choice

        case $choice in
            1)
                run_cpu_test
                pause
                ;;
            2)
                run_gpu_test
                pause
                ;;
            3)
                run_ram_test
                pause
                ;;
            4)
                run_storage_test
                pause
                ;;
            5)
                run_combined_test
                pause
                ;;
            0)
                print_message "$GREEN" "\nExiting Test Orchestrator. Goodbye!"
                exit 0
                ;;
            *)
                print_message "$RED" "\nInvalid choice. Please select a number between 0 and 5."
                pause
                ;;
        esac
    done
}

# Check if running with proper permissions
if [ "$EUID" -ne 0 ] && [ "$(id -u)" -ne 0 ]; then
    print_message "$YELLOW" "Warning: Some tests may require root privileges to run properly."
    print_message "$YELLOW" "Consider running with sudo if tests fail."
    echo ""
fi

# Run main menu
main
