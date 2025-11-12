#!/bin/bash

################################################################################
# JETSON ORIN - COMMON UTILITIES
################################################################################
# Description: Shared utility functions for all test modules
# Version: 2.2 - Fixed core detection and added GPU functions
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

################################################################################
# LOGGING FUNCTIONS
################################################################################

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_phase() {
    echo ""
    echo "================================================================================"
    echo -e "${MAGENTA}$1${NC}"
    echo "================================================================================"
    echo ""
}

################################################################################
# PROGRESS BAR FUNCTION
################################################################################

print_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' '.'
    printf "] %d%% (%d/%d)" $percentage $current $total
}

################################################################################
# SYSTEM DETECTION FUNCTIONS
################################################################################

# Get real physical CPU cores (not hyperthreads)
get_physical_cores() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    
    if [ -n "$ip" ] && [ -n "$user" ] && [ -n "$pass" ]; then
        # Remote detection for Jetson systems
        ssh_execute "$ip" "$user" "$pass" "
            # For Jetson systems, use nproc directly as it gives correct core count
            cores=\$(nproc)
            
            # Double check with /proc/cpuinfo for Jetson-specific detection
            if [ -f /etc/nv_tegra_release ] || [ -f /proc/device-tree/model ]; then
                # This is a Jetson system, nproc should be accurate
                echo \$cores
            else
                # Non-Jetson system, try more sophisticated detection
                if [ -f /sys/devices/system/cpu/cpu0/topology/core_siblings_list ]; then
                    # Method 1: Use topology info
                    unique_cores=\$(cat /sys/devices/system/cpu/cpu*/topology/core_siblings_list 2>/dev/null | sort -u | wc -l)
                    if [ \$unique_cores -gt 0 ] && [ \$unique_cores -le \$cores ]; then
                        echo \$unique_cores
                    else
                        echo \$cores
                    fi
                elif [ -f /proc/cpuinfo ]; then
                    # Method 2: Count unique core IDs
                    unique_cores=\$(grep 'core id' /proc/cpuinfo | sort -u | wc -l 2>/dev/null || echo 0)
                    if [ \$unique_cores -gt 0 ]; then
                        echo \$unique_cores
                    else
                        echo \$cores
                    fi
                else
                    echo \$cores
                fi
            fi
        " 2>/dev/null || echo "8"
    else
        # Local detection
        cores=$(nproc)
        if [ -f /etc/nv_tegra_release ] || [ -f /proc/device-tree/model ]; then
            # This is a Jetson system
            echo $cores
        else
            # Non-Jetson system
            if [ -f /sys/devices/system/cpu/cpu0/topology/core_siblings_list ]; then
                unique_cores=$(cat /sys/devices/system/cpu/cpu*/topology/core_siblings_list 2>/dev/null | sort -u | wc -l)
                if [ $unique_cores -gt 0 ] && [ $unique_cores -le $cores ]; then
                    echo $unique_cores
                else
                    echo $cores
                fi
            else
                echo $cores
            fi
        fi
    fi
}

# Detect Jetson model
detect_jetson_model() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    
    if [ -n "$ip" ] && [ -n "$user" ] && [ -n "$pass" ]; then
        ssh_execute "$ip" "$user" "$pass" "
            if [ -f /proc/device-tree/model ]; then
                cat /proc/device-tree/model 2>/dev/null | tr -d '\0'
            elif [ -f /etc/nv_tegra_release ]; then
                grep -o 'Jetson [^,]*' /etc/nv_tegra_release 2>/dev/null | head -1
            else
                echo 'Unknown Jetson'
            fi
        " 2>/dev/null || echo "Unknown Jetson"
    else
        if [ -f /proc/device-tree/model ]; then
            cat /proc/device-tree/model 2>/dev/null | tr -d '\0'
        elif [ -f /etc/nv_tegra_release ]; then
            grep -o 'Jetson [^,]*' /etc/nv_tegra_release 2>/dev/null | head -1
        else
            echo 'Unknown Jetson'
        fi
    fi
}

################################################################################
# SSH UTILITY FUNCTIONS
################################################################################

ssh_execute() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local command="$4"
    
    sshpass -p "$pass" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$user@$ip" "$command" 2>/dev/null
}

ssh_execute_with_output() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local command="$4"
    
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$user@$ip" "$command"
}

scp_copy_from_remote() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local remote_path="$4"
    local local_path="$5"
    
    sshpass -p "$pass" scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$user@$ip:$remote_path" "$local_path" 2>/dev/null
}

