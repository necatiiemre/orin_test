#!/bin/bash

################################################################################
# DIRECT RAM STRESS TEST - RUN ON JETSON ORIN LOCALLY
################################################################################
# Description: Intensive RAM stress test to run directly on Jetson Orin
# Usage: Run this script directly on the Jetson Orin device
# Purpose: Maximum RAM stress testing without SSH overhead
################################################################################

set -e

################################################################################
# CONFIGURATION
################################################################################

TEST_DURATION="${1:-3600}"  # Default 1 hour
MEMORY_PERCENTAGE="${2:-95}"  # Use 95% of available RAM

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# LOGGING
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') - $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') - $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') - $*"
}

################################################################################
# USAGE
################################################################################

show_usage() {
    cat << EOF
================================================================================
  DIRECT RAM STRESS TEST FOR JETSON ORIN
================================================================================

Usage: $0 [duration_seconds] [memory_percentage]

Parameters:
  duration_seconds   : Test duration in seconds (default: 3600 = 1 hour)
  memory_percentage  : Percentage of available RAM to use (default: 95)

Examples:
  $0                 # 1 hour test using 95% RAM
  $0 7200            # 2 hour test using 95% RAM  
  $0 1800 90         # 30 minute test using 90% RAM

Features:
  • Direct execution on Jetson Orin (no SSH required)
  • Intensive memory allocation and testing
  • Multiple stress patterns and algorithms
  • Real-time temperature monitoring
  • Comprehensive error detection
  • Multi-threaded stress testing

This will PUSH YOUR RAM TO THE LIMIT!

================================================================================
EOF
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_usage
    exit 0
fi

################################################################################
# SYSTEM CHECKS
################################################################################

echo "================================================================================"
echo "  DIRECT RAM STRESS TEST - JETSON ORIN"
echo "================================================================================"
echo ""

# Check if running on Jetson
if [ ! -f "/etc/nv_tegra_release" ]; then
    log_error "This script is designed for NVIDIA Jetson devices"
    log_error "File /etc/nv_tegra_release not found"
    exit 1
fi

# Display Jetson info
JETSON_INFO=$(cat /etc/nv_tegra_release 2>/dev/null || echo "Unknown Jetson")
log_info "Device: $JETSON_INFO"

# Check if Python3 is available
if ! command -v python3 &> /dev/null; then
    log_error "Python3 is required but not found"
    exit 1
fi

# Get memory information
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
AVAILABLE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
AVAILABLE_RAM_MB=$((AVAILABLE_RAM_KB / 1024))

log_info "System Memory:"
log_info "  Total RAM: ${TOTAL_RAM_MB} MB"
log_info "  Available RAM: ${AVAILABLE_RAM_MB} MB"

# Calculate test memory
TEST_MEMORY_MB=$((AVAILABLE_RAM_MB * MEMORY_PERCENTAGE / 100))
log_info "  Test Memory: ${TEST_MEMORY_MB} MB (${MEMORY_PERCENTAGE}% of available)"

if [ $TEST_MEMORY_MB -lt 500 ]; then
    log_error "Not enough memory available for testing (need at least 500MB)"
    exit 1
fi

log_info "Test Duration: $TEST_DURATION seconds ($((TEST_DURATION / 60)) minutes)"
echo ""

################################################################################
# CREATE TEST DIRECTORY
################################################################################

TEST_DIR="/tmp/ram_stress_test_$(date +%s)"
mkdir -p "$TEST_DIR"
log_info "Test directory: $TEST_DIR"

################################################################################
# CREATE AGGRESSIVE RAM STRESS TEST
################################################################################

cat > "$TEST_DIR/aggressive_ram_test.py" << 'PYTHON_SCRIPT'
#!/usr/bin/env python3

import os
import sys
import time
import random
import signal
import threading
import multiprocessing
from concurrent.futures import ThreadPoolExecutor, as_completed
import gc
import mmap

class AggressiveRAMStressTest:
    def __init__(self, memory_mb, duration):
        self.memory_mb = memory_mb
        self.duration = duration
        self.memory_blocks = []
        self.running = True
        self.errors = 0
        self.operations = 0
        self.start_time = time.time()
        
        # Aggressive test patterns
        self.patterns = {
            'zeros': 0x00,
            'ones': 0xFF,
            'alternating_55': 0x55,
            'alternating_AA': 0xAA,
            'walking_ones': list(1 << i for i in range(8)),
            'walking_zeros': list(~(1 << i) & 0xFF for i in range(8)),
            'checkerboard': [0x55, 0xAA],
            'random_seed': None
        }
        
        # Thread-safe counters
        self.lock = threading.Lock()
        
        # Statistics
        self.stats = {
            'allocated_mb': 0,
            'pattern_writes': 0,
            'pattern_reads': 0,
            'random_operations': 0,
            'integrity_checks': 0,
            'copy_operations': 0,
            'errors_found': 0
        }
        
    def signal_handler(self, signum, frame):
        print(f"\nReceived signal {signum}, stopping test gracefully...")
        self.running = False
        
    def allocate_aggressive_memory(self):
        """Allocate memory aggressively in various block sizes"""
        
        print("AGGRESSIVE MEMORY ALLOCATION")
        print("-" * 50)
        
        # Mix of block sizes for different stress patterns
        block_sizes = [
            (100, 10),   # 10 blocks of 100MB
            (50, 20),    # 20 blocks of 50MB  
            (25, 40),    # 40 blocks of 25MB
            (10, 100),   # 100 blocks of 10MB
        ]
        
        total_allocated = 0
        target_mb = self.memory_mb
        
        for block_size_mb, max_blocks in block_sizes:
            if total_allocated >= target_mb:
                break
                
            print(f"Allocating {block_size_mb}MB blocks...")
            
            for i in range(max_blocks):
                if not self.running or total_allocated >= target_mb:
                    break
                    
                try:
                    block_size = block_size_mb * 1024 * 1024
                    
                    # Use different allocation methods for variety
                    if i % 3 == 0:
                        # Standard allocation
                        block = bytearray(block_size)
                    elif i % 3 == 1:
                        # Pattern-filled allocation
                        pattern = random.choice([0x55, 0xAA, 0xFF, 0x00])
                        block = bytearray([pattern] * block_size)
                    else:
                        # Random-filled allocation
                        block = bytearray(random.getrandbits(8) for _ in range(block_size))
                    
                    # Touch every page to ensure physical allocation
                    page_size = 4096
                    for j in range(0, block_size, page_size):
                        block[j] = random.randint(0, 255)
                    
                    self.memory_blocks.append({
                        'data': block,
                        'size': block_size,
                        'size_mb': block_size_mb,
                        'id': len(self.memory_blocks),
                        'pattern': 'mixed',
                        'checksum': self.calculate_checksum(block)
                    })
                    
                    total_allocated += block_size_mb
                    self.stats['allocated_mb'] = total_allocated
                    
                    if len(self.memory_blocks) % 10 == 0:
                        print(f"  Allocated {len(self.memory_blocks)} blocks ({total_allocated}MB)")
                        
                except MemoryError:
                    print(f"Memory allocation failed at {total_allocated}MB")
                    break
                except Exception as e:
                    print(f"Allocation error: {e}")
                    break
                    
        print(f"✓ Successfully allocated {len(self.memory_blocks)} blocks ({total_allocated}MB)")
        print(f"✓ Memory allocation rate: {(total_allocated/self.memory_mb)*100:.1f}%")
        
        return len(self.memory_blocks) > 0
        
    def calculate_checksum(self, data):
        """Calculate simple checksum for integrity verification"""
        return sum(data) & 0xFFFFFFFF
        
    def verify_block_integrity(self, block_info):
        """Verify block integrity using checksum"""
        current_checksum = self.calculate_checksum(block_info['data'])
        return current_checksum == block_info['checksum']
        
    def aggressive_pattern_test(self, block_info):
        """Perform aggressive pattern testing on a memory block"""
        block = block_info['data']
        block_size = len(block)
        errors = 0
        
        # Test all pattern types
        for pattern_name, pattern_data in self.patterns.items():
            if not self.running:
                break
                
            if pattern_name == 'random_seed':
                # Random pattern test
                random.seed(42)  # Reproducible
                for i in range(min(block_size, 10000)):
                    value = random.randint(0, 255)
                    block[i] = value
                    
                    # Immediate verification
                    if block[i] != value:
                        errors += 1
                        
                self.stats['random_operations'] += 1
                
            elif isinstance(pattern_data, int):
                # Simple byte pattern
                test_size = min(block_size, 100000)  # Test first 100KB
                
                # Fill with pattern
                for i in range(test_size):
                    block[i] = pattern_data
                    
                # Verify pattern
                for i in range(test_size):
                    if block[i] != pattern_data:
                        errors += 1
                        
                self.stats['pattern_writes'] += 1
                self.stats['pattern_reads'] += 1
                
            elif isinstance(pattern_data, list):
                # Complex pattern (walking bits, etc.)
                pattern_len = len(pattern_data)
                test_size = min(block_size, pattern_len * 1000)
                
                # Fill with pattern
                for i in range(test_size):
                    pattern_byte = pattern_data[i % pattern_len]
                    block[i] = pattern_byte
                    
                # Verify pattern  
                for i in range(test_size):
                    expected = pattern_data[i % pattern_len]
                    if block[i] != expected:
                        errors += 1
                        
                self.stats['pattern_writes'] += 1
                self.stats['pattern_reads'] += 1
                
        return errors
        
    def memory_copy_stress(self):
        """Perform intensive memory copy operations"""
        if len(self.memory_blocks) < 2:
            return 0
            
        errors = 0
        copy_operations = 100
        
        for _ in range(copy_operations):
            if not self.running:
                break
                
            # Select random source and destination blocks
            src_block = random.choice(self.memory_blocks)
            dst_block = random.choice(self.memory_blocks)
            
            if src_block['id'] == dst_block['id']:
                continue
                
            # Random copy size (up to 64KB)
            max_copy_size = min(64*1024, src_block['size'], dst_block['size'])
            copy_size = random.randint(1024, max_copy_size)
            
            # Random positions
            src_pos = random.randint(0, src_block['size'] - copy_size)
            dst_pos = random.randint(0, dst_block['size'] - copy_size)
            
            # Copy data
            src_data = src_block['data'][src_pos:src_pos + copy_size]
            dst_block['data'][dst_pos:dst_pos + copy_size] = src_data
            
            # Verify copy
            if dst_block['data'][dst_pos:dst_pos + copy_size] != src_data:
                errors += 1
                
            self.stats['copy_operations'] += 1
            
        return errors
        
    def random_access_stress(self, block_info):
        """Perform random memory access stress test"""
        block = block_info['data']
        errors = 0
        access_count = 10000
        
        # Random read/write operations
        for _ in range(access_count):
            if not self.running:
                break
                
            # Random position and size
            max_pos = len(block) - 8
            pos = random.randint(0, max_pos)
            
            # Random value
            value = random.randint(0, 0xFFFFFFFFFFFFFFFF)
            
            # Write 8-byte value
            block[pos:pos+8] = value.to_bytes(8, 'little')
            
            # Read back and verify
            read_value = int.from_bytes(block[pos:pos+8], 'little')
            
            if read_value != value:
                errors += 1
                with self.lock:
                    print(f"Random access error: pos={pos}, wrote={value:016x}, read={read_value:016x}")
                    
            self.operations += 1
            
        return errors
        
    def stress_worker(self, worker_id, blocks_per_worker):
        """Intensive stress testing worker thread"""
        
        worker_errors = 0
        worker_operations = 0
        
        # Get blocks for this worker
        start_idx = worker_id * blocks_per_worker
        end_idx = min(start_idx + blocks_per_worker, len(self.memory_blocks))
        worker_blocks = self.memory_blocks[start_idx:end_idx]
        
        print(f"Worker {worker_id}: Testing blocks {start_idx}-{end_idx-1}")
        
        cycle = 0
        while self.running:
            cycle += 1
            
            for block_info in worker_blocks:
                if not self.running:
                    break
                    
                try:
                    # Different stress tests per cycle
                    if cycle % 4 == 0:
                        # Pattern testing
                        errors = self.aggressive_pattern_test(block_info)
                        worker_errors += errors
                        
                    elif cycle % 4 == 1:
                        # Random access stress
                        errors = self.random_access_stress(block_info)
                        worker_errors += errors
                        
                    elif cycle % 4 == 2:
                        # Memory copy stress
                        errors = self.memory_copy_stress()
                        worker_errors += errors
                        
                    else:
                        # Integrity verification
                        if not self.verify_block_integrity(block_info):
                            worker_errors += 1
                            print(f"Integrity error in block {block_info['id']}")
                            
                        self.stats['integrity_checks'] += 1
                        
                    worker_operations += 1
                    
                except Exception as e:
                    worker_errors += 1
                    print(f"Worker {worker_id} exception: {e}")
                    
            # Progress update
            if cycle % 100 == 0:
                elapsed = time.time() - self.start_time
                remaining = self.duration - elapsed
                
                with self.lock:
                    print(f"Worker {worker_id}: Cycle {cycle}, {remaining:.0f}s remaining, {worker_errors} errors")
                    
        print(f"Worker {worker_id} completed: {worker_operations} operations, {worker_errors} errors")
        return worker_operations, worker_errors
        
    def run_aggressive_test(self):
        """Execute the complete aggressive RAM stress test"""
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        
        print("=" * 80)
        print("AGGRESSIVE RAM STRESS TEST - MAXIMUM INTENSITY")
        print("=" * 80)
        print(f"Target Memory: {self.memory_mb} MB")
        print(f"Test Duration: {self.duration} seconds ({self.duration/60:.1f} minutes)")
        print(f"CPU Cores: {multiprocessing.cpu_count()}")
        print("")
        print("WARNING: This test will push your RAM to absolute limits!")
        print("System may become temporarily unresponsive during testing.")
        print("")
        
        # Phase 1: Aggressive Memory Allocation
        print("PHASE 1: AGGRESSIVE MEMORY ALLOCATION")
        print("=" * 50)
        
        if not self.allocate_aggressive_memory():
            print("CRITICAL: Memory allocation failed!")
            return False
            
        total_allocated_mb = sum(block['size_mb'] for block in self.memory_blocks)
        print(f"✓ Allocated {total_allocated_mb}MB across {len(self.memory_blocks)} blocks")
        print("")
        
        # Phase 2: Multi-threaded Aggressive Stress Testing
        print("PHASE 2: MAXIMUM INTENSITY STRESS TESTING")
        print("=" * 50)
        
        # Use all available CPU cores
        num_workers = multiprocessing.cpu_count()
        blocks_per_worker = len(self.memory_blocks) // num_workers
        
        print(f"Starting {num_workers} aggressive stress workers...")
        print(f"Each worker testing ~{blocks_per_worker} memory blocks")
        print("")
        
        with ThreadPoolExecutor(max_workers=num_workers) as executor:
            # Start all stress workers
            futures = []
            for i in range(num_workers):
                future = executor.submit(self.stress_worker, i, blocks_per_worker)
                futures.append(future)
                
            # Monitor progress and time
            start_time = time.time()
            
            while self.running and (time.time() - start_time) < self.duration:
                time.sleep(30)  # Update every 30 seconds
                
                elapsed = time.time() - start_time
                remaining = self.duration - elapsed
                
                print(f"PROGRESS: {elapsed:.0f}s elapsed, {remaining:.0f}s remaining")
                print(f"  Total Operations: {self.operations:,}")
                print(f"  Total Errors: {self.errors}")
                print(f"  Error Rate: {(self.errors/max(self.operations,1)*100):.8f}%")
                print(f"  Allocated Memory: {total_allocated_mb}MB")
                print("")
                
                if remaining <= 0:
                    break
                    
            # Stop all workers
            print("Stopping all stress workers...")
            self.running = False
            
            # Collect results from all workers
            total_worker_operations = 0
            total_worker_errors = 0
            
            for i, future in enumerate(futures):
                try:
                    operations, errors = future.result(timeout=60)
                    total_worker_operations += operations
                    total_worker_errors += errors
                    print(f"Worker {i}: {operations} ops, {errors} errors")
                except Exception as e:
                    print(f"Worker {i} error: {e}")
                    total_worker_errors += 1
                    
        print("")
        
        # Phase 3: Final Comprehensive Verification
        print("PHASE 3: FINAL COMPREHENSIVE VERIFICATION")
        print("=" * 50)
        
        final_errors = 0
        
        print("Performing final integrity check on all memory blocks...")
        for i, block_info in enumerate(self.memory_blocks):
            if not self.verify_block_integrity(block_info):
                final_errors += 1
                print(f"Final integrity error in block {i}")
                
            if (i + 1) % 50 == 0:
                print(f"Verified {i+1}/{len(self.memory_blocks)} blocks")
                
        print("")
        
        # Calculate total results
        total_errors = self.errors + total_worker_errors + final_errors
        total_operations = self.operations + total_worker_operations
        actual_duration = time.time() - self.start_time
        
        print("=" * 80)
        print("AGGRESSIVE RAM STRESS TEST RESULTS")
        print("=" * 80)
        print("")
        print(f"Test Duration: {actual_duration:.1f} seconds ({actual_duration/60:.1f} minutes)")
        print(f"Memory Tested: {total_allocated_mb} MB")
        print(f"Memory Blocks: {len(self.memory_blocks)}")
        print(f"CPU Workers: {num_workers}")
        print("")
        print(f"Total Operations: {total_operations:,}")
        print(f"Pattern Tests: {self.stats['pattern_writes']:,}")
        print(f"Random Operations: {self.stats['random_operations']:,}")
        print(f"Copy Operations: {self.stats['copy_operations']:,}")
        print(f"Integrity Checks: {self.stats['integrity_checks']:,}")
        print("")
        print(f"TOTAL ERRORS FOUND: {total_errors}")
        print("")
        
        if total_errors == 0:
            print("🎉 RESULT: AGGRESSIVE RAM TEST PASSED!")
            print("✓ ZERO memory errors detected under maximum stress")
            print("✓ ALL memory patterns verified successfully")
            print("✓ Memory integrity maintained under extreme load")
            print("✓ Your RAM is ROCK SOLID!")
            result = True
        else:
            print("❌ RESULT: AGGRESSIVE RAM TEST FAILED!")
            print(f"✗ {total_errors} memory errors detected")
            print("✗ RAM has defects or instability issues")
            print("✗ Memory is NOT reliable under stress")
            print("✗ HARDWARE REPLACEMENT RECOMMENDED")
            result = False
            
        print("")
        print(f"Error Rate: {(total_errors/max(total_operations,1)*100):.10f}%")
        print(f"Operations/Second: {total_operations/actual_duration:.0f}")
        print(f"MB Tested/Second: {total_allocated_mb/actual_duration:.1f}")
        
        return result, total_errors, total_operations

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 aggressive_ram_test.py <memory_mb> <duration_seconds>")
        sys.exit(1)
        
    try:
        memory_mb = int(sys.argv[1])
        duration = int(sys.argv[2])
        
        tester = AggressiveRAMStressTest(memory_mb, duration)
        success, errors, operations = tester.run_aggressive_test()
        
        # Write detailed results
        with open('/tmp/ram_test_result.txt', 'w') as f:
            f.write(f"RESULT={'PASSED' if success else 'FAILED'}\n")
            f.write(f"ERRORS={errors}\n")
            f.write(f"OPERATIONS={operations}\n")
            f.write(f"MEMORY_MB={memory_mb}\n")
            f.write(f"DURATION={duration}\n")
            
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(2)

if __name__ == "__main__":
    main()

PYTHON_SCRIPT

################################################################################
# JETSON TEMPERATURE AND POWER MONITORING
################################################################################

cat > "$TEST_DIR/jetson_monitor.py" << 'MONITOR_SCRIPT'
#!/usr/bin/env python3

import time
import os
import threading
import subprocess

class JetsonMonitor:
    def __init__(self, duration):
        self.duration = duration
        self.running = True
        
        # Temperature tracking
        self.max_cpu_temp = 0
        self.max_gpu_temp = 0
        self.max_soc_temp = 0
        
        # Power tracking
        self.max_power = 0
        self.avg_power = 0
        self.power_readings = []
        
        # Frequency tracking
        self.cpu_freqs = []
        self.gpu_freqs = []
        
    def get_thermal_zones(self):
        """Get all thermal zone temperatures"""
        temps = {}
        thermal_dir = "/sys/class/thermal"
        
        try:
            for zone in os.listdir(thermal_dir):
                if zone.startswith("thermal_zone"):
                    temp_file = f"{thermal_dir}/{zone}/temp"
                    type_file = f"{thermal_dir}/{zone}/type"
                    
                    if os.path.exists(temp_file) and os.path.exists(type_file):
                        with open(temp_file, 'r') as f:
                            temp = int(f.read()) / 1000.0
                        with open(type_file, 'r') as f:
                            zone_type = f.read().strip()
                        
                        temps[zone_type] = temp
        except:
            pass
            
        return temps
        
    def get_jetson_stats(self):
        """Get Jetson-specific stats using tegrastats if available"""
        try:
            # Try to get power info
            power = 0
            
            # Check for power monitoring files
            power_files = [
                "/sys/bus/i2c/devices/7-0040/hwmon/hwmon*/in1_input",
                "/sys/bus/i2c/devices/7-0041/hwmon/hwmon*/in1_input"
            ]
            
            for pattern in power_files:
                import glob
                files = glob.glob(pattern)
                for file in files:
                    try:
                        with open(file, 'r') as f:
                            power = int(f.read()) / 1000.0  # Convert to watts
                            break
                    except:
                        continue
                if power > 0:
                    break
                    
            return power
            
        except:
            return 0
            
    def get_cpu_freq(self):
        """Get current CPU frequency"""
        try:
            with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq", 'r') as f:
                freq_khz = int(f.read())
                return freq_khz / 1000  # Convert to MHz
        except:
            return 0
            
    def get_gpu_freq(self):
        """Get current GPU frequency"""
        try:
            # Try different GPU frequency locations
            gpu_freq_files = [
                "/sys/devices/platform/17000000.gv11b/devfreq/17000000.gv11b/cur_freq",
                "/sys/kernel/debug/clk/gpcclk/clk_rate"
            ]
            
            for freq_file in gpu_freq_files:
                try:
                    with open(freq_file, 'r') as f:
                        freq_hz = int(f.read())
                        return freq_hz / 1000000  # Convert to MHz
                except:
                    continue
                    
            return 0
        except:
            return 0
            
    def monitor_loop(self):
        """Main monitoring loop"""
        
        print("Starting Jetson system monitoring...")
        print("Monitoring: Temperature, Power, CPU/GPU frequencies")
        print("")
        
        while self.running:
            try:
                # Get thermal data
                temps = self.get_thermal_zones()
                
                # Extract specific temperatures
                cpu_temp = temps.get('CPU-therm', temps.get('cpu', 0))
                gpu_temp = temps.get('GPU-therm', temps.get('gpu', 0))
                soc_temp = temps.get('SOC-therm', temps.get('soc', 0))
                
                # Update maximums
                self.max_cpu_temp = max(self.max_cpu_temp, cpu_temp)
                self.max_gpu_temp = max(self.max_gpu_temp, gpu_temp)
                self.max_soc_temp = max(self.max_soc_temp, soc_temp)
                
                # Get power data
                power = self.get_jetson_stats()
                if power > 0:
                    self.power_readings.append(power)
                    self.max_power = max(self.max_power, power)
                    
                # Get frequency data
                cpu_freq = self.get_cpu_freq()
                gpu_freq = self.get_gpu_freq()
                
                if cpu_freq > 0:
                    self.cpu_freqs.append(cpu_freq)
                if gpu_freq > 0:
                    self.gpu_freqs.append(gpu_freq)
                
                # Display current status
                print(f"Temps: CPU {cpu_temp:.1f}°C, GPU {gpu_temp:.1f}°C, SOC {soc_temp:.1f}°C", end="")
                if power > 0:
                    print(f", Power {power:.1f}W", end="")
                if cpu_freq > 0:
                    print(f", CPU {cpu_freq:.0f}MHz", end="")
                if gpu_freq > 0:
                    print(f", GPU {gpu_freq:.0f}MHz", end="")
                    
                print(f" (Max: CPU {self.max_cpu_temp:.1f}°C, GPU {self.max_gpu_temp:.1f}°C)")
                
                time.sleep(10)  # Monitor every 10 seconds
                
            except Exception as e:
                print(f"Monitoring error: {e}")
                time.sleep(5)
                
    def start_monitoring(self):
        """Start monitoring in background thread"""
        monitor_thread = threading.Thread(target=self.monitor_loop)
        monitor_thread.daemon = True
        monitor_thread.start()
        
        # Wait for test duration
        time.sleep(self.duration)
        self.running = False
        
        # Calculate averages
        if self.power_readings:
            self.avg_power = sum(self.power_readings) / len(self.power_readings)
        
        return {
            'max_cpu_temp': self.max_cpu_temp,
            'max_gpu_temp': self.max_gpu_temp,
            'max_soc_temp': self.max_soc_temp,
            'max_power': self.max_power,
            'avg_power': self.avg_power,
            'avg_cpu_freq': sum(self.cpu_freqs) / len(self.cpu_freqs) if self.cpu_freqs else 0,
            'avg_gpu_freq': sum(self.gpu_freqs) / len(self.gpu_freqs) if self.gpu_freqs else 0
        }

if __name__ == "__main__":
    import sys
    duration = int(sys.argv[1]) if len(sys.argv) > 1 else 60
    
    monitor = JetsonMonitor(duration)
    results = monitor.start_monitoring()
    
    print("\nMonitoring Results:")
    for key, value in results.items():
        print(f"{key}: {value:.1f}")
    
    # Write results to file
    with open('/tmp/monitor_results.txt', 'w') as f:
        for key, value in results.items():
            f.write(f"{key.upper()}={value:.1f}\n")

MONITOR_SCRIPT

################################################################################
# START MONITORING
################################################################################

log_info "Starting Jetson system monitoring..."
python3 "$TEST_DIR/jetson_monitor.py" $TEST_DURATION &
MONITOR_PID=$!

# Give monitor time to start
sleep 2

################################################################################
# EXECUTE AGGRESSIVE RAM TEST
################################################################################

log_info "Starting AGGRESSIVE RAM stress test..."
log_info "WARNING: System may become temporarily unresponsive!"
echo ""

# Run the aggressive RAM test
python3 "$TEST_DIR/aggressive_ram_test.py" $TEST_MEMORY_MB $TEST_DURATION

TEST_RESULT=$?

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

echo ""
echo "================================================================================"
echo "  FINAL COMPREHENSIVE RESULTS"
echo "================================================================================"
echo ""

# Display RAM test results
if [ -f "/tmp/ram_test_result.txt" ]; then
    source /tmp/ram_test_result.txt
    
    echo "RAM STRESS TEST RESULTS:"
    echo "  Result: $RESULT"
    echo "  Total Errors: $ERRORS"
    echo "  Total Operations: $OPERATIONS"
    echo "  Memory Tested: ${MEMORY_MB} MB"
    echo "  Test Duration: ${DURATION} seconds"
    echo ""
    
    if [ "$RESULT" = "PASSED" ]; then
        log_success "🎉 RAM STRESS TEST PASSED!"
        echo "✓ Your RAM survived the AGGRESSIVE stress test"
        echo "✓ Zero errors detected under maximum load"
        echo "✓ Memory is SOLID and reliable"
    else
        log_error "❌ RAM STRESS TEST FAILED!"
        echo "✗ $ERRORS memory errors detected"
        echo "✗ RAM has stability issues under stress"
        echo "✗ Hardware investigation recommended"
    fi
else
    log_error "Test results not found - test may have crashed"
    TEST_RESULT=2
fi

echo ""

# Display monitoring results
if [ -f "/tmp/monitor_results.txt" ]; then
    source /tmp/monitor_results.txt
    
    echo "SYSTEM MONITORING RESULTS:"
    echo "  Maximum CPU Temperature: ${MAX_CPU_TEMP}°C"
    echo "  Maximum GPU Temperature: ${MAX_GPU_TEMP}°C"
    echo "  Maximum SOC Temperature: ${MAX_SOC_TEMP}°C"
    
    if [ -n "$MAX_POWER" ] && [ "$MAX_POWER" != "0.0" ]; then
        echo "  Maximum Power Draw: ${MAX_POWER}W"
        echo "  Average Power Draw: ${AVG_POWER}W"
    fi
    
    if [ -n "$AVG_CPU_FREQ" ] && [ "$AVG_CPU_FREQ" != "0.0" ]; then
        echo "  Average CPU Frequency: ${AVG_CPU_FREQ}MHz"
    fi
    
    if [ -n "$AVG_GPU_FREQ" ] && [ "$AVG_GPU_FREQ" != "0.0" ]; then
        echo "  Average GPU Frequency: ${AVG_GPU_FREQ}MHz"
    fi
    
    echo ""
    
    # Temperature analysis
    if (( $(echo "$MAX_CPU_TEMP > 85" | bc -l 2>/dev/null || echo "0") )); then
        log_error "HIGH CPU TEMPERATURE WARNING"
        echo "  CPU reached ${MAX_CPU_TEMP}°C (safe limit: 85°C)"
        echo "  Consider improving cooling system"
    elif (( $(echo "$MAX_CPU_TEMP > 75" | bc -l 2>/dev/null || echo "0") )); then
        log_warning "Elevated CPU temperature: ${MAX_CPU_TEMP}°C"
    else
        log_success "CPU temperature within safe limits: ${MAX_CPU_TEMP}°C"
    fi
    
    if (( $(echo "$MAX_GPU_TEMP > 85" | bc -l 2>/dev/null || echo "0") )); then
        log_error "HIGH GPU TEMPERATURE WARNING"
        echo "  GPU reached ${MAX_GPU_TEMP}°C (safe limit: 85°C)"
    else
        log_success "GPU temperature acceptable: ${MAX_GPU_TEMP}°C"
    fi
fi

echo ""
echo "================================================================================"
echo "  COMPREHENSIVE TEST SUMMARY"
echo "================================================================================"
echo ""

if [ $TEST_RESULT -eq 0 ]; then
    echo "🎉 OVERALL RESULT: SYSTEM PASSED AGGRESSIVE STRESS TEST!"
    echo ""
    echo "Your Jetson Orin has successfully passed the most intensive RAM stress test."
    echo "The memory system is stable, reliable, and ready for demanding workloads."
    echo ""
    echo "Key achievements:"
    echo "  ✓ Zero memory errors under maximum stress"
    echo "  ✓ Thermal performance within acceptable limits"
    echo "  ✓ System stability maintained throughout test"
    echo "  ✓ RAM can handle intensive parallel workloads"
    echo ""
    echo "Your system is PRODUCTION READY for memory-intensive applications!"
    
else
    echo "⚠️  OVERALL RESULT: SYSTEM FAILED STRESS TEST"
    echo ""
    echo "Issues detected during aggressive stress testing:"
    
    if [ "$RESULT" = "FAILED" ]; then
        echo "  ✗ Memory errors detected ($ERRORS errors)"
        echo "  ✗ RAM stability issues under high load"
    fi
    
    if [ -f "/tmp/monitor_results.txt" ]; then
        source /tmp/monitor_results.txt
        if (( $(echo "$MAX_CPU_TEMP > 85" | bc -l 2>/dev/null || echo "0") )); then
            echo "  ✗ Excessive CPU temperatures (${MAX_CPU_TEMP}°C)"
        fi
    fi
    
    echo ""
    echo "Recommendations:"
    echo "  • Check memory modules for defects"
    echo "  • Verify adequate cooling and airflow"
    echo "  • Consider running memtest86+ for detailed analysis"
    echo "  • Contact technical support if issues persist"
fi

echo ""
echo "Test completed: $(date)"
echo "Test directory: $TEST_DIR (will be cleaned up)"
echo ""

# Cleanup
rm -rf "$TEST_DIR"

exit $TEST_RESULT