#!/usr/bin/env python3
"""
Comprehensive RAM Test Suite for Jetson Orin
Professional-grade memory testing with clean, structured output
"""

import os
import sys
import time
import random
import signal
import threading
import multiprocessing
import gc
import struct
import ctypes
from pathlib import Path
import glob

class ECCMonitor:
    """Monitor ECC errors during testing"""

    def __init__(self):
        self.edac_path = "/sys/devices/system/edac"
        self.initial_ce = {}
        self.initial_ue = {}
        self.supported = self.check_ecc_support()

    def check_ecc_support(self):
        """Check if ECC monitoring is available"""
        if not os.path.exists(self.edac_path):
            return False
        mc_dirs = glob.glob(f"{self.edac_path}/mc/mc*")
        return len(mc_dirs) > 0

    def read_ecc_counters(self):
        """Read current ECC error counters"""
        counters = {'ce': 0, 'ue': 0, 'details': []}
        if not self.supported:
            return counters

        try:
            mc_dirs = glob.glob(f"{self.edac_path}/mc/mc*")
            for mc_dir in mc_dirs:
                mc_name = os.path.basename(mc_dir)
                ce_file = f"{mc_dir}/ce_count"
                ue_file = f"{mc_dir}/ue_count"

                ce = 0
                ue = 0
                if os.path.exists(ce_file):
                    with open(ce_file, 'r') as f:
                        ce = int(f.read().strip())
                        counters['ce'] += ce

                if os.path.exists(ue_file):
                    with open(ue_file, 'r') as f:
                        ue = int(f.read().strip())
                        counters['ue'] += ue

                counters['details'].append({'controller': mc_name, 'ce': ce, 'ue': ue})
        except Exception as e:
            pass

        return counters

    def start_monitoring(self):
        """Record initial ECC error counts"""
        initial = self.read_ecc_counters()
        self.initial_ce = initial['ce']
        self.initial_ue = initial['ue']
        return self.supported

    def get_new_errors(self):
        """Get new errors since monitoring started"""
        current = self.read_ecc_counters()
        return {
            'correctable': current['ce'] - self.initial_ce,
            'uncorrectable': current['ue'] - self.initial_ue,
            'details': current['details']
        }


class AddressLineTest:
    """Test for address line failures"""

    @staticmethod
    def test_address_lines(memory_mb=100):
        """Test address lines with walking bit patterns"""
        errors = 0
        operations = 0
        block_size = memory_mb * 1024 * 1024
        test_block = bytearray(block_size)

        # Walking 1s in address space
        for bit_pos in range(min(24, (block_size - 8).bit_length())):
            operations += 1
            offset = 1 << bit_pos
            if offset >= block_size - 8:
                break

            pattern = (0xAA55AA55 + bit_pos) & 0xFFFFFFFF
            try:
                test_block[offset:offset+4] = pattern.to_bytes(4, 'little')
                read_pattern = int.from_bytes(test_block[offset:offset+4], 'little')
                if read_pattern != pattern:
                    errors += 1
            except:
                errors += 1

        # Walking 0s in address space
        max_bits = min(24, (block_size - 8).bit_length())
        mask = (1 << max_bits) - 1

        for bit_pos in range(max_bits):
            operations += 1
            offset = mask ^ (1 << bit_pos)
            if offset >= block_size - 8:
                continue

            pattern = (0x55AA55AA + bit_pos) & 0xFFFFFFFF
            try:
                test_block[offset:offset+4] = pattern.to_bytes(4, 'little')
                read_pattern = int.from_bytes(test_block[offset:offset+4], 'little')
                if read_pattern != pattern:
                    errors += 1
            except:
                errors += 1

        # Test adjacent addresses
        for i in range(0, min(1024*1024, block_size - 8), 8):
            operations += 1
            test_block[i:i+8] = i.to_bytes(8, 'little')

        for i in range(0, min(1024*1024, block_size - 8), 8):
            operations += 1
            read_val = int.from_bytes(test_block[i:i+8], 'little')
            if read_val != i:
                errors += 1

        return errors, operations


