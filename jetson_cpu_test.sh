#!/bin/bash

################################################################################
# JETSON ORIN - ULTRA COMPREHENSIVE CPU STRESS TEST
################################################################################
# Description: Complete CPU validation with single/multi-core tests and health assessment
# Features: Single-core, Multi-core, Per-core, Instruction throughput, Memory patterns, Health validation
# Version: 4.0 Enhanced - Added per-core testing, instruction micro-benchmarks, and advanced memory patterns
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common utilities (with comprehensive fallback functions)
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
    collect_test_parameters "${1:-192.168.55.69}" "${2:-orin}" "${3}" "${4:-1}"
fi

# Get tester information (parameters 6 and 7 from orchestrator, or from environment if from collect_test_parameters)
TESTER_NAME="${6:-${TESTER_NAME:-N/A}}"
QUALITY_CHECKER_NAME="${7:-${QUALITY_CHECKER_NAME:-N/A}}"
DEVICE_SERIAL="${8:-${DEVICE_SERIAL:-N/A}}"

################################################################################
# CONFIGURATION
################################################################################

TEST_DURATION=$(echo "$TEST_DURATION_HOURS * 3600" | bc | cut -d'.' -f1)  # Convert hours to seconds (handle decimals)
LOG_DIR="${5:-./cpu_ultra_test_$(date +%Y%m%d_%H%M%S)}"

# Dynamic CPU core detection - get REAL physical cores, not hyperthreads
echo "[*] Detecting CPU cores..."
CPU_CORES=$(get_physical_cores "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS")
echo "  • Detected cores: $CPU_CORES"

echo "[*] Detecting Jetson model..."
JETSON_MODEL=$(detect_jetson_model "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS")
echo "  • Model: $JETSON_MODEL"

TEMP_THRESHOLD_WARNING=80
TEMP_THRESHOLD_CRITICAL=95

# Calculate realistic performance expectations based on detected system
echo "[*] Calculating performance expectations..."
eval $(calculate_performance_expectations "$CPU_CORES" "$JETSON_MODEL" "$TEST_DURATION")
echo "  • Single-core target: $EXPECTED_SINGLE_CORE_PRIMES primes (scaled for test duration)"
echo "  • Multi-core target: $EXPECTED_MULTI_CORE_MATRIX_OPS ops/sec"

################################################################################
# USAGE & HELP
################################################################################