# Added missing scp_download function
scp_download() {
    local ip="$1"
    local user="$2" 
    local pass="$3"
    local remote_path="$4"
    local local_path="$5"
    
    sshpass -p "$pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$user@$ip:$remote_path" "$local_path" 2>/dev/null || {
        log_warning "Failed to download $remote_path from remote system"
        return 1
    }
}

################################################################################
# INTERACTIVE PARAMETER COLLECTION
################################################################################

# Function to collect test parameters interactively with defaults
collect_test_parameters() {
    local default_ip="${1:-192.168.55.69}"
    local default_user="${2:-orin}"
    local default_pass="${3}"
    local default_duration="${4:-1}"

    # Clear screen and show banner
    clear
    echo -e "${CYAN}${BOLD}"
    echo "================================================================================"
    echo "  JETSON ORIN AGX - TEST PARAMETER CONFIGURATION"
    echo "================================================================================"
    echo -e "${NC}"
    echo ""

    # Collect IP address
    echo -e "${YELLOW}Enter test parameters (press Enter to use default):${NC}"
    echo ""
    read -p "$(echo -e ${BOLD}IP Address${NC}) [$default_ip]: " input_ip
    ORIN_IP="${input_ip:-$default_ip}"

    # Collect username
    read -p "$(echo -e ${BOLD}Username${NC}) [$default_user]: " input_user
    ORIN_USER="${input_user:-$default_user}"

    # Collect password (hidden)
    if [ -n "$default_pass" ]; then
        read -sp "$(echo -e ${BOLD}Password${NC}) [using provided password]: " input_pass
        echo ""
        ORIN_PASS="${input_pass:-$default_pass}"
    else
        read -sp "$(echo -e ${BOLD}Password${NC}): " input_pass
        echo ""
        ORIN_PASS="$input_pass"
    fi
    echo ""

    # Collect tester name
    read -p "$(echo -e ${BOLD}Tester name${NC}): " TESTER_NAME
    while [ -z "$TESTER_NAME" ]; do
        echo -e "${RED}Tester name is required${NC}"
        read -p "$(echo -e ${BOLD}Tester name${NC}): " TESTER_NAME
    done

    # Collect quality checker name
    read -p "$(echo -e ${BOLD}Quality checker name${NC}): " QUALITY_CHECKER_NAME
    while [ -z "$QUALITY_CHECKER_NAME" ]; do
        echo -e "${RED}Quality checker name is required${NC}"
        read -p "$(echo -e ${BOLD}Quality checker name${NC}): " QUALITY_CHECKER_NAME
    done

    # Collect device serial number
    read -p "$(echo -e ${BOLD}Device serial number${NC}): " DEVICE_SERIAL
    while true; do
        if [ -z "$DEVICE_SERIAL" ]; then
            echo -e "${RED}Device serial number is required${NC}"
            read -p "$(echo -e ${BOLD}Device serial number${NC}): " DEVICE_SERIAL
        elif ! [[ "$DEVICE_SERIAL" =~ ^[a-zA-Z0-9]+$ ]]; then
            echo -e "${RED}Device serial number must contain only letters and numbers${NC}"
            read -p "$(echo -e ${BOLD}Device serial number${NC}): " DEVICE_SERIAL
        else
            # Convert to uppercase
            DEVICE_SERIAL=$(echo "$DEVICE_SERIAL" | tr '[:lower:]' '[:upper:]')
            break
        fi
    done

    # Collect test duration
    read -p "$(echo -e ${BOLD}Test duration in hours${NC}) [$default_duration]: " input_duration
    TEST_DURATION_HOURS="${input_duration:-$default_duration}"

    # Validate duration is a number
    if ! [[ "$TEST_DURATION_HOURS" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "Invalid duration. Using default: $default_duration hours"
        TEST_DURATION_HOURS="$default_duration"
    fi

    # Display confirmation
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  TEST CONFIGURATION${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Target IP:${NC}          $ORIN_IP"
    echo -e "${BOLD}Username:${NC}           $ORIN_USER"
    echo -e "${BOLD}Password:${NC}           $(echo "$ORIN_PASS" | sed 's/./*/g')"
    echo -e "${BOLD}Tester name:${NC}        $TESTER_NAME"
    echo -e "${BOLD}Quality checker:${NC}    $QUALITY_CHECKER_NAME"
    echo -e "${BOLD}Test duration:${NC}      $TEST_DURATION_HOURS hours"
    echo ""

    # Ask for confirmation
    read -p "$(echo -e ${YELLOW}Proceed with these settings?${NC}) (yes/no) [yes]: " confirm
    confirm="${confirm:-yes}"

    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo ""
        log_warning "Test cancelled by user"
        exit 0
    fi

    echo ""
    echo -e "${GREEN}✓ Configuration confirmed${NC}"
    echo ""

    # Export variables for use in calling script
    export ORIN_IP
    export ORIN_USER
    export ORIN_PASS
    export TESTER_NAME
    export QUALITY_CHECKER_NAME
    export TEST_DURATION_HOURS
}

################################################################################
# PREREQUISITE CHECKS
################################################################################

check_prerequisites() {
    local ip="$1"
    local user="$2"
    local pass="$3"

    # Check for sshpass
    if ! command -v sshpass &> /dev/null; then
        log_error "'sshpass' is not installed"
        echo ""
        echo "Install instructions:"
        echo "  Rocky Linux: sudo dnf install epel-release && sudo dnf install sshpass"
        echo "  Ubuntu/Debian: sudo apt-get install sshpass"
        exit 1
    fi

    # Test SSH connection
    log_info "Testing SSH connection to $ip..."
    if ! ssh_execute "$ip" "$user" "$pass" "echo 'Connection OK'" | grep -q "Connection OK"; then
        log_error "SSH connection failed"
        echo "  Please check:"
        echo "  • IP address is correct"
        echo "  • Jetson Orin is powered on and network is accessible"
        echo "  • SSH password is correct"
        exit 1
    fi
    log_success "SSH connection successful"
    echo ""
}

################################################################################
# SYSTEM INFORMATION FUNCTIONS
################################################################################

get_system_info() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local log_file="$4"
    
    log_info "Collecting system information..."
    
    ssh_execute_with_output "$ip" "$user" "$pass" "
        echo '=== JETSON ORIN SYSTEM INFORMATION ==='
        echo 'Date: \$(date)'
        echo 'Hostname: \$(hostname)'
        echo 'Uptime: \$(uptime)'
        echo ''
        echo '=== HARDWARE INFO ==='
        cat /proc/cpuinfo | grep -E '(processor|model name|cpu cores|Hardware)' | head -20
        echo ''
        echo '=== REAL CORE COUNT ==='
        if [ -f /sys/devices/system/cpu/cpu0/topology/core_siblings_list ]; then
            echo 'Physical cores: '\$(cat /sys/devices/system/cpu/cpu*/topology/core_siblings_list | sort -u | wc -l)
        fi
        echo 'Logical cores: '\$(nproc)
        echo ''
        echo '=== MEMORY INFO ==='
        free -h
        echo ''
        echo '=== DISK INFO ==='
        df -h
        echo ''
        echo '=== GPU INFO ==='
        nvidia-smi || echo 'nvidia-smi not available'
        echo ''
        echo '=== JETPACK VERSION ==='
        cat /etc/nv_tegra_release 2>/dev/null || echo 'JetPack info not available'
        echo ''
        echo '=== TEMPERATURE SENSORS ==='
        cat /sys/devices/virtual/thermal/thermal_zone*/temp 2>/dev/null | head -5 || echo 'Thermal info not available'
    " > "$log_file"
}

################################################################################
# TEMPERATURE MONITORING FUNCTIONS
################################################################################

start_temperature_monitoring() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local log_file="$4"
    local interval="${5:-5}"
    
    log_info "Starting temperature monitoring (interval: ${interval}s)..."
    
    # Create header for local log file
    echo 'timestamp,cpu_temp,gpu_temp,cpu_usage,gpu_usage,memory_usage' > "$log_file"
    
    ssh_execute_with_output "$ip" "$user" "$pass" "
        while true; do
            timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
            
            # CPU temperature (thermal_zone0 is usually CPU)
            cpu_temp=\$(cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null | awk '{print \$1/1000}' || echo 'N/A')
            
            # GPU temperature (thermal_zone1 is usually GPU)
            gpu_temp=\$(cat /sys/devices/virtual/thermal/thermal_zone1/temp 2>/dev/null | awk '{print \$1/1000}' || echo 'N/A')
            
            # CPU usage
            cpu_usage=\$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | awk -F'%' '{print \$1}' || echo 'N/A')
            
            # GPU usage (if available)
            gpu_usage=\$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 'N/A')
            
            # Memory usage
            memory_usage=\$(free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}' || echo 'N/A')
            
            echo \"\$timestamp,\$cpu_temp,\$gpu_temp,\$cpu_usage,\$gpu_usage,\$memory_usage\"
            
            sleep $interval
        done
    " >> "$log_file" &
    
    # Store the SSH PID for later cleanup
    TEMP_MONITOR_PID=$!
    echo $TEMP_MONITOR_PID > /tmp/temp_monitor_pid
}

