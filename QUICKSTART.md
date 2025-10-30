# Jetson Orin AGX Test Suite - Quick Start Guide

## 🚀 Quick Start

### Option 1: Interactive Orchestrator (Recommended)

```bash
./jetson_orchestrator.sh 192.168.55.69 orin <password>
```

Select test mode and duration from interactive menus!

### Option 2: Direct Commands

```bash
# Individual component tests
./jetson_cpu_test.sh 192.168.55.69 orin <password> 1
./jetson_gpu_test.sh 192.168.55.69 orin <password> 1
./jetson_ram_test.sh 192.168.55.69 orin <password> 1
./jetson_storage_test.sh 192.168.55.69 orin <password> 1

# Combined tests
./jetson_combined_sequential.sh 192.168.55.69 orin <password> 1  # Sequential (4 hours)
./jetson_combined_parallel.sh 192.168.55.69 orin <password> 1    # Parallel (1 hour)
```

---

## 📋 Available Test Scripts

### **Individual Component Tests**

| Script | Tests | Duration |
|--------|-------|----------|
| `jetson_cpu_test.sh` | CPU cores, cache, multi-threading | Per parameter |
| `jetson_gpu_test.sh` | GPU (CUDA + VPU + Graphics) | Per parameter |
| `jetson_ram_test.sh` | Memory integrity, patterns | Per parameter |
| `jetson_storage_test.sh` | Disk I/O, health, performance | Per parameter |

### **Combined Tests**

| Script | Tests | Duration |
|--------|-------|----------|
| `jetson_combined_sequential.sh` | CPU → GPU → RAM → Storage (in order) | 4× parameter |
| `jetson_combined_parallel.sh` | All components simultaneously | Per parameter |

### **Orchestrator**

| Script | Purpose |
|--------|---------|
| `jetson_orchestrator.sh` | Interactive menu to select test mode and duration |

---

## 🎯 Test Modes Explained

### 1. CPU Test (`jetson_cpu_test.sh`)
- Single-core performance tests
- Multi-core parallel stress
- Memory/cache torture
- **What it catches:** CPU defects, thermal issues, cache errors

### 2. GPU Test (`jetson_gpu_test.sh`)
- CUDA compute stress
- VPU video encoding (4K)
- Graphics pipeline stress
- **What it catches:** GPU hardware failures, CUDA issues, thermal problems

### 3. RAM Test (`jetson_ram_test.sh`)
- Pattern verification (0x00, 0xFF, 0x55, 0xAA)
- Multi-threaded stress
- Integrity checking
- **What it catches:** Bad RAM chips, timing issues, bit errors

### 4. Storage Test (`jetson_storage_test.sh`)
- Sequential/random I/O
- Filesystem metadata stress
- eMMC health monitoring
- **What it catches:** Bad sectors, controller failures, wear issues

### 5. Sequential Combined (`jetson_combined_sequential.sh`)
- Runs: CPU → GPU → RAM → Storage (one after another)
- **Duration:** 4× test parameter (e.g., 1 hour each = 4 hours total)
- **What it catches:** Cumulative thermal effects, degradation over time

### 6. Parallel Combined (`jetson_combined_parallel.sh`)
- Runs: CPU + GPU + RAM + Storage simultaneously
- **Duration:** 1× test parameter
- **What it catches:** Power supply issues, maximum thermal stress, real-world multi-workload

---

## ⏱️ Test Duration Guide

| Duration Parameter | Actual Time | Use Case |
|-------------------|-------------|----------|
| `0.25` | 15 minutes | Quick smoke test |
| `0.5` | 30 minutes | Fast validation |
| `1` | 1 hour | **Standard** (recommended) |
| `2` | 2 hours | Extended testing |
| `4` | 4 hours | Long burn-in |
| `8` | 8 hours | Overnight test |

### Examples:

```bash
# 30-minute quick test
./jetson_cpu_test.sh 192.168.55.69 orin mypass 0.5

# 1-hour standard test (recommended)
./jetson_gpu_test.sh 192.168.55.69 orin mypass 1

# 2-hour extended test
./jetson_ram_test.sh 192.168.55.69 orin mypass 2
```

---

## 🎬 Example Session

### Using the Orchestrator:

```bash
$ ./jetson_orchestrator.sh 192.168.55.69 orin mypassword

================================================================================
      _      _                    ___       _         ___           _
     | |    | |                  / _ \     (_)       / _ \         | |
     | | ___| |_ ___  ___  _ __ | | | |_ __ _ _ __ | | | |_ __ ___| |__  ___
 _   | |/ _ \ __/ __|/ _ \| '_ \| | | | '__| | '_ \| | | | '__/ __| '_ \/ __|
| |__| |  __/ |_\__ \ (_) | | | | |_| | |  | | | | | |_| | | | (__| | | \__ \
 \____/ \___|\__|___/\___/|_| |_|\___/|_|  |_|_| |_|\___/|_|  \___|_| |_|___/

    T E S T   O R C H E S T R A T O R
================================================================================
Target Device: orin@192.168.55.69

SELECT TEST MODE:

  [INDIVIDUAL COMPONENTS]
  1) CPU Test                    - Test CPU cores only
  2) GPU Test                    - Test GPU (CUDA + VPU + Graphics)
  3) RAM Test                    - Test memory integrity
  4) Storage Test                - Test disk I/O performance

  [COMBINED TESTS]
  5) Sequential Combined         - Run all tests in sequence (CPU → GPU → RAM → Storage)
  6) Parallel Combined           - Run all tests simultaneously (maximum stress)

  0) Exit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enter your choice [0-6]: 6

Selected Test Mode: Parallel Combined Test

SELECT TEST DURATION:

  [QUICK TESTS]
  1) 15 minutes      - Quick smoke test
  2) 30 minutes      - Fast validation

  [STANDARD TESTS]
  3) 1 hour          - Standard test (recommended)
  4) 2 hours         - Extended test

  [LONG TESTS]
  5) 4 hours         - Long burn-in test
  6) 8 hours         - Overnight test

  [CUSTOM]
  7) Custom duration - Enter your own duration

  0) Back to test mode selection

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enter your choice [0-7]: 3

═══════════════════════════════════════════════════════════════════════════════
  TEST CONFIGURATION SUMMARY
═══════════════════════════════════════════════════════════════════════════════

Test Mode:           Parallel Combined Test
Target Device:       orin@192.168.55.69
Duration per test:   1 hours
Total duration:      1 hours

Start time:          2024-10-30 15:00:00
Estimated end:       2024-10-30 16:00:00

⚠ WARNING: This will push ALL components to maximum simultaneously!
   Expect high temperatures and maximum power consumption.

═══════════════════════════════════════════════════════════════════════════════

Do you want to start this test? (yes/no): yes

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  STARTING TEST: Parallel Combined Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Test runs...]
```

---

## 📊 Test Selection Decision Tree

```
Need quick validation (< 1 hour)?
  └─> Use: jetson_combined_parallel.sh with 0.5-1 hour

Need individual component testing?
  └─> Use: jetson_cpu_test.sh / jetson_gpu_test.sh / jetson_ram_test.sh / jetson_storage_test.sh

Need comprehensive validation?
  └─> Use: jetson_combined_sequential.sh with 1-2 hours per component

Need maximum stress test?
  └─> Use: jetson_combined_parallel.sh with 1-2 hours

Not sure what you need?
  └─> Use: jetson_orchestrator.sh (interactive menu)
```

---

## 💡 Recommended Test Strategies

### For Different Use Cases:

#### **Development/Prototyping** (1 hour total)
```bash
./jetson_combined_parallel.sh 192.168.55.69 orin <password> 1
```

#### **Pre-Production Testing** (4-5 hours total)
```bash
./jetson_cpu_test.sh 192.168.55.69 orin <password> 1
./jetson_gpu_test.sh 192.168.55.69 orin <password> 1
./jetson_ram_test.sh 192.168.55.69 orin <password> 1
./jetson_storage_test.sh 192.168.55.69 orin <password> 1
./jetson_combined_parallel.sh 192.168.55.69 orin <password> 1
```

#### **Production Validation** (4-8 hours total)
```bash
./jetson_combined_sequential.sh 192.168.55.69 orin <password> 1-2
```

#### **Maximum Stress** (1-2 hours)
```bash
./jetson_combined_parallel.sh 192.168.55.69 orin <password> 1-2
```

---

## 📁 Results Location

All tests save results to timestamped directories:

```
./orchestrator_<mode>_YYYYMMDD_HHMMSS/     # When using orchestrator
./combined_sequential_test_YYYYMMDD_HHMMSS/ # Sequential test
./combined_parallel_test_YYYYMMDD_HHMMSS/   # Parallel test
./jetson_cpu_test_YYYYMMDD_HHMMSS/          # Individual CPU test
./jetson_gpu_test_YYYYMMDD_HHMMSS/          # Individual GPU test
...etc
```

---

## ✅ What Tests Are Adequate For You

Based on **1-2 hour per component** testing requirement:

| Scenario | Recommended Test | Total Time | Detection Rate |
|----------|------------------|------------|----------------|
| **Quick validation** | `jetson_combined_parallel.sh` 1h | 1 hour | ~70-80% |
| **Standard testing** | All 4 individual tests, 1h each | 4 hours | ~85-90% |
| **Comprehensive** | `jetson_combined_sequential.sh` 1h | 4 hours | ~85-90% |
| **Best balance** | 4 individual + parallel, 1h each | 5 hours | ~90-95% |

---

## 🆘 Help Commands

```bash
# Show help for any script
./jetson_cpu_test.sh --help
./jetson_gpu_test.sh --help
./jetson_ram_test.sh --help
./jetson_storage_test.sh --help
./jetson_combined_sequential.sh --help
./jetson_combined_parallel.sh --help
```

---

## 📚 Additional Documentation

- **QUICKSTART.md** (this file) - Quick reference guide
- **TEST_ORCHESTRATOR_README.md** - Detailed orchestrator documentation
- **TEST_SELECTION_GUIDE.md** - Test selection strategies

---

## 🎯 Summary

**Simplest way to run tests:**
```bash
./jetson_orchestrator.sh 192.168.55.69 orin <password>
```

**Then just:**
1. Select test mode (1-6)
2. Select duration (1-7)
3. Confirm and run

**That's it!** 🚀