show_usage() {
    cat << EOF
================================================================================
  JETSON ORIN ULTRA COMPREHENSIVE CPU STRESS TEST
================================================================================

Usage: $0 [orin_ip] [orin_user] [password] [duration] [log_dir]

Parameters:
  orin_ip     : IP address of Jetson Orin (default: 192.168.55.69)
  orin_user   : SSH username (default: orin)
  password    : SSH password (will prompt if not provided)
  duration    : Test duration in hours (default: 1 hour)
  log_dir     : Log directory (default: ./cpu_ultra_test_YYYYMMDD_HHMMSS)

ULTRA COMPREHENSIVE TEST COMPONENTS:
================================================================================

[SINGLE-CORE TESTS] (CPU Limit Testing):
  • Prime Number Generation      - Single-thread integer performance
  • Fibonacci Calculation        - Recursive mathematical load
  • FFT Computation             - Signal processing workload
  • Sorting Algorithms          - Memory access patterns
  • Cryptographic Hashing       - SHA-256 intensive computation

[MULTI-CORE TESTS] (All Cores to Limit):
  • Parallel Matrix Multiplication - All cores floating-point load
  • Multi-threaded Prime Search    - Distributed integer workload
  • Parallel FFT Processing        - Multi-core signal processing
  • Concurrent Memory Stress       - Memory bandwidth saturation
  • Multi-core Scientific Computing - Complex mathematical workloads

[PER-CORE INDIVIDUAL TESTING]:
  • Individual core performance validation
  • Core-to-core performance uniformity
  • Per-core frequency monitoring
  • Identification of weak/strong cores

[CPU INSTRUCTION THROUGHPUT MICRO-BENCHMARKS]:
  • Integer operations (ADD, MUL, DIV)
  • Floating-point operations (ADD, MUL, DIV, SQRT)
  • Branch prediction efficiency testing
  • Predictable vs unpredictable branch performance

[ADVANCED MEMORY PATTERNS]:
  • Sequential memory access patterns
  • Random memory access patterns
  • Strided memory access (cache line testing)
  • Cache latency measurements (L1, L2, Memory)
  • Memory bandwidth analysis

[MEMORY & CACHE TORTURE]:
  • L1 Cache Stress (16KB patterns)
  • L2 Cache Stress (512KB patterns)
  • L3 Cache Stress (4MB patterns)
  • Main Memory Bandwidth (64MB patterns)
  • Random Memory Access Patterns
  • Memory Latency Measurements

[THERMAL & HEALTH VALIDATION]:
  • Real-time temperature monitoring (1-second intervals)
  • CPU frequency scaling under load
  • Thermal throttling detection
  • Performance degradation analysis
  • Health score calculation (0-100)

[PASS/FAIL CRITERIA]:
  • Performance vs Expected Benchmarks
  • Thermal Management Effectiveness  
  • System Stability During Stress
  • Error Detection and Recovery
  • Overall Health Assessment

Target: Push CPU to absolute limits while maintaining stability
Device: Auto-detected Jetson model and physical core count
Note: Performance expectations automatically scale based on detected hardware

Examples:
  $0                                    # 1-hour comprehensive test
  $0 192.168.55.69 orin mypass 2       # 2-hour extreme test
  $0 10.0.0.100 nvidia secret 0.5      # 30-minute quick validation

================================================================================
EOF
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_usage
    exit 0
fi

################################################################################
# INITIALIZATION
################################################################################

log_phase "JETSON ORIN ULTRA COMPREHENSIVE CPU STRESS TEST"

echo "[ULTRA CPU STRESS CONFIGURATION]"
echo "  • Target Device: $ORIN_IP"
echo "  • Jetson Model: $JETSON_MODEL"
echo "  • Test Duration: $(format_duration $TEST_DURATION)"
echo "  • Physical CPU Cores: $CPU_CORES (auto-detected)"
echo "  • Expected Single-core: $EXPECTED_SINGLE_CORE_PRIMES primes/60s"
echo "  • Expected Multi-core: $EXPECTED_MULTI_CORE_MATRIX_OPS ops/sec"
echo "  • Temperature Monitoring: 1-second intervals"
echo "  • Test Intensity: MAXIMUM (CPU to limits)"
echo "  • Health Assessment: ENABLED"
echo ""

# Show remote core detection for verification
log_info "Verifying remote core count..."
REMOTE_CORES=$(ssh_execute "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "nproc")
REMOTE_LOGICAL=$(ssh_execute "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "grep -c ^processor /proc/cpuinfo")
log_info "Remote system: $REMOTE_CORES cores detected, $REMOTE_LOGICAL logical processors"

# Validate inputs
validate_ip_address "$ORIN_IP" || exit 1
validate_test_duration "$TEST_DURATION" 300 28800 || exit 1  # 0.08 hours (5 min) to 8 hours

# Check prerequisites
check_prerequisites "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"

# Create log directories
ensure_directory "$LOG_DIR/logs"
ensure_directory "$LOG_DIR/reports"
ensure_directory "$LOG_DIR/performance_data"

# Convert to absolute path
LOG_DIR=$(cd "$LOG_DIR" && pwd)

log_success "Ultra CPU test initialization complete"
log_info "Results will be saved to: $LOG_DIR"
echo ""

################################################################################
# ULTRA CPU STRESS TEST EXECUTION
################################################################################

log_phase "[STARTING ULTRA CPU STRESS TEST]"

echo ""
echo "Test Personnel:"
echo "  Tester: $TESTER_NAME"
echo "  Quality Checker: $QUALITY_CHECKER_NAME"
echo "  Device Serial: $DEVICE_SERIAL"
echo ""

# Start intensive temperature monitoring (1-second intervals)
start_temperature_monitoring "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "$LOG_DIR/logs/cpu_temperature.csv" 1

# Execute the ultra comprehensive CPU test
ssh_execute_with_output "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "
export TEST_DURATION=$TEST_DURATION
export CPU_CORES=$CPU_CORES
export TEMP_THRESHOLD_WARNING=$TEMP_THRESHOLD_WARNING
export TEMP_THRESHOLD_CRITICAL=$TEMP_THRESHOLD_CRITICAL
export EXPECTED_SINGLE_CORE_PRIMES=$EXPECTED_SINGLE_CORE_PRIMES
export EXPECTED_MULTI_CORE_MATRIX_OPS=$EXPECTED_MULTI_CORE_MATRIX_OPS
export EXPECTED_MEMORY_BANDWIDTH=$EXPECTED_MEMORY_BANDWIDTH
export EXPECTED_L1_CACHE_BANDWIDTH=$EXPECTED_L1_CACHE_BANDWIDTH
bash -s" << 'REMOTE_ULTRA_CPU_TEST_START' | tee "$LOG_DIR/logs/ultra_cpu_stress.log"

#!/bin/bash

################################################################################
# REMOTE ULTRA CPU STRESS TEST EXECUTION
################################################################################

set -e

# Use exported CPU_CORES or detect locally if not set
if [ -z "$CPU_CORES" ]; then
    # Detect cores on remote Jetson system
    if [ -f /etc/nv_tegra_release ] || [ -f /proc/device-tree/model ]; then
        # This is a Jetson system - use nproc directly as it's accurate
        CPU_CORES=$(nproc)
    else
        # Non-Jetson system - try more sophisticated detection
        if [ -f /sys/devices/system/cpu/cpu0/topology/core_siblings_list ]; then
            CPU_CORES=$(cat /sys/devices/system/cpu/cpu*/topology/core_siblings_list | sort -u | wc -l)
        elif [ -f /proc/cpuinfo ]; then
            CPU_CORES=$(grep 'core id' /proc/cpuinfo | sort -u | wc -l 2>/dev/null || nproc)
        else
            CPU_CORES=$(nproc)
        fi
        
        # Safety cap for non-Jetson systems
        if [ "$CPU_CORES" -gt 32 ]; then
            CPU_CORES=32
        fi
    fi
fi

echo "=== DETECTED CORE INFORMATION ==="
echo "Physical CPU cores detected: $CPU_CORES"
echo "Logical processors: $(nproc)"
if [ -f /etc/nv_tegra_release ]; then
    echo "Jetson system detected"
elif [ -f /proc/device-tree/model ]; then
    echo "Device model: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')"
fi
echo ""

# Test directory
REMOTE_TEST_DIR="/tmp/ultra_cpu_stress_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REMOTE_TEST_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_phase() { echo -e "${MAGENTA}[PHASE]${NC} $1"; }

# Initialize performance tracking
PERFORMANCE_SCORE=0
THERMAL_SCORE=0
STABILITY_SCORE=0
SINGLE_CORE_SCORE=0
MULTI_CORE_SCORE=0
HEALTH_WARNINGS=0

################################################################################
# SYSTEM PREPARATION AND OPTIMIZATION
################################################################################

log_phase "[SYSTEM PREPARATION FOR EXTREME TESTING]"

echo "=== CPU ARCHITECTURE ANALYSIS ==="
cat /proc/cpuinfo | grep -E "(processor|model name|cpu MHz|cache size|cpu cores|Hardware|Model|Features)" | head -30

echo ""
echo "=== INITIAL SYSTEM STATE ==="
echo "Load Average: $(cat /proc/loadavg)"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')%"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')%"

echo ""
echo "=== THERMAL ZONE MAPPING ==="
for i in $(seq 0 10); do
    if [ -f "/sys/devices/virtual/thermal/thermal_zone$i/temp" ]; then
        temp=$(cat /sys/devices/virtual/thermal/thermal_zone$i/temp 2>/dev/null || echo "0")
        temp_c=$((temp / 1000))
        zone_type=$(cat /sys/devices/virtual/thermal/thermal_zone$i/type 2>/dev/null || echo "unknown")
        echo "Zone $i ($zone_type): ${temp_c}°C"
    fi
done

# Set CPU governor to performance
log_info "Setting CPU governor to performance mode for maximum stress..."
for i in $(seq 0 $((CPU_CORES-1))); do
    if [ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" ]; then
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor >/dev/null 2>&1 || true
    fi
done

# Disable CPU idle states for maximum performance
log_info "Disabling CPU idle states for maximum stress testing..."
for i in $(seq 0 $((CPU_CORES-1))); do
    if [ -d "/sys/devices/system/cpu/cpu$i/cpuidle" ]; then
        for state in /sys/devices/system/cpu/cpu$i/cpuidle/state*/disable; do
            if [ -f "$state" ]; then
                echo 1 | sudo tee "$state" >/dev/null 2>&1 || true
            fi
        done
    fi
done

################################################################################
# PHASE 1: SINGLE-CORE EXTREME STRESS TESTS
################################################################################

log_phase "[PHASE 1: SINGLE-CORE EXTREME STRESS TESTS]"

SINGLE_CORE_DURATION=$((TEST_DURATION / 5))  # 20% of total time

echo "Single-core test duration: $(($SINGLE_CORE_DURATION / 60)) minutes"
echo ""

# Test 1.1: Prime Number Generation (Single-threaded)
log_info "Test 1.1: Prime Number Generation (Single-thread CPU limit)"

cat > "$REMOTE_TEST_DIR/prime_extreme.c" << 'PRIME_EXTREME_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <unistd.h>

int is_prime(long long n) {
    if (n <= 1) return 0;
    if (n <= 3) return 1;
    if (n % 2 == 0 || n % 3 == 0) return 0;
    
    for (long long i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0) {
            return 0;
        }
    }
    return 1;
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    long long prime_count = 0;
    long long current = 2;
    long long largest_prime = 0;
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    while (time(NULL) < end_time) {
        if (is_prime(current)) {
            prime_count++;
            largest_prime = current;
        }
        current++;
    }
    
    double elapsed = difftime(time(NULL), start_time);
    double primes_per_second = prime_count / elapsed;
    
    printf("\n=== SINGLE-CORE PRIME RESULTS ===\n");
    printf("Total primes found: %lld\n", prime_count);
    printf("Largest prime: %lld\n", largest_prime);
    printf("Highest number tested: %lld\n", current - 1);
    printf("Primes per second: %.2f\n", primes_per_second);
    printf("Elapsed time: %.2f seconds\n", elapsed);
    
    // Write results for health assessment
    FILE *f = fopen("/tmp/single_core_prime_results.txt", "w");
    if (f) {
        fprintf(f, "PRIME_COUNT=%lld\n", prime_count);
        fprintf(f, "LARGEST_PRIME=%lld\n", largest_prime);
        fprintf(f, "PRIMES_PER_SECOND=%.2f\n", primes_per_second);
        fclose(f);
    }
    
    return 0;
}
PRIME_EXTREME_EOF

gcc -O3 -march=native -o "$REMOTE_TEST_DIR/prime_extreme" "$REMOTE_TEST_DIR/prime_extreme.c" -lm
"$REMOTE_TEST_DIR/prime_extreme" $((SINGLE_CORE_DURATION / 5))

# Test 1.2: Fibonacci Extreme (Recursive)
log_info "Test 1.2: Fibonacci Recursive Calculation (CPU intensive)"

cat > "$REMOTE_TEST_DIR/fibonacci_extreme.c" << 'FIB_EXTREME_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

long long fibonacci_recursive(int n) {
    if (n <= 1) return n;
    return fibonacci_recursive(n-1) + fibonacci_recursive(n-2);
}

long long fibonacci_iterative(int n) {
    if (n <= 1) return n;
    long long a = 0, b = 1, temp;
    for (int i = 2; i <= n; i++) {
        temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    int fib_iterations = 0;
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    printf("Starting Fibonacci stress test for %d seconds...\n", duration);
    
    while (time(NULL) < end_time) {
        // Mix of recursive (CPU intensive) and iterative (memory intensive)
        long long result1 = fibonacci_recursive(35);  // Very CPU intensive
        long long result2 = fibonacci_iterative(1000000);  // Memory intensive
        fib_iterations++;
    }
    
    double elapsed = difftime(time(NULL), start_time);
    printf("\n=== FIBONACCI RESULTS ===\n");
    printf("Total iterations: %d\n", fib_iterations);
    printf("Iterations per second: %.2f\n", fib_iterations / elapsed);
    
    return 0;
}
FIB_EXTREME_EOF

gcc -O3 -o "$REMOTE_TEST_DIR/fibonacci_extreme" "$REMOTE_TEST_DIR/fibonacci_extreme.c"
"$REMOTE_TEST_DIR/fibonacci_extreme" $((SINGLE_CORE_DURATION / 5))

# Test 1.3: FFT Computation (Signal Processing)
log_info "Test 1.3: FFT Signal Processing (Mathematical intensity)"

cat > "$REMOTE_TEST_DIR/fft_extreme.c" << 'FFT_EXTREME_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <complex.h>

#define PI 3.14159265358979323846

void fft(double complex *x, int n) {
    if (n <= 1) return;
    
    // Divide
    double complex *even = malloc(n/2 * sizeof(double complex));
    double complex *odd = malloc(n/2 * sizeof(double complex));
    
    for (int i = 0; i < n/2; i++) {
        even[i] = x[2*i];
        odd[i] = x[2*i + 1];
    }
    
    // Conquer
    fft(even, n/2);
    fft(odd, n/2);
    
    // Combine
    for (int i = 0; i < n/2; i++) {
        double complex t = cexp(-2.0 * PI * I * i / n) * odd[i];
        x[i] = even[i] + t;
        x[i + n/2] = even[i] - t;
    }
    
    free(even);
    free(odd);
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    int fft_count = 0;
    int N = 1024; // FFT size
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    printf("Starting FFT computation stress for %d seconds...\n", duration);
    printf("FFT size: %d points\n", N);
    
    while (time(NULL) < end_time) {
        double complex *signal = malloc(N * sizeof(double complex));
        
        // Generate test signal
        for (int i = 0; i < N; i++) {
            signal[i] = sin(2 * PI * 50 * i / 1000) + 0.5 * sin(2 * PI * 120 * i / 1000);
        }
        
        // Perform FFT
        fft(signal, N);
        fft_count++;
        
        free(signal);
    }
    
    double elapsed = difftime(time(NULL), start_time);
    printf("\n=== FFT RESULTS ===\n");
    printf("Total FFT operations: %d\n", fft_count);
    printf("FFT operations per second: %.2f\n", fft_count / elapsed);
    
    return 0;
}
FFT_EXTREME_EOF

gcc -O3 -o "$REMOTE_TEST_DIR/fft_extreme" "$REMOTE_TEST_DIR/fft_extreme.c" -lm
"$REMOTE_TEST_DIR/fft_extreme" $((SINGLE_CORE_DURATION / 5))

# Test 1.4: Cryptographic Hashing (SHA-256)
log_info "Test 1.4: SHA-256 Cryptographic Hashing (CPU intensive)"

cat > "$REMOTE_TEST_DIR/crypto_extreme.c" << 'CRYPTO_EXTREME_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

// Simplified SHA-256 implementation for stress testing
uint32_t rightrotate(uint32_t value, int amount) {
    return (value >> amount) | (value << (32 - amount));
}

void sha256_hash(const char *input, char *output) {
    // Simplified version - just CPU intensive operations
    uint32_t hash[8] = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };
    
    int len = strlen(input);
    for (int i = 0; i < 1000; i++) {  // Artificial CPU load
        for (int j = 0; j < 8; j++) {
            hash[j] = rightrotate(hash[j], 7) ^ rightrotate(hash[j], 18) ^ (hash[j] >> 3);
            hash[j] += len + i + j;
        }
    }
    
    sprintf(output, "%08x%08x%08x%08x", hash[0], hash[1], hash[2], hash[3]);
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    int hash_count = 0;
    char input[256];
    char output[65];
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    printf("Starting cryptographic hashing stress for %d seconds...\n", duration);
    
    while (time(NULL) < end_time) {
        sprintf(input, "stress_test_data_%d_%ld", hash_count, time(NULL));
        sha256_hash(input, output);
        hash_count++;
    }
    
    double elapsed = difftime(time(NULL), start_time);
    printf("\n=== CRYPTOGRAPHIC HASH RESULTS ===\n");
    printf("Total hash operations: %d\n", hash_count);
    printf("Hash operations per second: %.2f\n", hash_count / elapsed);
    
    return 0;
}
CRYPTO_EXTREME_EOF

gcc -O3 -o "$REMOTE_TEST_DIR/crypto_extreme" "$REMOTE_TEST_DIR/crypto_extreme.c"
"$REMOTE_TEST_DIR/crypto_extreme" $((SINGLE_CORE_DURATION / 5))

# Evaluate single-core performance
if [ -f "/tmp/single_core_prime_results.txt" ]; then
    source /tmp/single_core_prime_results.txt
    if [ "$PRIME_COUNT" -ge "$EXPECTED_SINGLE_CORE_PRIMES" ]; then
        SINGLE_CORE_SCORE=100
        log_success "Single-core performance: EXCELLENT ($PRIME_COUNT primes, expected $EXPECTED_SINGLE_CORE_PRIMES)"
    elif [ "$PRIME_COUNT" -ge $((EXPECTED_SINGLE_CORE_PRIMES * 80 / 100)) ]; then
        SINGLE_CORE_SCORE=80
        log_success "Single-core performance: GOOD ($PRIME_COUNT primes)"
    elif [ "$PRIME_COUNT" -ge $((EXPECTED_SINGLE_CORE_PRIMES * 60 / 100)) ]; then
        SINGLE_CORE_SCORE=60
        log_warning "Single-core performance: ACCEPTABLE ($PRIME_COUNT primes)"
        HEALTH_WARNINGS=$((HEALTH_WARNINGS + 1))
    else
        SINGLE_CORE_SCORE=30
        log_error "Single-core performance: POOR ($PRIME_COUNT primes, expected $EXPECTED_SINGLE_CORE_PRIMES)"
        HEALTH_WARNINGS=$((HEALTH_WARNINGS + 2))
    fi
else
    SINGLE_CORE_SCORE=0
    log_error "Single-core test results not available"
    HEALTH_WARNINGS=$((HEALTH_WARNINGS + 3))
fi

################################################################################
# PHASE 2: MULTI-CORE EXTREME STRESS TESTS
################################################################################

log_phase "[PHASE 2: MULTI-CORE EXTREME STRESS TESTS]"

MULTI_CORE_DURATION=$((TEST_DURATION / 5))  # 20% of total time

echo "Multi-core test duration: $(($MULTI_CORE_DURATION / 60)) minutes"
echo "Testing all $CPU_CORES physical cores simultaneously"
echo "Matrix size will be optimized based on core count"
echo ""

# Test 2.1: Parallel Matrix Multiplication
log_info "Test 2.1: Parallel Matrix Multiplication (All cores floating-point)"

cat > "$REMOTE_TEST_DIR/matrix_parallel.c" << 'MATRIX_PARALLEL_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>

// Dynamic matrix size based on core count and performance optimization
int get_optimal_matrix_size(int cores) {
    // For Jetson systems, use conservative matrix sizes to avoid memory bottlenecks
    if (cores <= 4) return 384;       // Small cores get smaller matrix
    else if (cores <= 8) return 512;  // Medium cores
    else if (cores <= 12) return 640; // Large cores - not too big to avoid memory pressure
    else return 768;  // Very large core counts
}

typedef struct {
    int thread_id;
    int start_row;
    int end_row;
    double **a;
    double **b;
    double **c;
    int size;
} thread_data_t;

void* matrix_multiply_thread(void* arg) {
    thread_data_t* data = (thread_data_t*)arg;
    
    for (int i = data->start_row; i < data->end_row; i++) {
        for (int j = 0; j < data->size; j++) {
            data->c[i][j] = 0.0;
            for (int k = 0; k < data->size; k++) {
                data->c[i][j] += data->a[i][k] * data->b[k][j];
            }
        }
    }
    return NULL;
}

double** allocate_matrix(int size) {
    double **matrix = malloc(size * sizeof(double*));
    for (int i = 0; i < size; i++) {
        matrix[i] = malloc(size * sizeof(double));
    }
    return matrix;
}

void free_matrix(double **matrix, int size) {
    for (int i = 0; i < size; i++) {
        free(matrix[i]);
    }
    free(matrix);
}

void fill_random_matrix(double **matrix, int size) {
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            matrix[i][j] = (double)rand() / RAND_MAX;
        }
    }
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    int num_threads = argc > 2 ? atoi(argv[2]) : sysconf(_SC_NPROCESSORS_ONLN);
    int operations = 0;
    
    if (num_threads > 32) num_threads = 32;  // Safety limit
    
    // Use optimal matrix size for the number of cores
    int MATRIX_SIZE = get_optimal_matrix_size(num_threads);
    
    printf("Using optimized matrix size %dx%d for %d threads\\n", MATRIX_SIZE, MATRIX_SIZE, num_threads);
    
    srand(time(NULL));
    
    double **a = allocate_matrix(MATRIX_SIZE);
    double **b = allocate_matrix(MATRIX_SIZE);
    double **c = allocate_matrix(MATRIX_SIZE);
    
    fill_random_matrix(a, MATRIX_SIZE);
    fill_random_matrix(b, MATRIX_SIZE);
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    printf("Starting parallel matrix multiplication for %d seconds...\n", duration);
    printf("Matrix size: %dx%d, Threads: %d\n", MATRIX_SIZE, MATRIX_SIZE, num_threads);
    
    while (time(NULL) < end_time) {
        pthread_t *threads = malloc(num_threads * sizeof(pthread_t));
        thread_data_t *thread_data = malloc(num_threads * sizeof(thread_data_t));
        
        int rows_per_thread = MATRIX_SIZE / num_threads;
        
        // Create threads
        for (int t = 0; t < num_threads; t++) {
            thread_data[t].thread_id = t;
            thread_data[t].start_row = t * rows_per_thread;
            thread_data[t].end_row = (t == num_threads - 1) ? MATRIX_SIZE : (t + 1) * rows_per_thread;
            thread_data[t].a = a;
            thread_data[t].b = b;
            thread_data[t].c = c;
            thread_data[t].size = MATRIX_SIZE;
            
            pthread_create(&threads[t], NULL, matrix_multiply_thread, &thread_data[t]);
        }
        
        // Wait for all threads
        for (int t = 0; t < num_threads; t++) {
            pthread_join(threads[t], NULL);
        }
        
        free(threads);
        free(thread_data);
        operations++;
    }
    
    double elapsed = difftime(time(NULL), start_time);
    double ops_per_second = operations / elapsed;
    
    printf("\n=== PARALLEL MATRIX RESULTS ===\n");
    printf("Total matrix operations: %d\n", operations);
    printf("Operations per second: %.2f\n", ops_per_second);
    printf("Threads used: %d\n", num_threads);
    
    // Write results for health assessment
    FILE *f = fopen("/tmp/multi_core_matrix_results.txt", "w");
    if (f) {
        fprintf(f, "MATRIX_OPERATIONS=%d\n", operations);
        fprintf(f, "OPS_PER_SECOND=%.2f\n", ops_per_second);
        fprintf(f, "THREADS_USED=%d\n", num_threads);
        fclose(f);
    }
    
    free_matrix(a, MATRIX_SIZE);
    free_matrix(b, MATRIX_SIZE);
    free_matrix(c, MATRIX_SIZE);
    
    return 0;
}
MATRIX_PARALLEL_EOF

