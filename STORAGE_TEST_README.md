# 💾 JETSON ORIN STORAGE STRESS TEST - TECHNICAL DOCUMENTATION

## 📋 Table of Contents
1. [Overview](#overview)
2. [Storage Types & Architecture](#storage-types--architecture)
3. [Phase 1: Storage Analysis](#phase-1-storage-analysis)
4. [Phase 2: Sequential I/O](#phase-2-sequential-io-performance)
5. [Phase 3: Random I/O](#phase-3-random-io-performance)
6. [Phase 4: Sustained Stress](#phase-4-sustained-io-stress)
7. [Phase 5: Metadata Stress](#phase-5-filesystem-metadata-stress)
8. [Phase 6: Health Analysis](#phase-6-storage-health-analysis)
9. [Phase 7: SMART Testing](#phase-7-extended-smart-test)
10. [Phase 8: Sector Control](#phase-8-disk-sector-control-test)
11. [Usage Guide](#usage-guide)
12. [Result Interpretation](#result-interpretation)

---

## 📖 Overview

### Purpose
**Comprehensive storage validation** for Jetson Orin's eMMC, NVMe SSD, microSD, and external storage. Tests performance, reliability, data integrity, and hardware health.

### Target Hardware
- **Primary Storage:** eMMC 5.1 (64GB/128GB)
- **Optional:** NVMe M.2 SSD
- **Optional:** microSD Card (UHS-I/II)
- **Optional:** USB 3.2 Storage

### Test Philosophy
```
Storage Reliability = Performance + Health + Integrity + Endurance
Detection = Bad sectors, wear leveling, controller issues, data corruption
Methodology = Professional tools (fio) + Fallback (dd) + SMART + Integrity checks
```

### Key Features
✅ **Dual Testing Modes** - fio (professional) or dd (fallback)
✅ **SMART Health Analysis** - Comprehensive attribute checking
✅ **Bad Sector Detection** - Surface scan with hdparm
✅ **Data Integrity** - Checksum validation
✅ **Temperature Monitoring** - Thermal stress tracking
✅ **Realistic Workloads** - Sequential, random, mixed patterns

---

## 🏗️ Storage Types & Architecture

### eMMC (Embedded MultiMediaCard)

```
eMMC Architecture:
┌─────────────────────────────────────────────────────┐
│              eMMC Controller (On-Chip)              │
│   ├─ Wear Leveling                                  │
│   ├─ Bad Block Management                           │
│   ├─ ECC (Error Correction Code)                    │
│   └─ Command Queue (up to 32 commands)              │
├─────────────────────────────────────────────────────┤
│              NAND Flash Memory                       │
│   Multiple dies, multiple planes per die            │
│   SLC cache for burst performance                   │
└─────────────────────────────────────────────────────┘

Interface: MMC bus, 8-bit data, HS400 mode
Speed: Up to 400 MB/s sequential read
Endurance: Limited write cycles (typically 3,000 P/E cycles)
```

**Characteristics:**
- ✅ Soldered to board (no connection issues)
- ✅ Reliable for embedded systems
- ⚠️ Limited write endurance
- ⚠️ Slower than NVMe

---

### NVMe SSD (Optional)

```
NVMe Architecture:
┌─────────────────────────────────────────────────────┐
│            NVMe Controller (On SSD)                  │
│   ├─ PCIe 3.0/4.0 x4 lanes                          │
│   ├─ NVMe Command Set                                │
│   ├─ Multiple queues (up to 65,535)                  │
│   └─ Advanced caching algorithms                     │
├─────────────────────────────────────────────────────┤
│         3D NAND Flash (TLC/QLC)                      │
│   DRAM cache for mapping table                       │
│   SLC write cache                                    │
└─────────────────────────────────────────────────────┘

Interface: PCIe Gen3 x4 (or Gen4 on some models)
Speed: 2,000-7,000 MB/s sequential read
Endurance: Higher than eMMC (typically 600 TBW+)
```

**Characteristics:**
- ✅ Very high performance
- ✅ High endurance (TBW ratings)
- ⚠️ Requires M.2 slot
- ⚠️ Power consumption higher than eMMC

---

### Storage Performance Expectations

| Storage Type | Seq Read | Seq Write | Random Read | Random Write |
|--------------|----------|-----------|-------------|--------------|
| **eMMC 5.1** | 250-400 MB/s | 100-200 MB/s | 5-15 MB/s | 5-10 MB/s |
| **NVMe (Gen3)** | 2,000-3,500 MB/s | 1,500-3,000 MB/s | 300-500 MB/s | 200-400 MB/s |
| **microSD UHS-I** | 80-95 MB/s | 50-70 MB/s | 5-10 MB/s | 3-8 MB/s |

---

## 📊 Phase 1: Storage System Analysis

### Purpose
Discover all storage devices, gather detailed information, and prepare for testing.

### Information Collected

#### 1. Block Devices
```bash
lsblk -f

Example Output:
NAME         FSTYPE LABEL    SIZE TYPE MOUNTPOINT
mmcblk0                     119.1G disk
├─mmcblk0p1  ext4   APP     116.1G part /
└─mmcblk0p2  vfat   BOOT      128M part /boot/efi
nvme0n1                       1.9T disk
└─nvme0n1p1  ext4   DATA      1.9T part /mnt/nvme
```

**Interpreted:**
- mmcblk0 = eMMC (primary storage)
- nvme0n1 = NVMe SSD (additional storage)
- Partition layout visible
- Filesystem types shown

---

#### 2. Filesystem Information
```bash
df -h

Filesystem      Size  Used Avail Use% Mounted on
/dev/mmcblk0p1  114G   45G   64G  42% /
/dev/nvme0n1p1  1.9T  500G  1.3T  28% /mnt/nvme
```

**Metrics:**
- Total capacity
- Used space
- Available space
- Usage percentage

---

#### 3. Mount Points
```bash
mount | grep -E "^/dev"

/dev/mmcblk0p1 on / type ext4 (rw,relatime)
/dev/nvme0n1p1 on /mnt/nvme type ext4 (rw,noatime,nodiratime)
```

**Important Details:**
- Read-write status
- Mount options (atime, noatime, etc.)
- Filesystem type

---

## 🚀 Phase 2: Sequential I/O Performance

### Purpose
Measure **sequential read/write** performance (large contiguous blocks).

### Why Sequential Matters
```
Use Cases:
• Video recording (continuous write)
• Large file transfers
• OS boot process
• Log file writes
• Backup operations

Sequential = Best-case performance
Good indicator of storage bandwidth
```

---

### Test Methods

#### Method 1: fio (Professional Tool)

```bash
# Sequential Write Test
fio --name=seq-write \
    --filename=/tmp/fio_test_file \
    --size=1G \
    --bs=1M \
    --rw=write \
    --direct=1 \
    --numjobs=1 \
    --time_based \
    --runtime=60

# Parameters explained:
# --bs=1M        : Block size (1 MB chunks)
# --rw=write     : Sequential write
# --direct=1     : Bypass OS cache (O_DIRECT)
# --numjobs=1    : Single thread
# --runtime=60   : Run for 60 seconds
```

**Why 1MB blocks?**
- Typical for large file I/O
- Efficient for sequential access
- Standard benchmark size

**Why O_DIRECT?**
- Bypasses Linux page cache
- Tests actual hardware performance
- Prevents inflated results from RAM cache

---

#### Method 2: dd (Fallback)

```bash
# Sequential Write (if fio unavailable)
dd if=/dev/zero of=/tmp/test_file bs=1M count=1024 conv=fdatasync

# Sequential Read
dd if=/tmp/test_file of=/dev/null bs=1M

# Calculate bandwidth
# 1024 MB / time_seconds = MB/s
```

**Limitations of dd:**
- Less precise than fio
- No IOPS measurement
- Simpler reporting

---

### Expected Results

#### eMMC Sequential Performance
```
Sequential Write: 150-250 MB/s
Sequential Read:  250-400 MB/s

Write slower than read (typical for flash)
```

#### NVMe Sequential Performance
```
Sequential Write: 1,500-3,000 MB/s
Sequential Read:  2,000-3,500 MB/s

10× faster than eMMC!
```

---

### Failure Indicators

#### Performance Degradation
```
Expected: 250 MB/s
Actual:   50 MB/s

Causes:
❌ Bad sectors forcing retries
❌ Controller malfunction
❌ Thermal throttling
❌ Wear leveling overhead (flash wearing out)
```

#### Inconsistent Performance
```
Run 1: 250 MB/s ✅
Run 2: 240 MB/s ✅
Run 3: 80 MB/s  ❌ Sudden drop!
Run 4: 250 MB/s ✅

Causes:
❌ Intermittent hardware fault
❌ Temperature-dependent issue
❌ Controller firmware bug
```

---

## 🎲 Phase 3: Random I/O Performance

### Purpose
Measure **random read/write** performance (small non-contiguous blocks).

### Why Random Matters
```
Use Cases:
• Database operations
• Web server (many small files)
• Software compilation
• Package management
• Real-world mixed workloads

Random = Worst-case performance
Most applications are random, not sequential!
```

---

### Random I/O Test

```bash
# Random Read Test (4KB blocks)
fio --name=rand-read \
    --filename=/tmp/fio_test_file \
    --size=1G \
    --bs=4K \
    --rw=randread \
    --direct=1 \
    --numjobs=4 \
    --ioengine=libaio \
    --iodepth=32 \
    --runtime=60

# Random Write Test (4KB blocks)
fio --name=rand-write \
    --filename=/tmp/fio_test_file \
    --size=1G \
    --bs=4K \
    --rw=randwrite \
    --direct=1 \
    --numjobs=4 \
    --ioengine=libaio \
    --iodepth=32 \
    --runtime=60
```

**Key Parameters:**
- `--bs=4K` : Typical database/filesystem block size
- `--rw=randread/randwrite` : Random access pattern
- `--iodepth=32` : Queue depth (outstanding I/O operations)
- `--numjobs=4` : Parallel threads (simulate concurrent access)

---

### Random vs Sequential Performance

```
eMMC Example:

Sequential Read:  400 MB/s  = 102,400 IOPS (4KB blocks)
Random Read:       20 MB/s  =   5,120 IOPS (4KB blocks)

Random is 20× SLOWER! ⚠️

Why?
• Sequential: Read entire NAND pages (optimal)
• Random: Read scattered pages (many seeks)
• Flash optimized for sequential access
```

---

### IOPS (Input/Output Operations Per Second)

```
IOPS = (Bandwidth in MB/s × 1024) / Block Size in KB

Example (Random Read @ 20 MB/s, 4KB blocks):
IOPS = (20 × 1024) / 4 = 5,120 IOPS

Interpretation:
5,000+ IOPS: Good for eMMC ✅
1,000-5,000 IOPS: Acceptable ⚠️
<1,000 IOPS: Poor ❌
```

---

## 💪 Phase 4: Sustained I/O Stress

### Purpose
Continuous I/O load for extended duration to test **endurance**, **thermal stability**, and **sustained performance**.

### Test Strategy

```bash
# Sustained mixed workload
fio --name=sustained-stress \
    --filename=/tmp/stress_file \
    --size=4G \
    --bs=128K \
    --rw=randrw \
    --rwmixread=70 \
    --direct=1 \
    --numjobs=2 \
    --runtime=1800 \     # 30 minutes
    --time_based
```

**Workload Mix:**
- 70% read, 30% write (realistic ratio)
- 128KB blocks (moderate size)
- 2 parallel jobs (concurrent access)
- 30 minutes duration

---

### Monitoring During Stress

```bash
# Real-time I/O statistics
iostat -x 5

Device            r/s     w/s     rkB/s     wkB/s   %util
mmcblk0         120.4    51.2   15360.0    6553.6    89.5%

# Metrics:
# r/s    : Reads per second
# w/s    : Writes per second
# rkB/s  : Read bandwidth (KB/s)
# wkB/s  : Write bandwidth (KB/s)
# %util  : Device utilization (0-100%)
```

**Healthy Behavior:**
- Consistent bandwidth (±10%)
- %util between 70-100%
- No I/O errors
- Temperature stable

**Unhealthy Behavior:**
- Bandwidth degrades over time
- %util drops suddenly
- I/O errors in dmesg
- Temperature exceeds 70°C

---

### Performance Over Time

```
Expected (Healthy eMMC):
Time:  0min  5min  10min  15min  20min  30min
BW:    200   195   198    196    197    195  MB/s
Temp:  40°C  50°C  55°C   58°C   60°C   60°C

Variation: <5% → Excellent ✅

Degraded (Failing eMMC):
Time:  0min  5min  10min  15min  20min  30min
BW:    200   180   150    120    100    80   MB/s
Temp:  40°C  55°C  65°C   72°C   78°C   82°C

Variation: >40% degradation → Failed ❌
```

---

## 📁 Phase 5: Filesystem Metadata Stress

### Purpose
Test **filesystem metadata operations** (file creation, deletion, directory operations) which stress different aspects than data I/O.

### Why Metadata Matters
```
Metadata Operations:
• Creating files (inode allocation)
• Deleting files (inode deallocation)
• Creating directories (directory entries)
• File stat() calls (metadata lookup)
• Hard links, symlinks

These stress:
• Filesystem journal
• Metadata caching
• Directory indexing (B-trees)
• Inode tables

Can fail even if data I/O works! ❌
```

---

### Metadata Test

```bash
# Create 10,000 small files
for i in $(seq 1 10000); do
    echo "test" > /tmp/metadata_test/file_$i.txt
done

# Stat all files (metadata lookup)
for i in $(seq 1 10000); do
    stat /tmp/metadata_test/file_$i.txt > /dev/null
done

# Delete all files
rm -rf /tmp/metadata_test/*

# Measure time for each operation
```

**Metrics:**
- Files created per second
- Stat operations per second
- Deletion rate

**Expected (ext4 on eMMC):**
```
Create: 1,000-3,000 files/sec
Stat:   5,000-10,000 ops/sec
Delete: 2,000-5,000 files/sec
```

---

### Failure Indicators

```
Symptom: Extremely slow file creation

Create 10,000 files:
Expected: 3-10 seconds
Actual:   60+ seconds ❌

Causes:
❌ Filesystem corruption
❌ Journal issues
❌ Inode table fragmentation
❌ Bad sectors in metadata area
```

---

## 🏥 Phase 6: Storage Health Analysis

### Purpose
Read and interpret **SMART attributes** (Self-Monitoring, Analysis and Reporting Technology) to assess storage health.

### SMART Overview

```
SMART System:
┌──────────────────────────────────────────────────┐
│  Storage Device (eMMC/SSD/HDD)                   │
│  ├─ Monitors internal parameters                 │
│  ├─ Tracks errors and wear                       │
│  ├─ Predicts failures                            │
│  └─ Reports via SMART commands                   │
└──────────────────────────────────────────────────┘
         │
         ▼
    smartctl tool
         │
         ▼
    Health Report
```

---

### Key SMART Attributes

#### For eMMC
```bash
smartctl -a /dev/mmcblk0

Important Attributes:
1. Device Life Used:        5%  ← Wear level
2. Pre-EOL Info:           0x01 ← Health status
3. SLC Cache Used:          15% ← Cache pressure
4. Average Erase Count:   1,250 ← Write cycles
5. Max Erase Count:       1,890 ← Worst block
6. Uncorrectable Errors:      0 ← Critical!

Health Status:
0x01 = Normal (0-10% used)
0x02 = Warning (10-90% used)
0x03 = Urgent (>90% used) ⚠️
```

**Interpretation:**
```
Device Life Used < 50%:     Healthy ✅
Device Life Used 50-80%:    Aging ⚠️
Device Life Used > 80%:     Replace soon ❌
Uncorrectable Errors > 0:   Data at risk! ❌
```

---

#### For NVMe SSD
```bash
smartctl -a /dev/nvme0n1

Critical Attributes:
1. Critical Warning:            0x00  ← No warnings
2. Temperature:                 45°C  ← Operating temp
3. Available Spare:            100%  ← Reserved blocks
4. Available Spare Threshold:    5%  ← Warning level
5. Percentage Used:             12%  ← Wear level
6. Data Units Read:         1,234 GB
7. Data Units Written:        567 GB
8. Power Cycles:                 45
9. Unsafe Shutdowns:              3
10. Media Errors:                 0  ← Critical!

Health Status: PASSED ✅
```

**Red Flags:**
```
Available Spare < 10%:        ❌ Drive dying
Percentage Used > 90%:        ❌ Replace imminent
Media Errors > 0:             ❌ Bad blocks
Temperature > 70°C sustained: ⚠️ Cooling issue
Unsafe Shutdowns > 100:       ⚠️ Power issues
```

---

## 🔬 Phase 7: Extended SMART Test

### Purpose
Run device's **built-in self-test** (comprehensive internal diagnostics).

### Test Types

#### Short Test (2-5 minutes)
```bash
smartctl -t short /dev/mmcblk0

# Wait for completion
smartctl -a /dev/mmcblk0 | grep -A 10 "Self-test execution status"
```

**What it tests:**
- Read verification (sampled sectors)
- Basic controller functions
- Quick health check

---

#### Long Test (30-120 minutes)
```bash
smartctl -t long /dev/nvme0n1

# Monitor progress
while true; do
    smartctl -a /dev/nvme0n1 | grep "test remaining"
    sleep 60
done
```

**What it tests:**
- Full surface scan
- All sectors read and verified
- Controller stress test
- Thermal stability

---

### Test Results

```bash
# Check test result
smartctl -a /dev/mmcblk0 | grep -A 20 "SMART Self-test log"

# Example output:
Test Description    Status                 Remaining  LifeTime(hours)
Short offline       Completed without error    0%      12345
Long offline        Completed without error    0%      12340

✅ PASSED: No errors found

# Failure example:
Long offline        Completed: read failure    90%     12350
                    First failing LBA: 0x12ab34cd

❌ FAILED: Bad sector at LBA 0x12ab34cd
          Replace storage immediately!
```

---

## 🎯 Phase 8: Disk Sector Control Test

### Purpose
**Surface scan** to detect bad sectors before they cause data loss.

### hdparm Sector Test

```bash
# Read-only surface scan (safe)
sudo hdparm --read-sector 0 /dev/mmcblk0  # Test sector 0
sudo hdparm --read-sector 1000 /dev/mmcblk0

# Full device scan (slow but thorough)
TOTAL_SECTORS=$(blockdev --getsz /dev/mmcblk0)

for sector in $(seq 0 1000 $TOTAL_SECTORS); do
    if ! hdparm --read-sector $sector /dev/mmcblk0 >/dev/null 2>&1; then
        echo "Bad sector detected: $sector" >> bad_sectors.log
    fi
done
```

**What happens on bad sector:**
```
Good Sector:
hdparm reads sector → Data returned ✅

Bad Sector (Uncorrectable):
hdparm reads sector → ECC failure → I/O error ❌
Kernel logs: "I/O error, dev mmcblk0, sector 12345"
```

---

### badblocks Tool (Alternative)

```bash
# Read-only scan (safe)
sudo badblocks -sv /dev/mmcblk0 > bad_blocks.txt

# Progress shown:
Checking blocks 0 to 124952575
  0.00% done, 0:00 elapsed. (0/0/0 errors)
  1.00% done, 0:15 elapsed. (0/0/0 errors)
  ...
  100.00% done, 2:30:15 elapsed. (0/0/0 errors)

Pass completed, 0 bad blocks found. ✅
```

**If bad blocks found:**
```
124952575 done, 2:30:15 elapsed. (3/0/0 errors)

Bad blocks found:
  12345678
  45678901
  89012345

❌ 3 bad blocks → Storage failing
   Backup data immediately!
   Replace storage soon!
```

---

## 🚀 Usage Guide

### Basic Usage
```bash
# Default: 2-hour test
./jetson_storage_test.sh 192.168.55.69 orin password 2

# Quick test: 30 minutes
./jetson_storage_test.sh 192.168.55.69 orin password 0.5

# Comprehensive: 8 hours (includes long SMART test)
./jetson_storage_test.sh 192.168.55.69 orin password 8
```

---

## 📊 Result Interpretation

### Pass Criteria
```
✅ PASS if:
  - Sequential I/O within 80% of expected
  - Random I/O within 70% of expected
  - Sustained performance stable (±10%)
  - No bad sectors detected
  - SMART health: PASSED
  - Extended SMART test: passed
  - No uncorrectable errors

❌ FAIL if:
  - Performance <50% expected
  - Bad sectors found
  - SMART warnings/errors
  - Device life >80%
  - Extended test failed
```

---

### Health Status Summary

| Indicator | Good | Warning | Critical |
|-----------|------|---------|----------|
| Sequential BW | >80% | 50-80% | <50% |
| Random IOPS | >70% | 40-70% | <40% |
| Bad Sectors | 0 | 1-5 | >5 |
| Device Life | <50% | 50-80% | >80% |
| SMART Status | PASSED | - | FAILED |
| Temperature | <60°C | 60-70°C | >70°C |

---

## 🔧 Troubleshooting

### Issue: Very Slow Performance

**Check:**
```bash
# Check if TRIM/discard enabled
sudo fstrim -v /

# Check mount options
mount | grep mmcblk0
# Should have: noatime,nodiratime for best performance
```

---

### Issue: Bad Sectors Detected

**Action:**
```bash
# Backup data IMMEDIATELY
rsync -av /source/ /backup/

# Note bad sector addresses
# Check if sectors remappable (SSD/eMMC usually auto-remap)

# Monitor if count increases
# If count stable → Storage may continue working
# If count increasing → Replace immediately!
```

---

### Issue: High Temperature

**Solutions:**
```bash
# Check ambient temperature
# Improve airflow/cooling
# Reduce I/O load if embedded deployment
# Consider heatsink on M.2 SSD
```

---

**END OF STORAGE TEST DOCUMENTATION**
