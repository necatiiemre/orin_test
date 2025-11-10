# STORAGE TESTLERİ - DETAYLI DOKÜMANTASYON

## İçindekiler
1. [Genel Bakış](#genel-bakış)
2. [Storage Test Kategorileri](#storage-test-kategorileri)
3. [Neden Bu Testler Yapılıyor](#neden-bu-testler-yapılıyor)
4. [Ölçülen Metrikler](#ölçülen-metrikler)
5. [Test Örnekleri](#test-örnekleri)

---

## Genel Bakış

Storage testleri, Jetson Orin'in depolama sistemlerinin (eMMC, NVMe SSD, microSD) performansını, güvenilirliğini ve sağlığını kapsamlı şekilde doğrular.

**Test Süresi:** 2-4 saat (ayarlanabilir)
**Test Kapsamı:** Sequential/Random I/O, SMART health, sector integrity, thermal
**Desteklenen Storage:** eMMC (internal), NVMe SSD, microSD, SATA/USB
**Test Boyutu:** Dinamik (mevcut alanın %70'i, max 50GB)

---

## Storage Test Kategorileri

### 1. Sequential I/O Performance - Sıralı Okuma/Yazma Testleri

**Amaç:** Büyük dosya transferlerinde storage performansını ölçmek

#### Test 1.1: Sequential Write (Sıralı Yazma)

**Ne Test Edilir:**
- Write bandwidth (yazma bant genişliği)
- Sustained write performance
- Write cache effectiveness
- Controller write buffer management

**Neden Test Edilir:**
Sequential write performansı kritiktir:
- Büyük dosya kopyalama (video, images)
- Log file yazımı
- Database writes
- Application installation

**Nasıl Zorlanır (FIO ile - Professional):**
```bash
# 4K block size test
fio --name=seq_write_4k \
    --rw=write \
    --bs=4k \
    --size=10G \
    --numjobs=1 \
    --direct=1 \
    --runtime=120 \
    --time_based

# 64K block size test
fio --name=seq_write_64k \
    --rw=write \
    --bs=64k \
    --size=10G \
    --direct=1 \
    --runtime=120

# 1MB block size test (large transfers)
fio --name=seq_write_1m \
    --rw=write \
    --bs=1m \
    --size=10G \
    --direct=1 \
    --runtime=120
```

**Nasıl Zorlanır (DD ile - Basic):**
```bash
# Sequential write test
dd if=/dev/zero of=/tmp/test_file \
   bs=1M count=10000 \
   oflag=direct

# Sonuç: 10GB yazıldı
# Örnek çıktı: 10737418240 bytes (10 GB) copied, 85.2 s, 126 MB/s
```

**Ölçülen Değerler:**
- Write bandwidth (MB/s veya GB/s)
- IOPS (I/O Operations Per Second) - 4K blocks için
- Average latency (ms)
- P95/P99 latency (95th/99th percentile)

**Beklenen Performans:**

| Storage Type | 4K Write | 64K Write | 1MB Write |
|--------------|----------|-----------|-----------|
| eMMC 5.1 | 15-25 MB/s | 80-120 MB/s | 120-150 MB/s |
| NVMe SSD | 200-400 MB/s | 1-2 GB/s | 2-3 GB/s |
| microSD (UHS-I) | 10-20 MB/s | 40-80 MB/s | 80-90 MB/s |

---

#### Test 1.2: Sequential Read (Sıralı Okuma)

**Ne Test Edilir:**
- Read bandwidth
- Read cache effectiveness
- Prefetcher efficiency
- ECC (Error Correction) overhead

**Neden Test Edilir:**
Sequential read:
- Application loading
- Media playback
- Database queries
- OS boot time

**Nasıl Zorlanır:**
```bash
# FIO sequential read
fio --name=seq_read_1m \
    --rw=read \
    --bs=1m \
    --size=10G \
    --numjobs=1 \
    --direct=1 \
    --runtime=120

# DD sequential read
dd if=/tmp/test_file of=/dev/null bs=1M
```

**Ölçülen Değerler:**
- Read bandwidth (MB/s)
- IOPS (for 4K blocks)
- Cache hit rate
- Latency distribution

**Beklenen Performans:**

| Storage Type | 4K Read | 64K Read | 1MB Read |
|--------------|---------|----------|----------|
| eMMC 5.1 | 20-35 MB/s | 150-250 MB/s | 250-300 MB/s |
| NVMe SSD | 300-600 MB/s | 2-3 GB/s | 3-4 GB/s |
| microSD | 15-30 MB/s | 60-90 MB/s | 90-95 MB/s |

---

### 2. Random I/O Performance - Rastgele Okuma/Yazma Testleri

**Amaç:** Küçük, rastgele erişim pattern'lerinde performansı test etmek

#### Test 2.1: Random 4K Read

**Ne Test Edilir:**
- Small block read performance
- Queue depth handling
- Random access latency
- IOPS capability

**Neden Test Edilir:**
Random 4K reads:
- Database operations (en kritik metrik)
- File system metadata access
- Small file reads
- Application responsiveness

**Nasıl Zorlanır:**
```bash
# Random 4K read with queue depth 16
fio --name=random_4k_read \
    --rw=randread \
    --bs=4k \
    --size=2G \
    --numjobs=1 \
    --iodepth=16 \
    --direct=1 \
    --runtime=180 \
    --ioengine=libaio
```

**Ölçülen Değerler:**
- IOPS (operations/second)
- Average latency (microseconds)
- Bandwidth (MB/s)
- Queue depth utilization

**Beklenen Performans (Random 4K Read IOPS):**
- eMMC 5.1: 3,000-6,000 IOPS
- NVMe SSD: 50,000-200,000 IOPS
- microSD: 500-2,000 IOPS

---

#### Test 2.2: Random 4K Write

**Ne Test Edilir:**
- Write amplification
- Garbage collection impact
- Write endurance stress
- Small write handling

**Neden Test Edilir:**
Random 4K writes:
- En zorlu storage workload
- Database writes
- Log updates
- Metadata updates

**Nasıl Zorlanır:**
```bash
# Random 4K write
fio --name=random_4k_write \
    --rw=randwrite \
    --bs=4k \
    --size=2G \
    --iodepth=16 \
    --direct=1 \
    --runtime=180
```

**Ölçülen Değerler:**
- IOPS
- Write amplification factor
- Latency (especially P99)
- Consistency

**Beklenen Performans (Random 4K Write IOPS):**
- eMMC 5.1: 1,500-3,000 IOPS
- NVMe SSD: 40,000-150,000 IOPS
- microSD: 300-1,000 IOPS

---

#### Test 2.3: Mixed Random Read/Write (70/30)

**Ne Test Edilir:**
- Mixed workload performance
- Read/write scheduling
- Real-world simulation
- QoS (Quality of Service)

**Nasıl Zorlanır:**
```bash
# 70% read, 30% write mix
fio --name=randrw \
    --rw=randrw \
    --rwmixread=70 \
    --bs=4k \
    --size=2G \
    --iodepth=16 \
    --runtime=180
```

**Ölçülen Değerler:**
- Total IOPS (read + write)
- Read/write latency separately
- Performance consistency
- Interference effects

---

### 3. Sustained I/O Stress Test - Uzun Süreli Yük Testi

**Amaç:** Storage'ı uzun süre maksimum yük altında tutmak

**Ne Test Edilir:**
- Write cache exhaustion
- Garbage collection effects
- Thermal throttling
- Performance degradation over time

**Neden Test Edilir:**
Sustained load:
- SSD'lerde SLC cache dolması
- Garbage collection tetiklenmesi
- Thermal management
- Long-term reliability

**Nasıl Zorlanır:**
```bash
# Sürekli write/read/delete döngüsü
STRESS_DURATION=3600  # 1 saat

start_time=$(date +%s)
operation_count=0

while [ $(($(date +%s) - start_time)) -lt $STRESS_DURATION ]; do
    # Write operation (32MB dosya)
    dd if=/dev/urandom of=/tmp/stress_$operation_count.dat \
       bs=1M count=32 2>/dev/null

    # Read operation
    dd if=/tmp/stress_$operation_count.dat of=/dev/null \
       bs=1M 2>/dev/null

    # Delete operation
    rm -f /tmp/stress_$operation_count.dat

    operation_count=$((operation_count + 1))

    # Progress
    if [ $((operation_count % 10)) -eq 0 ]; then
        echo "Completed $operation_count stress operations..."
    fi
done

echo "Total operations: $operation_count"
echo "Operations per second: $((operation_count / STRESS_DURATION))"
```

**Ölçülen Değerler:**
- Initial vs sustained performance
- Performance degradation percentage
- Recovery time after stress
- Thermal impact

**Başarı Kriteri:**
- Performance degradation <20%
- No errors or timeouts
- Temperature remains safe (<70°C for SSD)

---

### 4. Filesystem Metadata Stress - Dosya Sistemi Metadata Testi

**Amaç:** Filesystem metadata operations'ı stres altında test etmek

**Ne Test Edilir:**
- Directory operations (mkdir, rmdir)
- File creation/deletion speed
- Inode allocation
- Metadata journaling

**Neden Test Edilir:**
Metadata operations:
- Small file handling (logs, configs)
- Build systems (thousands of files)
- Package management
- Development workloads

**Nasıl Zorlanır:**
```bash
# 5000 küçük dosya oluştur
FILE_COUNT=5000

# Create phase
start_time=$(date +%s)
for i in $(seq 1 $FILE_COUNT); do
    echo "Test data for file $i $(date)" > /tmp/fs_test/small_$i.txt
done
create_time=$(($(date +%s) - start_time))

# Find phase (metadata search)
start_time=$(date +%s)
found_count=$(find /tmp/fs_test -name "small_*.txt" | wc -l)
find_time=$(($(date +%s) - start_time))

# List phase (directory listing)
start_time=$(date +%s)
list_count=$(ls /tmp/fs_test | wc -l)
list_time=$(($(date +%s) - start_time))

# Delete phase
start_time=$(date +%s)
rm -f /tmp/fs_test/small_*.txt
delete_time=$(($(date +%s) - start_time))
```

**Ölçülen Değerler:**
- Files created per second
- Find operation speed
- Directory listing speed
- Delete operation speed

**Beklenen Performans:**
- Create: >500 files/second
- Find: <5 seconds for 5000 files
- List: <2 seconds
- Delete: <3 seconds

---

### 5. SMART Health Check - Disk Sağlık Kontrolü

**Amaç:** Storage device'ın sağlık durumunu izlemek

**Ne Test Edilir:**
- SMART attributes
- Error logs
- Temperature
- Wear leveling (SSD)
- Bad sector count

**Neden Test Edilir:**
SMART data:
- Predictive failure detection
- Remaining lifetime estimation
- Performance degradation tracking
- Warranty validation

**Nasıl Zorlanır:**
```bash
# SMART overall health
smartctl -H /dev/nvme0n1

# SMART attributes
smartctl -A /dev/nvme0n1

# Error logs
smartctl -l error /dev/nvme0n1

# Self-test logs
smartctl -l selftest /dev/nvme0n1

# Temperature
smartctl -A /dev/nvme0n1 | grep -i temperature
```

**Kritik SMART Attributes:**

#### For SSD/NVMe:
```
5 - Reallocated_Sector_Count: Should be 0
    > Bad sectors remapped

9 - Power_On_Hours: Device age
    > Hours device has been powered

177 - Wear_Leveling_Count: SSD wear
      > 100 = new, 0 = end of life

194 - Temperature_Celsius: Current temp
      > Should be <70°C

199 - UDMA_CRC_Error_Count: Cable/interface errors
      > Should be 0
```

#### For eMMC:
```
Life Time Estimation A: 0x01-0x0A (hex)
    0x01: 0-10% life used
    0x0B: >100% life used (worn out)

Pre-EOL Info: 0x01-0x03
    0x01: Normal
    0x02: Warning (80% used)
    0x03: Urgent (90% used)
```

**Ölçülen Değerler:**
- SMART health status (PASSED/FAILED)
- Temperature
- Reallocated sector count
- Pending sector count
- Wear level (for SSD)
- eMMC lifetime (for eMMC)

---

### 6. Extended SMART Test - Kapsamlı Disk Testi

**Amaç:** Disk üreticisinin built-in self-test'ini çalıştırmak

**Ne Test Edilir:**
- Comprehensive disk surface scan
- Read verification
- Internal diagnostics
- Controller self-test

**Neden Test Edilir:**
Extended SMART test:
- Factory-level diagnostics
- Bad sector detection
- Controller validation
- Comprehensive health check

**Nasıl Zorlanır:**
```bash
# Start extended self-test (background)
smartctl -t long /dev/nvme0n1

# Output örneği:
# "Testing has begun.
#  Please wait 120 minutes for test to complete."

# Test progress check
smartctl -a /dev/nvme0n1 | grep -A 10 "Self-test execution status"

# Test completion check
smartctl -l selftest /dev/nvme0n1
```

**Test Duration:**
- Short test: 1-2 minutes
- Long test: 1-4 hours (disk size'a bağlı)

**Ölçülen Değerler:**
- Test completion status
- Errors found
- Failed LBA (Logical Block Address)
- Test duration

**Başarı Kriteri:**
- Test completes without errors
- Status: "Completed without error"
- No failed LBAs

---

### 7. Disk Sector Control Test - Sektör Bütünlüğü Testi

**Amaç:** Bad sectors ve read errors tespiti

**Ne Test Edilir:**
- Bad sector presence
- Read error detection
- Data integrity verification
- Sector remapping effectiveness

**Neden Test Edilir:**
Bad sectors:
- Data corruption risk
- Performance degradation
- Progressive failure indicator
- Critical data loss prevention

**Nasıl Zorlanır:**

#### Method 1: System Log Analysis
```bash
# Check dmesg for bad sector reports
dmesg | grep -i "bad sector\|bad block\|medium error"
```

#### Method 2: Sequential Read Test
```bash
# Create test file
dd if=/dev/zero of=/tmp/sector_test.dat bs=1M count=1024

# Read back and check for errors
dd if=/tmp/sector_test.dat of=/dev/null bs=1M 2>read_errors.log

# Check for errors
if [ -s read_errors.log ]; then
    echo "READ ERRORS DETECTED!"
else
    echo "No read errors"
fi
```

#### Method 3: Pattern Write/Read Verification
```bash
# Write known pattern
dd if=/dev/urandom of=/tmp/pattern_test.dat bs=1M count=100

# Calculate checksum
original_sum=$(md5sum /tmp/pattern_test.dat | awk '{print $1}')

# Force write to disk
sync

# Read back and verify
readback_sum=$(md5sum /tmp/pattern_test.dat | awk '{print $1}')

if [ "$original_sum" = "$readback_sum" ]; then
    echo "Data integrity: PASSED"
else
    echo "DATA CORRUPTION DETECTED!"
fi
```

#### Method 4: SMART Bad Sector Count
```bash
# Check reallocated sectors
smartctl -A /dev/sda | grep -i "Reallocated_Sector"

# Check pending sectors
smartctl -A /dev/sda | grep -i "Current_Pending_Sector"

# Check uncorrectable errors
smartctl -A /dev/sda | grep -i "Offline_Uncorrectable"
```

**Ölçülen Değerler:**
- Bad sector count (from system logs)
- Reallocated sector count (SMART)
- Pending sector count (SMART)
- Uncorrectable sector count (SMART)
- Data integrity (checksum match)

**Başarı Kriteri:**
- Bad sector warnings: 0
- Read errors: 0
- Data integrity: PASSED (checksums match)
- SMART counters: All 0

---

### 8. Temperature Monitoring - Sıcaklık İzleme

**Amaç:** I/O yükü altında storage thermal behavior'ını izlemek

**Ne Test Edilir:**
- Operating temperature
- Temperature under load
- Thermal throttling
- Cooling effectiveness

**Neden Test Edilir:**
Temperature:
- Performance impact (throttling)
- Reliability (high temp = shorter life)
- Data retention
- Error rate increase

**Nasıl Zorlanır:**
```bash
# Monitor temperature during I/O stress
while true; do
    # Get storage temperature
    TEMP=$(smartctl -A /dev/nvme0n1 | grep -i "temperature" | awk '{print $10}')

    # Get timestamp
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Log
    echo "$TIMESTAMP: Storage Temperature: ${TEMP}°C"

    # Start background I/O if not running
    if ! pgrep -f "dd if=/dev/zero" > /dev/null; then
        (dd if=/dev/zero of=/tmp/heat_test.dat bs=1M count=1000 &)
    fi

    sleep 10
done
```

**Ölçülen Değerler:**
- Idle temperature
- Temperature under load
- Peak temperature
- Temperature rise rate (°C/minute)
- Time to thermal equilibrium

**Thermal Thresholds:**

| Temperature | Status | Action |
|-------------|--------|--------|
| <50°C | Excellent | Normal operation |
| 50-60°C | Normal | Monitor |
| 60-70°C | Elevated | Check cooling |
| 70-80°C | Warning | Improve cooling |
| >80°C | Critical | Throttling likely |

**Başarı Kriteri:**
- Operating temp <70°C under sustained load
- No thermal throttling detected
- Temperature stable (not continuously rising)

---

## Neden Bu Testler Yapılıyor

### 1. Manufacturing Defects

**Storage Üretim Hataları:**
- Bad flash cells (NAND flash defects)
- Controller firmware bugs
- Interface problems (PCIe, eMMC bus)
- Power delivery issues

**Test Coverage:**
```
Sequential I/O → Controller & interface validation
Random I/O → Flash cell quality
SMART tests → Factory diagnostics
Sector tests → Media defects
```

---

### 2. Performance Validation

**Specification Compliance:**
- Advertised speeds (MB/s, IOPS)
- Queue depth handling
- Latency requirements
- Consistency

**Real-world Simulation:**
```
Sequential tests → Large file transfers
Random 4K → Database workloads
Mixed workload → Typical usage
Sustained stress → Long-running apps
```

---

### 3. Reliability & Wear

**Long-term Health:**
- Write endurance (TBW - Terabytes Written)
- Wear leveling effectiveness
- Bad sector development
- Performance degradation

**Predictive Maintenance:**
```
SMART monitoring → Predict failures
Temperature tracking → Thermal issues
Error logs → Emerging problems
Performance trends → Degradation detection
```

---

### 4. Data Integrity

**Corruption Prevention:**
- ECC (Error Correction Code) effectiveness
- Read disturb handling
- Write verify
- Power loss protection

**Critical for:**
- Databases
- File systems
- OS stability
- Application reliability

---

## Ölçülen Metrikler

### 1. Performans Metrikleri

**Sequential Performance:**
```
Bandwidth (MB/s) = Data_Size / Time

Örnek (NVMe SSD):
10GB transferred in 4.2 seconds
Bandwidth = 10000 MB / 4.2 s = 2380 MB/s ✓ EXCELLENT
```

**Random Performance:**
```
IOPS = Operations_Completed / Time

Örnek (Random 4K Read):
180 seconds, 8,640,000 operations
IOPS = 8,640,000 / 180 = 48,000 IOPS ✓ GOOD
```

**Latency:**
```
Average Latency = Total_Time / Operations
P95 Latency = 95th percentile of latency distribution
P99 Latency = 99th percentile (tail latency)

Örnek:
Average: 0.25ms
P95: 0.8ms
P99: 2.5ms ✓ GOOD (low tail latency)
```

---

### 2. Sağlık Metrikleri

**SMART Health Score:**
```
Health Status: PASSED/FAILED (critical metric)

Critical Attributes:
- Reallocated Sectors: 0 (any value >0 is concerning)
- Pending Sectors: 0 (must be 0)
- Uncorrectable Errors: 0 (must be 0)
- Temperature: <70°C
```

**eMMC Life Estimation:**
```
Life Time A/B: 0x01 (0-10% used) → EXCELLENT
               0x05 (40-50% used) → GOOD
               0x09 (80-90% used) → REPLACE SOON
               0x0B (>100% used) → REPLACE NOW
```

**Wear Leveling (SSD):**
```
Wear Level = (Initial - Current) / Initial × 100%

100% = New
50% = Half life
<10% = Replace soon
```

---

### 3. Güvenilirlik Metrikleri

**Data Integrity:**
```
Integrity Score = (Successful Verifications / Total Verifications) × 100%
Target: 100% (zero tolerance for corruption)

Örnek:
10,000 write/read/verify cycles
Checksum mismatches: 0
Integrity: 100% ✓ PASS
```

**Error Rate:**
```
Error Rate = (Failed Operations / Total Operations) × 100%
Target: <0.01% (1 in 10,000 acceptable for some workloads)

Örnek:
1,000,000 I/O operations
Errors: 5
Error Rate: 0.0005% ✓ PASS
```

---

### 4. Sağlık Skoru

```
Storage Health Score = (Performance × 40%) +
                       (SMART Health × 30%) +
                       (Data Integrity × 20%) +
                       (Thermal × 10%)

90-100: EXCELLENT - Full performance, no issues
80-89:  GOOD - Normal operation, minor wear
70-79:  FAIR - Increased wear, monitor closely
60-69:  POOR - Significant issues, plan replacement
<60:    CRITICAL - Imminent failure, replace immediately

Örnek Hesaplama:
Performance: 95/100 (good IOPS and bandwidth)
SMART: 100/100 (all attributes healthy)
Integrity: 100/100 (no corruption)
Thermal: 90/100 (temperature normal)

Total: (95×0.4) + (100×0.3) + (100×0.2) + (90×0.1)
     = 38 + 30 + 20 + 9
     = 97/100 ✓ EXCELLENT
```

---

## Test Örnekleri

### Örnek 1: Temel Storage Testi (2 saat)

```bash
./jetson_storage_test.sh 192.168.55.69 orin password 2
```

**Beklenen Çıktı:**
```
=== PHASE 1: STORAGE SYSTEM ANALYSIS ===
Device: /dev/mmcblk0 (eMMC)
Size: 64GB
Available: 45GB

=== PHASE 2: SEQUENTIAL I/O ===
Sequential Write (1MB): 142 MB/s  ✓ PASS
Sequential Read (1MB): 285 MB/s   ✓ PASS

=== PHASE 3: RANDOM I/O ===
Random 4K Read: 5,200 IOPS        ✓ PASS
Random 4K Write: 2,800 IOPS       ✓ PASS
Mixed 70/30: 4,100 IOPS           ✓ PASS

=== PHASE 4: SUSTAINED STRESS ===
Operations: 2,450
Operations/sec: 0.34              ✓ PASS
Performance degradation: 8%       ✓ PASS (<20%)

=== PHASE 5: FILESYSTEM METADATA ===
Created 5,000 files in 9s         ✓ PASS
Find test: 3.2s                   ✓ PASS
Delete test: 2.8s                 ✓ PASS

=== PHASE 6: SMART HEALTH ===
Health Status: PASSED             ✓ PASS
Life Time A: 0x02 (10-20% used)   ✓ GOOD
Temperature: 52°C                 ✓ PASS
I/O Errors: 0                     ✓ PASS

=== PHASE 7: EXTENDED SMART TEST ===
Extended test initiated (background)
Check status later with: smartctl -a /dev/mmcblk0

=== PHASE 8: SECTOR INTEGRITY ===
Bad sector warnings: 0            ✓ PASS
Read errors: 0                    ✓ PASS
Data integrity: PASSED            ✓ PASS

=== PHASE 9: TEMPERATURE MONITORING ===
Temperature remained normal       ✓ PASS
No thermal throttling detected    ✓ PASS

=== RESULTS ===
Storage Health Score: 94/100 (EXCELLENT)
Performance Rating: GOOD
All tests PASSED ✓
```

---

### Örnek 2: Hızlı Validasyon (30 dakika)

```bash
./jetson_storage_test.sh 192.168.55.69 orin password 0.5
```

**Kullanım:** Üretim hattı hızlı doğrulama
**Kapsamı:**
- Basic sequential I/O
- Quick random test
- SMART health check only

---

### Örnek 3: Extended Burn-in (24 saat)

```bash
./jetson_storage_test.sh 192.168.55.69 orin password 24
```

**Kullanım:** Mission-critical systems validation
**Kapsamı:**
- Extended sustained stress
- Multiple SMART test cycles
- Temperature cycling
- Long-term stability

---

## Hata Tipleri ve Anlamları

### Performance Failures

```
Error: "Sequential write <100 MB/s (expected >120 MB/s)"
Meaning: Storage performance below specification
Possible Causes:
  - Thermal throttling
  - Worn out flash (high write count)
  - Controller issue
  - Interface problem (bad cable for external drives)
Action: Check temperature, SMART attributes, connections
```

### SMART Failures

```
Error: "SMART Health: FAILED"
Meaning: Drive reports internal failure prediction
Critical Attributes:
  - Reallocated_Sector_Count: >0 (bad blocks found)
  - Current_Pending_Sector: >0 (sectors waiting remapping)
  - Offline_Uncorrectable: >0 (unrecoverable bad sectors)
Action: Backup data immediately, replace drive
```

### Sector Errors

```
Error: "Data corruption detected - checksum mismatch"
Meaning: Data read back doesn't match written data
Possible Causes:
  - Bad sectors
  - Defective flash cells
  - Controller error
  - Power loss during write
Action: Run extended SMART test, check error logs, consider replacement
```

### Thermal Issues

```
Error: "Temperature >75°C under load, throttling detected"
Meaning: Storage overheating, performance reduced
Impacts:
  - Reduced IOPS/bandwidth
  - Increased error rate
  - Shorter device lifespan
Action: Improve cooling (heatsink, airflow), reduce workload intensity
```

### Wear Issues (eMMC/SSD)

```
Error: "eMMC Life Time A: 0x0A (90-100% used)"
Meaning: Storage nearing end of life
Expected Behavior:
  - Performance degradation
  - Increased bad sectors
  - Higher error rates
Action: Plan replacement, avoid write-heavy workloads
```

---

## Storage Type Karşılaştırması

### eMMC (Embedded MultiMediaCard)

**Özellikler:**
- Soldered to board (internal)
- Lower cost
- Moderate performance
- Limited write endurance

**Typical Specs (Jetson Orin eMMC 5.1):**
- Sequential Read: 250-300 MB/s
- Sequential Write: 120-150 MB/s
- Random 4K Read: 3,000-6,000 IOPS
- Random 4K Write: 1,500-3,000 IOPS
- Lifetime: ~3000 P/E cycles

**Best For:**
- OS/boot storage
- Light workloads
- Cost-sensitive applications

---

### NVMe SSD (M.2 or PCIe)

**Özellikler:**
- Replaceable
- High performance
- Better endurance
- Higher cost

**Typical Specs (PCIe Gen3 x4):**
- Sequential Read: 3,000-4,000 MB/s
- Sequential Write: 2,000-3,000 MB/s
- Random 4K Read: 50,000-200,000 IOPS
- Random 4K Write: 40,000-150,000 IOPS
- Lifetime: ~600-3000 TBW (Terabytes Written)

**Best For:**
- Database workloads
- Video recording/editing
- High-performance computing
- Data-intensive applications

---

### microSD Card

**Özellikler:**
- Removable
- Lowest cost
- Slowest performance
- Wear concerns

**Typical Specs (UHS-I, Class 10):**
- Sequential Read: 80-95 MB/s
- Sequential Write: 40-90 MB/s
- Random 4K: Poor (500-2,000 IOPS)
- Lifetime: Limited (varies greatly)

**Best For:**
- Additional storage
- Data transfer
- Non-critical data
- Temporary use

---

## Sonuç

Storage testleri, depolama sistemlerinin tüm yönlerini kapsamlı şekilde doğrular:

- **Sequential I/O:** Büyük dosya transfer performansı
- **Random I/O:** Database ve small file performance
- **Sustained Stress:** Uzun süreli kararlılık ve throttling tespiti
- **SMART Health:** Predictive failure detection
- **Sector Integrity:** Data corruption prevention
- **Thermal Management:** Operating temperature validation

Tüm testlerin başarıyla geçilmesi, storage sisteminin:
- Specification'ları karşıladığını
- Data integrity garantisi verdiğini
- Uzun vadeli güvenilir olduğunu
- Production-ready olduğunu kanıtlar.

**Kritik:** Storage hataları geri döndürülemez data loss'a yol açabilir. Düzenli test ve monitoring gereklidir.