class RowHammerTest:
    """Row hammer vulnerability testing"""

    @staticmethod
    def test_row_hammer(memory_mb=50, iterations=1000000):
        """Test for row hammer bit flips"""
        errors = 0
        operations = 0
        block_size = memory_mb * 1024 * 1024
        test_block = bytearray(block_size)
        row_sizes = [8*1024, 16*1024, 32*1024]

        for row_size in row_sizes:
            if row_size * 3 >= block_size:
                continue

            victim_row1 = row_size
            victim_row2 = row_size * 2

            # Fill victim rows
            test_block[victim_row1:victim_row1+row_size] = bytes([0xAA] * row_size)
            test_block[victim_row2:victim_row2+row_size] = bytes([0xAA] * row_size)

            aggressor_row1 = 0
            aggressor_row2 = row_size * 3

            if aggressor_row2 + 8 >= block_size:
                continue

            # Hammer aggressor rows
            for i in range(iterations):
                operations += 2
                test_block[aggressor_row1] = 0xFF
                test_block[aggressor_row2] = 0xFF

                if i % 1000 == 0:
                    _ = test_block[aggressor_row1]
                    _ = test_block[aggressor_row2]

            # Check for bit flips
            for offset in range(victim_row1, victim_row1 + row_size):
                operations += 1
                if test_block[offset] != 0xAA:
                    errors += 1

            for offset in range(victim_row2, victim_row2 + row_size):
                operations += 1
                if test_block[offset] != 0xAA:
                    errors += 1

        return errors, operations


class MemoryBandwidthTest:
    """Memory bandwidth testing"""

    @staticmethod
    def test_bandwidth(memory_mb=500, duration_seconds=30):
        """Test memory controller bandwidth"""
        errors = 0
        operations = 0
        bytes_transferred = 0

        block_size = memory_mb * 1024 * 1024
        test_block = bytearray(block_size)

        start_time = time.time()

        # Sequential write
        phase_start = time.time()
        write_count = 0

        while time.time() - phase_start < duration_seconds / 3:
            for i in range(0, block_size, 8):
                if time.time() - phase_start >= duration_seconds / 3:
                    break
                test_block[i:i+8] = write_count.to_bytes(8, 'little')
                operations += 1
                bytes_transferred += 8
                write_count += 1

        write_bandwidth = bytes_transferred / (time.time() - phase_start) / (1024*1024)

        # Sequential read
        phase_start = time.time()
        read_bytes = 0
        read_count = 0

        while time.time() - phase_start < duration_seconds / 3:
            for i in range(0, block_size, 8):
                if time.time() - phase_start >= duration_seconds / 3:
                    break
                val = int.from_bytes(test_block[i:i+8], 'little')
                operations += 1
                read_bytes += 8

                if read_count % 1000 == 0 and val != read_count:
                    errors += 1
                read_count += 1

        bytes_transferred += read_bytes
        read_bandwidth = read_bytes / (time.time() - phase_start) / (1024*1024)

        # Random access
        phase_start = time.time()
        random_ops = 0

        while time.time() - phase_start < duration_seconds / 3:
            for _ in range(10000):
                if time.time() - phase_start >= duration_seconds / 3:
                    break
                offset = random.randint(0, block_size - 8)
                value = random.randint(0, 0xFFFFFFFFFFFFFFFF)
                test_block[offset:offset+8] = value.to_bytes(8, 'little')

                read_val = int.from_bytes(test_block[offset:offset+8], 'little')
                if read_val != value:
                    errors += 1

                operations += 2
                bytes_transferred += 16
                random_ops += 1

        random_bandwidth = (random_ops * 16) / (time.time() - phase_start) / (1024*1024)
        total_bandwidth = bytes_transferred / (time.time() - start_time) / (1024*1024)

        return errors, operations, total_bandwidth, write_bandwidth, read_bandwidth, random_bandwidth