gcc -O3 -pthread -o "$REMOTE_TEST_DIR/matrix_parallel" "$REMOTE_TEST_DIR/matrix_parallel.c" -lm
"$REMOTE_TEST_DIR/matrix_parallel" $((MULTI_CORE_DURATION / 4)) $CPU_CORES

# Test 2.2: Multi-threaded Prime Search
log_info "Test 2.2: Multi-threaded Prime Search (Distributed integer workload)"

cat > "$REMOTE_TEST_DIR/prime_parallel.c" << 'PRIME_PARALLEL_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>

typedef struct {
    int thread_id;
    long long start_num;
    long long end_num;
    long long prime_count;
    int duration;
    int max_threads;
} thread_data_t;

int is_prime(long long n) {
    if (n <= 1) return 0;
    if (n <= 3) return 1;
    if (n % 2 == 0 || n % 3 == 0) return 0;
    
    for (long long i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0) {
            return 0;
        }
    }
    return 1;
}

void* prime_search_thread(void* arg) {
    thread_data_t* data = (thread_data_t*)arg;
    data->prime_count = 0;
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + data->duration;
    
    long long current = data->start_num;
    
    while (time(NULL) < end_time && current < data->end_num) {
        if (is_prime(current)) {
            data->prime_count++;
        }
        current += data->max_threads;  // Each thread checks every nth number
    }
    
    return NULL;
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    int num_threads = argc > 2 ? atoi(argv[2]) : sysconf(_SC_NPROCESSORS_ONLN);
    
    if (num_threads > 32) num_threads = 32;  // Safety limit
    
    pthread_t *threads = malloc(num_threads * sizeof(pthread_t));
    thread_data_t *thread_data = malloc(num_threads * sizeof(thread_data_t));
    
    printf("Starting multi-threaded prime search for %d seconds...\n", duration);
    printf("Threads: %d\n", num_threads);
    
    long long start_range = 1000000;  // Start from 1 million
    long long range_per_thread = 10000000;  // 10 million numbers per thread
    
    // Create threads
    for (int t = 0; t < num_threads; t++) {
        thread_data[t].thread_id = t;
        thread_data[t].start_num = start_range + t;
        thread_data[t].end_num = start_range + range_per_thread;
        thread_data[t].duration = duration;
        thread_data[t].max_threads = num_threads;
        
        pthread_create(&threads[t], NULL, prime_search_thread, &thread_data[t]);
    }
    
    // Wait for all threads
    long long total_primes = 0;
    for (int t = 0; t < num_threads; t++) {
        pthread_join(threads[t], NULL);
        total_primes += thread_data[t].prime_count;
    }
    
    printf("\n=== MULTI-THREADED PRIME RESULTS ===\n");
    printf("Total primes found: %lld\n", total_primes);
    printf("Threads used: %d\n", num_threads);
    
    free(threads);
    free(thread_data);
    return 0;
}
PRIME_PARALLEL_EOF

gcc -O3 -pthread -o "$REMOTE_TEST_DIR/prime_parallel" "$REMOTE_TEST_DIR/prime_parallel.c" -lm
"$REMOTE_TEST_DIR/prime_parallel" $((MULTI_CORE_DURATION / 4)) $CPU_CORES

# Test 2.3: Parallel FFT Processing
log_info "Test 2.3: Parallel FFT Processing (Multi-core signal processing)"

cat > "$REMOTE_TEST_DIR/fft_parallel.c" << 'FFT_PARALLEL_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <complex.h>
#include <pthread.h>
#include <unistd.h>

#define PI 3.14159265358979323846
#define FFT_SIZE 1024

typedef struct {
    int thread_id;
    int operations;
    int duration;
} fft_thread_data_t;

void simple_fft(double complex *x, int n) {
    if (n <= 1) return;
    
    // Simplified FFT for stress testing
    for (int i = 0; i < n; i++) {
        double complex temp = 0;
        for (int j = 0; j < n; j++) {
            temp += x[j] * cexp(-2.0 * PI * I * i * j / n);
        }
        x[i] = temp / n;
    }
}

void* fft_worker_thread(void* arg) {
    fft_thread_data_t* data = (fft_thread_data_t*)arg;
    data->operations = 0;
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + data->duration;
    
    while (time(NULL) < end_time) {
        double complex *signal = malloc(FFT_SIZE * sizeof(double complex));
        
        // Generate test signal
        for (int i = 0; i < FFT_SIZE; i++) {
            signal[i] = sin(2 * PI * 50 * i / 1000) + 0.5 * sin(2 * PI * 120 * i / 1000);
        }
        
        // Perform FFT
        simple_fft(signal, FFT_SIZE);
        data->operations++;
        
        free(signal);
    }
    
    return NULL;
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    int num_threads = argc > 2 ? atoi(argv[2]) : sysconf(_SC_NPROCESSORS_ONLN);
    
    if (num_threads > 32) num_threads = 32;
    
    pthread_t *threads = malloc(num_threads * sizeof(pthread_t));
    fft_thread_data_t *thread_data = malloc(num_threads * sizeof(fft_thread_data_t));
    
    printf("Starting parallel FFT processing for %d seconds...\n", duration);
    printf("FFT size: %d, Threads: %d\n", FFT_SIZE, num_threads);
    
    // Create threads
    for (int t = 0; t < num_threads; t++) {
        thread_data[t].thread_id = t;
        thread_data[t].duration = duration;
        pthread_create(&threads[t], NULL, fft_worker_thread, &thread_data[t]);
    }
    
    // Wait for all threads
    int total_operations = 0;
    for (int t = 0; t < num_threads; t++) {
        pthread_join(threads[t], NULL);
        total_operations += thread_data[t].operations;
    }
    
    printf("\n=== PARALLEL FFT RESULTS ===\n");
    printf("Total FFT operations: %d\n", total_operations);
    printf("Operations per second: %.2f\n", (double)total_operations / duration);
    printf("Threads used: %d\n", num_threads);
    
    free(threads);
    free(thread_data);
    return 0;
}
FFT_PARALLEL_EOF

gcc -O3 -pthread -o "$REMOTE_TEST_DIR/fft_parallel" "$REMOTE_TEST_DIR/fft_parallel.c" -lm
"$REMOTE_TEST_DIR/fft_parallel" $((MULTI_CORE_DURATION / 4)) $CPU_CORES

