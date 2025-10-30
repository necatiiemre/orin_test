# Test Selection Guide

## Quick Reference: How to Run Specific Tests

### 🎯 Interactive Menu (Easiest!)

```bash
# Launch interactive test selector
./jetson_test_selector.sh 192.168.55.69 orin <password> 1

# Or let it prompt for password
./jetson_test_selector.sh 192.168.55.69 orin
```

The interactive menu lets you:
- Choose specific tests from a numbered list
- See estimated duration before running
- Run tests individually or in combinations
- No need to remember script names!

---

## 📋 Direct Command Reference

### Individual Component Tests

```bash
# CPU Test Only (1 hour)
./jetson_cpu_test.sh 192.168.55.69 orin <password> 1

# GPU Test Only (1 hour)
./jetson_gpu_test.sh 192.168.55.69 orin <password> 1

# RAM Test Only (1 hour)
./ram/complete_ram_test.sh 192.168.55.69 orin <password> 1

# Storage Test Only (1 hour)
./jetson_storage_test.sh 192.168.55.69 orin <password> 1
```

### Combined Tests

```bash
# Parallel Combined - All components simultaneously (1 hour)
./jetson_combined_parallel_test.sh 192.168.55.69 orin <password> 1

# Full Orchestrator - All 6 phases (6-8 hours)
./jetson_test_orchestrator.sh 192.168.55.69 orin <password> 1
```

### System Preparation

```bash
# Prepare system only (install dependencies, optimize settings)
./jetson_system_prep.sh 192.168.55.69 orin <password>
```

---

## 🔥 Quick Test Combinations (Manual)

### Scenario 1: Quick Hardware Validation (2 hours)
Test the most critical components:

```bash
# CPU + GPU (most likely to fail)
./jetson_cpu_test.sh 192.168.55.69 orin <password> 1
./jetson_gpu_test.sh 192.168.55.69 orin <password> 1
```

### Scenario 2: Memory & Storage Only (2 hours)
Focus on data integrity:

```bash
# RAM + Storage
./ram/complete_ram_test.sh 192.168.55.69 orin <password> 1
./jetson_storage_test.sh 192.168.55.69 orin <password> 1
```

### Scenario 3: Core Components (3 hours)
CPU + GPU + Parallel stress:

```bash
./jetson_cpu_test.sh 192.168.55.69 orin <password> 1
./jetson_gpu_test.sh 192.168.55.69 orin <password> 1
./jetson_combined_parallel_test.sh 192.168.55.69 orin <password> 1
```

### Scenario 4: Full Individual Tests (4 hours)
All components separately:

```bash
./jetson_cpu_test.sh 192.168.55.69 orin <password> 1
./jetson_gpu_test.sh 192.168.55.69 orin <password> 1
./ram/complete_ram_test.sh 192.168.55.69 orin <password> 1
./jetson_storage_test.sh 192.168.55.69 orin <password> 1
```

### Scenario 5: Individual + Parallel (5 hours)
Best balance for thorough testing:

```bash
./jetson_cpu_test.sh 192.168.55.69 orin <password> 1
./jetson_gpu_test.sh 192.168.55.69 orin <password> 1
./ram/complete_ram_test.sh 192.168.55.69 orin <password> 1
./jetson_storage_test.sh 192.168.55.69 orin <password> 1
./jetson_combined_parallel_test.sh 192.168.55.69 orin <password> 1
```

---

## 🛠️ Custom Test Durations

All tests accept custom durations in hours:

```bash
# 30 minute quick test
./jetson_cpu_test.sh 192.168.55.69 orin <password> 0.5

# 2 hour extended test
./jetson_gpu_test.sh 192.168.55.69 orin <password> 2

# 15 minute smoke test
./ram/complete_ram_test.sh 192.168.55.69 orin <password> 0.25
```

---

## 📊 Test Selection Decision Tree

```
START
  │
  ├─ Time < 1 hour?
  │   └─ Run: ./jetson_combined_parallel_test.sh (0.5 hours)
  │
  ├─ Time = 1-2 hours?
  │   └─ Run: CPU + GPU tests
  │
  ├─ Time = 2-4 hours?
  │   └─ Run: All individual tests (CPU, GPU, RAM, Storage)
  │
  ├─ Time = 4-6 hours?
  │   └─ Run: All individual + Parallel combined
  │
  └─ Time = 6+ hours?
      └─ Run: Full orchestrator (all 6 phases)
```

---

## 💡 Recommended Test Strategies

### For Different Use Cases:

#### Development/Prototyping
```bash
# Quick validation (1 hour)
./jetson_combined_parallel_test.sh 192.168.55.69 orin <password> 1
```

#### Pre-Production Testing
```bash
# Individual tests + parallel (5 hours)
./jetson_cpu_test.sh 192.168.55.69 orin <password> 1
./jetson_gpu_test.sh 192.168.55.69 orin <password> 1
./ram/complete_ram_test.sh 192.168.55.69 orin <password> 1
./jetson_storage_test.sh 192.168.55.69 orin <password> 1
./jetson_combined_parallel_test.sh 192.168.55.69 orin <password> 1
```