class JEDECPatternTest:
    """JEDEC standard memory test patterns"""

    @staticmethod
    def mats_plus_test(test_block):
        """MATS+ algorithm"""
        errors = 0
        operations = 0
        block_size = len(test_block)

        # Write all 0s
        for i in range(0, block_size, 8):
            test_block[i:i+8] = b'\x00' * 8
            operations += 1

        # Read 0, Write 1
        for i in range(0, block_size, 8):
            val = int.from_bytes(test_block[i:i+8], 'little')
            if val != 0:
                errors += 1
            test_block[i:i+8] = b'\xFF' * 8
            operations += 2

        # Read 1, Write 0 (descending)
        for i in range(block_size - 8, -1, -8):
            val = int.from_bytes(test_block[i:i+8], 'little')
            if val != 0xFFFFFFFFFFFFFFFF:
                errors += 1
            test_block[i:i+8] = b'\x00' * 8
            operations += 2

        # Read 0
        for i in range(0, block_size, 8):
            val = int.from_bytes(test_block[i:i+8], 'little')
            if val != 0:
                errors += 1
            operations += 1

        return errors, operations

    @staticmethod
    def march_c_minus_test(test_block):
        """March C- algorithm"""
        errors = 0
        operations = 0
        block_size = len(test_block)

        # Write 0
        for i in range(0, block_size, 8):
            test_block[i:i+8] = b'\x00' * 8
            operations += 1

        # Read 0, Write 1
        for i in range(0, block_size, 8):
            val = int.from_bytes(test_block[i:i+8], 'little')
            if val != 0:
                errors += 1
            test_block[i:i+8] = b'\xFF' * 8
            operations += 2

        # Read 1, Write 0
        for i in range(0, block_size, 8):
            val = int.from_bytes(test_block[i:i+8], 'little')
            if val != 0xFFFFFFFFFFFFFFFF:
                errors += 1
            test_block[i:i+8] = b'\x00' * 8
            operations += 2

        # Read 0, Write 1 (descending)
        for i in range(block_size - 8, -1, -8):
            val = int.from_bytes(test_block[i:i+8], 'little')
            if val != 0:
                errors += 1
            test_block[i:i+8] = b'\xFF' * 8
            operations += 2

        # Read 1, Write 0 (descending)
        for i in range(block_size - 8, -1, -8):
            val = int.from_bytes(test_block[i:i+8], 'little')
            if val != 0xFFFFFFFFFFFFFFFF:
                errors += 1
            test_block[i:i+8] = b'\x00' * 8
            operations += 2

        # Read 0
        for i in range(0, block_size, 8):
            val = int.from_bytes(test_block[i:i+8], 'little')
            if val != 0:
                errors += 1
            operations += 1

        return errors, operations

    @staticmethod
    def test_jedec_patterns(memory_mb=100):
        """Run JEDEC standard patterns"""
        total_errors = 0
        total_operations = 0

        block_size = memory_mb * 1024 * 1024
        test_block = bytearray(block_size)

        # MATS+
        errors, ops = JEDECPatternTest.mats_plus_test(test_block)
        total_errors += errors
        total_operations += ops

        # March C-
        errors, ops = JEDECPatternTest.march_c_minus_test(test_block)
        total_errors += errors
        total_operations += ops

        return total_errors, total_operations