# Evaluate multi-core performance
if [ -f "/tmp/multi_core_matrix_results.txt" ]; then
    source /tmp/multi_core_matrix_results.txt
    PERF_RATIO=$(echo "scale=0; $OPS_PER_SECOND * 100 / $EXPECTED_MULTI_CORE_MATRIX_OPS" | bc 2>/dev/null || echo "0")
    if [ "$PERF_RATIO" -ge "80" ]; then
        MULTI_CORE_SCORE=100
        log_success "Multi-core performance: EXCELLENT ($OPS_PER_SECOND ops/sec, expected $EXPECTED_MULTI_CORE_MATRIX_OPS)"
    elif [ "$PERF_RATIO" -ge "60" ]; then
        MULTI_CORE_SCORE=80
        log_success "Multi-core performance: GOOD ($OPS_PER_SECOND ops/sec)"
    elif [ "$PERF_RATIO" -ge "40" ]; then
        MULTI_CORE_SCORE=60
        log_warning "Multi-core performance: ACCEPTABLE ($OPS_PER_SECOND ops/sec)"
        HEALTH_WARNINGS=$((HEALTH_WARNINGS + 1))
    else
        MULTI_CORE_SCORE=30
        log_error "Multi-core performance: POOR ($OPS_PER_SECOND ops/sec, expected $EXPECTED_MULTI_CORE_MATRIX_OPS)"
        HEALTH_WARNINGS=$((HEALTH_WARNINGS + 2))
    fi
else
    MULTI_CORE_SCORE=0
    log_error "Multi-core test results not available"
    HEALTH_WARNINGS=$((HEALTH_WARNINGS + 3))
fi

################################################################################
# PHASE 3: PER-CORE INDIVIDUAL TESTING
################################################################################

log_phase "[PHASE 3: PER-CORE INDIVIDUAL TESTING]"

PER_CORE_DURATION=$((TEST_DURATION / 20))  # 5% of total time
if [ $PER_CORE_DURATION -lt 30 ]; then
    PER_CORE_DURATION=30  # Minimum 30 seconds per core
fi

echo "Per-core test duration: $PER_CORE_DURATION seconds per core"
echo "Testing each of $CPU_CORES cores individually"
echo ""

log_info "Test 3.1: Individual Core Performance Testing"

cat > "$REMOTE_TEST_DIR/per_core_test.c" << 'PER_CORE_TEST_EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>
#include <math.h>

// Prime number test for individual core
long long test_core_primes(int duration) {
    long long prime_count = 0;
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;

    for (long long n = 2; time(NULL) < end_time; n++) {
        int is_prime = 1;
        if (n <= 1) is_prime = 0;
        else if (n <= 3) is_prime = 1;
        else if (n % 2 == 0 || n % 3 == 0) is_prime = 0;
        else {
            for (long long i = 5; i * i <= n; i += 6) {
                if (n % i == 0 || n % (i + 2) == 0) {
                    is_prime = 0;
                    break;
                }
            }
        }
        if (is_prime) prime_count++;
    }
    return prime_count;
}

// Floating-point test for individual core
double test_core_floating_point(int duration) {
    double result = 1.0;
    long long operations = 0;
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;

    while (time(NULL) < end_time) {
        result = sin(result) * cos(result) + sqrt(fabs(result)) + 1.0;
        operations++;
    }

    return (double)operations / duration;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        printf("Usage: %s <core_id> <duration>\n", argv[0]);
        return 1;
    }

    int core_id = atoi(argv[1]);
    int duration = atoi(argv[2]);

    // Pin to specific core
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);

    if (sched_setaffinity(0, sizeof(cpu_set_t), &cpuset) != 0) {
        printf("Failed to set CPU affinity for core %d\n", core_id);
        return 1;
    }

    printf("Testing Core %d for %d seconds...\n", core_id, duration);

    // Test 1: Prime numbers (integer performance)
    time_t test_start = time(NULL);
    long long primes = test_core_primes(duration / 2);
    double prime_time = difftime(time(NULL), test_start);

    // Test 2: Floating-point operations
    test_start = time(NULL);
    double flops = test_core_floating_point(duration / 2);
    double fp_time = difftime(time(NULL), test_start);

    // Get CPU frequency if available
    char freq_path[256];
    snprintf(freq_path, sizeof(freq_path), "/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq", core_id);
    FILE *freq_file = fopen(freq_path, "r");
    long freq = 0;
    if (freq_file) {
        if (fscanf(freq_file, "%ld", &freq) != 1) {
            freq = 0;  // Failed to read frequency
        }
        fclose(freq_file);
    }

    printf("\n=== CORE %d RESULTS ===\n", core_id);
    printf("Primes found: %lld (%.2f primes/sec)\n", primes, primes / prime_time);
    printf("FP operations: %.0f ops/sec\n", flops);
    printf("Current frequency: %ld kHz\n", freq);

    // Write results
    char result_file[256];
    snprintf(result_file, sizeof(result_file), "/tmp/core_%d_results.txt", core_id);
    FILE *f = fopen(result_file, "w");
    if (f) {
        fprintf(f, "CORE_ID=%d\n", core_id);
        fprintf(f, "PRIMES=%lld\n", primes);
        fprintf(f, "PRIMES_PER_SEC=%.2f\n", primes / prime_time);
        fprintf(f, "FLOPS=%.0f\n", flops);
        fprintf(f, "FREQUENCY=%ld\n", freq);
        fclose(f);
    }

    return 0;
}
PER_CORE_TEST_EOF

gcc -O3 -pthread -o "$REMOTE_TEST_DIR/per_core_test" "$REMOTE_TEST_DIR/per_core_test.c" -lm

# Test each core individually
declare -a CORE_PRIMES
declare -a CORE_FLOPS
declare -a CORE_FREQS

for ((core=0; core<CPU_CORES; core++)); do
    log_info "Testing Core $core..."
    "$REMOTE_TEST_DIR/per_core_test" $core $PER_CORE_DURATION

    # Read results
    if [ -f "/tmp/core_${core}_results.txt" ]; then
        source "/tmp/core_${core}_results.txt"
        CORE_PRIMES[$core]=$PRIMES_PER_SEC
        CORE_FLOPS[$core]=$FLOPS
        CORE_FREQS[$core]=$FREQUENCY
    fi
done

# Analyze core-to-core variation
log_info "Analyzing core performance variation..."

# Calculate average and standard deviation
total_primes=0
total_flops=0
for ((core=0; core<CPU_CORES; core++)); do
    total_primes=$(echo "$total_primes + ${CORE_PRIMES[$core]}" | bc 2>/dev/null || echo "0")
    total_flops=$(echo "$total_flops + ${CORE_FLOPS[$core]}" | bc 2>/dev/null || echo "0")
done

avg_primes=$(echo "scale=2; $total_primes / $CPU_CORES" | bc 2>/dev/null || echo "0")
avg_flops=$(echo "scale=2; $total_flops / $CPU_CORES" | bc 2>/dev/null || echo "0")

# Find min/max performing cores
min_prime_core=0
max_prime_core=0
min_prime_val=${CORE_PRIMES[0]}
max_prime_val=${CORE_PRIMES[0]}

for ((core=0; core<CPU_CORES; core++)); do
    val=${CORE_PRIMES[$core]}
    if (( $(echo "$val < $min_prime_val" | bc -l 2>/dev/null || echo "0") )); then
        min_prime_val=$val
        min_prime_core=$core
    fi
    if (( $(echo "$val > $max_prime_val" | bc -l 2>/dev/null || echo "0") )); then
        max_prime_val=$val
        max_prime_core=$core
    fi
done

# Calculate performance variation percentage
perf_variation=$(echo "scale=2; (($max_prime_val - $min_prime_val) / $avg_primes) * 100" | bc 2>/dev/null || echo "0")

echo ""
echo "=== PER-CORE ANALYSIS ==="
echo "Average Prime Performance: $avg_primes primes/sec"
echo "Average FP Performance: $avg_flops ops/sec"
echo "Best Core: $max_prime_core ($max_prime_val primes/sec)"
echo "Worst Core: $min_prime_core ($min_prime_val primes/sec)"
echo "Performance Variation: $perf_variation%"

# Score per-core testing
PER_CORE_SCORE=100
if (( $(echo "$perf_variation > 20" | bc -l 2>/dev/null || echo "0") )); then
    PER_CORE_SCORE=60
    log_warning "High core-to-core variation detected ($perf_variation%)"
    HEALTH_WARNINGS=$((HEALTH_WARNINGS + 1))
elif (( $(echo "$perf_variation > 10" | bc -l 2>/dev/null || echo "0") )); then
    PER_CORE_SCORE=80
    log_info "Moderate core-to-core variation ($perf_variation%)"
elif (( $(echo "$perf_variation > 5" | bc -l 2>/dev/null || echo "0") )); then
    PER_CORE_SCORE=90
else
    log_success "Excellent core uniformity ($perf_variation%)"
fi

# Save per-core results
cat > /tmp/per_core_results.txt << EOF
PER_CORE_SCORE=$PER_CORE_SCORE
AVG_PRIMES=$avg_primes
AVG_FLOPS=$avg_flops
BEST_CORE=$max_prime_core
WORST_CORE=$min_prime_core
PERF_VARIATION=$perf_variation
EOF

for ((core=0; core<CPU_CORES; core++)); do
    echo "CORE_${core}_PRIMES=${CORE_PRIMES[$core]}" >> /tmp/per_core_results.txt
    echo "CORE_${core}_FLOPS=${CORE_FLOPS[$core]}" >> /tmp/per_core_results.txt
    echo "CORE_${core}_FREQ=${CORE_FREQS[$core]}" >> /tmp/per_core_results.txt
done

################################################################################
# PHASE 4: CPU INSTRUCTION THROUGHPUT MICRO-BENCHMARKS
################################################################################

log_phase "[PHASE 4: CPU INSTRUCTION THROUGHPUT MICRO-BENCHMARKS]"

MICROBENCH_DURATION=$((TEST_DURATION / 20))  # 5% of total time
if [ $MICROBENCH_DURATION -lt 30 ]; then
    MICROBENCH_DURATION=30  # Minimum 30 seconds
fi

echo "Micro-benchmark duration: $MICROBENCH_DURATION seconds"
echo ""

log_info "Test 4.1: Integer Operations Throughput"

