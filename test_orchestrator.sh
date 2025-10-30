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

# Function to display the menu
display_menu() {
    clear
    echo "=============================================="
    echo "    Jetson Orin Test Orchestrator"
    echo "=============================================="
    echo ""
    echo "Select a test to run:"
    echo ""
    echo "  1. CPU Test"
    echo "  2. GPU Test"
    echo "  3. RAM Test"
    echo "  4. Storage Test"
    echo "  5. Combined Test (All Tests)"
    echo "  0. Exit"
    echo ""
    echo "=============================================="
}

# Function to run CPU test
run_cpu_test() {
    print_message "$BLUE" "\nStarting CPU Test..."
    if [ -f "$SCRIPT_DIR/jetson_cpu_test.sh" ]; then
        bash "$SCRIPT_DIR/jetson_cpu_test.sh"
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
    print_message "$BLUE" "\nStarting GPU Test..."
    if [ -f "$SCRIPT_DIR/jetson_gpu_test.sh" ]; then
        bash "$SCRIPT_DIR/jetson_gpu_test.sh"
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
    print_message "$BLUE" "\nStarting RAM Test..."
    if [ -f "$SCRIPT_DIR/ram/complete_ram_test.sh" ]; then
        bash "$SCRIPT_DIR/ram/complete_ram_test.sh"
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
    print_message "$BLUE" "\nStarting Storage Test..."
    if [ -f "$SCRIPT_DIR/jetson_storage_test.sh" ]; then
        bash "$SCRIPT_DIR/jetson_storage_test.sh"
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

    local failed_tests=()
    local passed_tests=()

    # Run CPU Test
    print_message "$YELLOW" "\n[1/4] Running CPU Test..."
    if run_cpu_test; then
        passed_tests+=("CPU")
    else
        failed_tests+=("CPU")
    fi

    # Run GPU Test
    print_message "$YELLOW" "\n[2/4] Running GPU Test..."
    if run_gpu_test; then
        passed_tests+=("GPU")
    else
        failed_tests+=("GPU")
    fi

    # Run RAM Test
    print_message "$YELLOW" "\n[3/4] Running RAM Test..."
    if run_ram_test; then
        passed_tests+=("RAM")
    else
        failed_tests+=("RAM")
    fi

    # Run Storage Test
    print_message "$YELLOW" "\n[4/4] Running Storage Test..."
    if run_storage_test; then
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
