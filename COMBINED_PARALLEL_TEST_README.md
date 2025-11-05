# Jetson Orin Combined Parallel Stress Test

## Overview

The Combined Parallel Stress Test runs **all four stress tests simultaneously** to validate system performance under maximum combined load conditions. This simulates real-world scenarios where CPU, GPU, RAM, and Storage are all under heavy stress at the same time.

## What It Does

This test launches all four stress tests in parallel:
- **CPU Test**: Multi-core stress, thermal monitoring
- **GPU Test**: CUDA, VPU, and Graphics workloads
- **RAM Test**: Memory integrity and pattern validation
- **Storage Test**: I/O performance and health checks

## Why Use Parallel Testing?

- **Real-world Simulation**: Most production workloads use multiple system components simultaneously
- **Thermal Validation**: Tests thermal management under maximum load
- **Interaction Testing**: Identifies issues that only appear when components compete for resources
- **System Stability**: Validates system stability under extreme conditions
- **Comprehensive Assessment**: Provides a complete picture of system capabilities

## Usage

```bash
./jetson_combined_parallel_test.sh [ip] [user] [password] [duration_hours]
```

### Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| ip | Jetson Orin IP address | 192.168.55.69 | 10.0.0.100 |
| user | SSH username | orin | nvidia |
| password | SSH password | (prompted) | mypass |
| duration_hours | Test duration in hours | 2 | 1, 0.5, 4 |

### Examples

```bash
# 2-hour test with defaults
./jetson_combined_parallel_test.sh

# 1-hour test with custom parameters
./jetson_combined_parallel_test.sh 192.168.55.69 orin mypass 1

# 30-minute quick test
./jetson_combined_parallel_test.sh 192.168.55.69 orin mypass 0.5

# 4-hour extended test
./jetson_combined_parallel_test.sh 192.168.55.69 orin mypass 4
```

## Output Structure

The test creates a comprehensive directory structure:

```
combined_parallel_test_YYYYMMDD_HHMMSS/
├── cpu_test/           # CPU test results
│   ├── logs/
│   ├── reports/
│   └── performance_data/
├── gpu_test/           # GPU test results
│   ├── logs/
│   ├── reports/
│   └── monitoring/
├── ram_test/           # RAM test results
│   ├── logs/
│   └── reports/
├── storage_test/       # Storage test results
│   ├── logs/
│   └── reports/
├── monitoring/         # System-wide monitoring during parallel execution
│   └── system_monitor.log
├── logs/               # Orchestration logs
│   ├── baseline.log
│   ├── final_state.log
│   ├── cpu_test.log
│   ├── gpu_test.log
│   ├── ram_test.log
│   └── storage_test.log
└── reports/            # Combined reports
    └── COMBINED_TEST_REPORT.txt
```

## Key Reports

### Combined Report
- **Location**: `reports/COMBINED_TEST_REPORT.txt`
- **Contains**: Overall system assessment, pass/fail status for all tests, recommendations

### Individual Test Reports
- **CPU**: `cpu_test/reports/CPU_PERFORMANCE_REPORT.txt`
- **GPU**: `gpu_test/reports/GPU_TEST_REPORT.txt`
- **RAM**: `ram_test/reports/ram_test_summary.txt`
- **Storage**: `storage_test/reports/DISK_PERFORMANCE_REPORT.txt`

### System Monitoring
- **Location**: `monitoring/system_monitor.log`
- **Contains**: Real-time system metrics during parallel execution (CPU load, memory usage, temperature, GPU utilization, I/O stats)
- **Update Interval**: Every 30 seconds

## Test Flow

1. **Phase 0: Baseline Capture**
   - Captures system state before tests begin
   - Records CPU info, memory, GPU status, thermal baseline, storage info

2. **Phase 1: Launch Parallel Tests**
   - Launches all 4 tests as background processes
   - 2-second delay between launches to avoid initialization conflicts
   - Records process IDs for monitoring

3. **Phase 2: Real-time Monitoring**
   - Monitors all tests in parallel
   - Captures system metrics every 30 seconds
   - Provides status updates every 60 seconds
   - Tracks: CPU load, memory usage, temperature, GPU utilization, storage I/O

4. **Phase 3: Result Collection**
   - Waits for all tests to complete
   - Captures exit codes from each test
   - Records final system state

5. **Phase 4: Report Generation**
   - Aggregates results from all tests
   - Generates combined assessment
   - Provides overall verdict and recommendations

## Understanding Results

### Pass/Fail Criteria