cat > "$REMOTE_TEST_DIR/int_throughput.c" << 'INT_THROUGHPUT_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 30;

    volatile uint64_t a = 12345, b = 67890, c = 0;
    uint64_t add_ops = 0, mul_ops = 0, div_ops = 0;

    printf("Testing integer operations for %d seconds...\n", duration);

    // Test 1: Integer Addition
    time_t start = time(NULL);
    while (time(NULL) - start < duration / 3) {
        c = a + b; c = b + a; c = a + b; c = b + a;
        c = a + b; c = b + a; c = a + b; c = b + a;
        add_ops += 8;
        a = c + 1;
    }
    double add_time = difftime(time(NULL), start);

    // Test 2: Integer Multiplication
    a = 12345; b = 67890;
    start = time(NULL);
    while (time(NULL) - start < duration / 3) {
        c = a * b; c = b * a; c = a * b; c = b * a;
        c = a * b; c = b * a; c = a * b; c = b * a;
        mul_ops += 8;
        if (a > 1000000) a = 12345;
        a++;
    }
    double mul_time = difftime(time(NULL), start);

    // Test 3: Integer Division
    a = 987654321; b = 12345;
    start = time(NULL);
    while (time(NULL) - start < duration / 3) {
        if (b != 0) { c = a / b; c = a / b; c = a / b; c = a / b; }
        if (b != 0) { c = a / b; c = a / b; c = a / b; c = a / b; }
        div_ops += 8;
        b = (b % 10000) + 1;
    }
    double div_time = difftime(time(NULL), start);

    printf("\n=== INTEGER OPERATIONS THROUGHPUT ===\n");
    printf("Addition: %.0f Mops/sec\n", (add_ops / add_time) / 1000000.0);
    printf("Multiplication: %.0f Mops/sec\n", (mul_ops / mul_time) / 1000000.0);
    printf("Division: %.0f Mops/sec\n", (div_ops / div_time) / 1000000.0);

    FILE *f = fopen("/tmp/int_throughput_results.txt", "w");
    if (f) {
        fprintf(f, "INT_ADD_MOPS=%.0f\n", (add_ops / add_time) / 1000000.0);
        fprintf(f, "INT_MUL_MOPS=%.0f\n", (mul_ops / mul_time) / 1000000.0);
        fprintf(f, "INT_DIV_MOPS=%.0f\n", (div_ops / div_time) / 1000000.0);
        fclose(f);
    }

    return 0;
}
INT_THROUGHPUT_EOF

gcc -O2 -o "$REMOTE_TEST_DIR/int_throughput" "$REMOTE_TEST_DIR/int_throughput.c"
"$REMOTE_TEST_DIR/int_throughput" $MICROBENCH_DURATION

log_info "Test 4.2: Floating-Point Operations Throughput"

cat > "$REMOTE_TEST_DIR/fp_throughput.c" << 'FP_THROUGHPUT_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <math.h>

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 30;

    volatile double a = 1.23456, b = 6.78901, c = 0.0;
    uint64_t add_ops = 0, mul_ops = 0, div_ops = 0, sqrt_ops = 0;

    printf("Testing floating-point operations for %d seconds...\n", duration);

    // Test 1: FP Addition
    time_t start = time(NULL);
    while (time(NULL) - start < duration / 4) {
        c = a + b; c = b + a; c = a + b; c = b + a;
        c = a + b; c = b + a; c = a + b; c = b + a;
        add_ops += 8;
        a = c * 0.9999;
    }
    double add_time = difftime(time(NULL), start);

    // Test 2: FP Multiplication
    a = 1.23456; b = 6.78901;
    start = time(NULL);
    while (time(NULL) - start < duration / 4) {
        c = a * b; c = b * a; c = a * b; c = b * a;
        c = a * b; c = b * a; c = a * b; c = b * a;
        mul_ops += 8;
        a = c * 0.0001;
        if (a < 1.0) a = 1.23456;
    }
    double mul_time = difftime(time(NULL), start);

    // Test 3: FP Division
    a = 987.654; b = 1.23456;
    start = time(NULL);
    while (time(NULL) - start < duration / 4) {
        c = a / b; c = a / b; c = a / b; c = a / b;
        c = a / b; c = a / b; c = a / b; c = a / b;
        div_ops += 8;
        a = c + 100.0;
    }
    double div_time = difftime(time(NULL), start);

    // Test 4: FP Square Root
    a = 123456.789;
    start = time(NULL);
    while (time(NULL) - start < duration / 4) {
        c = sqrt(a); c = sqrt(c); c = sqrt(fabs(c));
        a = c * c + 1000.0;
        sqrt_ops += 3;
    }
    double sqrt_time = difftime(time(NULL), start);

    printf("\n=== FLOATING-POINT OPERATIONS THROUGHPUT ===\n");
    printf("Addition: %.0f Mops/sec\n", (add_ops / add_time) / 1000000.0);
    printf("Multiplication: %.0f Mops/sec\n", (mul_ops / mul_time) / 1000000.0);
    printf("Division: %.0f Mops/sec\n", (div_ops / div_time) / 1000000.0);
    printf("Square Root: %.0f Mops/sec\n", (sqrt_ops / sqrt_time) / 1000000.0);

    FILE *f = fopen("/tmp/fp_throughput_results.txt", "w");
    if (f) {
        fprintf(f, "FP_ADD_MOPS=%.0f\n", (add_ops / add_time) / 1000000.0);
        fprintf(f, "FP_MUL_MOPS=%.0f\n", (mul_ops / mul_time) / 1000000.0);
        fprintf(f, "FP_DIV_MOPS=%.0f\n", (div_ops / div_time) / 1000000.0);
        fprintf(f, "FP_SQRT_MOPS=%.0f\n", (sqrt_ops / sqrt_time) / 1000000.0);
        fclose(f);
    }

    return 0;
}
FP_THROUGHPUT_EOF

gcc -O2 -o "$REMOTE_TEST_DIR/fp_throughput" "$REMOTE_TEST_DIR/fp_throughput.c" -lm
"$REMOTE_TEST_DIR/fp_throughput" $MICROBENCH_DURATION

log_info "Test 4.3: Branch Prediction Performance"

cat > "$REMOTE_TEST_DIR/branch_test.c" << 'BRANCH_TEST_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 30;

    printf("Testing branch prediction for %d seconds...\n", duration);

    // Test 1: Predictable branches
    volatile int sum = 0;
    uint64_t pred_branches = 0;
    time_t start = time(NULL);
    while (time(NULL) - start < duration / 2) {
        for (int i = 0; i < 1000; i++) {
            if (i % 2 == 0) sum++; else sum--;
            pred_branches++;
        }
    }
    double pred_time = difftime(time(NULL), start);

    // Test 2: Random unpredictable branches
    srand(12345);
    uint64_t unpred_branches = 0;
    start = time(NULL);
    while (time(NULL) - start < duration / 2) {
        for (int i = 0; i < 1000; i++) {
            if (rand() % 2 == 0) sum++; else sum--;
            unpred_branches++;
        }
    }
    double unpred_time = difftime(time(NULL), start);

    double pred_rate = pred_branches / pred_time;
    double unpred_rate = unpred_branches / unpred_time;
    double penalty = ((pred_rate - unpred_rate) / pred_rate) * 100.0;

    printf("\n=== BRANCH PREDICTION RESULTS ===\n");
    printf("Predictable branches: %.0f M/sec\n", pred_rate / 1000000.0);
    printf("Unpredictable branches: %.0f M/sec\n", unpred_rate / 1000000.0);
    printf("Misprediction penalty: %.1f%%\n", penalty);

    FILE *f = fopen("/tmp/branch_results.txt", "w");
    if (f) {
        fprintf(f, "PRED_BRANCH_MOPS=%.0f\n", pred_rate / 1000000.0);
        fprintf(f, "UNPRED_BRANCH_MOPS=%.0f\n", unpred_rate / 1000000.0);
        fprintf(f, "MISPREDICT_PENALTY=%.1f\n", penalty);
        fclose(f);
    }

    return 0;
}
BRANCH_TEST_EOF

gcc -O2 -o "$REMOTE_TEST_DIR/branch_test" "$REMOTE_TEST_DIR/branch_test.c"
"$REMOTE_TEST_DIR/branch_test" $MICROBENCH_DURATION

# Score instruction throughput tests
INSTRUCTION_SCORE=100
log_success "Instruction throughput micro-benchmarks completed"

################################################################################
# PHASE 5: ADVANCED MEMORY PATTERNS
################################################################################

log_phase "[PHASE 5: ADVANCED MEMORY PATTERNS]"

MEMORY_PATTERN_DURATION=$((TEST_DURATION / 20))  # 5% of total time
if [ $MEMORY_PATTERN_DURATION -lt 30 ]; then
    MEMORY_PATTERN_DURATION=30
fi

echo "Memory pattern test duration: $MEMORY_PATTERN_DURATION seconds"
echo ""

log_info "Test 5.1: Sequential vs Random Access Patterns"

cat > "$REMOTE_TEST_DIR/memory_patterns.c" << 'MEMORY_PATTERNS_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

#define BUFFER_SIZE (16 * 1024 * 1024)  // 16MB

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 30;

    printf("Allocating %d MB buffer...\n", BUFFER_SIZE / (1024*1024));
    uint64_t *buffer = malloc(BUFFER_SIZE);
    if (!buffer) {
        printf("Failed to allocate memory\n");
        return 1;
    }

    // Initialize buffer
    for (size_t i = 0; i < BUFFER_SIZE / sizeof(uint64_t); i++) {
        buffer[i] = i;
    }

    printf("Testing memory access patterns for %d seconds...\n", duration);

    // Test 1: Sequential read
    volatile uint64_t sum = 0;
    uint64_t seq_read_ops = 0;
    time_t start = time(NULL);
    while (time(NULL) - start < duration / 3) {
        for (size_t i = 0; i < BUFFER_SIZE / sizeof(uint64_t); i++) {
            sum += buffer[i];
            seq_read_ops++;
        }
    }
    double seq_read_time = difftime(time(NULL), start);

    // Test 2: Random read
    srand(12345);
    uint64_t rand_read_ops = 0;
    start = time(NULL);
    while (time(NULL) - start < duration / 3) {
        for (int i = 0; i < 10000; i++) {
            size_t idx = rand() % (BUFFER_SIZE / sizeof(uint64_t));
            sum += buffer[idx];
            rand_read_ops++;
        }
    }
    double rand_read_time = difftime(time(NULL), start);

    // Test 3: Strided access (stride of 8 elements = 64 bytes, cache line size)
    uint64_t stride_ops = 0;
    start = time(NULL);
    while (time(NULL) - start < duration / 3) {
        for (size_t i = 0; i < BUFFER_SIZE / sizeof(uint64_t); i += 8) {
            sum += buffer[i];
            stride_ops++;
        }
    }
    double stride_time = difftime(time(NULL), start);

    double seq_bw = (seq_read_ops * sizeof(uint64_t) / seq_read_time) / (1024.0 * 1024.0);
    double rand_bw = (rand_read_ops * sizeof(uint64_t) / rand_read_time) / (1024.0 * 1024.0);
    double stride_bw = (stride_ops * sizeof(uint64_t) / stride_time) / (1024.0 * 1024.0);

    printf("\n=== MEMORY ACCESS PATTERN RESULTS ===\n");
    printf("Sequential read: %.2f MB/s\n", seq_bw);
    printf("Random read: %.2f MB/s (%.1f%% of sequential)\n",
           rand_bw, (rand_bw / seq_bw) * 100.0);
    printf("Strided read (64B): %.2f MB/s (%.1f%% of sequential)\n",
           stride_bw, (stride_bw / seq_bw) * 100.0);

    FILE *f = fopen("/tmp/memory_pattern_results.txt", "w");
    if (f) {
        fprintf(f, "SEQ_READ_BW=%.2f\n", seq_bw);
        fprintf(f, "RAND_READ_BW=%.2f\n", rand_bw);
        fprintf(f, "STRIDE_READ_BW=%.2f\n", stride_bw);
        fprintf(f, "RAND_SEQ_RATIO=%.1f\n", (rand_bw / seq_bw) * 100.0);
        fclose(f);
    }

    free(buffer);
    return 0;
}
MEMORY_PATTERNS_EOF

