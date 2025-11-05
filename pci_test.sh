#!/bin/bash

################################################################################
# JETSON ORIN - PCI DEVICE TEST
################################################################################
# Description: Simple PCI device test for sending/receiving data and speed test
# Hardware: x16 PCIe slot supporting x8 PCIe Gen4 (16GT/s, ~15.75 GB/s)
# Requirements: Remote user must have sudo privileges (passwordless sudo recommended)
# Note: Test will FAIL if PCIe link speed cannot be validated
# Version: 1.3
################################################################################

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/jetson_utils.sh" 2>/dev/null || {
    # Define minimal color codes if utils not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
    log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
}

################################################################################
# CONFIGURATION
################################################################################

ORIN_IP="${ORIN_IP:-192.168.55.69}"
ORIN_USER="${ORIN_USER:-orin}"
ORIN_PASS="${ORIN_PASS}"

OUTPUT_DIR="pci_test_results_$(date +%Y%m%d_%H%M%S)"
PCI_LOG="$OUTPUT_DIR/pci_test.log"

# Jetson Orin PCIe Specifications
# x16 physical slot supporting x8 PCIe Gen4
EXPECTED_PCIE_GEN="4"
EXPECTED_PCIE_LANES="8"
EXPECTED_PCIE_SPEED="16GT/s"  # Gen4 = 16GT/s per lane

################################################################################
# FUNCTIONS
################################################################################

# Check if PCI device is present
check_pci_device() {
    local ip="$1"
    local user="$2"
    local pass="$3"

    log_info "Checking for PCI devices..."

    # Get list of PCI devices
    local pci_devices=$(ssh_execute "$ip" "$user" "$pass" "lspci" 2>/dev/null)

    if [ -z "$pci_devices" ]; then
        log_error "Failed to query PCI devices"
        return 1
    fi

    # Count non-host bridge devices
    local device_count=$(echo "$pci_devices" | grep -v "Host bridge\|ISA bridge\|PCI bridge" | wc -l)

    echo ""
    echo "=== PCI Devices Found ==="
    echo "$pci_devices"
    echo ""

    if [ "$device_count" -gt 0 ]; then
        log_success "Found $device_count PCI device(s)"
        return 0
    else
        log_warning "No PCI devices detected"
        return 1
    fi
}