- **100% Pass Rate**: All tests passed - System is excellent
- **75-99% Pass Rate**: Acceptable with concerns - Review failed components
- **Below 75%**: System issues detected - Immediate attention required

### Overall Verdicts

#### ✓ EXCELLENT (100% pass rate)
System demonstrates excellent stability and performance under maximum combined stress. Suitable for demanding production workloads.

#### ⚠ ACCEPTABLE WITH CONCERNS (75-99% pass rate)
Most components perform well, but some issues detected. Review individual test reports and consider improvements.

#### ✗ SYSTEM ISSUES DETECTED (below 75% pass rate)
Multiple components failed under stress. System requires immediate attention before production use.

## Interpreting Monitoring Data

### Temperature Monitoring
- **Normal**: Below 80°C
- **Elevated**: 80-90°C (monitor closely, consider improved cooling)
- **High**: Above 90°C (warning - check cooling system)

### CPU Load Average
- Load average should stabilize during test
- Spike at start is normal
- Continuous increase may indicate thermal throttling

### Memory Usage
- Memory usage should be high but stable
- Swap usage indicates memory pressure
- OOM errors indicate insufficient memory

### GPU Utilization
- Should show high utilization during test
- Low utilization may indicate bottlenecks
- Temperature should remain stable

## Troubleshooting

### Test Failed to Start
- Check SSH connectivity: `ssh user@ip`
- Verify credentials are correct
- Ensure Jetson device is powered on and accessible

### Individual Test Failures
1. Review the specific test log in `logs/<test>_test.log`
2. Check the individual test report for details
3. Run the failing test individually for more information
4. Review system logs: `dmesg`, `/var/log/syslog`

### All Tests Failed
- Check system baseline in `logs/baseline.log`
- Review final state in `logs/final_state.log`
- Check for hardware errors in system logs
- Verify adequate cooling
- Check power supply capacity

### High Temperatures
- Ensure adequate cooling and airflow
- Check thermal paste application
- Consider adding heatsinks or fans
- Reduce ambient temperature
- Check power management settings

### Performance Below Expected
- Review thermal throttling in monitoring log
- Check for background processes consuming resources
- Verify power mode settings (MAXN mode for best performance)
- Check for insufficient cooling
- Review individual test reports for specific bottlenecks

## Best Practices

### Before Running Tests
1. Ensure Jetson is in MAXN power mode: `sudo nvpmodel -m 0`
2. Verify adequate cooling is in place
3. Close unnecessary applications
4. Check available disk space (at least 20GB recommended)
5. Ensure stable power supply

### During Tests
1. Monitor the status updates every minute
2. Watch for temperature warnings
3. Do not interrupt tests unless necessary
4. Avoid running other intensive tasks

### After Tests
1. Review the combined report first
2. Check individual test reports for failed components
3. Review monitoring logs for thermal issues
4. Compare results with baseline if running periodic tests
5. Document any issues for tracking

### Regular Testing Schedule
- **Monthly**: Run combined parallel test for production systems
- **Quarterly**: Run after firmware/driver updates
- **As Needed**: After hardware changes or environmental changes

## System Requirements

### Host Machine
- `sshpass` installed
- `bc` installed (for duration calculations)
- SSH access to Jetson Orin
- Network connectivity to Jetson device

### Jetson Orin
- All individual test dependencies installed
- Sufficient disk space (at least 20GB free)
- SSH server running
- Recommended: MAXN power mode for accurate testing

## Notes

- **Test Duration**: Recommended minimum 1 hour, ideal 2-4 hours for comprehensive testing
- **Resource Usage**: All system resources will be heavily utilized during testing
- **Network Usage**: Minimal, only for SSH control and result transfer
- **Disk Usage**: Up to 10-15GB during testing (cleaned up afterwards)
- **System Availability**: System will be under heavy load and should not be used for other tasks during testing

## Related Tests

- **CPU Test**: `jetson_cpu_test.sh` - Isolated CPU stress testing
- **GPU Test**: `jetson_gpu_test.sh` - Isolated GPU stress testing
- **RAM Test**: `jetson_ram_test.sh` - Isolated RAM stress testing
- **Storage Test**: `jetson_storage_test.sh` - Isolated storage stress testing
- **Sequential Test**: `jetson_sequential_test.sh` - Run all tests one after another

## Support

For issues or questions:
1. Review individual test README files
2. Check system logs and error messages
3. Refer to NVIDIA Jetson documentation
4. Contact system administrator or NVIDIA support

## Version History

- **v1.0** (2025): Initial release
  - Parallel execution of all 4 tests
  - Real-time system monitoring
  - Combined report generation
  - Comprehensive assessment and recommendations
