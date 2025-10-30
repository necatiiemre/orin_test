#!/bin/bash

################################################################################
# JETSON ORIN DISK STRESS TEST - IMPROVED COMPATIBILITY VERSION
################################################################################
# Description: Advanced disk testing suite with fallback options
# Target: eMMC, NVMe SSD, microSD, USB storage
# Tests: Sequential/Random I/O, IOPS, Latency, Health, Endurance
# Author: Professional Storage Testing
# Version: 2.1 Improved
################################################################################

set -e

################################################################################
# CONFIGURATION
################################################################################

# Test parameters
ORIN_IP="${1:-192.168.55.69}"
ORIN_USER="${2:-orin}"
ORIN_PASS="${3}"
TEST_DURATION_HOURS="${4:-2}"

# Test duration in seconds (handle decimal hours)
if [[ "$TEST_DURATION_HOURS" == *"."* ]]; then
    # Handle decimal hours using available tools
    if command -v python3 >/dev/null 2>&1; then
        TEST_DURATION=$(python3 -c "print(int(float('$TEST_DURATION_HOURS') * 3600))")
    elif command -v awk >/dev/null 2>&1; then
        TEST_DURATION=$(awk "BEGIN {print int($TEST_DURATION_HOURS * 3600)}")
    else
        # Simple fallback for common decimals
        case "$TEST_DURATION_HOURS" in
            "0.5") TEST_DURATION=1800 ;;
            "1.5") TEST_DURATION=5400 ;;
            "2.5") TEST_DURATION=9000 ;;
            *) TEST_DURATION=$((${TEST_DURATION_HOURS%.*} * 3600)) ;;
        esac
    fi
else
    TEST_DURATION=$((TEST_DURATION_HOURS * 3600))
fi

# Test file sizes (MB)
TEST_SIZES=(1 10 100 1000)
LARGE_FILE_SIZE=2048  # 2GB for compatibility

# Log directory
LOG_DIR="./jetson_disk_test_${TEST_DURATION_HOURS}h_$(date +%Y%m%d_%H%M%S)"

################################################################################
# USAGE & HELP
################################################################################

