# Jetson Orin Test Suite

Comprehensive hardware testing suite for NVIDIA Jetson Orin, including professional-grade RAM testing, GPU testing, and CPU testing.

## Features

- **Comprehensive RAM Testing** - Industry-standard memory validation with 6+ professional test methods
- **GPU Testing** - GPU stress testing and validation
- **CPU Testing** - Multi-core CPU stress testing
- **Sequential Test Orchestration** - Run all tests in sequence with unified reporting

---

## RAM Testing

### Overview

Three RAM test options with increasing comprehensiveness:

1. **Quick Test** (`jetson_ram_test.sh`) - Basic validation, ~30 minutes
2. **Aggressive Test** (`ram/direct_ram_test.sh`) - Intensive stress test, ~1 hour
3. **⭐ Comprehensive Test** (`jetson_comprehensive_ram_test.sh`) - **RECOMMENDED for production** - Professional-grade validation with all industry-standard test methods, 1+ hours

### Comprehensive RAM Test (Recommended)

The comprehensive test includes **all professional-grade test methods**:

#### Test Methods Included:

1. **ECC Error Monitoring** - Detects correctable/uncorrectable memory errors
2. **Address Line Testing** - Finds stuck or shorted address lines
3. **Row Hammer Detection** - Tests for bit flip vulnerabilities
4. **Memory Controller Bandwidth Stress** - Stresses memory controller under maximum load
5. **JEDEC Standard Patterns** - MATS+ and March C- algorithms (industry standard)
6. **Walking Bit Patterns** - Detects stuck or weak individual bits

#### Usage:

```bash
# Interactive mode (will prompt for parameters)
./jetson_comprehensive_ram_test.sh

# Non-interactive mode
./jetson_comprehensive_ram_test.sh <ip> <user> <password> <duration_hours>

# Example: 2-hour comprehensive test
./jetson_comprehensive_ram_test.sh 192.168.55.69 orin mypassword 2
```

#### What It Tests:

- ✓ Address line failures (stuck/shorted lines)
- ✓ Data line failures (stuck bits)
- ✓ Row hammer vulnerabilities
- ✓ Memory controller errors
- ✓ Cell coupling faults
- ✓ Refresh failures
- ✓ ECC errors (if available)
- ✓ Bandwidth degradation

#### Results:

Pass criteria: **0 errors** across all test methods

```
✓ ECC Monitoring:          PASS      (CE: 0, UE: 0)
✓ Address Line Test:       PASS      (0 errors)
✓ Walking Bit Patterns:    PASS      (0 errors)
✓ JEDEC Patterns:          PASS      (0 errors)
✓ Memory Bandwidth:        PASS      (0 errors)
✓ Row Hammer Test:         PASS      (0 errors)

RESULT: PASSED - RAM is production ready
```

### Other RAM Tests

#### Basic RAM Test
```bash
./jetson_ram_test.sh <ip> <user> <password> <duration_hours>
```
- Tests 75% of available RAM
- Simple patterns (0x00, 0xFF, 0x55, 0xAA)
- Good for quick validation

#### Aggressive RAM Test (Direct on Jetson)
```bash
# Run directly on Jetson Orin
./ram/direct_ram_test.sh <duration_hours> <memory_percentage>

# Example: 1 hour test using 95% RAM
./ram/direct_ram_test.sh 1 95
```
- Tests up to 95% of available RAM
- Multiple stress patterns
- Multi-threaded stress testing
- More intensive than basic test

---

## Documentation

### RAM Testing

- **[RAM Test Methods](ram/RAM_TEST_METHODS.md)** - Detailed explanation of all test methods
  - ECC monitoring
  - Address line testing
  - Row hammer detection
  - Memory bandwidth stress
  - JEDEC patterns (MATS+, March C-)
  - Walking bit patterns
  - When to use each test
  - Understanding test results

---

## Test Recommendations

### For Development Systems
- Run **comprehensive test** once after initial setup
- Run **basic test** monthly for health checks
- Enable ECC monitoring if available

### For Production Deployment
- **REQUIRED:** Run **comprehensive test** before deployment
- Run monthly health checks
- Set up automated ECC monitoring with alerting
- Document all test results