stop_temperature_monitoring() {
    if [ -f /tmp/temp_monitor_pid ]; then
        local pid=$(cat /tmp/temp_monitor_pid)
        log_info "Stopping temperature monitoring..."
        kill "$pid" 2>/dev/null || true
        rm -f /tmp/temp_monitor_pid
        sleep 2
    elif [ -n "$TEMP_MONITOR_PID" ]; then
        kill "$TEMP_MONITOR_PID" 2>/dev/null || true
        sleep 2
    fi
}

################################################################################
# RESULT PROCESSING FUNCTIONS
################################################################################

# Added missing generate_temperature_analysis function
generate_temperature_analysis() {
    local temp_log="$1"
    local output_file="$2"
    
    if [ -f "$temp_log" ]; then
        log_info "Processing temperature results..."
        
        # Calculate temperature statistics
        awk -F',' '
        NR>1 && $2!="N/A" && $3!="N/A" {
            cpu_sum+=$2; cpu_count++; 
            cpu_max=($2>cpu_max || cpu_max=="")?$2:cpu_max; 
            cpu_min=($2<cpu_min || cpu_min=="")?$2:cpu_min;
            gpu_sum+=$3; gpu_count++; 
            gpu_max=($3>gpu_max || gpu_max=="")?$3:gpu_max; 
            gpu_min=($3<gpu_min || gpu_min=="")?$3:gpu_min;
        }
        END {
            if(cpu_count>0) print "CPU_MIN="int(cpu_min); else print "CPU_MIN=N/A";
            if(cpu_count>0) print "CPU_MAX="int(cpu_max); else print "CPU_MAX=N/A";
            if(cpu_count>0) print "CPU_AVG="int(cpu_sum/cpu_count); else print "CPU_AVG=N/A";
            if(gpu_count>0) print "GPU_MIN="int(gpu_min); else print "GPU_MIN=N/A";
            if(gpu_count>0) print "GPU_MAX="int(gpu_max); else print "GPU_MAX=N/A";
            if(gpu_count>0) print "GPU_AVG="int(gpu_sum/gpu_count); else print "GPU_AVG=N/A";
        }' "$temp_log" > "$output_file"
    else
        log_warning "Temperature log not found: $temp_log"
        echo "CPU_MIN=N/A
CPU_MAX=N/A
CPU_AVG=N/A
GPU_MIN=N/A
GPU_MAX=N/A
GPU_AVG=N/A" > "$output_file"
    fi
}