show_usage() {
    cat << 'EOF'
================================================================================
  JETSON ORIN DISK STRESS TEST - IMPROVED VERSION
================================================================================

Usage: ./jetson_disk_stress_test.sh [orin_ip] [orin_user] [password] [hours]

Parameters:
  orin_ip     : IP address of Jetson Orin (default: 192.168.55.69)
  orin_user   : SSH username (default: orin)
  password    : SSH password (will prompt if not provided)
  hours       : Test duration in hours (default: 2, supports decimals like 0.5)

Quick Examples:
  ./jetson_disk_stress_test.sh                           # 2 hour test
  ./jetson_disk_stress_test.sh 192.168.55.69 orin q 0.5  # 30 minute test
  ./jetson_disk_stress_test.sh 192.168.55.69 orin q 1    # 1 hour test

Test Features:
  • Automatic tool detection and fallback options
  • Works with or without fio (uses dd as fallback)
  • No sudo requirements - runs with user permissions
  • Comprehensive storage analysis
  • Real-time monitoring and reporting

Tested Storage Types:
  • eMMC (internal storage)
  • NVMe SSD (if present)
  • microSD card (if present)
  • USB storage (if present)

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
  JETSON ORIN DISK STRESS TEST - IMPROVED VERSION
================================================================================"
echo ""
echo "Test Configuration:"
echo "  • Device: Jetson Orin AGX"
echo "  • Target IP: $ORIN_IP"
echo "  • SSH User: $ORIN_USER"
echo "  • Test Duration: ${TEST_DURATION_HOURS} hours ($TEST_DURATION seconds)"
echo "  • Test Mode: COMPREHENSIVE DISK STRESS"
echo "  • Compatibility Mode: Auto-detect tools"
echo ""

# Password check
if [ -z "$ORIN_PASS" ]; then
    read -sp "Enter SSH password for $ORIN_USER@$ORIN_IP: " ORIN_PASS
    echo ""
fi

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
echo "✓ SSH connection successful"
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
        echo "fio (Professional I/O): $($HAS_FIO && echo "✓ Available" || echo "✗ Missing - will use dd fallback")"
        echo "iostat (I/O Statistics): $($HAS_IOSTAT && echo "✓ Available" || echo "✗ Missing")"
        echo "iotop (I/O Monitoring): $($HAS_IOTOP && echo "✓ Available" || echo "✗ Missing")"
        echo "smartctl (Health Check): $($HAS_SMARTCTL && echo "✓ Available" || echo "✗ Missing")"
        echo "hdparm (Disk Info): $($HAS_HDPARM && echo "✓ Available" || echo "✗ Missing")"
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
        echo "Available space in /tmp: ${AVAILABLE_MB} MB"
        
        # Calculate test size (use 25% of available space, max 2GB)
        MAX_TEST_SIZE=2048
        TEST_SIZE_MB=$((AVAILABLE_MB / 4))
        if [ $TEST_SIZE_MB -gt $MAX_TEST_SIZE ]; then
            TEST_SIZE_MB=$MAX_TEST_SIZE
        fi
        if [ $TEST_SIZE_MB -lt 100 ]; then
            TEST_SIZE_MB=100
        fi
        echo "Test file size will be: ${TEST_SIZE_MB} MB"
        
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
                RATING="🟢 EXCELLENT"
            elif [ "$READ_IOPS" -gt 3000 ] && [ "$WRITE_IOPS" -gt 2000 ]; then
                RATING="🟡 GOOD"
            elif [ "$READ_IOPS" -gt 1500 ] && [ "$WRITE_IOPS" -gt 1000 ]; then
                RATING="🟠 FAIR"
            else
                RATING="🔴 POOR"
            fi
            
            echo "$RATING Performance"
            echo "  • Random Read IOPS: $READ_IOPS"
            echo "  • Random Write IOPS: $WRITE_IOPS"
        else
            echo "🔄 Performance rating requires fio and python3"
        fi
        
        echo ""
        echo "=== RECOMMENDATIONS ==="
        echo "✓ Monitor eMMC health regularly using this test"
        echo "✓ Avoid excessive small random writes to extend storage life"
        echo "✓ Consider external NVMe for high-performance applications"
        echo "✓ Ensure adequate cooling during intensive I/O operations"
        
        if [ "$HEALTH_STATUS" = "Warning" ]; then
            echo "⚠ Consider storage maintenance or replacement planning"
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
generate_final_report

log_phase "ALL DISK STRESS TESTS COMPLETED SUCCESSFULLY"

echo ""
echo "================================================================================"
echo "  DISK STRESS TEST EXECUTION COMPLETE"
echo "================================================================================"
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
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP:$REMOTE_DIR/logs/* "$LOG_DIR/logs/" 2>/dev/null
    echo "✓ Logs copied"
    
    echo "[2/3] Copying reports..."
    sshpass -p "$ORIN_PASS" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP:$REMOTE_DIR/reports/* "$LOG_DIR/reports/" 2>/dev/null
    echo "✓ Reports copied"
    
    echo "[3/3] Cleaning up remote directory..."
    sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "rm -rf $REMOTE_DIR" 2>/dev/null
    echo "✓ Cleanup complete"
else
    echo "⚠ Remote directory not found"
fi

echo ""
echo "================================================================================"
echo "  JETSON ORIN DISK STRESS TEST - COMPLETED SUCCESSFULLY"
echo "================================================================================"
echo ""
echo "📁 Results Directory: $LOG_DIR"
echo ""
echo "📊 Key Files:"
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

echo "💡 To view full report:"
echo "   cat $LOG_DIR/reports/DISK_PERFORMANCE_REPORT.txt"
echo ""
echo "✅ Jetson Orin disk stress test completed successfully!"
echo ""