#### Production Validation
```bash
# Full orchestrator with 2 hours per test (12-14 hours)
./jetson_test_orchestrator.sh 192.168.55.69 orin <password> 2
```

#### Batch Testing (Multiple Units)
```bash
# Sample units: Full orchestrator (6-8 hours)
./jetson_test_orchestrator.sh 192.168.55.69 orin <password> 1

# Remaining units: Quick parallel test (1 hour)
./jetson_combined_parallel_test.sh 192.168.55.69 orin <password> 1
```

---

## 🎬 Example Session

### Interactive Menu Example:

```bash
$ ./jetson_test_selector.sh 192.168.55.69 orin mypassword 1

================================================================================
  JETSON ORIN AGX - TEST SELECTOR
================================================================================
Target: orin@192.168.55.69
Duration per test: 1 hours

Select tests to run:

  [INDIVIDUAL COMPONENT TESTS]
  1) CPU Stress Test                    (~1 hour)
  2) GPU Stress Test                    (~1 hour)
  3) RAM Stress Test                    (~1 hour)
  4) Storage Stress Test                (~1 hour)

  [COMBINED TESTS]
  5) Sequential Combined Test           (~4 hours - all tests in sequence)
  6) Parallel Combined Test             (~1 hour - all simultaneously)

  [QUICK COMBINATIONS]
  7) CPU + GPU Tests                    (~2 hours)
  8) RAM + Storage Tests                (~2 hours)
  9) All Individual Tests (1-4)         (~4 hours)

  [FULL SUITE]
  10) Full Orchestrator (All 6 Phases)  (~8 hours)

  [OTHER]
  11) System Preparation Only           (~10 minutes)

  0) Exit

Enter your choice [0-11]: 6

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Running: Parallel Combined Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Test script: jetson_combined_parallel_test.sh
Duration: 1 hours
Start time: 2024-10-30 14:30:00

Press Enter to start or Ctrl+C to cancel...
```

---

## 📝 Test Selection Cheat Sheet

| Goal | Command | Time |
|------|---------|------|
| **Fastest validation** | `./jetson_combined_parallel_test.sh ... 0.5` | 30 min |
| **CPU only** | `./jetson_cpu_test.sh ... 1` | 1 hour |
| **GPU only** | `./jetson_gpu_test.sh ... 1` | 1 hour |
| **RAM only** | `./ram/complete_ram_test.sh ... 1` | 1 hour |
| **Storage only** | `./jetson_storage_test.sh ... 1` | 1 hour |
| **CPU + GPU** | Run both scripts | 2 hours |
| **All individual** | Run all 4 scripts | 4 hours |
| **Comprehensive** | `./jetson_test_orchestrator.sh ... 1` | 6-8 hours |
| **Maximum stress** | `./jetson_combined_parallel_test.sh ... 2` | 2 hours |

---

## ⚙️ Advanced: Run Specific Orchestrator Phases

If you want to modify the orchestrator to skip phases, edit `jetson_test_orchestrator.sh`:

```bash
# Comment out phases you don't want:

# Skip Phase 1 (CPU) - add # before the line:
# run_test "1" "CPU Stress Test" "jetson_cpu_test.sh" "$TEST_DURATION_HOURS"

# Skip Phase 5 (Sequential Combined) - add # before all Phase 5 lines
```

Or create a custom orchestrator script with only the phases you need.

---

## 🚀 Quick Start Examples

### Example 1: "I only have 1 hour"
```bash
./jetson_combined_parallel_test.sh 192.168.55.69 orin <password> 1
```

### Example 2: "I want to test CPU and GPU only"
```bash
./jetson_test_selector.sh 192.168.55.69 orin <password> 1
# Then select option 7 (CPU + GPU Tests)
```

### Example 3: "I need full validation but fast"
```bash
# Run individual tests with 30 min each (2 hours total)
./jetson_cpu_test.sh 192.168.55.69 orin <password> 0.5
./jetson_gpu_test.sh 192.168.55.69 orin <password> 0.5
./ram/complete_ram_test.sh 192.168.55.69 orin <password> 0.5
./jetson_storage_test.sh 192.168.55.69 orin <password> 0.5
```

### Example 4: "I want the full suite overnight"
```bash
./jetson_test_orchestrator.sh 192.168.55.69 orin <password> 1
```

---

## 📞 Help Commands

```bash
# Show help for any script
./jetson_cpu_test.sh --help
./jetson_gpu_test.sh --help
./jetson_combined_parallel_test.sh --help
./jetson_test_orchestrator.sh --help

# Show this selection guide
cat TEST_SELECTION_GUIDE.md

# Show orchestrator documentation
cat TEST_ORCHESTRATOR_README.md
```

---

## ✅ Summary

Three ways to select specific tests:

1. **Interactive Menu** (Easiest)
   ```bash
   ./jetson_test_selector.sh 192.168.55.69 orin <password> 1
   ```

2. **Direct Commands** (Fastest)
   ```bash
   ./jetson_cpu_test.sh 192.168.55.69 orin <password> 1
   ```

3. **Full Orchestrator** (Most Comprehensive)
   ```bash
   ./jetson_test_orchestrator.sh 192.168.55.69 orin <password> 1
   ```

Choose based on your time constraints and validation requirements!