process_temperature_results() {
    local temp_log="$1"
    local output_file="$2"
    
    generate_temperature_analysis "$temp_log" "$output_file"
}

################################################################################
# PERFORMANCE CALCULATION FUNCTIONS
################################################################################

# Calculate realistic performance expectations based on Jetson model and cores
# NOTE: This function now accepts test_duration to scale expectations properly
calculate_performance_expectations() {
    local cores="$1"
    local model="$2"
    local test_duration="${3:-3600}"  # Default 1 hour if not provided

    # Base performance rates for different Jetson models (per 60 seconds for single-core)
    # Single-core primes: primes found in 60 seconds
    # Multi-core matrix: operations per second
    case "$model" in
        *"Orin AGX"*|*"AGX Orin"*)
            base_single_core_primes_per_60s=1290000  # 21,500/s * 60 = 1,290,000 per 60s
            # AGX Orin has high-performance cores but matrix ops are memory-bound
            case "$cores" in
                [1-4])   base_matrix_ops_per_sec=8 ;;
                [5-8])   base_matrix_ops_per_sec=10 ;;
                [9-12])  base_matrix_ops_per_sec=11 ;;  # Actual measurement: ~11 ops/sec
                *)       base_matrix_ops_per_sec=11 ;;
            esac
            ;;
        *"Orin NX"*|*"NX Orin"*)
            base_single_core_primes_per_60s=1032000  # 80% of AGX (proportional)
            case "$cores" in
                [1-4])   base_matrix_ops_per_sec=6 ;;
                [5-8])   base_matrix_ops_per_sec=9 ;;
                *)       base_matrix_ops_per_sec=9 ;;
            esac
            ;;
        *"Orin Nano"*|*"Nano Orin"*)
            base_single_core_primes_per_60s=774000  # 60% of AGX (proportional)
            case "$cores" in
                [1-4])   base_matrix_ops_per_sec=5 ;;
                [5-8])   base_matrix_ops_per_sec=7 ;;
                *)       base_matrix_ops_per_sec=7 ;;
            esac
            ;;
        *)
            # Default conservative values
            base_single_core_primes_per_60s=1032000  # Use NX values as default
            case "$cores" in
                [1-4])   base_matrix_ops_per_sec=6 ;;
                [5-8])   base_matrix_ops_per_sec=9 ;;
                [9-12])  base_matrix_ops_per_sec=11 ;;
                *)       base_matrix_ops_per_sec=11 ;;
            esac
            ;;
    esac

    # Calculate single-core duration (20% of total test time)
    local single_core_test_duration=$((test_duration / 5))

    # Scale single-core primes based on actual test duration
    # base is per 60 seconds, scale to actual duration
    local single_core_primes=$(echo "scale=0; $base_single_core_primes_per_60s * $single_core_test_duration / 60" | bc)

    # Multi-core matrix ops is already per second, no scaling needed
    local multi_core_matrix=$base_matrix_ops_per_sec

    echo "EXPECTED_SINGLE_CORE_PRIMES=$single_core_primes"
    echo "EXPECTED_MULTI_CORE_MATRIX_OPS=$multi_core_matrix"
    echo "EXPECTED_MEMORY_BANDWIDTH=7500"  # 7.5 GB/s realistic memory bandwidth in MB/s
    echo "EXPECTED_L1_CACHE_BANDWIDTH=100000"
}

