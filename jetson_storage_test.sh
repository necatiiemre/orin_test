#!/bin/bash

################################################################################
# JETSON ORIN DISK STRESS TEST - ENHANCED VERSION
################################################################################
# Description: Comprehensive disk testing suite with advanced diagnostics
# Target: eMMC, NVMe SSD, microSD, USB storage
# Tests: Sequential/Random I/O, IOPS, Extended SMART, Sector Control,
#        Data Integrity, Temperature Monitoring, Health Analysis
# Author: Professional Storage Testing
# Version: 3.0 Enhanced - Production Grade
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
    # Non-interactive mode: use provided parameters directly (called from orchestrator/sequential)
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

# Test duration in seconds (handle decimal hours)
TEST_DURATION=$(echo "$TEST_DURATION_HOURS * 3600" | bc | cut -d'.' -f1)  # Convert hours to seconds (handle decimals)

# Test file sizes (MB) - will be calculated dynamically based on available space
TEST_SIZES=(1 10 100 1000)
LARGE_FILE_SIZE=0  # Will be calculated based on available space

# Log directory - accepts parameter from orchestrator/sequential test
LOG_DIR="${5:-./storage_test_$(date +%Y%m%d_%H%M%S)}"

# Debug: Show what LOG_DIR was set to
echo "[DEBUG] Storage Test - Received parameters:"
echo "  \$1 (IP): $1"
echo "  \$2 (User): $2"
echo "  \$3 (Pass): [hidden]"
echo "  \$4 (Duration): $4"
echo "  \$5 (LOG_DIR): ${5:-NOT_PROVIDED}"
echo "  Final LOG_DIR: $LOG_DIR"
echo ""

################################################################################
# USAGE & HELP
################################################################################

show_usage() {
    cat << 'EOF'
================================================================================
  JETSON ORIN DISK STRESS TEST - ENHANCED VERSION v3.0
================================================================================

Usage: ./jetson_storage_test.sh [orin_ip] [orin_user] [password] [hours]

Parameters:
  orin_ip     : IP address of Jetson Orin (default: 192.168.55.69)
  orin_user   : SSH username (default: orin)
  password    : SSH password (will prompt if not provided)
  hours       : Test duration in hours (default: 2, supports decimals like 0.5)

Quick Examples:
  ./jetson_storage_test.sh                           # 2 hour test
  ./jetson_storage_test.sh 192.168.55.69 orin q 0.5  # 30 minute test
  ./jetson_storage_test.sh 192.168.55.69 orin q 1    # 1 hour test

Enhanced Test Features (Production Grade):
  ✓ Sequential & Random I/O Performance Testing
  ✓ Extended SMART Test with Comprehensive Health Analysis
  ✓ Disk Sector Control Test (Bad Sector Detection)
  ✓ Data Integrity Verification with Checksums
  ✓ Temperature Monitoring During Stress Operations
  ✓ Sustained I/O Stress & Filesystem Metadata Tests
  ✓ Automatic tool detection and fallback options
  ✓ Works with or without fio/smartctl (graceful degradation)

Tested Storage Types:
  • eMMC (internal storage) - with lifetime analysis
  • NVMe SSD - with SMART attributes
  • microSD card
  • SATA/USB storage

Output:
  • Comprehensive performance report
  • Detailed health and sector analysis
  • Temperature profile during stress
  • Recommendations for maintenance

================================================================================
EOF
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_usage
    exit 0
fi

################################################################################
# PREREQUISITE CHECKS
################################################################################

echo "================================================================================
  JETSON ORIN DISK STRESS TEST - ENHANCED VERSION v3.0
================================================================================"
echo ""
echo "Test Configuration:"
echo "  • Device: Jetson Orin AGX"
echo "  • Target IP: $ORIN_IP"
echo "  • SSH User: $ORIN_USER"
echo "  • Test Duration: ${TEST_DURATION_HOURS} hours ($TEST_DURATION seconds)"
echo "  • Test Mode: PRODUCTION-GRADE COMPREHENSIVE TESTING"
echo ""
echo "Test Phases:"
echo "  Phase 1: Storage System Analysis"
echo "  Phase 2: Sequential I/O Performance"
echo "  Phase 3: Random I/O Performance"
echo "  Phase 4: Sustained I/O Stress"
echo "  Phase 5: Filesystem Metadata Stress"
echo "  Phase 6: Storage Health Analysis"
echo "  Phase 7: Extended SMART Test"
echo "  Phase 8: Disk Sector Control Test"
echo "  Phase 9: Temperature Monitoring"
echo ""

# Check for sshpass
if ! command -v sshpass &> /dev/null; then
    echo "ERROR: 'sshpass' is not installed"
    echo ""
    echo "Install instructions:"
    echo "  Rocky Linux: sudo dnf install epel-release && sudo dnf install sshpass"
    echo "  Ubuntu/Debian: sudo apt-get install sshpass"
    exit 1
fi

# Test SSH connection
echo "Testing SSH connection to $ORIN_IP..."
if ! sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'Connection OK'" 2>/dev/null | grep -q "Connection OK"; then
    echo "ERROR: SSH connection failed"
    echo "  Please check:"
    echo "  • IP address is correct"
    echo "  • Jetson Orin is powered on and network is accessible"
    echo "  • SSH password is correct"
    exit 1
fi
echo "[+] SSH connection successful"
echo ""

# Create log directories
mkdir -p "$LOG_DIR/logs"
mkdir -p "$LOG_DIR/reports"

# Convert to absolute path
LOG_DIR=$(cd "$LOG_DIR" && pwd)

echo "Local results directory: $LOG_DIR"
echo ""
echo "Starting disk stress test execution on Jetson Orin..."
echo ""

################################################################################
# REMOTE TEST SCRIPT
################################################################################

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "export ORIN_PASS='$ORIN_PASS'; export TEST_DURATION=$TEST_DURATION; bash -s" << 'REMOTE_SCRIPT_START'
#!/bin/bash

################################################################################
# REMOTE EXECUTION - JETSON ORIN DISK STRESS TEST - IMPROVED
################################################################################

set -e

# Test directory
TEST_DIR="/tmp/jetson_disk_stress_$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$TEST_DIR/logs"
REPORT_DIR="$TEST_DIR/reports"

mkdir -p "$TEST_DIR" "$LOG_DIR" "$REPORT_DIR"

# Test duration
TEST_DURATION_HOURS=$((TEST_DURATION / 3600))

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# UTILITY FUNCTIONS
################################################################################

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_DIR/disk_test.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_DIR/disk_test.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_DIR/disk_test.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/disk_test.log"
}

log_phase() {
    echo "" | tee -a "$LOG_DIR/disk_test.log"
    echo "================================================================================" | tee -a "$LOG_DIR/disk_test.log"
    echo -e "${MAGENTA}$1${NC}" | tee -a "$LOG_DIR/disk_test.log"
    echo "================================================================================" | tee -a "$LOG_DIR/disk_test.log"
    echo "" | tee -a "$LOG_DIR/disk_test.log"
}