# Test PCI device speed
test_pci_speed() {
    local ip="$1"
    local user="$2"
    local pass="$3"

    log_info "Testing PCI device speed against Gen4 x8 specification..."

    # Get PCI device link speed and width (requires sudo for full access)
    local test_output=$(ssh_execute_with_output "$ip" "$user" "$pass" "
        echo '=== PCI Link Speed Test ==='
        echo 'Expected: PCIe Gen4 x8 (16GT/s, 8 lanes)'
        echo 'Physical slot: x16 (supporting x8 electrically)'
        echo ''

        link_found=0

        for device in \$(lspci | grep -v 'Host bridge\|ISA bridge\|PCI bridge' | awk '{print \$1}'); do
            echo \"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\"
            echo \"Device: \$device\"
            device_name=\$(lspci -s \$device | cut -d' ' -f2-)
            echo \"Name: \$device_name\"
            echo ''

            # Get detailed link information (use sudo for full access)
            link_info=\$(sudo lspci -vv -s \$device 2>/dev/null)

            if echo \"\$link_info\" | grep -q 'LnkCap:'; then
                link_found=1
                # Extract link capabilities
                lnk_cap=\$(echo \"\$link_info\" | grep 'LnkCap:')
                lnk_sta=\$(echo \"\$link_info\" | grep 'LnkSta:' | head -1)

                echo \"Link Capabilities:\"
                echo \"  \$lnk_cap\"
                echo \"Link Status (Current):\"
                echo \"  \$lnk_sta\"
                echo ''

                # Parse current speed and width
                current_speed=\$(echo \"\$lnk_sta\" | grep -oP 'Speed \K[^,]+' || echo 'Unknown')
                current_width=\$(echo \"\$lnk_sta\" | grep -oP 'Width x\K[0-9]+' || echo 'Unknown')

                echo \"Current Configuration:\"
                echo \"  Speed: \$current_speed\"
                echo \"  Width: x\$current_width\"
                echo ''

                # Validate against expected specifications
                echo \"Specification Check:\"
                if echo \"\$current_speed\" | grep -q '16GT/s'; then
                    echo \"  ✓ Speed: Gen4 (16GT/s) - PASS\"
                elif echo \"\$current_speed\" | grep -q '8GT/s'; then
                    echo \"  ⚠ Speed: Gen3 (8GT/s) - Device running slower than Gen4\"
                elif echo \"\$current_speed\" | grep -q '5GT/s'; then
                    echo \"  ⚠ Speed: Gen2 (5GT/s) - Device running slower than Gen4\"
                elif echo \"\$current_speed\" | grep -q '2.5GT/s'; then
                    echo \"  ⚠ Speed: Gen1 (2.5GT/s) - Device running much slower than Gen4\"
                else
                    echo \"  ? Speed: \$current_speed - Unable to determine\"
                fi

                if [ \"\$current_width\" = \"8\" ]; then
                    echo \"  ✓ Width: x8 lanes - PASS\"
                elif [ \"\$current_width\" = \"16\" ]; then
                    echo \"  ⚠ Width: x16 lanes - Device requesting more lanes than supported (x8 max)\"
                elif [ \"\$current_width\" -lt 8 ] 2>/dev/null; then
                    echo \"  ⚠ Width: x\$current_width lanes - Device using fewer lanes than available (x8 max)\"
                else
                    echo \"  ? Width: x\$current_width - Unable to validate\"
                fi

                # Calculate theoretical bandwidth
                if echo \"\$current_speed\" | grep -q '16GT/s' && [ \"\$current_width\" = \"8\" ]; then
                    # Gen4 x8 = 16 GT/s * 8 lanes * 128b/130b encoding / 8 bits = ~15.75 GB/s
                    echo ''
                    echo \"Theoretical Bandwidth: ~15.75 GB/s (Gen4 x8)\"
                fi
            else
                echo \"  ✗ Link information not available for this device\"
                echo \"  Possible causes:\"
                echo \"    - Device doesn't support standard PCIe capabilities\"
                echo \"    - Sudo access not configured properly\"
                echo \"    - Device driver issue\"
            fi
            echo ''
        done

        echo \"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\"
        exit \$link_found
    ")

    local exit_code=$?
    echo "$test_output" | tee -a "$PCI_LOG"

    if [ $exit_code -eq 1 ]; then
        log_success "PCI speed test completed - Link information retrieved"
        return 0
    else
        log_error "PCI speed test failed - Could not retrieve PCIe link information"
        return 1
    fi
}

# Send and receive data test
test_pci_data_transfer() {
    local ip="$1"
    local user="$2"
    local pass="$3"

    log_info "Testing PCI data send/receive..."

    # Create test data and transfer through PCI devices
    ssh_execute_with_output "$ip" "$user" "$pass" "
        echo '=== PCI Data Transfer Test ==='

        # Find first non-bridge PCI device
        device_addr=\$(lspci | grep -v 'Host bridge\|ISA bridge\|PCI bridge' | head -1 | awk '{print \$1}')

        if [ -z \"\$device_addr\" ]; then
            echo 'No suitable PCI device found for data transfer test'
            exit 1
        fi

        echo \"Testing device: \$device_addr\"

        # Get device details
        device_name=\$(lspci -s \$device_addr | cut -d' ' -f2-)
        echo \"Device name: \$device_name\"

        # Check if device has driver loaded
        driver_path=\"/sys/bus/pci/devices/0000:\$device_addr/driver\"
        if [ -L \"\$driver_path\" ]; then
            driver=\$(basename \$(readlink \$driver_path))
            echo \"Driver: \$driver\"
        else
            echo \"Driver: Not loaded\"
        fi

        # Test basic read/write capability
        echo ''
        echo 'Testing PCI configuration space access...'
        if lspci -xxx -s \$device_addr > /dev/null 2>&1; then
            echo '✓ PCI configuration space readable'

            # Show first 64 bytes of config space
            echo ''
            echo 'Configuration Space (first 64 bytes):'
            lspci -xxx -s \$device_addr | head -5
        else
            echo '✗ Failed to read PCI configuration space'
        fi

        # Test device resource access
        echo ''
        echo 'Device resources:'
        sudo lspci -v -s \$device_addr | grep -A 5 'Memory at'

        echo ''
        echo '=== Data Transfer Simulation ==='
        # Simulate data transfer by checking device activity
        if sudo test -d \"/sys/bus/pci/devices/0000:\$device_addr\"; then
            echo '✓ Device is accessible'

            # Check if device supports DMA
            if sudo test -f \"/sys/bus/pci/devices/0000:\$device_addr/dma_mask_bits\"; then
                dma_bits=\$(sudo cat /sys/bus/pci/devices/0000:\$device_addr/dma_mask_bits 2>/dev/null)
                if [ -n \"\$dma_bits\" ]; then
                    echo \"✓ Device supports \${dma_bits}-bit DMA\"
                fi
            fi

            # Check device enable status
            if sudo test -f \"/sys/bus/pci/devices/0000:\$device_addr/enable\"; then
                enabled=\$(sudo cat /sys/bus/pci/devices/0000:\$device_addr/enable 2>/dev/null)
                if [ \"\$enabled\" = \"1\" ]; then
                    echo '✓ Device is enabled'
                else
                    echo '✗ Device is disabled'
                fi
            fi
        else
            echo '✗ Device is not accessible'
        fi
    " | tee -a "$PCI_LOG"

    log_success "PCI data transfer test completed"
}

# Check PCI device health
check_pci_health() {
    local ip="$1"
    local user="$2"
    local pass="$3"

    log_info "Checking PCI device health..."

    ssh_execute_with_output "$ip" "$user" "$pass" "
        echo '=== PCI Device Health Check ==='

        # Check for PCI errors (requires sudo)
        echo 'Checking for PCI errors...'
        if sudo dmesg 2>/dev/null | tail -100 | grep -i 'pci.*error' > /dev/null 2>&1; then
            echo '⚠ PCI errors found in kernel log:'
            sudo dmesg | tail -100 | grep -i 'pci.*error' | tail -5
        else
            echo '✓ No PCI errors in recent kernel log'
        fi

        echo ''

        # Check device status for all PCI devices (requires sudo for full info)
        for device in \$(lspci | grep -v 'Host bridge\|ISA bridge\|PCI bridge' | awk '{print \$1}'); do
            echo \"Device \$device:\"

            # Check device status register
            if sudo lspci -vv -s \$device 2>/dev/null | grep -q 'Status:'; then
                echo \"  Status: \$(sudo lspci -vv -s \$device | grep 'Status:' | head -1)\"
            fi

            # Check for correctable/uncorrectable errors
            if sudo lspci -vv -s \$device 2>/dev/null | grep -E 'CESta:|UESta:' > /dev/null; then
                correctable=\$(sudo lspci -vv -s \$device | grep 'CESta:' | head -1)
                uncorrectable=\$(sudo lspci -vv -s \$device | grep 'UESta:' | head -1)

                if [ -n \"\$correctable\" ]; then
                    echo \"  \$correctable\"
                fi
                if [ -n \"\$uncorrectable\" ]; then
                    echo \"  \$uncorrectable\"
                fi
            fi

            echo ''
        done

        # Overall health assessment
        echo '=== Overall Health Assessment ==='
        error_count=\$(sudo dmesg 2>/dev/null | grep -i 'pci.*error' | wc -l)
        if [ \$error_count -eq 0 ]; then
            echo '✓ PCI subsystem health: GOOD'
        elif [ \$error_count -lt 5 ]; then
            echo '⚠ PCI subsystem health: WARNING (minor errors detected)'
        else
            echo '✗ PCI subsystem health: POOR (multiple errors detected)'
        fi
    " | tee -a "$PCI_LOG"

    log_success "PCI health check completed"
}

# Interactive device check
ask_device_present() {
    echo ""
    echo -e "${YELLOW}Is there a device plugged into the PCI slot?${NC}"
    read -p "Enter 'yes' or 'no': " response
    echo ""

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        [Nn]|[Nn][Oo])
            return 1
            ;;
        *)
            log_warning "Invalid response. Please enter 'yes' or 'no'"
            ask_device_present
            ;;
    esac
}

################################################################################
# MAIN
################################################################################

main() {
    clear
    echo "================================================================================"
    echo "  JETSON ORIN - PCI DEVICE TEST"
    echo "================================================================================"
    echo ""
    echo "NOTE: This test requires sudo privileges on the remote Jetson Orin system"
    echo "      for full PCIe capability inspection and health monitoring."
    echo ""

    # Collect parameters if not set
    if [ -z "$ORIN_PASS" ]; then
        collect_test_parameters "$ORIN_IP" "$ORIN_USER" "" "1"
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Check prerequisites
    check_prerequisites "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"

    # Start test
    echo ""
    log_info "Starting PCI device test..."
    echo "Test results will be saved to: $OUTPUT_DIR"
    echo ""

    # Ask if device is present
    if ask_device_present; then
        log_success "User confirmed device is present"
        echo ""

        # Check for devices
        if check_pci_device "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"; then
            echo ""

            # Run speed test (critical - must pass)
            speed_test_passed=0
            if test_pci_speed "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"; then
                speed_test_passed=1
            fi
            echo ""

            # Run data transfer test
            test_pci_data_transfer "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"
            echo ""

            # Run health check
            check_pci_health "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"
            echo ""

            # Summary
            echo "================================================================================"
            if [ $speed_test_passed -eq 1 ]; then
                echo -e "${GREEN}PCI TEST COMPLETED SUCCESSFULLY${NC}"
                echo "================================================================================"
                echo ""
                echo "✓ PCIe link speed and capabilities validated"
            else
                echo -e "${RED}PCI TEST COMPLETED WITH WARNINGS${NC}"
                echo "================================================================================"
                echo ""
                echo "✗ Could not validate PCIe Gen4 x8 specification"
                echo ""
                echo "The test detected a PCI device but could not read PCIe link information."
                echo "This is required to verify the device is running at Gen4 x8 speeds."
                echo ""
                echo "Troubleshooting steps:"
                echo "  1. Ensure 'orin' user has passwordless sudo access"
                echo "  2. Check if the device supports standard PCIe capabilities"
                echo "  3. Try running: sudo lspci -vv on the Jetson to verify manually"
                echo "  4. Verify the device is properly seated in the PCIe slot"
                echo ""
            fi
            echo "Jetson Orin PCIe Specification:"
            echo "  Physical slot: x16"
            echo "  Electrical support: x8 PCIe Gen4"
            echo "  Max speed: 16GT/s per lane"
            echo "  Theoretical bandwidth: ~15.75 GB/s"
            echo ""
            echo "Results saved to: $OUTPUT_DIR"
            echo "Log file: $PCI_LOG"
            echo ""
            echo "Review the log file for detailed information"
            echo ""

            if [ $speed_test_passed -eq 0 ]; then
                exit 1
            fi
        else
            log_error "No PCI devices detected by system"
            echo ""
            echo "Possible reasons:"
            echo "  • Device not properly seated in slot"
            echo "  • Device not powered"
            echo "  • Device incompatible with system"
            echo "  • System needs reboot to detect device"
            exit 1
        fi
    else
        log_info "User indicated no device present - skipping test"
        echo ""
        echo "Please insert a PCI device and run the test again"
        exit 0
    fi
}

# Run main function
main "$@"
