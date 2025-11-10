# GPU TESTLERİ - DETAYLI DOKÜMANTASYON

## İçindekiler
1. [Genel Bakış](#genel-bakış)
2. [GPU Bileşenleri ve Test Alanları](#gpu-bileşenleri-ve-test-alanları)
3. [Test Metodları](#test-metodları)
4. [Neden Bu Testler Yapılıyor](#neden-bu-testler-yapılıyor)
5. [Ölçülen Metrikler](#ölçülen-metrikler)
6. [Test Örnekleri](#test-örnekleri)

---

## Genel Bakış

GPU testleri, Jetson Orin'in grafik işlem biriminin tüm alt sistemlerini maksimum yük altında test ederek donanımın kararlılığını, performansını ve termal yönetimini doğrular.

**Test Süresi:** 2-4 saat (ayarlanabilir)
**Test Yoğunluğu:** Maksimum (%100 GPU kullanımı)
**Başarı Kriteri:** Sıfır hata toleransı

---

## GPU Bileşenleri ve Test Alanları

### 1. VPU (Video Processing Unit) - Video İşleme Birimi

**Ne Test Edilir:**
- H.264 ve H.265 video codec'leri
- 4K çözünürlükte video encoding (kodlama)
- Video decoding (kod çözme) işlemleri
- Multi-codec eş zamanlı işlem

**Neden Test Edilir:**
VPU, video işleme ve yapay zeka uygulamalarında yoğun kullanılır. Kusurlu VPU:
- Video akışlarında bozulmalara
- Yapay zeka modellerinde hatalara
- Sistem çökmelerine neden olur

**Nasıl Zorlanır:**
```bash
# 4K video sürekli encode edilir
gst-launch-1.0 videotestsrc pattern=ball ! \
    video/x-raw,width=3840,height=2160,framerate=30/1 ! \
    nvv4l2h264enc bitrate=30000000 ! \
    h264parse ! qtmux ! filesink location=output.mp4
```

**Ölçülen Değerler:**
- Encoding hızı (FPS - frames per second)
- Codec switch süreleri
- Bellek kullanımı
- Termal performans
- Hata oranı (bozuk frame sayısı)

---

### 2. CUDA Cores - Genel Amaçlı Hesaplama Birimleri

**Ne Test Edilir:**
- Compute kernels (hesaplama çekirdekleri)
- Memory bandwidth (bellek bant genişliği)
  - Host to Device (H2D) - CPU'dan GPU'ya
  - Device to Host (D2H) - GPU'dan CPU'ya
  - Device to Device (D2D) - GPU içi
- Farklı hassasiyetler:
  - FP16 (Half precision - 16-bit)
  - FP32 (Single precision - 32-bit)
  - FP64 (Double precision - 64-bit)
- Concurrent kernel execution (eş zamanlı çekirdek çalıştırma)

**Neden Test Edilir:**
CUDA cores, makine öğrenimi, bilimsel hesaplama ve genel GPU computing için kritiktir. Hatalı CUDA cores:
- ML model inference'da yanlış sonuçlar
- Bilimsel hesaplamalarda doğruluk kaybı
- Performans düşüşü
- Rastgele hesaplama hataları

**Nasıl Zorlanır:**
```c
// Matrix multiplication ile tüm CUDA cores aktif edilir
__global__ void matrixMul(float *A, float *B, float *C, int N) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < N && col < N) {
        float sum = 0.0f;
        for (int k = 0; k < N; k++) {
            sum += A[row * N + k] * B[k * N + col];
        }
        C[row * N + col] = sum;
    }
}

// Binlerce thread ile sürekli çalıştırılır
dim3 blocks(N/16, N/16);
dim3 threads(16, 16);
matrixMul<<<blocks, threads>>>(d_A, d_B, d_C, N);
```

**Ölçülen Değerler:**
- GFLOPS (Giga Floating Point Operations Per Second)
- Memory bandwidth (GB/s)
- Kernel execution time (microseconds)
- Throughput (operations/second)
- Precision accuracy (hassasiyet doğruluğu)
- Concurrent execution efficiency

---

### 3. Graphics Pipeline (GFX) - Grafik İşlem Hattı

**Ne Test Edilir:**
- EGL (Embedded Graphics Library) headless rendering
- OpenGL ES compute shaders
- Texture processing
- Vertex/Fragment shaders
- Frame buffer operations

**Neden Test Edilir:**
Graphics pipeline, görselleştirme ve rendering işlemleri için kullanılır. Kusurlu grafik hattı:
- Ekran çıktısında bozulmalar
- 3D rendering hatalarına
- Görselleştirme uygulamalarında sorunlar

**Nasıl Zorlanır:**
```c
// Headless EGL context oluşturulur
EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
eglInitialize(display, NULL, NULL);

// Compute shader ile sürekli hesaplama
const char* computeShader = R"(
    #version 310 es
    layout(local_size_x = 16, local_size_y = 16) in;

    void main() {
        // Yoğun matematiksel işlemler
        vec4 data = imageLoad(inputImage, ivec2(gl_GlobalInvocationID.xy));
        vec4 result = complexComputation(data);
        imageStore(outputImage, ivec2(gl_GlobalInvocationID.xy), result);
    }
)";
```

**Ölçülen Değerler:**
- Frame rate (FPS)
- Rendering latency (ms)
- Shader compilation time
- GPU memory usage
- Context switch overhead

---

### 4. Combined Test - Kombine Yük Testi

**Ne Test Edilir:**
Tüm GPU bileşenleri eş zamanlı:
- VPU: Video encoding/decoding
- CUDA: Matrix operations
- Graphics: Headless rendering
- Memory: Concurrent transfers

**Neden Test Edilir:**
Gerçek dünya uygulamalarında GPU'nun tüm birimleri aynı anda kullanılabilir. Bu test:
- Kaynak çakışmalarını (resource contention)
- Termal limitleri
- Power budget yönetimini
- Scheduler etkinliğini test eder

**Nasıl Zorlanır:**
```bash
# Paralel işlemler başlatılır
(video_encode_loop) &     # VPU yükü
(cuda_matrix_loop) &      # CUDA yükü
(graphics_render_loop) &  # Graphics yükü
(memory_transfer_loop) &  # Memory yükü

# Tümü eş zamanlı çalışır
wait
```

**Ölçülen Değerler:**
- Combined throughput
- Resource scheduling efficiency
- Memory bandwidth saturation
- Thermal throttling detection
- Power consumption
- Overall stability

---

## Test Metodları

### Test 1: Sürekli Video Encoding
**Amaç:** VPU'yu maksimum yük altında tutmak

**Metod:**
1. Sentetik 4K video kaynağı oluştur (videotestsrc)
2. H.264/H.265 codec'leri ile sürekli encode et
3. Codec'ler arasında geçiş yap
4. Hata kontrolü yap (frame corruption)

**Başarı Kriteri:**
- %0 frame loss
- Consistent framerate (30 FPS)
- Sıfır encoding error

---

### Test 2: CUDA Matrix Multiplication Stress
**Amaç:** CUDA cores'u %100 kullanımda tutmak

**Metod:**
1. Büyük matrisler oluştur (4096x4096)
2. Sürekli matrix multiplication
3. Farklı hassasiyetlerde test (FP16, FP32, FP64)
4. Sonuçları doğrula (checksums ile)

**Başarı Kriteri:**
- Hesaplama doğruluğu %100
- GFLOPS hedefine ulaşma
- Sıfı computational error

---

### Test 3: Memory Bandwidth Saturation
**Amaç:** GPU bellek sistemini zorlamak

**Metod:**
1. Büyük veri transferleri (GB seviyesinde)
2. H2D, D2H, D2D tüm yönler test edilir
3. Concurrent memory operations
4. Bandwidth measurement

**Başarı Kriteri:**
- Beklenen bandwidth'e ulaşma (GB/s)
- Sıfır memory transfer error
- Consistent performance

---

### Test 4: Thermal Stress Test
**Amaç:** GPU'yu termal limitlerde çalıştırma

**Metod:**
1. Tüm GPU bileşenleri maksimum yük
2. Sıcaklık 1 saniyede bir ölçülür
3. Thermal throttling tespiti
4. Performans düşüşü analizi

**Başarı Kriteri:**
- Sıcaklık < 85°C (critical limit)
- Throttling varsa minimal olmalı
- Performans degradation < %5

---

## Neden Bu Testler Yapılıyor

### 1. Üretim Kalite Kontrolü
GPU üretim hataları:
- Defective CUDA cores
- Memory interface sorunları
- Thermal interface problemleri
- Power delivery hatası

Bu testler üretim hatalarını erkenden yakalar.

### 2. Kararlılık Doğrulaması
Uzun süreli yük altında:
- Termal yönetim etkinliği
- Power budget yönetimi
- Error correction mechanisms
- System stability

### 3. Performans Validasyonu
GPU'nun belirtilen performansa ulaşıp ulaşmadığı:
- GFLOPS targets
- Memory bandwidth targets
- Video encoding speeds
- Graphics rendering performance

### 4. Gerçek Dünya Simülasyonu
Uygulamalarda GPU kullanımı:
- AI inference workloads
- Video processing pipelines
- Scientific computing
- Graphics rendering

---

## Ölçülen Metrikler

### Performans Metrikleri

#### CUDA Performance
```
GFLOPS (FP32) = (Operations × Iterations) / (Time × 10^9)
Örnek: 2048 GFLOPS @ FP32
```

#### Memory Bandwidth
```
Bandwidth = (Data_Size_Bytes) / (Transfer_Time_Seconds × 10^9)
Örnek: 204.8 GB/s (theoretical max)
```

#### Video Encoding
```
Encoding Speed = Frames_Encoded / Time
Örnek: 30 FPS @ 4K H.265
```

### Termal Metrikler
```
GPU Temperature: 45-85°C range
Thermal throttling: Detection at >80°C
Performance degradation: <5% acceptable
```

### Kararlılık Metrikleri
```
Error Rate = (Failed_Operations / Total_Operations) × 100
Target: 0% error rate
```

### Sağlık Skoru
```
GPU Health Score = (Performance × 40%) +
                   (Thermal × 30%) +
                   (Stability × 30%)

90-100: Excellent
80-89:  Good
70-79:  Fair
<70:    Poor (hardware issue suspected)
```

---

## Test Örnekleri

### Örnek 1: Temel GPU Testi (2 saat)
```bash
./jetson_gpu_test.sh 192.168.55.69 orin password 2
```

**Beklenen Çıktı:**
```
PHASE 1 (VPU): PASS - 216000 frames encoded
PHASE 2 (CUDA): PASS - 2048 GFLOPS achieved
PHASE 3 (Graphics): PASS - 60 FPS sustained
PHASE 4 (Combined): PASS - All systems stable

GPU Health Score: 95/100 (EXCELLENT)
```

### Örnek 2: Hızlı Validasyon (10 dakika)
```bash
./jetson_gpu_test.sh 192.168.55.69 orin password 0.17
```

**Kullanım Senaryosu:**
Üretim hattında hızlı donanım kontrolü

### Örnek 3: Uzun Süreli Stability Testi (24 saat)
```bash
./jetson_gpu_test.sh 192.168.55.69 orin password 24
```

**Kullanım Senaryosu:**
Kritik sistemler için burn-in testi

---

## Hata Tipleri ve Anlamları

### VPU Hataları
```
Frame corruption detected: Video memory hatası
Encoding timeout: VPU clock problemi
Codec switch failure: VPU scheduler sorunu
```

### CUDA Hataları
```
Computation mismatch: CUDA core defect
Memory allocation failed: GPU memory problem
Kernel timeout: Infinite loop or hang
```

### Termal Hataları
```
Temperature >85°C: Cooling yetersiz
Thermal throttling: Power/thermal limit
Performance drop >10%: Thermal paste problemi
```

### Kombinasyon Hataları
```
Resource contention: Scheduler sorun
Power budget exceeded: Power delivery hatası
System instability: Multiple hardware issues
```

---

## Sonuç

GPU testleri, Jetson Orin'in grafik ve hesaplama yeteneklerinin eksiksiz validasyonunu sağlar. Testler:

- **VPU:** Video işleme donanımını zorlar
- **CUDA:** Genel amaçlı hesaplamayı test eder
- **Graphics:** Rendering pipeline'ı doğrular
- **Combined:** Gerçek dünya yüklerini simüle eder

Tüm testlerin başarıyla geçilmesi, GPU donanımının üretim kalitesinde ve belirtilen performansta olduğunu garanti eder.