# Calculate realistic GPU performance expectations based on Jetson model
calculate_gpu_performance_expectations() {
    local model="$1"
    
    # Realistic performance expectations for different Jetson models
    case "$model" in
        *"Orin AGX"*|*"AGX Orin"*)
            expected_cuda_gflops=275
            expected_memory_bandwidth=80
            expected_graphics_fps=60
            ;;
        *"Orin NX"*|*"NX Orin"*)
            expected_cuda_gflops=200
            expected_memory_bandwidth=60
            expected_graphics_fps=45
            ;;
        *"Orin Nano"*|*"Nano Orin"*)
            expected_cuda_gflops=150
            expected_memory_bandwidth=40
            expected_graphics_fps=30
            ;;
        *)
            # Conservative defaults
            expected_cuda_gflops=200
            expected_memory_bandwidth=60
            expected_graphics_fps=45
            ;;
    esac
    
    echo "EXPECTED_CUDA_GFLOPS=$expected_cuda_gflops"
    echo "EXPECTED_MEMORY_BANDWIDTH=$expected_memory_bandwidth"
    echo "EXPECTED_GRAPHICS_FPS=$expected_graphics_fps"
    echo "EXPECTED_ML_INFERENCE_FPS=30"
}

################################################################################
# CLEANUP FUNCTIONS
################################################################################

cleanup_remote_files() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local remote_dir="$4"
    
    if [ -n "$remote_dir" ]; then
        log_info "Cleaning up remote directory: $remote_dir"
        ssh_execute "$ip" "$user" "$pass" "rm -rf '$remote_dir'" || true
    fi
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################

validate_test_duration() {
    local duration="$1"
    local min_duration="${2:-60}"
    local max_duration="${3:-86400}"
    
    if [ "$duration" -lt "$min_duration" ]; then
        log_error "Test duration too short (minimum: ${min_duration}s)"
        return 1
    fi
    
    if [ "$duration" -gt "$max_duration" ]; then
        log_error "Test duration too long (maximum: ${max_duration}s)"
        return 1
    fi
    
    return 0
}

validate_ip_address() {
    local ip="$1"
    local valid_ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ ! $ip =~ $valid_ip_regex ]]; then
        log_error "Invalid IP address format: $ip"
        return 1
    fi
    
    return 0
}

################################################################################
# MATH UTILITIES
################################################################################

calculate_percentage() {
    local part="$1"
    local total="$2"
    
    if [ "$total" -eq 0 ]; then
        echo "0"
    else
        echo $((part * 100 / total))
    fi
}

format_duration() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

################################################################################
# FILE UTILITIES
################################################################################

ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}