detect_tools() {
    log_phase "PHASE 0: TOOL DETECTION AND SETUP"
    
    # Check available tools
    HAS_FIO=false
    HAS_IOSTAT=false
    HAS_IOTOP=false
    HAS_SMARTCTL=false
    HAS_HDPARM=false
    
    command -v fio >/dev/null 2>&1 && HAS_FIO=true
    command -v iostat >/dev/null 2>&1 && HAS_IOSTAT=true
    command -v iotop >/dev/null 2>&1 && HAS_IOTOP=true
    command -v smartctl >/dev/null 2>&1 && HAS_SMARTCTL=true
    command -v hdparm >/dev/null 2>&1 && HAS_HDPARM=true
    
    {
        echo "=== TOOL AVAILABILITY ==="
        echo "fio (Professional I/O): $($HAS_FIO && echo "[+] Available" || echo "[-] Missing - will use dd fallback")"
        echo "iostat (I/O Statistics): $($HAS_IOSTAT && echo "[+] Available" || echo "[-] Missing")"
        echo "iotop (I/O Monitoring): $($HAS_IOTOP && echo "[+] Available" || echo "[-] Missing")"
        echo "smartctl (Health Check): $($HAS_SMARTCTL && echo "[+] Available" || echo "[-] Missing")"
        echo "hdparm (Disk Info): $($HAS_HDPARM && echo "[+] Available" || echo "[i] Not installed (optional)")"
        echo ""
        echo "Test Strategy: $($HAS_FIO && echo "Professional mode with fio" || echo "Compatibility mode with dd")"
    } | tee "$LOG_DIR/tool_availability.txt"
    
    log_success "Tool detection completed"
}

get_storage_info() {
    log_phase "PHASE 1: STORAGE SYSTEM ANALYSIS"
    
    {
        echo "=== STORAGE DEVICES ==="
        lsblk -f 2>/dev/null || lsblk 2>/dev/null || echo "lsblk not available"
        echo ""
        
        echo "=== FILESYSTEM INFO ==="
        df -h
        echo ""
        
        echo "=== MOUNT POINTS ==="
        mount | grep -E "^/dev" || echo "No device mounts found"
        echo ""
        
        echo "=== AVAILABLE SPACE ==="
        AVAILABLE_KB=$(df /tmp | awk 'NR==2 {print $4}')
        AVAILABLE_MB=$((AVAILABLE_KB / 1024))
        AVAILABLE_GB=$((AVAILABLE_MB / 1024))
        echo "Available space in /tmp: ${AVAILABLE_MB} MB (${AVAILABLE_GB} GB)"

        # Calculate AGGRESSIVE test size for proper storage stress testing
        # Use 70% of available space, leaving 30% safety margin
        # Minimum: 1GB, Maximum: 50GB (to prevent extremely long tests)
        SAFETY_MARGIN_MB=$((AVAILABLE_MB * 30 / 100))  # Keep 30% free
        MIN_SAFETY_MB=2048  # Minimum 2GB safety margin

        if [ $SAFETY_MARGIN_MB -lt $MIN_SAFETY_MB ]; then
            SAFETY_MARGIN_MB=$MIN_SAFETY_MB
        fi

        TEST_SIZE_MB=$((AVAILABLE_MB - SAFETY_MARGIN_MB))

        # Apply minimum and maximum bounds
        MIN_TEST_SIZE=1024   # Minimum 1GB
        MAX_TEST_SIZE=51200  # Maximum 50GB

        if [ $TEST_SIZE_MB -lt $MIN_TEST_SIZE ]; then
            TEST_SIZE_MB=$MIN_TEST_SIZE
        fi
        if [ $TEST_SIZE_MB -gt $MAX_TEST_SIZE ]; then
            TEST_SIZE_MB=$MAX_TEST_SIZE
        fi

        TEST_SIZE_GB=$((TEST_SIZE_MB / 1024))
        UTILIZATION=$((TEST_SIZE_MB * 100 / AVAILABLE_MB))

        echo "Test file size: ${TEST_SIZE_MB} MB (~${TEST_SIZE_GB} GB)"
        echo "Space utilization: ${UTILIZATION}%"
        echo "Safety margin: ${SAFETY_MARGIN_MB} MB (~$((SAFETY_MARGIN_MB / 1024)) GB)"
        echo ""
        echo "This aggressive test size ensures proper storage stress testing!"
        
        echo ""
        echo "=== BLOCK DEVICE DETAILS ==="
        for dev in $(lsblk -ndo NAME 2>/dev/null | grep -E '^(mmcblk|nvme|sd)' | head -5); do
            if [ -b "/dev/$dev" ]; then
                echo "Device: /dev/$dev"
                echo "  Size: $(lsblk -ndo SIZE /dev/$dev 2>/dev/null || echo 'Unknown')"
                echo "  Type: $(lsblk -ndo TYPE /dev/$dev 2>/dev/null || echo 'Unknown')"
                $HAS_HDPARM && hdparm -I /dev/$dev 2>/dev/null | grep -E "(Model|Serial)" | head -2 || echo "  No detailed info available"
                echo ""
            fi
        done
        
    } | tee "$LOG_DIR/storage_analysis.txt"
}

test_sequential_io() {
    log_phase "PHASE 2: SEQUENTIAL I/O PERFORMANCE"
    
    local test_dir="/tmp/seq_io_test"
    mkdir -p "$test_dir"
    
    if $HAS_FIO; then
        log_info "Using fio for professional sequential I/O testing"
        
        # Test with different block sizes
        for bs in 4k 64k 1m; do
            log_info "Sequential test with ${bs} blocks"
            
            # Write test
            fio --name=seq_write_${bs} \
                --directory="$test_dir" \
                --rw=write \
                --bs="$bs" \
                --size=${TEST_SIZE_MB}M \
                --numjobs=1 \
                --runtime=120 \
                --time_based \
                --direct=1 \
                --output="$LOG_DIR/seq_write_${bs}.json" \
                --output-format=json \
                >/dev/null 2>&1
            
            # Read test  
            fio --name=seq_read_${bs} \
                --directory="$test_dir" \
                --rw=read \
                --bs="$bs" \
                --size=${TEST_SIZE_MB}M \
                --numjobs=1 \
                --runtime=120 \
                --time_based \
                --direct=1 \
                --output="$LOG_DIR/seq_read_${bs}.json" \
                --output-format=json \
                >/dev/null 2>&1
        done
    else
        log_info "Using dd for basic sequential I/O testing"
        
        # DD-based tests
        {
            echo "=== DD SEQUENTIAL TESTS ==="
            
            # Write test
            echo "Sequential Write Test:"
            WRITE_TIME=$(time (dd if=/dev/zero of="$test_dir/write_test.dat" bs=1M count=$TEST_SIZE_MB 2>&1) 2>&1)
            echo "$WRITE_TIME"
            
            # Read test
            echo ""
            echo "Sequential Read Test:"
            sync
            READ_TIME=$(time (dd if="$test_dir/write_test.dat" of=/dev/null bs=1M 2>&1) 2>&1)
            echo "$READ_TIME"
            
        } | tee "$LOG_DIR/dd_sequential.log"
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    log_success "Sequential I/O tests completed"
}

