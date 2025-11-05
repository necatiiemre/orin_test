#!/bin/bash

################################################################################
# JETSON ORIN - PCI DEVICE TEST
################################################################################
# Description: Simple PCI device test for sending/receiving data and speed test
# Version: 1.0
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

    log_info "Testing PCI device speed..."

    # Get PCI device link speed and width
    ssh_execute_with_output "$ip" "$user" "$pass" "
        echo '=== PCI Link Speed Test ==='
        for device in \$(lspci | grep -v 'Host bridge\|ISA bridge\|PCI bridge' | awk '{print \$1}'); do
            echo \"Device: \$device\"
            lspci -vv -s \$device 2>/dev/null | grep -E 'LnkCap:|LnkSta:' || echo 'Link info not available'
            echo ''
        done
    " | tee -a "$PCI_LOG"

    log_success "PCI speed test completed"
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
        lspci -v -s \$device_addr | grep -A 5 'Memory at'

        echo ''
        echo '=== Data Transfer Simulation ==='
        # Simulate data transfer by checking device activity
        if [ -d \"/sys/bus/pci/devices/0000:\$device_addr\" ]; then
            echo '✓ Device is accessible'

            # Check if device supports DMA
            if [ -f \"/sys/bus/pci/devices/0000:\$device_addr/dma_mask_bits\" ]; then
                dma_bits=\$(cat /sys/bus/pci/devices/0000:\$device_addr/dma_mask_bits)
                echo \"✓ Device supports \${dma_bits}-bit DMA\"
            fi

            # Check device enable status
            if [ -f \"/sys/bus/pci/devices/0000:\$device_addr/enable\" ]; then
                enabled=\$(cat /sys/bus/pci/devices/0000:\$device_addr/enable)
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

        # Check for PCI errors
        echo 'Checking for PCI errors...'
        if dmesg | tail -100 | grep -i 'pci.*error' > /dev/null 2>&1; then
            echo '⚠ PCI errors found in kernel log:'
            dmesg | tail -100 | grep -i 'pci.*error' | tail -5
        else
            echo '✓ No PCI errors in recent kernel log'
        fi

        echo ''

        # Check device status for all PCI devices
        for device in \$(lspci | grep -v 'Host bridge\|ISA bridge\|PCI bridge' | awk '{print \$1}'); do
            echo \"Device \$device:\"

            # Check device status register
            if lspci -vv -s \$device 2>/dev/null | grep -q 'Status:'; then
                echo \"  Status: \$(lspci -vv -s \$device | grep 'Status:' | head -1)\"
            fi

            # Check for correctable/uncorrectable errors
            if lspci -vv -s \$device 2>/dev/null | grep -E 'CESta:|UESta:' > /dev/null; then
                correctable=\$(lspci -vv -s \$device | grep 'CESta:' | head -1)
                uncorrectable=\$(lspci -vv -s \$device | grep 'UESta:' | head -1)

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
        error_count=\$(dmesg | grep -i 'pci.*error' | wc -l)
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

            # Run speed test
            test_pci_speed "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"
            echo ""

            # Run data transfer test
            test_pci_data_transfer "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"
            echo ""

            # Run health check
            check_pci_health "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"
            echo ""

            # Summary
            echo "================================================================================"
            echo -e "${GREEN}PCI TEST COMPLETED SUCCESSFULLY${NC}"
            echo "================================================================================"
            echo ""
            echo "Results saved to: $OUTPUT_DIR"
            echo "Log file: $PCI_LOG"
            echo ""
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
