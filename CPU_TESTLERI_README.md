# CPU TESTLERİ - DETAYLI DOKÜMANTASYON

## İçindekiler
1. [Genel Bakış](#genel-bakış)
2. [CPU Test Kategorileri](#cpu-test-kategorileri)
3. [Neden Bu Testler Yapılıyor](#neden-bu-testler-yapılıyor)
4. [Ölçülen Metrikler](#ölçülen-metrikler)
5. [Test Örnekleri](#test-örnekleri)

---

## Genel Bakış

CPU testleri, işlemcinin tüm çekirdeklerinin, instruction pipeline'larının ve cache sistemlerinin maksimum yük altında kararlılığını ve performansını doğrular.

**Test Süresi:** 1-4 saat (ayarlanabilir)
**Test Yoğunluğu:** %100 CPU kullanımı (tüm çekirdekler)
**Otomatik Tespit:** CPU çekirdek sayısı ve model otomatik belirlenir
**Başarı Kriteri:** Performans hedeflerine ulaşma + sıfır crash

---

## CPU Test Kategorileri

### 1. Single-Core Tests - Tek Çekirdek Testleri

**Amaç:** Her bir CPU core'un bireysel performansını test etmek

#### Test 1.1: Prime Number Generation - Asal Sayı Üretimi

**Ne Test Edilir:**
- Integer ALU (Arithmetic Logic Unit) performance
- Branch prediction efficiency
- L1/L2 cache effectiveness
- Single-thread sustained performance

**Neden Bu Test:**
Asal sayı hesaplama:
- Yoğun integer işlemleri
- Çok sayıda conditional branch
- Cache-friendly sequential access
- CPU'nun temel hesaplama yeteneğini test eder

**Nasıl Zorlanır:**
```python
def find_primes_upto(n):
    """Sieve of Eratosthenes - CPU intensive"""
    primes = []
    is_prime = [True] * (n + 1)
    is_prime[0] = is_prime[1] = False

    for i in range(2, n + 1):
        if is_prime[i]:
            primes.append(i)
            # Mark multiples as non-prime
            for j in range(i * i, n + 1, i):
                is_prime[j] = False

    return primes

# Test: 60 saniyede kaç asal sayı bulunabilir?
start = time.time()
primes = find_primes_upto(10_000_000)  # 10 milyon'a kadar
elapsed = time.time() - start
primes_per_minute = len(primes) * (60 / elapsed)
```

**Ölçülen Değerler:**
- Primes calculated per minute
- Cache miss rate
- Branch prediction accuracy
- Instructions per cycle (IPC)

**Beklenen Performans (Jetson Orin):**
- ARM Cortex-A78AE: ~450,000 primes/60s per core
- Comparison baseline: Performance variation <5% between cores

---

#### Test 1.2: Fibonacci Calculation - Fibonacci Hesaplama

**Ne Test Edilir:**
- Recursive function handling
- Stack operations
- Function call overhead
- Return address prediction

**Neden Bu Test:**
Recursive Fibonacci:
- Deep call stack
- Function prologue/epilogue overhead
- Return stack buffer test
- Branch prediction for returns

**Nasıl Zorlanır:**
```python
def fibonacci_recursive(n, memo={}):
    """Recursive Fibonacci with memoization"""
    if n in memo:
        return memo[n]
    if n <= 1:
        return n

    memo[n] = fibonacci_recursive(n-1, memo) + fibonacci_recursive(n-2, memo)
    return memo[n]

# Test: Büyük Fibonacci sayıları hesapla
for i in range(1000, 5000):  # 1000-5000 arası
    result = fibonacci_recursive(i)
    # CPU'nun recursive performance'ı test edilir
```

**Ölçülen Değerler:**
- Recursion depth handled
- Stack operations per second
- Call/return overhead (cycles)
- Memory access latency

---

#### Test 1.3: FFT (Fast Fourier Transform)

**Ne Test Edilir:**
- Floating-point performance (FP64)
- Complex mathematical operations
- Trigonometric functions (sin/cos)
- Memory access patterns (butterfly operations)

**Neden Bu Test:**
FFT:
- Signal processing temel algoritması
- Heavy floating-point load
- Mixed sequential/strided memory access
- Scientific computing representative workload

**Nasıl Zorlanır:**
```python
import numpy as np

def fft_stress_test(size=2**20):  # 1M points
    """FFT stress test with large data"""
    # Generate test signal
    signal = np.random.random(size) + 1j * np.random.random(size)

    # Forward FFT
    fft_result = np.fft.fft(signal)

    # Inverse FFT
    ifft_result = np.fft.ifft(fft_result)

    # Verify accuracy
    error = np.max(np.abs(signal - ifft_result))
    return error < 1e-10  # Accuracy check

# Sürekli FFT operasyonları
for iteration in range(1000):
    success = fft_stress_test()
```

**Ölçülen Değerler:**
- GFLOPS (Floating-point operations/sec)
- FFT throughput (transforms/second)
- Numerical accuracy
- Memory bandwidth utilization

---

#### Test 1.4: Cryptographic Hashing - SHA-256

**Ne Test Edilir:**
- Bitwise operations (AND, OR, XOR, rotate)
- Integer ALU full utilization
- Pipeline efficiency
- Instruction-level parallelism

**Neden Bu Test:**
SHA-256:
- Yoğun bitwise operations
- Fixed execution time (no branches)
- Representative of encryption workloads
- Tests ALU at maximum capacity

**Nasıl Zorlanır:**
```python
import hashlib

def sha256_stress_test(data_size_mb=1000):
    """Continuous SHA-256 hashing"""
    # Generate test data
    test_data = os.urandom(data_size_mb * 1024 * 1024)

    hash_count = 0
    start_time = time.time()

    # Hash sürekli hesapla
    while time.time() - start_time < 60:  # 1 dakika
        # 1MB chunks
        for i in range(0, len(test_data), 1024*1024):
            chunk = test_data[i:i+1024*1024]
            hash_obj = hashlib.sha256(chunk)
            digest = hash_obj.hexdigest()
            hash_count += 1

    hashes_per_second = hash_count / 60
    return hashes_per_second
```

**Ölçülen Değerler:**
- Hashes per second
- Throughput (MB/s)
- CPU utilization (should be 100%)
- Power consumption

---

### 2. Multi-Core Tests - Çok Çekirdekli Testler

**Amaç:** Tüm CPU cores'u eş zamanlı maksimum yük altında test etmek

#### Test 2.1: Parallel Matrix Multiplication

**Ne Test Edilir:**
- Multi-threaded floating-point performance
- Inter-core communication
- Cache coherency protocol
- Memory bandwidth under parallel load

**Neden Bu Test:**
Matrix multiplication:
- Highly parallelizable
- Intensive floating-point ops
- Memory-intensive (large matrices)
- Representative of HPC workloads

**Nasıl Zorlanır:**
```python
import numpy as np
from multiprocessing import Pool, cpu_count

def matrix_multiply_worker(args):
    """Single worker doing matrix multiplication"""
    worker_id, matrix_size = args

    # Large matrices (memory intensive)
    A = np.random.random((matrix_size, matrix_size))
    B = np.random.random((matrix_size, matrix_size))

    # Matrix multiply (CPU intensive)
    C = np.dot(A, B)

    return C.sum()  # Return checksum

# Tüm cores'u kullan
num_cores = cpu_count()  # Örnek: 12 cores
matrix_size = 2048

# Parallel execution
with Pool(processes=num_cores) as pool:
    # Her core bir matrix multiply yapar
    args = [(i, matrix_size) for i in range(num_cores)]
    results = pool.map(matrix_multiply_worker, args)
```

**Ölçülen Değerler:**
- Aggregate GFLOPS (all cores)
- Per-core performance
- Scaling efficiency (vs single-core)
- Memory bandwidth saturation

**Beklenen Performans:**
- Linear scaling up to memory bandwidth limit
- All cores should achieve similar performance
- Total GFLOPS = Single-core GFLOPS × num_cores × efficiency

---

#### Test 2.2: Multi-threaded Prime Search

**Ne Test Edilir:**
- Integer performance across all cores
- Work distribution efficiency
- Cache contention
- False sharing effects

**Nasıl Zorlanır:**
```python
from concurrent.futures import ThreadPoolExecutor

def find_primes_in_range(start, end):
    """Find primes in given range"""
    primes = []
    for num in range(start, end):
        if is_prime(num):
            primes.append(num)
    return primes

# Range'i cores arasında böl
num_cores = 12
search_range = 100_000_000
chunk_size = search_range // num_cores

# Parallel prime search
with ThreadPoolExecutor(max_workers=num_cores) as executor:
    futures = []
    for i in range(num_cores):
        start = i * chunk_size
        end = start + chunk_size
        future = executor.submit(find_primes_in_range, start, end)
        futures.append(future)

    # Collect results
    all_primes = []
    for future in futures:
        all_primes.extend(future.result())
```

**Ölçülen Değerler:**
- Primes found per second (aggregate)
- Load balancing efficiency
- Inter-thread overhead
- Cache miss rate

---

### 3. Per-Core Individual Testing

**Amaç:** Her core'u bağımsız test ederek zayıf/güçlü core tespiti

**Ne Test Edilir:**
- Core-to-core performance variance
- Defective core detection
- Frequency variation per core
- Individual thermal characteristics

**Nasıl Zorlanır:**
```python
import psutil

def test_single_core(core_id):
    """Bind to specific core and run test"""
    # Set CPU affinity to single core
    p = psutil.Process()
    p.cpu_affinity([core_id])

    # Run standardized workload
    start = time.time()
    primes = find_primes_upto(5_000_000)
    elapsed = time.time() - start

    return {
        'core_id': core_id,
        'primes_found': len(primes),
        'time_seconds': elapsed,
        'performance_score': len(primes) / elapsed
    }

# Test her core'u sırayla
results = []
for core_id in range(cpu_count()):
    result = test_single_core(core_id)
    results.append(result)

# Analiz: Performance variance
performances = [r['performance_score'] for r in results]
mean_perf = np.mean(performances)
variance = np.std(performances) / mean_perf * 100  # Coefficient of variation

print(f"Performance variance: {variance:.2f}%")
# Beklenen: <5% variance (uniform cores)
```

**Ölçülen Değerler:**
- Per-core performance score
- Performance uniformity (coefficient of variation)
- Frequency per core (if available)
- Temperature per core

**Başarı Kriteri:**
- Performance variance <5%
- No core performs <90% of average
- All cores stable under load

---

### 4. CPU Instruction Throughput Micro-Benchmarks

**Amaç:** CPU'nun instruction-level performance'ını detaylı test etmek

#### Test 4.1: Integer Operations

**Test Edilen Instruction'lar:**
```assembly
# Integer ADD
for i in range(100_000_000):
    result = a + b  # ADD instruction

# Integer MUL
for i in range(100_000_000):
    result = a * b  # IMUL instruction

# Integer DIV (slowest)
for i in range(100_000_000):
    result = a / b  # IDIV instruction
```

**Ölçülen:**
- Instructions per cycle (IPC) for each operation
- Throughput (operations/second)
- Latency (cycles per operation)

**Beklenen:**
- ADD: 4-6 operations/cycle (modern CPUs)
- MUL: 1-2 operations/cycle
- DIV: 0.1-0.5 operations/cycle (much slower)

---

#### Test 4.2: Floating-Point Operations

**Test Edilen Instruction'lar:**
```python
# FP32 operations
for i in range(100_000_000):
    result = float_a + float_b  # FADD

# FP64 operations
for i in range(100_000_000):
    result = double_a * double_b  # FMUL

# SQRT (expensive)
for i in range(100_000_000):
    result = math.sqrt(float_a)  # FSQRT
```

**Ölçülen:**
- FLOPS (Floating-point operations/second)
- FP32 vs FP64 performance ratio
- SIMD utilization (NEON on ARM)

---

#### Test 4.3: Branch Prediction Test

**Predictable Branches:**
```python
# Pattern: always taken
result = 0
for i in range(100_000_000):
    if True:  # Always taken - predictor learns quickly
        result += 1
# Expected: Near-zero branch mispredictions
```

**Unpredictable Branches:**
```python
# Random pattern - predictor fails
import random
result = 0
for i in range(100_000_000):
    if random.random() > 0.5:  # 50/50 random
        result += 1
# Expected: ~50% misprediction rate
```

**Ölçülen:**
- Branch prediction accuracy (%)
- Misprediction penalty (cycles)
- Performance impact of mispredictions

---

### 5. Memory & Cache Torture Tests

**Amaç:** Memory hierarchy'sinin tüm seviyelerini test etmek

#### Test 5.1: L1 Cache Stress

**Metod:**
```python
# L1 cache size: typically 32-64KB per core
l1_size = 16 * 1024  # 16KB working set (fits in L1)
data = [0] * (l1_size // 4)  # Integer array

# Sequential access (L1 hit)
for iteration in range(10000):
    for i in range(len(data)):
        data[i] = data[i] + 1
```

**Ölçülen:**
- L1 cache hit rate (should be >99%)
- Access latency (1-4 cycles)
- Bandwidth (GB/s)

**Beklenen:** ~1 TB/s L1 bandwidth (modern CPUs)

---

#### Test 5.2: L2 Cache Stress

**Metod:**
```python
# L2 cache: typically 256KB-1MB
l2_size = 512 * 1024  # 512KB (fits in L2, not L1)
data = [0] * (l2_size // 4)

# Sequential access
for iteration in range(1000):
    for i in range(len(data)):
        data[i] = data[i] + 1
```

**Ölçülen:**
- L2 cache hit rate
- Access latency (10-20 cycles)
- Bandwidth

**Beklenen:** ~200-400 GB/s L2 bandwidth

---

#### Test 5.3: Main Memory Stress

**Metod:**
```python
# Large dataset - exceeds all cache levels
mem_size = 64 * 1024 * 1024  # 64MB (goes to main memory)
data = [0] * (mem_size // 4)

# Sequential access
for iteration in range(100):
    for i in range(len(data)):
        data[i] = data[i] + 1
```

**Ölçülen:**
- Memory bandwidth (GB/s)
- Memory latency (100-300 cycles)
- DRAM efficiency

**Beklenen:** ~50-100 GB/s memory bandwidth (depends on LPDDR5)

---

#### Test 5.4: Random Access Pattern

**Metod:**
```python
import random

# Random access defeats prefetcher
size = 64 * 1024 * 1024
data = [0] * (size // 4)
indices = [random.randint(0, len(data)-1) for _ in range(1_000_000)]

# Random access
for idx in indices:
    data[idx] = data[idx] + 1
```

**Ölçülen:**
- Cache miss rate (should be high)
- Average latency (higher than sequential)
- Prefetcher effectiveness

**Beklenen:** >50% cache miss rate, higher latency

---

## Neden Bu Testler Yapılıyor

### 1. Manufacturing Defect Detection

**CPU Üretim Hataları:**
- Defective execution units (ALU, FPU)
- Cache parity errors
- Interconnect defects
- Timing violations

**Test Coverage:**
```
Integer operations → ALU defects
FP operations → FPU defects
Cache tests → Memory controller & SRAM defects
Multi-core tests → Interconnect defects
```

---

### 2. Thermal Validation

**Sıcaklık Yönetimi:**
- Maximum temperature under load (Tj max)
- Thermal throttling detection
- Cooling system effectiveness
- Sustained performance validation

**Test Stratejisi:**
```
Full load on all cores → Maximum heat generation
Temperature monitoring (1s intervals) → Throttle detection
Performance tracking → Degradation measurement

Beklenen:
- Temperature <95°C (throttle threshold)
- Performance degradation <10% if throttling occurs
```

---

### 3. Reliability & Stability

**Long-term Stability:**
- Infant mortality detection (early failures)
- Thermal cycling stress
- Electromigration effects
- Aging simulation

**Test Duration:**
```
1 hour:  Basic functionality
4 hours: Extended stability
24 hours: Burn-in (production systems)
```

---

### 4. Performance Validation

**Specification Verification:**
- Meets advertised clock speeds
- Achieves expected IPC
- Memory bandwidth targets
- Cache hierarchy performance

---

## Ölçülen Metrikler

### 1. Performans Skorları

**Single-Core Score:**
```
Score = (Integer Perf × 30%) +
        (FP Perf × 30%) +
        (Memory Perf × 20%) +
        (Cache Perf × 20%)

Örnek (Jetson Orin Cortex-A78AE):
Integer: 450k primes/60s → 95/100
FP: 25 GFLOPS → 90/100
Memory: 75 GB/s → 85/100
Cache: 98% hit rate → 95/100
Total: 91/100
```

**Multi-Core Score:**
```
Efficiency = (Actual Performance / (Single-Core Perf × Num Cores)) × 100%

Örnek (12 cores):
Single-core: 25 GFLOPS
Expected Multi-core: 25 × 12 = 300 GFLOPS
Actual Multi-core: 270 GFLOPS
Efficiency: 90% (Good - memory bandwidth limited)
```

---

### 2. Termal Metrikler

**Temperature Tracking:**
```
T_avg = Average temperature during test
T_max = Peak temperature
T_throttle = Temperature at which throttling occurs

Örnek:
T_avg: 72°C
T_max: 85°C
T_throttle: 95°C (not reached) ✓ PASS
```

**Throttling Detection:**
```
If (frequency_drop > 10% AND temperature > 80°C):
    Throttling detected
    Health_penalty = 20 points
```

---

### 3. Kararlılık Metrikleri

**Crash/Hang Detection:**
```
Stability = (Test Duration Completed / Test Duration Target) × 100%

Örnek:
Target: 4 hours (14400 seconds)
Completed: 4 hours (14400 seconds)
Crashes: 0
Stability: 100% ✓ PASS
```

**Error Detection:**
```
Computation Errors: 0 (checksums must match)
Cache Parity Errors: 0 (ECC if available)
Thermal Trips: 0 (no emergency shutdowns)
```

---

### 4. Sağlık Skoru

```
CPU Health Score = (Performance × 40%) +
                   (Thermal × 30%) +
                   (Stability × 30%)

95-100: EXCELLENT - Production ready, optimal performance
85-94:  GOOD - Acceptable, minor thermal concerns
75-84:  FAIR - Functional but monitoring needed
<75:    POOR - Failure or severe issues, replacement needed

Örnek:
Performance: 91/100 (good scores across all tests)
Thermal: 95/100 (excellent cooling, no throttling)
Stability: 100/100 (no crashes or errors)
Health Score: 95/100 ✓ EXCELLENT
```

---

## Test Örnekleri

### Örnek 1: Temel CPU Testi (1 saat)

```bash
./jetson_cpu_test.sh 192.168.55.69 orin password 1
```

**Beklenen Çıktı:**
```
=== DETECTED CORE INFORMATION ===
Physical CPU cores: 12
Model: ARM Cortex-A78AE
Expected Single-core: 450,000 primes/60s
Expected Multi-core: 280 GFLOPS

=== SINGLE-CORE TESTS ===
Prime Generation:   460,000 primes/60s  ✓ PASS (102%)
Fibonacci:          5000 levels deep    ✓ PASS
FFT:                28 GFLOPS           ✓ PASS
SHA-256:            850 MB/s            ✓ PASS

=== MULTI-CORE TESTS ===
Matrix Multiply:    270 GFLOPS          ✓ PASS (96% efficiency)
Parallel Primes:    5.2M primes/60s     ✓ PASS
Memory Bandwidth:   78 GB/s             ✓ PASS

=== PER-CORE TESTS ===
Core Performance Variance: 3.2%         ✓ PASS (<5%)
All cores performing within spec        ✓ PASS

=== THERMAL MONITORING ===
Average Temp: 71°C
Peak Temp: 82°C
Throttling: Not detected                ✓ PASS

=== RESULTS ===
CPU Health Score: 95/100 (EXCELLENT)
All tests PASSED ✓
```

---

### Örnek 2: Hızlı Validasyon (30 dakika)

```bash
./jetson_cpu_test.sh 192.168.55.69 orin password 0.5
```

**Kullanım:** Üretim hattı hızlı doğrulama
**Kapsamı:** Basic single + multi-core tests

---

### Örnek 3: Extended Burn-in (4 saat)

```bash
./jetson_cpu_test.sh 192.168.55.69 orin password 4
```

**Kullanım:** Server-grade validasyon
**Kapsamı:** Full test suite + thermal cycling

---

## Hata Tipleri ve Anlamları

### CPU Performance Failures

```
Error: "Single-core performance below 80% of expected"
Meaning: Clock speed issue, defective ALU, or thermal throttling
Action: Check frequency, temperature, power delivery
```

### Core Variance Issues

```
Error: "Core 5 performing at 65% of average"
Meaning: Defective core or asymmetric design
Action: Individual core has issues, may need RMA
```

### Thermal Failures

```
Error: "Thermal throttling detected at 78°C"
Meaning: Insufficient cooling or high TDP
Action: Improve cooling, check thermal paste, verify fan operation
```

### Stability Failures

```
Error: "System hang during multi-core test at iteration 5234"
Meaning: Memory controller issue, power delivery problem, or CPU defect
Action: Check power supply, memory configuration, CPU health
```

---

## Sonuç

CPU testleri, işlemcinin tüm yönlerini kapsamlı şekilde doğrular:

- **Single-core:** Bireysel çekirdek performansı ve kararlılığı
- **Multi-core:** Parallel execution ve scaling efficiency
- **Per-core:** Core uniformity ve defect detection
- **Instructions:** Micro-architecture validation
- **Memory:** Cache hierarchy ve bandwidth
- **Thermal:** Heat management ve throttling behavior

Tüm testlerin başarıyla geçilmesi, CPU'nun:
- Specification'ları karşıladığını
- Tüm cores'un sağlıklı olduğunu
- Termal yönetimin yeterli olduğunu
- Production-ready olduğunu kanıtlar.