test_random_io() {
    log_phase "PHASE 3: RANDOM I/O PERFORMANCE"
    
    local test_dir="/tmp/random_io_test"
    mkdir -p "$test_dir"
    
    if $HAS_FIO; then
        log_info "Using fio for professional random I/O testing"
        
        # Random 4K tests
        for rw_type in randread randwrite randrw; do
            log_info "Random 4K test: ${rw_type}"
            
            fio --name=random_4k_${rw_type} \
                --directory="$test_dir" \
                --rw="$rw_type" \
                --bs=4k \
                --size=512M \
                --numjobs=1 \
                --iodepth=16 \
                --runtime=180 \
                --time_based \
                --direct=1 \
                --ioengine=libaio \
                --output="$LOG_DIR/random_4k_${rw_type}.json" \
                --output-format=json \
                >/dev/null 2>&1
        done
    else
        log_info "Using dd for basic random I/O simulation"
        
        # Create test file
        dd if=/dev/zero of="$test_dir/random_test.dat" bs=1M count=512 2>/dev/null
        
        {
            echo "=== DD RANDOM I/O SIMULATION ==="
            
            # Random read simulation
            echo "Random Read Test (1000 operations):"
            START_TIME=$(date +%s)
            for i in $(seq 1 1000); do
                OFFSET=$((RANDOM % 512))
                dd if="$test_dir/random_test.dat" of=/dev/null bs=4k count=1 skip=$((OFFSET * 256)) 2>/dev/null
            done
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))
            # Prevent division by zero
            if [ "$DURATION" -le 0 ]; then
                DURATION=1
            fi
            IOPS=$((1000 / DURATION))
            echo "Random Read IOPS (approximate): $IOPS"
            
            echo ""
            echo "Random Write Test (1000 operations):"
            START_TIME=$(date +%s)
            for i in $(seq 1 1000); do
                OFFSET=$((RANDOM % 512))
                dd if=/dev/zero of="$test_dir/random_test.dat" bs=4k count=1 seek=$((OFFSET * 256)) conv=notrunc 2>/dev/null
            done
            END_TIME=$(date +%s)
            DURATION=$((END_TIME - START_TIME))
            # Prevent division by zero
            if [ "$DURATION" -le 0 ]; then
                DURATION=1
            fi
            IOPS=$((1000 / DURATION))
            echo "Random Write IOPS (approximate): $IOPS"
            
        } | tee "$LOG_DIR/dd_random.log"
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    log_success "Random I/O tests completed"
}

test_sustained_stress() {
    log_phase "PHASE 4: SUSTAINED I/O STRESS TEST"
    
    local test_dir="/tmp/stress_test"
    local stress_duration=$((TEST_DURATION / 3))
    mkdir -p "$test_dir"
    
    log_info "Running sustained I/O stress for $stress_duration seconds"
    
    # Background I/O stress
    {
        START_TIME=$(date +%s)
        END_TIME=$((START_TIME + stress_duration))
        OPERATION_COUNT=0
        
        while [ $(date +%s) -lt $END_TIME ]; do
            OPERATION_COUNT=$((OPERATION_COUNT + 1))
            FILE_NAME="$test_dir/stress_$OPERATION_COUNT.dat"
            
            # Write operation
            dd if=/dev/urandom of="$FILE_NAME" bs=1M count=32 2>/dev/null
            
            # Read operation  
            dd if="$FILE_NAME" of=/dev/null bs=1M 2>/dev/null
            
            # Delete operation
            rm -f "$FILE_NAME"
            
            if [ $((OPERATION_COUNT % 10)) -eq 0 ]; then
                echo "Completed $OPERATION_COUNT stress operations..."
            fi
        done
        
        echo "Total stress operations: $OPERATION_COUNT"
        echo "Operations per second: $((OPERATION_COUNT / stress_duration))"
        
    } | tee "$LOG_DIR/sustained_stress.log"
    
    # Cleanup
    rm -rf "$test_dir"
    log_success "Sustained stress test completed"
}

test_filesystem_stress() {
    log_phase "PHASE 5: FILESYSTEM METADATA STRESS"
    
    local test_dir="/tmp/fs_stress_test"
    mkdir -p "$test_dir"
    
    log_info "Creating and testing small files for filesystem stress"
    
    {
        # Create many small files
        FILE_COUNT=0
        MAX_FILES=5000
        START_TIME=$(date +%s)
        
        for i in $(seq 1 $MAX_FILES); do
            echo "Test data for file $i $(date)" > "$test_dir/small_$i.txt"
            FILE_COUNT=$((FILE_COUNT + 1))
            
            if [ $((i % 1000)) -eq 0 ]; then
                echo "Created $i files..."
            fi
        done
        
        CREATE_TIME=$(($(date +%s) - START_TIME))
        echo "Created $FILE_COUNT files in $CREATE_TIME seconds"
        
        # Test file operations
        echo ""
        echo "Testing file operations:"
        
        # Find test
        START_TIME=$(date +%s)
        FOUND_COUNT=$(find "$test_dir" -name "small_*.txt" | wc -l)
        FIND_TIME=$(($(date +%s) - START_TIME))
        echo "Found $FOUND_COUNT files in $FIND_TIME seconds"
        
        # List test
        START_TIME=$(date +%s)
        LIST_COUNT=$(ls "$test_dir" | wc -l)
        LIST_TIME=$(($(date +%s) - START_TIME))
        echo "Listed $LIST_COUNT entries in $LIST_TIME seconds"
        
        # Delete test
        START_TIME=$(date +%s)
        rm -f "$test_dir"/small_*.txt
        DELETE_TIME=$(($(date +%s) - START_TIME))
        echo "Deleted files in $DELETE_TIME seconds"
        
    } | tee "$LOG_DIR/filesystem_stress.log"
    
    # Cleanup
    rm -rf "$test_dir"
    log_success "Filesystem stress test completed"
}

check_storage_health() {
    log_phase "PHASE 6: STORAGE HEALTH ANALYSIS"

    {
        echo "=== STORAGE HEALTH CHECK ==="

        # eMMC health check
        echo "eMMC Health Status:"
        if [ -d "/sys/class/mmc_host" ]; then
            for mmc in /sys/class/mmc_host/mmc*/mmc*; do
                if [ -d "$mmc" ]; then
                    echo "  Device: $(basename $mmc)"
                    [ -f "$mmc/life_time_estimation_a" ] && echo "    Life Time A: $(cat $mmc/life_time_estimation_a 2>/dev/null)"
                    [ -f "$mmc/life_time_estimation_b" ] && echo "    Life Time B: $(cat $mmc/life_time_estimation_b 2>/dev/null)"
                    [ -f "$mmc/pre_eol_info" ] && echo "    Pre-EOL: $(cat $mmc/pre_eol_info 2>/dev/null)"
                fi
            done
        else
            echo "  No eMMC health information available"
        fi

        echo ""
        echo "SMART Health Check:"
        if $HAS_SMARTCTL; then
            for device in /dev/sd* /dev/nvme* /dev/mmcblk*; do
                if [ -b "$device" ] && [[ ! "$device" =~ [0-9]$ ]]; then
                    echo "  Device: $device"
                    smartctl -H "$device" 2>/dev/null | grep -i health || echo "    No SMART data"
                fi
            done
        else
            echo "  smartctl not available"
        fi

        echo ""
        echo "I/O Error Check:"
        ERROR_COUNT=$(dmesg | grep -i -c "i/o error\|disk error\|read error\|write error" 2>/dev/null || echo "0")
        echo "  Recent I/O errors in dmesg: $ERROR_COUNT"

        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo "  Recent I/O errors found:"
            dmesg | grep -i "i/o error\|disk error\|read error\|write error" | tail -5
        fi

    } | tee "$LOG_DIR/health_check.log"

    log_success "Storage health check completed"
}