### For Safety-Critical Applications
- Run **comprehensive test** quarterly minimum
- Use ECC RAM (mandatory)
- Zero tolerance for errors
- Full documentation required (ISO 26262, DO-178C compliance)

---

## Quick Start

### 1. Clone the repository
```bash
git clone <repository-url>
cd orin_test
```

### 2. Make scripts executable
```bash
chmod +x *.sh ram/*.sh ram/*.py
```

### 3. Run comprehensive RAM test (recommended)
```bash
./jetson_comprehensive_ram_test.sh
```

Follow the prompts to enter:
- Jetson Orin IP address
- SSH username
- SSH password
- Test duration (hours)

### 4. Review results
Results are saved to timestamped directories:
```
comprehensive_ram_test_YYYYMMDD_HHMMSS/
├── logs/
│   └── comprehensive_ram_test.log
└── reports/
    └── comprehensive_results.txt
```

---

## Requirements

- **Host machine:** Linux with `sshpass` installed
- **Jetson Orin:** SSH access, Python 3
- **Network:** SSH connectivity between host and Jetson

### Installing Dependencies

#### On host (Ubuntu/Debian):
```bash
sudo apt install sshpass bc
```

#### On Jetson Orin:
Python 3 is pre-installed, no additional dependencies required.

---

## File Structure

```
orin_test/
├── README.md                              # This file
├── jetson_utils.sh                        # Common utilities
├── jetson_ram_test.sh                     # Basic RAM test (remote)
├── jetson_comprehensive_ram_test.sh       # ⭐ Comprehensive RAM test (RECOMMENDED)
├── ram/
│   ├── comprehensive_ram_test.py          # Professional-grade test suite
│   ├── direct_ram_test.sh                 # Aggressive test (run on Jetson)
│   └── RAM_TEST_METHODS.md                # Detailed test method documentation
└── [other test scripts...]
```

---

## Comparison with Industry Tools

| Feature | Comprehensive Test | memtest86+ | Windows Memory Diagnostic |
|---------|-------------------|------------|---------------------------|
| ECC Monitoring | ✓ | ✓ | ✗ |
| Address Line Test | ✓ | ✓ | ✓ |
| Row Hammer Test | ✓ | ✗ | ✗ |
| Bandwidth Stress | ✓ | Limited | ✗ |
| JEDEC Patterns | ✓ | ✓ | ✓ |
| Walking Bits | ✓ | ✓ | ✓ |
| Jetson Integration | ✓ | ✗ | ✗ |

---

## FAQ

### Q: Which RAM test should I use?

**A:** Use the **comprehensive test** (`jetson_comprehensive_ram_test.sh`) for production validation. It includes all professional-grade test methods and provides industry-standard certification.

### Q: How long should I run the comprehensive test?

**A:** Minimum 1 hour for initial validation. For production certification, run 2-4 hours. For critical applications, consider 8+ hour burn-in tests.

### Q: What if I get correctable ECC errors (CE)?

**A:** A few CEs may be acceptable and indicate ECC is working. However, monitor trends:
- Increasing CEs over time = degrading memory, plan replacement
- High CE count (>100) = weak memory, consider replacement
- Any uncorrectable errors (UE) = **immediate replacement required**

### Q: Can I run tests while the system is in use?

**A:** Not recommended. The comprehensive test allocates 75% of available RAM and will impact system performance. Run during maintenance windows.

### Q: How does this compare to memtest86+?

**A:** Comprehensive test provides similar coverage with advantages:
- ✓ Direct Jetson integration
- ✓ Modern row hammer testing
- ✓ Detailed bandwidth metrics
- ✗ Runs in userspace (not bare metal)

For absolute validation, consider running both.

---

## Contributing

Contributions welcome! Please ensure:
- Code follows existing patterns
- Documentation is updated
- Tests are validated on real hardware

---

## License

[Specify license here]

---

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Provide test logs and system information
- Include Jetson model and configuration

---

## Changelog

### Latest
- Added comprehensive RAM test with 6 professional test methods
- Added ECC error monitoring
- Added row hammer detection
- Added JEDEC standard patterns (MATS+, March C-)
- Added address line testing
- Added memory controller bandwidth stress testing
- Added detailed documentation

---

**⭐ RECOMMENDED:** Start with `./jetson_comprehensive_ram_test.sh` for production-grade RAM validation