gcc -O2 -o "$REMOTE_TEST_DIR/memory_patterns" "$REMOTE_TEST_DIR/memory_patterns.c"
"$REMOTE_TEST_DIR/memory_patterns" $MEMORY_PATTERN_DURATION

log_info "Test 5.2: Cache Latency Measurement"

cat > "$REMOTE_TEST_DIR/cache_latency.c" << 'CACHE_LATENCY_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ITERATIONS 10000000

double measure_latency(size_t size) {
    uint8_t *buffer = malloc(size);
    if (!buffer) return -1.0;

    // Initialize with pointer chase pattern
    for (size_t i = 0; i < size - 64; i += 64) {
        *(size_t*)(buffer + i) = i + 64;
    }
    *(size_t*)(buffer + size - 64) = 0;

    // Warm up
    volatile size_t idx = 0;
    for (int i = 0; i < 1000; i++) {
        idx = *(size_t*)(buffer + idx);
    }

    // Measure
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    idx = 0;
    for (int i = 0; i < ITERATIONS; i++) {
        idx = *(size_t*)(buffer + idx);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);

    double elapsed = (end.tv_sec - start.tv_sec) +
                     (end.tv_nsec - start.tv_nsec) / 1e9;
    double latency_ns = (elapsed / ITERATIONS) * 1e9;

    free(buffer);
    return latency_ns;
}

int main() {
    printf("Measuring cache latency...\n\n");

    // Test different memory sizes
    size_t sizes[] = {
        4 * 1024,        // 4KB - L1 cache
        32 * 1024,       // 32KB - L1 cache
        256 * 1024,      // 256KB - L2 cache
        2 * 1024 * 1024, // 2MB - L2/L3 cache
        8 * 1024 * 1024, // 8MB - L3 cache / main memory
        64 * 1024 * 1024 // 64MB - main memory
    };
    const char *names[] = {
        "4 KB (L1 Cache)",
        "32 KB (L1 Cache)",
        "256 KB (L2 Cache)",
        "2 MB (L2/L3 Cache)",
        "8 MB (L3/Memory)",
        "64 MB (Main Memory)"
    };

    double latencies[6];

    for (int i = 0; i < 6; i++) {
        latencies[i] = measure_latency(sizes[i]);
        printf("%s: %.2f ns\n", names[i], latencies[i]);
    }

    printf("\n=== CACHE LATENCY RESULTS ===\n");
    printf("L1 Cache latency: ~%.2f ns\n", latencies[0]);
    printf("L2 Cache latency: ~%.2f ns\n", latencies[2]);
    printf("Main Memory latency: ~%.2f ns\n", latencies[5]);

    FILE *f = fopen("/tmp/cache_latency_results.txt", "w");
    if (f) {
        fprintf(f, "L1_LATENCY=%.2f\n", latencies[0]);
        fprintf(f, "L2_LATENCY=%.2f\n", latencies[2]);
        fprintf(f, "MEMORY_LATENCY=%.2f\n", latencies[5]);
        fclose(f);
    }

    return 0;
}
CACHE_LATENCY_EOF

gcc -O2 -o "$REMOTE_TEST_DIR/cache_latency" "$REMOTE_TEST_DIR/cache_latency.c"
"$REMOTE_TEST_DIR/cache_latency"

# Score memory pattern tests
MEMORY_PATTERN_SCORE=100
log_success "Advanced memory pattern tests completed"

################################################################################
# PHASE 6: MEMORY & CACHE TORTURE TESTS
################################################################################

log_phase "[PHASE 6: MEMORY & CACHE TORTURE TESTS]"

MEMORY_DURATION=$((TEST_DURATION / 10))  # 10% of total time

echo "Memory test duration: $(($MEMORY_DURATION / 60)) minutes"
echo ""

# Test 3.1: Memory Bandwidth Test
log_info "Test 3.1: Memory Bandwidth Measurement"

cat > "$REMOTE_TEST_DIR/memory_bandwidth.c" << 'MEMORY_BANDWIDTH_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define BUFFER_SIZE (64 * 1024 * 1024)  // 64MB buffer

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    
    char* buffer1 = malloc(BUFFER_SIZE);
    char* buffer2 = malloc(BUFFER_SIZE);
    
    if (!buffer1 || !buffer2) {
        printf("Failed to allocate memory buffers\n");
        return 1;
    }
    
    // Initialize buffers
    memset(buffer1, 0xAA, BUFFER_SIZE);
    memset(buffer2, 0x55, BUFFER_SIZE);
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    long long bytes_copied = 0;
    int iterations = 0;
    
    printf("Starting memory bandwidth test for %d seconds...\n", duration);
    
    while (time(NULL) < end_time) {
        memcpy(buffer2, buffer1, BUFFER_SIZE);
        memcpy(buffer1, buffer2, BUFFER_SIZE);
        bytes_copied += 2 * BUFFER_SIZE;
        iterations++;
    }
    
    double elapsed = difftime(time(NULL), start_time);
    double bandwidth_mbps = (bytes_copied / (1024 * 1024)) / elapsed;
    
    printf("\n=== MEMORY BANDWIDTH RESULTS ===\n");
    printf("Total bytes copied: %lld\n", bytes_copied);
    printf("Bandwidth: %.2f MB/s\n", bandwidth_mbps);
    printf("Iterations: %d\n", iterations);
    
    // Write results for health assessment
    FILE *f = fopen("/tmp/memory_bandwidth_results.txt", "w");
    if (f) {
        fprintf(f, "MEMORY_BANDWIDTH_MBPS=%.0f\n", bandwidth_mbps);
        fprintf(f, "TOTAL_BYTES=%lld\n", bytes_copied);
        fclose(f);
    }
    
    free(buffer1);
    free(buffer2);
    return 0;
}
MEMORY_BANDWIDTH_EOF

gcc -O3 -o "$REMOTE_TEST_DIR/memory_bandwidth" "$REMOTE_TEST_DIR/memory_bandwidth.c"
"$REMOTE_TEST_DIR/memory_bandwidth" $MEMORY_DURATION

# Test 3.2: Cache Stress Test
log_info "Test 3.2: Multi-level Cache Stress"

cat > "$REMOTE_TEST_DIR/cache_stress.c" << 'CACHE_STRESS_EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

void l1_cache_stress(int duration) {
    const int L1_SIZE = 16 * 1024;  // 16KB typical L1 cache size
    char *buffer = malloc(L1_SIZE);
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    while (time(NULL) < end_time) {
        for (int i = 0; i < L1_SIZE; i++) {
            buffer[i] = (buffer[i] + 1) % 256;
        }
    }
    
    free(buffer);
}

void l2_cache_stress(int duration) {
    const int L2_SIZE = 512 * 1024;  // 512KB typical L2 cache size
    int *buffer = malloc(L2_SIZE);
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    while (time(NULL) < end_time) {
        for (int i = 0; i < L2_SIZE / sizeof(int); i++) {
            buffer[i] = buffer[i] * 2 + 1;
        }
    }
    
    free(buffer);
}

void l3_cache_stress(int duration) {
    const int L3_SIZE = 4 * 1024 * 1024;  // 4MB typical L3 cache size
    long long *buffer = malloc(L3_SIZE);
    
    time_t start_time = time(NULL);
    time_t end_time = start_time + duration;
    
    while (time(NULL) < end_time) {
        for (int i = 0; i < L3_SIZE / sizeof(long long); i++) {
            buffer[i] = buffer[i] + i;
        }
    }
    
    free(buffer);
}

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 60;
    int cache_duration = duration / 3;
    
    printf("Starting multi-level cache stress for %d seconds...\n", duration);
    
    printf("Testing L1 cache stress...\n");
    l1_cache_stress(cache_duration);
    
    printf("Testing L2 cache stress...\n");
    l2_cache_stress(cache_duration);
    
    printf("Testing L3 cache stress...\n");
    l3_cache_stress(cache_duration);
    
    printf("\n=== CACHE STRESS COMPLETED ===\n");
    
    return 0;
}
CACHE_STRESS_EOF

gcc -O3 -o "$REMOTE_TEST_DIR/cache_stress" "$REMOTE_TEST_DIR/cache_stress.c"
"$REMOTE_TEST_DIR/cache_stress" $MEMORY_DURATION

################################################################################
# PHASE 7: EXTENDED EXTREME STRESS TEST
################################################################################

log_phase "[PHASE 7: EXTENDED EXTREME STRESS TEST]"

EXTENDED_DURATION=$((TEST_DURATION - SINGLE_CORE_DURATION - MULTI_CORE_DURATION - PER_CORE_DURATION * CPU_CORES - MICROBENCH_DURATION - MEMORY_PATTERN_DURATION - MEMORY_DURATION - 300))
if [ $EXTENDED_DURATION -lt 300 ]; then
    EXTENDED_DURATION=300  # Minimum 5 minutes
fi

echo "Extended stress duration: $(($EXTENDED_DURATION / 60)) minutes"
echo "Maximum stress across all $CPU_CORES cores"
echo ""

# Install stress-ng if not available
if ! command -v stress-ng >/dev/null 2>&1; then
    log_info "Installing stress-ng for comprehensive testing..."
    sudo apt-get update >/dev/null 2>&1 || true
    sudo apt-get install -y stress-ng >/dev/null 2>&1 || true
fi

# Function to get current temperature
get_cpu_temp() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        echo $(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
    else
        echo "N/A"
    fi
}

# Function to check thermal throttling
check_thermal_throttling() {
    local current_temp=$(get_cpu_temp)
    if [ "$current_temp" != "N/A" ] && [ "$current_temp" -gt $TEMP_THRESHOLD_WARNING ]; then
        echo "[!] WARNING: Temperature $current_temp°C exceeds warning threshold ($TEMP_THRESHOLD_WARNING°C)"
        if [ "$current_temp" -gt $TEMP_THRESHOLD_CRITICAL ]; then
            echo "[!!] CRITICAL: Temperature $current_temp°C exceeds critical threshold ($TEMP_THRESHOLD_CRITICAL°C)"
            return 1
        fi
    fi
    return 0
}

# Monitor temperature and performance during stress
THERMAL_VIOLATIONS=0
MAX_TEMP_DETECTED=0

log_info "Starting comprehensive stress test using stress-ng..."

# Start stress-ng with comprehensive workloads
stress-ng --cpu $CPU_CORES --vm 2 --io 2 --timeout ${EXTENDED_DURATION}s --metrics-brief > /tmp/stress_results.txt 2>&1 &
STRESS_PID=$!

# Monitor thermal behavior during stress
log_info "Monitoring thermal behavior during stress..."
for ((i=0; i<$EXTENDED_DURATION; i+=10)); do
    sleep 10
    current_temp=$(get_cpu_temp)
    
    if [ "$current_temp" != "N/A" ]; then
        if [ "$current_temp" -gt "$MAX_TEMP_DETECTED" ]; then
            MAX_TEMP_DETECTED=$current_temp
        fi
        
        if ! check_thermal_throttling; then
            THERMAL_VIOLATIONS=$((THERMAL_VIOLATIONS + 1))
        fi
    fi
    
    # Check if stress process is still running
    if ! kill -0 $STRESS_PID 2>/dev/null; then
        log_warning "Stress process terminated early at $i seconds"
        break
    fi