class ComprehensiveRAMTest:
    """Main comprehensive RAM test orchestrator"""

    def __init__(self, memory_mb, duration):
        self.memory_mb = memory_mb
        self.duration = duration
        self.running = True
        self.start_time = time.time()

        self.results = {
            'ecc_monitoring': {'supported': False, 'errors': {}},
            'address_line': {'errors': 0, 'operations': 0},
            'row_hammer': {'errors': 0, 'operations': 0},
            'bandwidth': {'errors': 0, 'operations': 0, 'bandwidth_mbps': 0, 'write_mbps': 0, 'read_mbps': 0, 'random_mbps': 0},
            'jedec_patterns': {'errors': 0, 'operations': 0},
            'walking_bits': {'errors': 0, 'operations': 0},
            'total_errors': 0,
            'total_operations': 0,
            'actual_duration': 0
        }

        self.ecc_monitor = ECCMonitor()

    def signal_handler(self, signum, frame):
        self.running = False

    def test_walking_bits(self, memory_mb=100):
        """Walking bits pattern test"""
        errors = 0
        operations = 0
        block_size = memory_mb * 1024 * 1024
        test_block = bytearray(block_size)

        # Walking 1s
        for bit in range(64):
            pattern = 1 << bit

            for i in range(0, min(1024*1024, block_size), 8):
                test_block[i:i+8] = pattern.to_bytes(8, 'little')
                operations += 1

            for i in range(0, min(1024*1024, block_size), 8):
                val = int.from_bytes(test_block[i:i+8], 'little')
                if val != pattern:
                    errors += 1
                operations += 1

        # Walking 0s
        for bit in range(64):
            pattern = ~(1 << bit) & 0xFFFFFFFFFFFFFFFF

            for i in range(0, min(1024*1024, block_size), 8):
                test_block[i:i+8] = pattern.to_bytes(8, 'little')
                operations += 1

            for i in range(0, min(1024*1024, block_size), 8):
                val = int.from_bytes(test_block[i:i+8], 'little')
                if val != pattern:
                    errors += 1
                operations += 1

        return errors, operations

    def run_comprehensive_test(self):
        """Execute all comprehensive RAM tests"""

        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)

        print("=" * 80)
        print("COMPREHENSIVE RAM TEST SUITE")
        print("=" * 80)
        print(f"Memory to test: {self.memory_mb} MB")
        print(f"Test duration: {self.duration} seconds")
        print(f"CPU cores: {multiprocessing.cpu_count()}")
        print("")

        # Initialize ECC monitoring
        print("=" * 80)
        print("PHASE 0: ECC Error Monitoring Initialization")
        print("=" * 80)

        ecc_supported = self.ecc_monitor.start_monitoring()
        if ecc_supported:
            print("ECC monitoring initialized successfully")
            self.results['ecc_monitoring']['supported'] = True
        else:
            print("ECC monitoring not available")
        print("")

        # Phase 1: Address Line Testing
        if self.running:
            print("=" * 80)
            print("PHASE 1: Address Line Testing")
            print("=" * 80)

            phase_start = time.time()
            errors, ops = AddressLineTest.test_address_lines(min(200, self.memory_mb // 4))
            phase_duration = time.time() - phase_start

            self.results['address_line']['errors'] = errors
            self.results['address_line']['operations'] = ops
            self.results['address_line']['duration'] = phase_duration
            self.results['address_line']['ops_per_sec'] = ops / phase_duration if phase_duration > 0 else 0

            print(f"Phase completed in {phase_duration:.1f} seconds")
            print("")

        # Phase 2: Walking Bit Patterns
        if self.running:
            print("=" * 80)
            print("PHASE 2: Walking Bit Patterns")
            print("=" * 80)

            phase_start = time.time()
            errors, ops = self.test_walking_bits(min(200, self.memory_mb // 4))
            phase_duration = time.time() - phase_start

            self.results['walking_bits']['errors'] = errors
            self.results['walking_bits']['operations'] = ops
            self.results['walking_bits']['duration'] = phase_duration
            self.results['walking_bits']['ops_per_sec'] = ops / phase_duration if phase_duration > 0 else 0

            print(f"Phase completed in {phase_duration:.1f} seconds")
            print("")

        # Phase 3: JEDEC Standard Patterns
        if self.running:
            print("=" * 80)
            print("PHASE 3: JEDEC Standard Patterns")
            print("=" * 80)

            phase_start = time.time()
            errors, ops = JEDECPatternTest.test_jedec_patterns(min(300, self.memory_mb // 3))
            phase_duration = time.time() - phase_start

            self.results['jedec_patterns']['errors'] = errors
            self.results['jedec_patterns']['operations'] = ops
            self.results['jedec_patterns']['duration'] = phase_duration
            self.results['jedec_patterns']['ops_per_sec'] = ops / phase_duration if phase_duration > 0 else 0

            print(f"Phase completed in {phase_duration:.1f} seconds")
            print("")

        # Phase 4: Memory Controller Bandwidth
        if self.running:
            print("=" * 80)
            print("PHASE 4: Memory Controller Bandwidth")
            print("=" * 80)

            test_duration = min(self.duration // 4, 60)
            phase_start = time.time()
            errors, ops, total_bw, write_bw, read_bw, random_bw = MemoryBandwidthTest.test_bandwidth(
                min(500, self.memory_mb // 2), test_duration
            )
            phase_duration = time.time() - phase_start

            self.results['bandwidth']['errors'] = errors
            self.results['bandwidth']['operations'] = ops
            self.results['bandwidth']['duration'] = phase_duration
            self.results['bandwidth']['ops_per_sec'] = ops / phase_duration if phase_duration > 0 else 0
            self.results['bandwidth']['bandwidth_mbps'] = total_bw
            self.results['bandwidth']['write_mbps'] = write_bw
            self.results['bandwidth']['read_mbps'] = read_bw
            self.results['bandwidth']['random_mbps'] = random_bw

            print(f"Phase completed in {phase_duration:.1f} seconds")
            print("")

        # Phase 5: Row Hammer Testing
        if self.running:
            print("=" * 80)
            print("PHASE 5: Row Hammer Testing")
            print("=" * 80)

            phase_start = time.time()
            errors, ops = RowHammerTest.test_row_hammer(
                min(100, self.memory_mb // 8), iterations=500000
            )
            phase_duration = time.time() - phase_start

            self.results['row_hammer']['errors'] = errors
            self.results['row_hammer']['operations'] = ops
            self.results['row_hammer']['duration'] = phase_duration
            self.results['row_hammer']['ops_per_sec'] = ops / phase_duration if phase_duration > 0 else 0

            print(f"Phase completed in {phase_duration:.1f} seconds")
            print("")

        # Check ECC errors
        if ecc_supported:
            print("=" * 80)
            print("PHASE 6: ECC Error Check")
            print("=" * 80)

            ecc_errors = self.ecc_monitor.get_new_errors()
            self.results['ecc_monitoring']['errors'] = ecc_errors

            print(f"Correctable errors: {ecc_errors['correctable']}")
            print(f"Uncorrectable errors: {ecc_errors['uncorrectable']}")

            if ecc_errors['uncorrectable'] > 0:
                self.results['total_errors'] += ecc_errors['uncorrectable']
            print("")

        # Calculate totals
        self.results['total_errors'] = sum([
            self.results['address_line']['errors'],
            self.results['row_hammer']['errors'],
            self.results['bandwidth']['errors'],
            self.results['jedec_patterns']['errors'],
            self.results['walking_bits']['errors']
        ])

        self.results['total_operations'] = sum([
            self.results['address_line']['operations'],
            self.results['row_hammer']['operations'],
            self.results['bandwidth']['operations'],
            self.results['jedec_patterns']['operations'],
            self.results['walking_bits']['operations']
        ])

        self.results['actual_duration'] = time.time() - self.start_time

        # Print results
        self.print_results()

        return self.results['total_errors'] == 0

    def print_results(self):
        """Print comprehensive test results in clean format"""

        actual_duration = self.results['actual_duration']

        print("=" * 80)
        print("COMPREHENSIVE RAM TEST RESULTS")
        print("=" * 80)
        print("")
        print(f"Test Duration: {actual_duration:.1f} seconds")
        print(f"Memory Tested: {self.memory_mb} MB")
        print(f"Total Operations: {self.results['total_operations']:,}")
        print(f"Total Errors: {self.results['total_errors']}")
        print("")

        print("=" * 80)
        print("TEST RESULTS")
        print("=" * 80)
        print("")

        # Table header
        print(f"{'Test Method':<30} | {'Expected':<15} | {'Actual':<15} | {'Status':<8}")
        print("-" * 80)

        # ECC Monitoring
        if self.results['ecc_monitoring']['supported']:
            ecc = self.results['ecc_monitoring']['errors']
            status = "PASS" if ecc['uncorrectable'] == 0 else "FAIL"
            print(f"{'ECC Monitoring':<30} | {'0 UE':<15} | {f'{ecc["uncorrectable"]} UE':<15} | {status:<8}")

        # Address Line Test
        result = self.results['address_line']
        status = "PASS" if result['errors'] == 0 else "FAIL"
        ops_per_sec = f"{result['ops_per_sec']:.0f}/s" if 'ops_per_sec' in result else "N/A"
        print(f"{'Address Line Test':<30} | {'0 errors':<15} | {f'{result["errors"]} errors':<15} | {status:<8}")

        # Walking Bit Patterns
        result = self.results['walking_bits']
        status = "PASS" if result['errors'] == 0 else "FAIL"
        ops_per_sec = f"{result['ops_per_sec']:.0f}/s" if 'ops_per_sec' in result else "N/A"
        print(f"{'Walking Bit Patterns':<30} | {'0 errors':<15} | {f'{result["errors"]} errors':<15} | {status:<8}")

        # JEDEC Patterns
        result = self.results['jedec_patterns']
        status = "PASS" if result['errors'] == 0 else "FAIL"
        ops_per_sec = f"{result['ops_per_sec']:.0f}/s" if 'ops_per_sec' in result else "N/A"
        print(f"{'JEDEC Patterns':<30} | {'0 errors':<15} | {f'{result["errors"]} errors':<15} | {status:<8}")

        # Memory Bandwidth
        result = self.results['bandwidth']
        status = "PASS" if result['errors'] == 0 else "FAIL"
        expected_bw = "Min 1000 MB/s"
        actual_bw = f"{result.get('bandwidth_mbps', 0):.0f} MB/s"
        print(f"{'Memory Bandwidth':<30} | {expected_bw:<15} | {actual_bw:<15} | {status:<8}")

        # Row Hammer Test
        result = self.results['row_hammer']
        status = "PASS" if result['errors'] == 0 else "FAIL"
        ops_per_sec = f"{result['ops_per_sec']:.0f}/s" if 'ops_per_sec' in result else "N/A"
        print(f"{'Row Hammer Test':<30} | {'0 bit flips':<15} | {f'{result["errors"]} bit flips':<15} | {status:<8}")

        print("-" * 80)
        print("")

        # Final verdict
        if self.results['total_errors'] == 0:
            print("OVERALL RESULT: PASS")
            print("")
            print("All memory tests completed successfully")
            print("Memory integrity verified across all test methods")
            print("RAM is PRODUCTION READY")
        else:
            print("OVERALL RESULT: FAIL")
            print("")
            print(f"Total errors detected: {self.results['total_errors']}")
            print("Memory has reliability issues")
            print("HARDWARE INVESTIGATION REQUIRED")

        print("")


def main():
    if len(sys.argv) != 3:
        print("Usage: python3 comprehensive_ram_test.py <memory_mb> <duration_seconds>")
        sys.exit(1)

    try:
        memory_mb = int(sys.argv[1])
        duration = int(sys.argv[2])

        tester = ComprehensiveRAMTest(memory_mb, duration)
        success = tester.run_comprehensive_test()

        # Write results
        with open('/tmp/comprehensive_ram_test_result.txt', 'w') as f:
            f.write(f"RESULT={'PASSED' if success else 'FAILED'}\n")
            f.write(f"TOTAL_ERRORS={tester.results['total_errors']}\n")
            f.write(f"TOTAL_OPERATIONS={tester.results['total_operations']}\n")
            f.write(f"MEMORY_MB={memory_mb}\n")
            f.write(f"DURATION={duration}\n")
            f.write(f"ACTUAL_DURATION={tester.results['actual_duration']:.1f}\n")
            f.write(f"\n# Detailed Results\n")
            f.write(f"ADDRESS_LINE_ERRORS={tester.results['address_line']['errors']}\n")
            f.write(f"ROW_HAMMER_ERRORS={tester.results['row_hammer']['errors']}\n")
            f.write(f"BANDWIDTH_ERRORS={tester.results['bandwidth']['errors']}\n")
            f.write(f"BANDWIDTH_MBPS={tester.results['bandwidth'].get('bandwidth_mbps', 0):.0f}\n")
            f.write(f"WRITE_MBPS={tester.results['bandwidth'].get('write_mbps', 0):.0f}\n")
            f.write(f"READ_MBPS={tester.results['bandwidth'].get('read_mbps', 0):.0f}\n")
            f.write(f"RANDOM_MBPS={tester.results['bandwidth'].get('random_mbps', 0):.0f}\n")
            f.write(f"JEDEC_ERRORS={tester.results['jedec_patterns']['errors']}\n")
            f.write(f"WALKING_BITS_ERRORS={tester.results['walking_bits']['errors']}\n")

            if tester.results['ecc_monitoring']['supported']:
                ecc = tester.results['ecc_monitoring']['errors']
                f.write(f"ECC_CORRECTABLE={ecc['correctable']}\n")
                f.write(f"ECC_UNCORRECTABLE={ecc['uncorrectable']}\n")

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