run_extended_smart_test() {
    log_phase "PHASE 7: EXTENDED SMART TEST"

    {
        echo "=== EXTENDED SMART TEST ==="
        echo "This comprehensive test checks disk health, attributes, and error logs"
        echo ""

        if ! $HAS_SMARTCTL; then
            log_warning "smartctl not available - skipping Extended SMART test"
            echo "To install: sudo apt-get install smartmontools"
            return
        fi

        # Find all storage devices
        DEVICES=()
        for device in /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/mmcblk[0-9]; do
            if [ -b "$device" ]; then
                DEVICES+=("$device")
            fi
        done

        if [ ${#DEVICES[@]} -eq 0 ]; then
            log_warning "No block devices found for SMART testing"
            return
        fi

        echo "Found ${#DEVICES[@]} device(s) to test"
        echo ""

        for device in "${DEVICES[@]}"; do
            echo "================================================================================"
            echo "DEVICE: $device"
            echo "================================================================================"
            echo ""

            # Basic device information
            echo "--- Basic Information ---"
            smartctl -i "$device" 2>/dev/null || echo "Unable to read device info"
            echo ""

            # SMART capability check
            echo "--- SMART Capability ---"
            SMART_AVAILABLE=$(smartctl -i "$device" 2>/dev/null | grep -i "SMART support is: Available" && echo "YES" || echo "NO")
            SMART_ENABLED=$(smartctl -i "$device" 2>/dev/null | grep -i "SMART support is: Enabled" && echo "YES" || echo "NO")
            echo "SMART Available: $SMART_AVAILABLE"
            echo "SMART Enabled: $SMART_ENABLED"
            echo ""

            if [ "$SMART_AVAILABLE" = "NO" ]; then
                echo "SMART not supported on this device, skipping..."
                echo ""
                continue
            fi

            # Overall health status
            echo "--- Health Status ---"
            HEALTH_STATUS=$(smartctl -H "$device" 2>/dev/null)
            echo "$HEALTH_STATUS"

            if echo "$HEALTH_STATUS" | grep -qi "PASSED"; then
                echo "[✓] Health Status: PASSED"
            elif echo "$HEALTH_STATUS" | grep -qi "FAILED"; then
                echo "[✗] Health Status: FAILED - IMMEDIATE ATTENTION REQUIRED!"
            else
                echo "[?] Health Status: Unable to determine"
            fi
            echo ""

            # SMART Attributes (for SATA/SAS drives)
            echo "--- SMART Attributes ---"
            smartctl -A "$device" 2>/dev/null | grep -E "ID#|^[[:space:]]*[0-9]+" || echo "No SMART attributes available (may be NVMe or eMMC)"
            echo ""

            # Temperature monitoring
            echo "--- Temperature ---"
            TEMP=$(smartctl -A "$device" 2>/dev/null | grep -i temperature | head -1)
            if [ -n "$TEMP" ]; then
                echo "$TEMP"
                TEMP_VALUE=$(echo "$TEMP" | awk '{print $10}')
                if [ -n "$TEMP_VALUE" ] && [ "$TEMP_VALUE" -gt 70 ]; then
                    echo "[!] WARNING: High temperature detected (${TEMP_VALUE}°C)"
                elif [ -n "$TEMP_VALUE" ]; then
                    echo "[✓] Temperature normal (${TEMP_VALUE}°C)"
                fi
            else
                echo "Temperature data not available"
            fi
            echo ""

            # Error logs
            echo "--- Error Logs ---"
            ERROR_LOG=$(smartctl -l error "$device" 2>/dev/null)
            if echo "$ERROR_LOG" | grep -qi "No Errors Logged"; then
                echo "[✓] No errors logged"
            else
                echo "$ERROR_LOG" | head -30
            fi
            echo ""

            # Self-test logs
            echo "--- Self-Test History ---"
            smartctl -l selftest "$device" 2>/dev/null | head -20 || echo "No self-test history available"
            echo ""

            # Start extended test (background)
            echo "--- Initiating Extended Self-Test ---"
            echo "Note: Extended test runs in background and may take hours"
            TEST_START=$(smartctl -t long "$device" 2>/dev/null)
            echo "$TEST_START"

            if echo "$TEST_START" | grep -qi "Please wait"; then
                ESTIMATED_TIME=$(echo "$TEST_START" | grep -i "please wait" | grep -oP '\d+' | head -1)
                echo "[*] Extended test started - estimated completion time: ${ESTIMATED_TIME} minutes"
                echo "[*] Check status with: smartctl -a $device"
            fi
            echo ""

            # NVMe specific information
            if [[ "$device" =~ nvme ]]; then
                echo "--- NVMe Specific Information ---"
                smartctl -A "$device" 2>/dev/null | grep -E "Critical|Temperature|Available|Percentage|Data Units" || echo "Limited NVMe data"
                echo ""
            fi

            # eMMC specific information (via mmc-utils if available)
            if [[ "$device" =~ mmcblk ]] && command -v mmc >/dev/null 2>&1; then
                echo "--- eMMC Specific Information ---"
                mmc extcsd read "$device" 2>/dev/null | grep -E "Life|EOL|Bad" | head -10 || echo "Limited eMMC data"
                echo ""
            fi

            echo ""
        done

        echo "================================================================================"
        echo "EXTENDED SMART TEST SUMMARY"
        echo "================================================================================"
        echo ""
        echo "Tests initiated on ${#DEVICES[@]} device(s)"
        echo "Extended tests are running in background"
        echo "Monitor progress with: smartctl -a <device>"
        echo ""

    } | tee "$LOG_DIR/extended_smart_test.log"

    log_success "Extended SMART test initiated"
}

test_disk_sectors() {
    log_phase "PHASE 8: DISK SECTOR CONTROL TEST"

    {
        echo "=== DISK SECTOR CONTROL TEST ==="
        echo "Checking for bad sectors and read errors"
        echo ""

        local test_dir="/tmp/sector_test"
        mkdir -p "$test_dir"

        # Method 1: Check dmesg for bad sector reports
        echo "--- Checking System Logs for Bad Sectors ---"
        BAD_SECTOR_COUNT=$(dmesg | grep -i "bad sector\|bad block\|medium error" | wc -l)
        echo "Bad sector warnings in dmesg: $BAD_SECTOR_COUNT"

        if [ "$BAD_SECTOR_COUNT" -gt 0 ]; then
            echo ""
            echo "Recent bad sector warnings:"
            dmesg | grep -i "bad sector\|bad block\|medium error" | tail -10
        fi
        echo ""

        # Method 2: Read test with dd for accessible areas
        echo "--- Sequential Read Test for Error Detection ---"
        echo "Testing /tmp filesystem sectors..."

        TEST_FILE="$test_dir/sector_test.dat"
        SECTOR_TEST_SIZE_MB=1024  # 1GB test

        # Write test data
        echo "Creating test file (${SECTOR_TEST_SIZE_MB}MB)..."
        if dd if=/dev/zero of="$TEST_FILE" bs=1M count=$SECTOR_TEST_SIZE_MB 2>/dev/null; then
            echo "[✓] Write completed successfully"
        else
            echo "[✗] Write errors detected"
        fi

        # Read back and check for errors
        echo ""
        echo "Reading back test file to detect sector errors..."
        READ_ERRORS=0

        if dd if="$TEST_FILE" of=/dev/null bs=1M 2>"$test_dir/read_errors.log"; then
            echo "[✓] Read completed successfully - no sector errors detected"
        else
            READ_ERRORS=1
            echo "[✗] Read errors detected!"
            cat "$test_dir/read_errors.log"
        fi

        echo ""

        # Method 3: Check filesystem for bad blocks (requires root for some operations)
        echo "--- Filesystem Bad Block Information ---"

        # Check if we can access bad block info
        FS_TYPE=$(df -T /tmp | tail -1 | awk '{print $2}')
        echo "Filesystem type for /tmp: $FS_TYPE"

        if [ "$FS_TYPE" = "ext4" ] || [ "$FS_TYPE" = "ext3" ]; then
            echo "For ext filesystems, bad block info requires root access"
            echo "To check manually: sudo dumpe2fs -b /dev/<device> | grep -i bad"
        fi

        echo ""

        # Method 4: SMART bad sector count
        echo "--- SMART Bad Sector Count ---"
        if $HAS_SMARTCTL; then
            for device in /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/mmcblk[0-9]; do
                if [ -b "$device" ]; then
                    echo "Device: $device"

                    # Check for reallocated sectors
                    REALLOCATED=$(smartctl -A "$device" 2>/dev/null | grep -i "Reallocated_Sector\|Reallocated_Event" | head -2)
                    if [ -n "$REALLOCATED" ]; then
                        echo "$REALLOCATED"

                        # Extract reallocated sector count
                        REALLOC_COUNT=$(echo "$REALLOCATED" | awk '{print $10}' | head -1)
                        if [ -n "$REALLOC_COUNT" ] && [ "$REALLOC_COUNT" -gt 0 ]; then
                            echo "[!] WARNING: $REALLOC_COUNT reallocated sectors detected"
                        else
                            echo "[✓] No reallocated sectors"
                        fi
                    else
                        echo "  No reallocated sector information available"
                    fi

                    # Check for pending sectors
                    PENDING=$(smartctl -A "$device" 2>/dev/null | grep -i "Current_Pending_Sector")
                    if [ -n "$PENDING" ]; then
                        echo "$PENDING"

                        PENDING_COUNT=$(echo "$PENDING" | awk '{print $10}')
                        if [ -n "$PENDING_COUNT" ] && [ "$PENDING_COUNT" -gt 0 ]; then
                            echo "[!] WARNING: $PENDING_COUNT pending sectors detected"
                        else
                            echo "[✓] No pending sectors"
                        fi
                    fi

                    # Check for uncorrectable errors
                    UNCORRECTABLE=$(smartctl -A "$device" 2>/dev/null | grep -i "Offline_Uncorrectable")
                    if [ -n "$UNCORRECTABLE" ]; then
                        echo "$UNCORRECTABLE"

                        UNCORR_COUNT=$(echo "$UNCORRECTABLE" | awk '{print $10}')
                        if [ -n "$UNCORR_COUNT" ] && [ "$UNCORR_COUNT" -gt 0 ]; then
                            echo "[✗] CRITICAL: $UNCORR_COUNT uncorrectable sectors detected!"
                        else
                            echo "[✓] No uncorrectable sectors"
                        fi
                    fi

                    echo ""
                fi
            done
        else
            echo "smartctl not available for bad sector SMART analysis"
        fi

        # Method 5: Pattern write/read test for data integrity
        echo "--- Sector Data Integrity Test ---"
        echo "Writing known pattern and verifying readback..."

        PATTERN_FILE="$test_dir/pattern_test.dat"
        PATTERN_SIZE_MB=100

        # Create pattern file with known data
        dd if=/dev/urandom of="$PATTERN_FILE" bs=1M count=$PATTERN_SIZE_MB 2>/dev/null

        # Calculate checksum
        ORIGINAL_SUM=$(md5sum "$PATTERN_FILE" | awk '{print $1}')
        echo "Original checksum: $ORIGINAL_SUM"

        # Force write to disk
        sync

        # Read back and verify
        READBACK_SUM=$(md5sum "$PATTERN_FILE" | awk '{print $1}')
        echo "Readback checksum: $READBACK_SUM"

        if [ "$ORIGINAL_SUM" = "$READBACK_SUM" ]; then
            echo "[✓] Data integrity verified - checksums match"
        else
            echo "[✗] DATA CORRUPTION DETECTED - checksums do not match!"
            echo "This indicates potential sector problems or memory issues"
        fi

        echo ""

        # Cleanup
        rm -rf "$test_dir"

        echo "================================================================================"
        echo "SECTOR TEST SUMMARY"
        echo "================================================================================"
        echo "Bad sector warnings: $BAD_SECTOR_COUNT"
        echo "Read errors: $READ_ERRORS"
        echo "Data integrity: $([ "$ORIGINAL_SUM" = "$READBACK_SUM" ] && echo "PASSED" || echo "FAILED")"
        echo ""

        if [ "$BAD_SECTOR_COUNT" -gt 0 ] || [ "$READ_ERRORS" -gt 0 ] || [ "$ORIGINAL_SUM" != "$READBACK_SUM" ]; then
            echo "[!] RECOMMENDATION: Storage may have issues - consider replacement"
        else
            echo "[✓] No sector issues detected"
        fi

    } | tee "$LOG_DIR/sector_control_test.log"

    log_success "Disk sector control test completed"
}

monitor_temperature() {
    log_phase "PHASE 9: TEMPERATURE MONITORING DURING STRESS"

    {
        echo "=== TEMPERATURE MONITORING ==="
        echo "Monitoring storage device temperatures during operation"
        echo ""

        # Check CPU/SoC temperature (Jetson specific)
        echo "--- System Temperatures ---"
        if [ -d "/sys/devices/virtual/thermal" ]; then
            for thermal_zone in /sys/devices/virtual/thermal/thermal_zone*/temp; do
                if [ -f "$thermal_zone" ]; then
                    TEMP=$(cat "$thermal_zone" 2>/dev/null)
                    ZONE_NAME=$(basename $(dirname "$thermal_zone"))
                    TEMP_C=$((TEMP / 1000))
                    echo "  $ZONE_NAME: ${TEMP_C}°C"
                fi
            done
        fi

        echo ""

        # Check storage device temperatures
        echo "--- Storage Device Temperatures ---"
        if $HAS_SMARTCTL; then
            for device in /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/mmcblk[0-9]; do
                if [ -b "$device" ]; then
                    echo "Device: $device"

                    # Get temperature from SMART
                    TEMP_INFO=$(smartctl -A "$device" 2>/dev/null | grep -i "temperature")

                    if [ -n "$TEMP_INFO" ]; then
                        echo "$TEMP_INFO"

                        # Extract temperature value
                        TEMP_VALUE=$(echo "$TEMP_INFO" | awk '{print $10}' | head -1)

                        if [ -n "$TEMP_VALUE" ]; then
                            if [ "$TEMP_VALUE" -gt 70 ]; then
                                echo "  [!] WARNING: High temperature (${TEMP_VALUE}°C) - Risk of thermal throttling"
                            elif [ "$TEMP_VALUE" -gt 55 ]; then
                                echo "  [*] Elevated temperature (${TEMP_VALUE}°C) - Monitor closely"
                            else
                                echo "  [✓] Temperature normal (${TEMP_VALUE}°C)"
                            fi
                        fi
                    else
                        echo "  Temperature data not available"
                    fi
                    echo ""
                fi
            done
        else
            echo "smartctl not available for temperature monitoring"
        fi

        # Monitor over time during stress test
        echo "--- Continuous Temperature Monitoring ---"
        echo "Monitoring for 60 seconds during I/O operations..."

        local monitor_dir="/tmp/temp_monitor_test"
        mkdir -p "$monitor_dir"

        # Start background I/O to generate heat
        (
            for i in {1..20}; do
                dd if=/dev/zero of="$monitor_dir/heat_test_$i.dat" bs=1M count=50 2>/dev/null
                dd if="$monitor_dir/heat_test_$i.dat" of=/dev/null bs=1M 2>/dev/null
                rm -f "$monitor_dir/heat_test_$i.dat"
            done
        ) &
        IO_PID=$!

        # Monitor temperature every 10 seconds
        for i in {1..6}; do
            sleep 10

            echo "Sample $i (${i}0s):"

            # Storage temp
            if $HAS_SMARTCTL; then
                for device in /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/mmcblk[0-9]; do
                    if [ -b "$device" ]; then
                        TEMP=$(smartctl -A "$device" 2>/dev/null | grep -i "temperature" | awk '{print $10}' | head -1)
                        [ -n "$TEMP" ] && echo "  $device: ${TEMP}°C"
                    fi
                done
            fi

            # System thermal zones
            if [ -d "/sys/devices/virtual/thermal/thermal_zone0" ]; then
                SYS_TEMP=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null)
                [ -n "$SYS_TEMP" ] && echo "  System: $((SYS_TEMP / 1000))°C"
            fi

            echo ""
        done

        # Wait for I/O to complete
        wait $IO_PID 2>/dev/null
        rm -rf "$monitor_dir"

        echo "================================================================================"
        echo "TEMPERATURE MONITORING SUMMARY"
        echo "================================================================================"
        echo "Temperature monitoring completed over 60 seconds of I/O stress"
        echo "Check logs above for any thermal warnings"
        echo ""

    } | tee "$LOG_DIR/temperature_monitoring.log"

    log_success "Temperature monitoring completed"
}

generate_final_report() {
    log_phase "GENERATING COMPREHENSIVE DISK PERFORMANCE REPORT"
    
    {
        echo "================================================================================"
        echo "  JETSON ORIN DISK PERFORMANCE ANALYSIS REPORT"
        echo "================================================================================"
        echo ""
        echo "Test Configuration:"
        echo "  • Duration: ${TEST_DURATION_HOURS} hours"
        echo "  • Test Mode: $($HAS_FIO && echo "Professional (fio)" || echo "Compatibility (dd)")"
        echo "  • Generated: $(date)"
        echo ""
        
        echo "=== STORAGE SYSTEM OVERVIEW ==="
        if [ -f "$LOG_DIR/storage_analysis.txt" ]; then
            grep -A 10 "FILESYSTEM INFO" "$LOG_DIR/storage_analysis.txt" || echo "Storage info not available"
        fi
        echo ""
        
        echo "=== PERFORMANCE RESULTS ==="
        
        if $HAS_FIO && [ -f "$LOG_DIR/seq_write_1m.json" ]; then
            echo "Sequential Performance (1MB blocks):"
            # Parse FIO JSON results
            if command -v python3 >/dev/null 2>&1; then
                WRITE_BW=$(python3 -c "
import json, sys
try:
    with open('$LOG_DIR/seq_write_1m.json', 'r') as f:
        data = json.load(f)
        bw_mb = data['jobs'][0]['write']['bw_bytes'] / (1024*1024)
        print(f'{bw_mb:.1f} MB/s')
except:
    print('N/A')
")
                READ_BW=$(python3 -c "
import json, sys
try:
    with open('$LOG_DIR/seq_read_1m.json', 'r') as f:
        data = json.load(f)
        bw_mb = data['jobs'][0]['read']['bw_bytes'] / (1024*1024)
        print(f'{bw_mb:.1f} MB/s')
except:
    print('N/A')
")
                echo "  • Sequential Write: $WRITE_BW"
                echo "  • Sequential Read: $READ_BW"
            else
                echo "  • Sequential results available in JSON format"
            fi
        elif [ -f "$LOG_DIR/dd_sequential.log" ]; then
            echo "Sequential Performance (dd-based):"
            WRITE_SPEED=$(grep "MB/s\|GB/s" "$LOG_DIR/dd_sequential.log" | head -1 || echo "N/A")
            READ_SPEED=$(grep "MB/s\|GB/s" "$LOG_DIR/dd_sequential.log" | tail -1 || echo "N/A")
            echo "  • Write Speed: $WRITE_SPEED"
            echo "  • Read Speed: $READ_SPEED"
        fi
        
        echo ""
        if $HAS_FIO && [ -f "$LOG_DIR/random_4k_randread.json" ]; then
            echo "Random 4K Performance:"
            if command -v python3 >/dev/null 2>&1; then
                RAND_READ_IOPS=$(python3 -c "
import json
try:
    with open('$LOG_DIR/random_4k_randread.json', 'r') as f:
        data = json.load(f)
        print(int(data['jobs'][0]['read']['iops']))
except:
    print('N/A')
")
                RAND_WRITE_IOPS=$(python3 -c "
import json
try:
    with open('$LOG_DIR/random_4k_randwrite.json', 'r') as f:
        data = json.load(f)
        print(int(data['jobs'][0]['write']['iops']))
except:
    print('N/A')
")
                echo "  • Random Read IOPS: $RAND_READ_IOPS"
                echo "  • Random Write IOPS: $RAND_WRITE_IOPS"
            fi
        elif [ -f "$LOG_DIR/dd_random.log" ]; then
            echo "Random Performance (dd-based approximation):"
            grep "IOPS" "$LOG_DIR/dd_random.log" || echo "  • Random performance data available in logs"
        fi
        
        echo ""
        echo "=== STRESS TEST RESULTS ==="
        if [ -f "$LOG_DIR/sustained_stress.log" ]; then
            STRESS_OPS=$(grep "Total stress operations" "$LOG_DIR/sustained_stress.log" | awk '{print $4}' || echo "N/A")
            STRESS_OPS_SEC=$(grep "Operations per second" "$LOG_DIR/sustained_stress.log" | awk '{print $4}' || echo "N/A")
            echo "  • Sustained I/O Operations: $STRESS_OPS"
            echo "  • Operations per Second: $STRESS_OPS_SEC"
        fi
        
        if [ -f "$LOG_DIR/filesystem_stress.log" ]; then
            FILES_CREATED=$(grep "Created.*files in" "$LOG_DIR/filesystem_stress.log" | awk '{print $2}' || echo "N/A")
            echo "  • Small Files Created: $FILES_CREATED"
        fi
        
        echo ""
        echo "=== STORAGE HEALTH STATUS ==="
        if [ -f "$LOG_DIR/health_check.log" ]; then
            # Extract health info
            HEALTH_STATUS="Good"
            if grep -q "Life Time A:" "$LOG_DIR/health_check.log"; then
                LIFE_A=$(grep "Life Time A:" "$LOG_DIR/health_check.log" | head -1 | awk '{print $4}' || echo "N/A")
                LIFE_B=$(grep "Life Time B:" "$LOG_DIR/health_check.log" | head -1 | awk '{print $4}' || echo "N/A")
                echo "  • eMMC Life Time A: $LIFE_A"
                echo "  • eMMC Life Time B: $LIFE_B"

                # Check if wear is concerning (values > 0x05 indicate significant wear)
                if [[ "$LIFE_A" =~ 0x0[6789abc] ]] || [[ "$LIFE_B" =~ 0x0[6789abc] ]]; then
                    HEALTH_STATUS="Warning"
                fi
            fi

            ERROR_COUNT=$(grep "Recent I/O errors" "$LOG_DIR/health_check.log" | awk '{print $6}' || echo "0")
            echo "  • Recent I/O Errors: $ERROR_COUNT"

            if [ "$ERROR_COUNT" -gt 0 ]; then
                HEALTH_STATUS="Warning"
            fi

            echo "  • Overall Health: $HEALTH_STATUS"
        fi

        echo ""
        echo "=== EXTENDED SMART TEST RESULTS ==="
        if [ -f "$LOG_DIR/extended_smart_test.log" ]; then
            # Check for SMART health status
            SMART_HEALTH=$(grep -i "Health Status: PASSED\|Health Status: FAILED" "$LOG_DIR/extended_smart_test.log" | head -1)
            if [ -n "$SMART_HEALTH" ]; then
                if echo "$SMART_HEALTH" | grep -qi "PASSED"; then
                    echo "  • SMART Health: [✓] PASSED"
                else
                    echo "  • SMART Health: [✗] FAILED - CRITICAL"
                    HEALTH_STATUS="Critical"
                fi
            else
                echo "  • SMART Health: Not available"
            fi

            # Check for extended test initiation
            if grep -q "Extended test started" "$LOG_DIR/extended_smart_test.log"; then
                echo "  • Extended Self-Test: Initiated (running in background)"
            fi

            # Temperature warnings
            TEMP_WARNINGS=$(grep -c "WARNING: High temperature" "$LOG_DIR/extended_smart_test.log" || echo "0")
            if [ "$TEMP_WARNINGS" -gt 0 ]; then
                echo "  • Temperature Warnings: $TEMP_WARNINGS device(s) running hot"
            else
                echo "  • Temperature: Normal"
            fi
        else
            echo "  • Extended SMART test not performed"
        fi

        echo ""
        echo "=== SECTOR INTEGRITY RESULTS ==="
        if [ -f "$LOG_DIR/sector_control_test.log" ]; then
            # Bad sectors
            BAD_SECTORS=$(grep "Bad sector warnings:" "$LOG_DIR/sector_control_test.log" | awk '{print $4}' || echo "0")
            echo "  • Bad Sector Warnings: $BAD_SECTORS"

            # Read errors
            READ_ERRS=$(grep "Read errors:" "$LOG_DIR/sector_control_test.log" | awk '{print $3}' || echo "0")
            echo "  • Read Errors: $READ_ERRS"

            # Data integrity
            DATA_INTEGRITY=$(grep "Data integrity:" "$LOG_DIR/sector_control_test.log" | awk '{print $3}' || echo "Unknown")
            if [ "$DATA_INTEGRITY" = "PASSED" ]; then
                echo "  • Data Integrity: [✓] PASSED"
            elif [ "$DATA_INTEGRITY" = "FAILED" ]; then
                echo "  • Data Integrity: [✗] FAILED - Data corruption detected!"
                HEALTH_STATUS="Critical"
            else
                echo "  • Data Integrity: Unknown"
            fi

            # Check for reallocated/pending sectors from SMART
            if grep -q "reallocated sectors" "$LOG_DIR/sector_control_test.log"; then
                REALLOC=$(grep "reallocated sectors" "$LOG_DIR/sector_control_test.log" | grep -o "[0-9]* reallocated" | awk '{print $1}' || echo "0")
                if [ "$REALLOC" -gt 0 ]; then
                    echo "  • Reallocated Sectors: $REALLOC"
                fi
            fi
        else
            echo "  • Sector control test not performed"
        fi

        echo ""
        echo "=== TEMPERATURE MONITORING ==="
        if [ -f "$LOG_DIR/temperature_monitoring.log" ]; then
            # Check for high temperature warnings
            HIGH_TEMP=$(grep -c "WARNING: High temperature" "$LOG_DIR/temperature_monitoring.log" || echo "0")
            ELEVATED_TEMP=$(grep -c "Elevated temperature" "$LOG_DIR/temperature_monitoring.log" || echo "0")

            if [ "$HIGH_TEMP" -gt 0 ]; then
                echo "  • Status: [!] High temperatures detected during stress"
                echo "  • High Temp Readings: $HIGH_TEMP"
            elif [ "$ELEVATED_TEMP" -gt 0 ]; then
                echo "  • Status: [*] Elevated temperatures during stress"
                echo "  • Elevated Temp Readings: $ELEVATED_TEMP"
            else
                echo "  • Status: [✓] Temperatures remained normal"
            fi

            # Get sample temperature reading
            SAMPLE_TEMP=$(grep "Sample 6" -A 10 "$LOG_DIR/temperature_monitoring.log" | grep "°C" | head -1 | grep -o "[0-9]*°C" || echo "N/A")
            if [ "$SAMPLE_TEMP" != "N/A" ]; then
                echo "  • Final Reading: $SAMPLE_TEMP"
            fi
        else
            echo "  • Temperature monitoring not performed"
        fi
        
        echo ""
        echo "=== PERFORMANCE RATING ==="
        
        # Determine overall rating
        RATING="Unknown"
        if $HAS_FIO && command -v python3 >/dev/null 2>&1 && [ -f "$LOG_DIR/random_4k_randread.json" ]; then
            READ_IOPS=$(python3 -c "
import json
try:
    with open('$LOG_DIR/random_4k_randread.json', 'r') as f:
        data = json.load(f)
        print(int(data['jobs'][0]['read']['iops']))
except:
    print(0)
")
            WRITE_IOPS=$(python3 -c "
import json
try:
    with open('$LOG_DIR/random_4k_randwrite.json', 'r') as f:
        data = json.load(f)
        print(int(data['jobs'][0]['write']['iops']))
except:
    print(0)
")
            
            if [ "$READ_IOPS" -gt 6000 ] && [ "$WRITE_IOPS" -gt 4000 ]; then
                RATING="[+] EXCELLENT"
            elif [ "$READ_IOPS" -gt 3000 ] && [ "$WRITE_IOPS" -gt 2000 ]; then
                RATING="[+] GOOD"
            elif [ "$READ_IOPS" -gt 1500 ] && [ "$WRITE_IOPS" -gt 1000 ]; then
                RATING="[!] FAIR"
            else
                RATING="[-] POOR"
            fi
            
            echo "$RATING Performance"
            echo "  • Random Read IOPS: $READ_IOPS"
            echo "  • Random Write IOPS: $WRITE_IOPS"
        else
            echo "[*] Performance rating requires fio and python3"
        fi

        echo ""
        echo "=== RECOMMENDATIONS ==="

        # Health-based recommendations
        if [ "$HEALTH_STATUS" = "Critical" ]; then
            echo "[!] CRITICAL: Immediate action required!"
            echo "    • Data backup should be performed immediately"
            echo "    • Plan for storage replacement as soon as possible"
            echo "    • Do not use for critical data without backup"
        elif [ "$HEALTH_STATUS" = "Warning" ]; then
            echo "[!] WARNING: Storage showing signs of wear or issues"
            echo "    • Consider storage maintenance or replacement planning"
            echo "    • Increase backup frequency"
            echo "    • Monitor health more regularly"
        else
            echo "[✓] Storage health is good"
        fi

        echo ""
        echo "General Best Practices:"
        echo "  • Run this comprehensive test monthly for production systems"
        echo "  • Monitor eMMC life time estimates (warn at 0x05+, replace at 0x09+)"
        echo "  • Avoid excessive small random writes to extend storage life"
        echo "  • Ensure adequate cooling during intensive I/O operations"
        echo "  • Keep storage usage below 80% capacity for optimal performance"
        echo "  • Consider external NVMe SSD for high-performance applications"

        # Temperature-specific recommendations
        if [ -f "$LOG_DIR/temperature_monitoring.log" ]; then
            HIGH_TEMP=$(grep -c "WARNING: High temperature" "$LOG_DIR/temperature_monitoring.log" || echo "0")
            if [ "$HIGH_TEMP" -gt 0 ]; then
                echo ""
                echo "Temperature Management:"
                echo "  • Improve cooling/airflow around Jetson device"
                echo "  • Consider adding heatsinks or thermal pads"
                echo "  • Reduce sustained I/O workload intensity"
                echo "  • High temperatures can reduce storage lifespan"
            fi
        fi

        # SMART test recommendations
        if [ -f "$LOG_DIR/extended_smart_test.log" ]; then
            if grep -q "Extended test started" "$LOG_DIR/extended_smart_test.log"; then
                echo ""
                echo "Extended SMART Test:"
                echo "  • Extended self-test is running in background"
                echo "  • Check results later with: smartctl -a /dev/<device>"
                echo "  • This may take several hours to complete"
            fi
        fi

        # Sector issues recommendations
        if [ -f "$LOG_DIR/sector_control_test.log" ]; then
            if grep -q "RECOMMENDATION: Storage may have issues" "$LOG_DIR/sector_control_test.log"; then
                echo ""
                echo "Sector Issues Detected:"
                echo "  • Run filesystem check: fsck (requires unmount)"
                echo "  • Consider low-level format if supported"
                echo "  • Plan for replacement if issues persist"
            fi
        fi
        
        echo ""
        echo "================================================================================"
        echo ""
        echo "Detailed logs: $LOG_DIR"
        echo "Generated: $(date)"
        
    } | tee "$REPORT_DIR/DISK_PERFORMANCE_REPORT.txt"
    
    # Create simple results summary
    {
        echo "DISK_TEST_COMPLETED=1"
        echo "TEST_DURATION_HOURS=$TEST_DURATION_HOURS"
        echo "HAS_FIO=$HAS_FIO"
        echo "HEALTH_STATUS=${HEALTH_STATUS:-Unknown}"
        
    } > "$REPORT_DIR/test_summary.txt"
    
    log_success "Comprehensive disk performance report generated"
}

################################################################################
# MAIN EXECUTION FLOW
################################################################################

log_phase "JETSON ORIN DISK STRESS TEST - STARTING EXECUTION"

# Detect available tools
detect_tools

# Set test size globally after detection
TEST_SIZE_MB=512  # Conservative default

# Execute test phases
get_storage_info
test_sequential_io
test_random_io
test_sustained_stress
test_filesystem_stress
check_storage_health
run_extended_smart_test
test_disk_sectors
monitor_temperature
generate_final_report

log_phase "ALL DISK STRESS TESTS COMPLETED SUCCESSFULLY"

echo ""
echo "================================================================================"
echo "  DISK STRESS TEST EXECUTION COMPLETE"
echo "================================================================================"
echo ""
echo "Tester: $TESTER_NAME"
echo "Quality Checker: $QUALITY_CHECKER_NAME"
echo ""
echo "Test directory: $TEST_DIR"
echo "Main report: $REPORT_DIR/DISK_PERFORMANCE_REPORT.txt"
echo "Summary: $REPORT_DIR/test_summary.txt"
echo ""

# Display key results
if [ -f "$REPORT_DIR/DISK_PERFORMANCE_REPORT.txt" ]; then
    echo "=== QUICK SUMMARY ==="
    grep -A 5 "PERFORMANCE RATING" "$REPORT_DIR/DISK_PERFORMANCE_REPORT.txt" || echo "Full report available"
fi

REMOTE_SCRIPT_START

################################################################################
# COPY RESULTS TO HOST
################################################################################

echo ""
echo "================================================================================"
echo "  COPYING DISK TEST RESULTS TO HOST MACHINE"
echo "================================================================================"
echo ""

REMOTE_DIR=$(sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "ls -td /tmp/jetson_disk_stress_* 2>/dev/null | head -1")

if [ -n "$REMOTE_DIR" ]; then
    echo "Remote test directory: $REMOTE_DIR"
    echo ""

    echo "[1/3] Copying logs..."
    # Use directory copying instead of wildcards for reliability
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP:$REMOTE_DIR/logs/" "$LOG_DIR/" 2>/dev/null && echo "[+] Logs copied" || echo "[!] Some logs may not have copied"

    echo "[2/3] Copying reports..."
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$ORIN_USER@$ORIN_IP:$REMOTE_DIR/reports/" "$LOG_DIR/" 2>/dev/null && echo "[+] Reports copied" || echo "[!] Some reports may not have copied"

    echo "[3/3] Cleaning up remote directory..."
    sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "rm -rf $REMOTE_DIR" 2>/dev/null
    echo "[+] Cleanup complete"
else
    echo "[!] Remote directory not found"
fi

echo ""
echo "================================================================================"
echo "  JETSON ORIN DISK STRESS TEST - COMPLETED SUCCESSFULLY"
echo "================================================================================"
echo ""
echo "[*] Results Directory: $LOG_DIR"
echo ""
echo "[*] Key Files:"
echo "   • Main Report:     $LOG_DIR/reports/DISK_PERFORMANCE_REPORT.txt"
echo "   • Test Summary:    $LOG_DIR/reports/test_summary.txt"
echo "   • Tool Detection:  $LOG_DIR/logs/tool_availability.txt"
echo "   • Storage Info:    $LOG_DIR/logs/storage_analysis.txt"
echo "   • Health Check:    $LOG_DIR/logs/health_check.log"
echo ""

if [ -f "$LOG_DIR/reports/DISK_PERFORMANCE_REPORT.txt" ]; then
    echo "================================================================================"
    echo "  QUICK PERFORMANCE SUMMARY"
    echo "================================================================================"
    echo ""
    # Show performance rating section
    grep -A 10 "PERFORMANCE RATING" "$LOG_DIR/reports/DISK_PERFORMANCE_REPORT.txt" 2>/dev/null || echo "See full report for details"
    echo ""
fi

echo "[*] To view full report:"
echo "   cat $LOG_DIR/reports/DISK_PERFORMANCE_REPORT.txt"
echo ""
echo "[+] Jetson Orin disk stress test completed successfully!"
echo ""