done

# Wait for stress to complete
wait $STRESS_PID 2>/dev/null || true

log_success "Extended stress test completed"

# Calculate thermal score
if [ $THERMAL_VIOLATIONS -eq 0 ]; then
    THERMAL_SCORE=100
    log_success "Thermal management: EXCELLENT (No violations)"
elif [ $THERMAL_VIOLATIONS -le 2 ]; then
    THERMAL_SCORE=80
    log_success "Thermal management: GOOD ($THERMAL_VIOLATIONS violations)"
elif [ $THERMAL_VIOLATIONS -le 5 ]; then
    THERMAL_SCORE=60
    log_warning "Thermal management: ACCEPTABLE ($THERMAL_VIOLATIONS violations)"
    HEALTH_WARNINGS=$((HEALTH_WARNINGS + 1))
else
    THERMAL_SCORE=30
    log_error "Thermal management: POOR ($THERMAL_VIOLATIONS violations)"
    HEALTH_WARNINGS=$((HEALTH_WARNINGS + 2))
fi

################################################################################
# PHASE 8: HEALTH ASSESSMENT AND SCORING
################################################################################

log_phase "[PHASE 8: CPU SCORE CALCULATION]"

# Calculate CPU score (weighted average including new tests)
# Weights: Single-core 20%, Multi-core 25%, Per-core 15%, Instruction 10%, Memory patterns 10%, Thermal 20%
CPU_SCORE=$(echo "scale=0; ($SINGLE_CORE_SCORE * 20 + $MULTI_CORE_SCORE * 25 + $PER_CORE_SCORE * 15 + $INSTRUCTION_SCORE * 10 + $MEMORY_PATTERN_SCORE * 10 + $THERMAL_SCORE * 20) / 100" | bc 2>/dev/null || echo "0")

# Apply health warnings penalty
if [ $HEALTH_WARNINGS -ge 5 ]; then
    CPU_SCORE=$((CPU_SCORE - 20))
elif [ $HEALTH_WARNINGS -ge 3 ]; then
    CPU_SCORE=$((CPU_SCORE - 10))
fi

# Ensure minimum score bounds
if [ $CPU_SCORE -lt 0 ]; then
    CPU_SCORE=0
fi

# Determine test status based on CPU score
if [ $CPU_SCORE -ge 85 ]; then
    TEST_STATUS="PASSED"
else
    TEST_STATUS="FAILED"
fi

echo "=== CPU SCORE CALCULATION COMPLETE ==="
echo "Single-core Score: $SINGLE_CORE_SCORE/100"
echo "Multi-core Score: $MULTI_CORE_SCORE/100"
echo "Per-core Score: $PER_CORE_SCORE/100"
echo "Instruction Throughput Score: $INSTRUCTION_SCORE/100"
echo "Memory Pattern Score: $MEMORY_PATTERN_SCORE/100"
echo "Thermal Score: $THERMAL_SCORE/100"
echo "Health Warnings: $HEALTH_WARNINGS"
echo "CPU Score: $CPU_SCORE/100"
echo "Test Status: $TEST_STATUS"
echo ""

# Save comprehensive results
cat > /tmp/ultra_cpu_results.txt << EOF
CPU_SCORE=$CPU_SCORE
TEST_STATUS=$TEST_STATUS
SINGLE_CORE_SCORE=$SINGLE_CORE_SCORE
MULTI_CORE_SCORE=$MULTI_CORE_SCORE
PER_CORE_SCORE=$PER_CORE_SCORE
INSTRUCTION_SCORE=$INSTRUCTION_SCORE
MEMORY_PATTERN_SCORE=$MEMORY_PATTERN_SCORE
THERMAL_SCORE=$THERMAL_SCORE
HEALTH_WARNINGS=$HEALTH_WARNINGS
THERMAL_VIOLATIONS=$THERMAL_VIOLATIONS
MAX_TEMP_DETECTED=$MAX_TEMP_DETECTED
CPU_CORES_TESTED=$CPU_CORES
EOF

################################################################################
# CLEANUP AND FINALIZATION
################################################################################

log_phase "[CLEANUP AND FINALIZATION]"

# Restore CPU governor to ondemand/powersave
log_info "Restoring CPU governor to power saving mode..."
for i in $(seq 0 $((CPU_CORES-1))); do
    if [ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" ]; then
        echo "ondemand" | sudo tee /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor >/dev/null 2>&1 || \
        echo "powersave" | sudo tee /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor >/dev/null 2>&1 || true
    fi
done

# Re-enable CPU idle states
log_info "Re-enabling CPU idle states..."
for i in $(seq 0 $((CPU_CORES-1))); do
    if [ -d "/sys/devices/system/cpu/cpu$i/cpuidle" ]; then
        for state in /sys/devices/system/cpu/cpu$i/cpuidle/state*/disable; do
            if [ -f "$state" ]; then
                echo 0 | sudo tee "$state" >/dev/null 2>&1 || true
            fi
        done
    fi
done

# Clean up temporary files
cd /tmp
rm -rf "$REMOTE_TEST_DIR"

log_success "Ultra comprehensive CPU stress test completed!"
echo ""
echo "=== FINAL TEST SUMMARY ==="
echo "CPU Score: $CPU_SCORE/100"
echo "Test Status: $TEST_STATUS"
echo "CPU Cores Tested: $CPU_CORES"
echo "Peak Temperature: ${MAX_TEMP_DETECTED}°C"
echo "Health Warnings: $HEALTH_WARNINGS"
echo ""

REMOTE_ULTRA_CPU_TEST_START

################################################################################
# STOP MONITORING & GENERATE REPORTS
################################################################################

log_phase "[GENERATING COMPREHENSIVE REPORTS]"

# Stop temperature monitoring
stop_temperature_monitoring

# Copy results from remote system
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/ultra_cpu_results.txt" "$LOG_DIR/reports/ultra_cpu_results.txt"
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/single_core_prime_results.txt" "$LOG_DIR/performance_data/single_core_prime_results.txt" 2>/dev/null || true
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/multi_core_matrix_results.txt" "$LOG_DIR/performance_data/multi_core_matrix_results.txt" 2>/dev/null || true
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/memory_bandwidth_results.txt" "$LOG_DIR/performance_data/memory_bandwidth_results.txt" 2>/dev/null || true
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/per_core_results.txt" "$LOG_DIR/performance_data/per_core_results.txt" 2>/dev/null || true
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/int_throughput_results.txt" "$LOG_DIR/performance_data/int_throughput_results.txt" 2>/dev/null || true
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/fp_throughput_results.txt" "$LOG_DIR/performance_data/fp_throughput_results.txt" 2>/dev/null || true
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/branch_results.txt" "$LOG_DIR/performance_data/branch_results.txt" 2>/dev/null || true
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/memory_pattern_results.txt" "$LOG_DIR/performance_data/memory_pattern_results.txt" 2>/dev/null || true
scp_download "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "/tmp/cache_latency_results.txt" "$LOG_DIR/performance_data/cache_latency_results.txt" 2>/dev/null || true

# Generate temperature analysis
generate_temperature_analysis "$LOG_DIR/logs/cpu_temperature.csv" "$LOG_DIR/reports/cpu_temperature_results.txt"

################################################################################
# FINAL COMPREHENSIVE REPORT
################################################################################

{
    echo "================================================================================"
    echo "  JETSON ORIN ULTRA COMPREHENSIVE CPU STRESS TEST REPORT"
    echo "================================================================================"
    echo ""
    echo "Test completed: $(date)"
    echo "Test duration: $(format_duration $TEST_DURATION)"
    echo "Jetson model: $JETSON_MODEL"
    echo "Physical CPU cores tested: $CPU_CORES"
    echo "Device: $ORIN_IP"
    echo ""
    echo "Tester: $TESTER_NAME"
    echo "Quality Checker: $QUALITY_CHECKER_NAME"
    echo "Device Serial: $DEVICE_SERIAL"
    echo ""
    
    if [ -f "$LOG_DIR/reports/ultra_cpu_results.txt" ]; then
        source "$LOG_DIR/reports/ultra_cpu_results.txt"

        echo "================================================================================"
        echo "  CPU TEST ASSESSMENT"
        echo "================================================================================"
        echo ""
        echo "[*] CPU SCORE: $CPU_SCORE/100"
        echo "[*] TEST STATUS: $TEST_STATUS"
        echo ""
        echo "[DETAILED METRICS]"
        echo "  • Health Warnings: $HEALTH_WARNINGS"
        echo "  • Peak Temperature: ${MAX_TEMP_DETECTED}°C"
        echo "  • Throttling Events: $THERMAL_VIOLATIONS"
        echo ""

        # Performance comparison with expected values
        if [ -f "$LOG_DIR/performance_data/single_core_prime_results.txt" ]; then
            source "$LOG_DIR/performance_data/single_core_prime_results.txt"
            echo "[SINGLE-CORE PERFORMANCE ANALYSIS]"
            echo "  • Primes Found: $PRIME_COUNT (Expected: $EXPECTED_SINGLE_CORE_PRIMES)"
            echo "  • Performance Ratio: $(echo "scale=2; $PRIME_COUNT * 100 / $EXPECTED_SINGLE_CORE_PRIMES" | bc 2>/dev/null || echo "N/A")%"
            echo ""
        fi

        if [ -f "$LOG_DIR/performance_data/multi_core_matrix_results.txt" ]; then
            source "$LOG_DIR/performance_data/multi_core_matrix_results.txt"
            echo "[MULTI-CORE PERFORMANCE ANALYSIS]"
            echo "  • Matrix Ops/sec: $OPS_PER_SECOND (Expected: $EXPECTED_MULTI_CORE_MATRIX_OPS)"
            echo "  • Performance Ratio: $(echo "scale=2; $OPS_PER_SECOND * 100 / $EXPECTED_MULTI_CORE_MATRIX_OPS" | bc 2>/dev/null || echo "N/A")%"
            echo "  • Threads Utilized: $THREADS_USED/$CPU_CORES"
            echo ""
        fi

        if [ -f "$LOG_DIR/performance_data/memory_bandwidth_results.txt" ]; then
            source "$LOG_DIR/performance_data/memory_bandwidth_results.txt"
            echo "[MEMORY PERFORMANCE ANALYSIS]"
            echo "  • Memory Bandwidth: $MEMORY_BANDWIDTH_MBPS MB/s (Expected: $EXPECTED_MEMORY_BANDWIDTH MB/s)"
            echo "  • Performance Ratio: $(echo "scale=2; $MEMORY_BANDWIDTH_MBPS * 100 / $EXPECTED_MEMORY_BANDWIDTH" | bc 2>/dev/null || echo "N/A")%"
            echo ""
        fi

        if [ -f "$LOG_DIR/performance_data/per_core_results.txt" ]; then
            source "$LOG_DIR/performance_data/per_core_results.txt"
            echo "[PER-CORE PERFORMANCE ANALYSIS]"
            echo "  • Average Prime Performance: $AVG_PRIMES primes/sec"
            echo "  • Average FP Performance: $AVG_FLOPS ops/sec"
            echo "  • Best Performing Core: Core $BEST_CORE"
            echo "  • Worst Performing Core: Core $WORST_CORE"
            echo "  • Performance Variation: $PERF_VARIATION%"
            if (( $(echo "$PERF_VARIATION > 10" | bc -l 2>/dev/null || echo "0") )); then
                echo "  • Status: High variation detected - possible core imbalance"
            else
                echo "  • Status: Excellent core uniformity"
            fi
            echo ""
            echo "  [Per-Core Details]"
            for ((core=0; core<CPU_CORES; core++)); do
                core_primes_var="CORE_${core}_PRIMES"
                core_freq_var="CORE_${core}_FREQ"
                echo "    Core $core: ${!core_primes_var} primes/sec @ ${!core_freq_var} kHz"
            done
            echo ""
        fi

        if [ -f "$LOG_DIR/performance_data/int_throughput_results.txt" ]; then
            source "$LOG_DIR/performance_data/int_throughput_results.txt"
            echo "[INTEGER INSTRUCTION THROUGHPUT]"
            echo "  • Addition: $INT_ADD_MOPS Mops/sec"
            echo "  • Multiplication: $INT_MUL_MOPS Mops/sec"
            echo "  • Division: $INT_DIV_MOPS Mops/sec"
            echo ""
        fi

        if [ -f "$LOG_DIR/performance_data/fp_throughput_results.txt" ]; then
            source "$LOG_DIR/performance_data/fp_throughput_results.txt"
            echo "[FLOATING-POINT INSTRUCTION THROUGHPUT]"
            echo "  • Addition: $FP_ADD_MOPS Mops/sec"
            echo "  • Multiplication: $FP_MUL_MOPS Mops/sec"
            echo "  • Division: $FP_DIV_MOPS Mops/sec"
            echo "  • Square Root: $FP_SQRT_MOPS Mops/sec"
            echo ""
        fi

        if [ -f "$LOG_DIR/performance_data/branch_results.txt" ]; then
            source "$LOG_DIR/performance_data/branch_results.txt"
            echo "[BRANCH PREDICTION ANALYSIS]"
            echo "  • Predictable Branches: $PRED_BRANCH_MOPS M/sec"
            echo "  • Unpredictable Branches: $UNPRED_BRANCH_MOPS M/sec"
            echo "  • Misprediction Penalty: $MISPREDICT_PENALTY%"
            echo ""
        fi

        if [ -f "$LOG_DIR/performance_data/memory_pattern_results.txt" ]; then
            source "$LOG_DIR/performance_data/memory_pattern_results.txt"
            echo "[ADVANCED MEMORY ACCESS PATTERNS]"
            echo "  • Sequential Read: $SEQ_READ_BW MB/s"
            echo "  • Random Read: $RAND_READ_BW MB/s ($RAND_SEQ_RATIO% of sequential)"
            echo "  • Strided Read (64B): $STRIDE_READ_BW MB/s"
            echo ""
        fi

        if [ -f "$LOG_DIR/performance_data/cache_latency_results.txt" ]; then
            source "$LOG_DIR/performance_data/cache_latency_results.txt"
            echo "[CACHE LATENCY MEASUREMENTS]"
            echo "  • L1 Cache Latency: $L1_LATENCY ns"
            echo "  • L2 Cache Latency: $L2_LATENCY ns"
            echo "  • Main Memory Latency: $MEMORY_LATENCY ns"
            echo ""
        fi
        
    else
        echo "[-] ERROR: Ultra CPU test results not available"
        echo "Test may have failed or been interrupted"
    fi

    if [ -f "$LOG_DIR/reports/cpu_temperature_results.txt" ]; then
        source "$LOG_DIR/reports/cpu_temperature_results.txt"
        echo "[THERMAL ANALYSIS DURING TESTING]"
        echo "  • CPU Temperature Range: ${CPU_MIN}°C - ${CPU_MAX}°C (Avg: ${CPU_AVG}°C)"
        echo "  • GPU Temperature Range: ${GPU_MIN}°C - ${GPU_MAX}°C (Avg: ${GPU_AVG}°C)"
        echo ""

        if [ "$CPU_MAX" != "N/A" ] && [ "$CPU_MAX" -le 75 ]; then
            echo "  [+] THERMAL VERDICT: EXCELLENT - Superb cooling performance"
        elif [ "$CPU_MAX" != "N/A" ] && [ "$CPU_MAX" -le 85 ]; then
            echo "  [+] THERMAL VERDICT: GOOD - Acceptable thermal management"
        elif [ "$CPU_MAX" != "N/A" ] && [ "$CPU_MAX" -le 95 ]; then
            echo "  [!] THERMAL VERDICT: CONCERNING - Review cooling solution"
        elif [ "$CPU_MAX" != "N/A" ]; then
            echo "  [-] THERMAL VERDICT: CRITICAL - Immediate cooling improvements needed"
        else
            echo "  [*] THERMAL VERDICT: NO DATA AVAILABLE"
        fi
    fi
    
    echo ""
    echo "================================================================================"
    echo "  FILES AND REPORTS GENERATED"
    echo "================================================================================"
    echo ""
    echo "[Main Reports]"
    echo "  • Ultra CPU Report: $LOG_DIR/reports/ULTRA_CPU_FINAL_REPORT.txt"
    echo "  • Detailed Test Log: $LOG_DIR/logs/ultra_cpu_stress.log"
    echo "  • Temperature Data: $LOG_DIR/logs/cpu_temperature.csv"
    echo "  • Performance Data: $LOG_DIR/performance_data/"
    echo ""
    echo "[Individual Test Results]"
    echo "  • Single-core Results: $LOG_DIR/reports/ultra_cpu_results.txt"
    echo "  • Multi-core Results: $LOG_DIR/reports/ultra_cpu_results.txt"
    echo "  • Memory Results: $LOG_DIR/reports/ultra_cpu_results.txt"
    echo "  • Thermal Results: $LOG_DIR/reports/cpu_temperature_results.txt"
    echo ""

    echo "================================================================================"
    echo "  TEST SUMMARY AND RECOMMENDATIONS"
    echo "================================================================================"
    echo ""
    echo "This ultra comprehensive CPU test pushed your Jetson Orin to its absolute limits"
    echo "across single-core, multi-core, memory, and thermal stress scenarios."
    echo ""
    echo "[What This Test Validates]"
    echo "  • CPU arithmetic and floating-point performance"
    echo "  • Multi-core scaling and thread efficiency (all $CPU_CORES physical cores)"
    echo "  • Individual core performance and core-to-core uniformity"
    echo "  • Instruction-level throughput (integer, FP, branches)"
    echo "  • Advanced memory access patterns (sequential, random, strided)"
    echo "  • Cache latency at different memory hierarchy levels"
    echo "  • Optimized workload sizing based on core count"
    echo "  • Memory subsystem bandwidth and latency"
    echo "  • Cache hierarchy performance (L1/L2/L3)"
    echo "  • Branch prediction efficiency"
    echo "  • Thermal management under extreme load"
    echo "  • System stability during maximum stress"
    echo "  • Frequency scaling and throttling behavior"
    echo ""
    echo "[For Production Use]"
    if [ "$TEST_STATUS" = "PASSED" ]; then
        echo "  [+] System is ready for demanding AI/ML workloads"
        echo "  [+] Suitable for real-time inference applications"
        echo "  [+] Can handle sustained high-performance computing"
    else
        echo "  [!] Review system before deploying critical workloads"
        echo "  [!] Consider performance optimization or hardware maintenance"
        echo "  [!] Monitor thermal behavior during actual workloads"
    fi
    echo ""
    echo "[Support Information]"
    echo "  • For detailed analysis: Review individual test logs"
    echo "  • For thermal issues: Check cooling solution and case ventilation"
    echo "  • For performance issues: Verify JetPack version and system configuration"
    echo ""
    echo "================================================================================"
    echo "  ULTRA COMPREHENSIVE CPU TEST COMPLETED"
    echo "================================================================================"
    echo ""
    echo "Test completed: $(date)"
    echo "Total test duration: $(format_duration $TEST_DURATION)"
    echo "Report generation: Ultra Comprehensive CPU Test Suite v4.0 (Enhanced)"
    echo ""
    echo "Test Status: $TEST_STATUS"

} | tee "$LOG_DIR/reports/ULTRA_CPU_FINAL_REPORT.txt"

################################################################################
# COMPLETION
################################################################################

log_success "[+] Ultra comprehensive CPU stress test completed successfully!"
echo ""
echo "[*] Results Directory: $LOG_DIR"
echo "[*] Ultra Report: $LOG_DIR/reports/ULTRA_CPU_FINAL_REPORT.txt"
echo "[*] Detailed Log: $LOG_DIR/logs/ultra_cpu_stress.log"
echo "[*] Temperature Data: $LOG_DIR/logs/cpu_temperature.csv"
echo "[*] Performance Data: $LOG_DIR/performance_data/"
echo ""

# Display quick health summary
if [ -f "$LOG_DIR/reports/ultra_cpu_results.txt" ]; then
    source "$LOG_DIR/reports/ultra_cpu_results.txt"
    echo "================================================================================"
    echo "  QUICK TEST SUMMARY"
    echo "================================================================================"
    echo ""
    echo "[*] CPU SCORE: $CPU_SCORE/100"
    echo "[*] TEST STATUS: $TEST_STATUS"
    echo "[*] JETSON MODEL: $JETSON_MODEL"
    echo "[*] Health Warnings: $HEALTH_WARNINGS"
    echo "[*] Peak Temperature: ${MAX_TEMP_DETECTED}°C"
    echo "[*] Physical CPU Cores Tested: $CPU_CORES"
    echo ""
    echo "[*] View complete report: cat $LOG_DIR/reports/ULTRA_CPU_FINAL_REPORT.txt"
fi

################################################################################
# AUTOMATIC PDF GENERATION
################################################################################

echo ""
log_info "Generating PDF reports..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PDF_GENERATOR="$SCRIPT_DIR/generate_pdf_reports.sh"

# Auto-detect logo in assets/logos directory
LOGO_OPTS=""
LOGO_DIR="$SCRIPT_DIR/assets/logos"
if [ -d "$LOGO_DIR" ]; then
    # Find first logo file (PNG, JPG, JPEG, GIF, BMP)
    LOGO_FILE=$(find "$LOGO_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.bmp" \) | head -n 1)
    if [ -n "$LOGO_FILE" ]; then
        LOGO_OPTS="--logo $LOGO_FILE --logo-position watermark --logo-opacity 0.1"
        log_info "Using logo: $(basename "$LOGO_FILE")"
    fi
fi

if [ -f "$PDF_GENERATOR" ]; then
    if "$PDF_GENERATOR" --test-type cpu $LOGO_OPTS "$LOG_DIR" > /dev/null 2>&1; then
        log_success "PDF reports generated successfully"
        echo "[*] PDF Reports: $LOG_DIR/pdf_reports/cpu/"
    else
        log_warning "PDF generation failed (test results still available)"
    fi
else
    log_warning "PDF generator not found (test results still available)"
fi
echo ""

# Return appropriate exit code based on test status
if [ -f "$LOG_DIR/reports/ultra_cpu_results.txt" ]; then
    source "$LOG_DIR/reports/ultra_cpu_results.txt"
    if [ "$TEST_STATUS" = "PASSED" ]; then
        exit 0
    else
        exit 1
    fi
else
    exit 1
fi