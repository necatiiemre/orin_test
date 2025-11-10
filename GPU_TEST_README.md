# 🎮 JETSON ORIN GPU STRESS TEST - TECHNICAL DOCUMENTATION

## 📋 Table of Contents
1. [Overview](#overview)
2. [GPU Architecture](#gpu-architecture)
3. [Phase 1: VPU Testing](#phase-1-vpu-testing)
4. [Phase 2: CUDA Testing](#phase-2-cuda-testing)
5. [Phase 3: Graphics Testing](#phase-3-graphics-testing)
6. [Phase 4: Combined Testing](#phase-4-combined-testing)
7. [Power & Thermal Monitoring](#power--thermal-monitoring)
8. [Usage Guide](#usage-guide)
9. [Result Interpretation](#result-interpretation)
10. [Troubleshooting](#troubleshooting)

---

## 📖 Overview

### Purpose
**Comprehensive GPU validation** for NVIDIA Jetson Orin, testing all major GPU subsystems: Video Processing (VPU/NVENC), CUDA Compute Cores, Graphics Pipeline (Ampere), and combined workload scenarios.

### Target Hardware
- **GPU:** NVIDIA Ampere Architecture
- **CUDA Cores:** 1792-2048 (varies by SKU)
- **Tensor Cores:** 56-64 (for AI workloads)
- **Video Encoders:** 2× NVENC (H.264, H.265)
- **Video Decoders:** 2× NVDEC
- **Memory:** Shared unified memory with CPU

### Test Philosophy
```
GPU Health = VPU + CUDA + Graphics + Thermal Stability
Coverage = All execution units tested under load
Methodology = Real-world workloads + Stress + Endurance
```

### Key Features
✅ **Multi-Codec Video Encoding** - H.264 and H.265 @ 4K
✅ **CUDA Kernel Diversity** - Compute, memory bandwidth, precision tests
✅ **Headless Graphics** - EGL-based rendering (no display needed)
✅ **Power Monitoring** - Real-time watts tracking
✅ **Thermal Throttling Detection** - Performance degradation alerts
✅ **Concurrent Execution** - All components simultaneously stressed

---

## 🏗️ GPU Architecture

### Jetson Orin AGX GPU Block Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                   NVIDIA Ampere GPU                          │
├───────────────────────┬───────────────────┬─────────────────┤
│   CUDA Cores          │   Tensor Cores    │   RT Cores      │
│   (1792-2048)         │   (56-64)         │   (14-16)       │
│   • FP32 compute      │   • AI/ML (FP16)  │   • Ray tracing │
│   • FP64 compute      │   • INT8 ops      │                 │
│   • INT operations    │                   │                 │
└───────────────────────┴───────────────────┴─────────────────┘
├─────────────────────────────────────────────────────────────┤
│              Shared L2 Cache (4 MB)                         │
├─────────────────────────────────────────────────────────────┤
│                 Memory Controllers                           │
│        (Unified Memory - Shared with CPU)                    │
├────────────────────┬────────────────────────────────────────┤
│   Video Encoders   │   Video Decoders                       │
│   • 2× NVENC       │   • 2× NVDEC                          │
│   • H.264/H.265    │   • H.264/H.265/VP9                   │
│   • Up to 4K60     │   • Up to 8K30                        │
└────────────────────┴────────────────────────────────────────┘
├─────────────────────────────────────────────────────────────┤
│              Graphics Pipeline (Ampere)                      │
│   • Rasterization • Texture Units • ROPs                    │
└─────────────────────────────────────────────────────────────┘
```

### Test Coverage Map

| GPU Component | Test Phase | Duration | Metrics |
|---------------|------------|----------|---------|
| **NVENC (Video Encoder)** | Phase 1 | 40% | FPS, bitrate, quality |
| **CUDA Cores** | Phase 2 | 40% | GFLOPS, bandwidth (GB/s) |
| **Graphics Pipeline** | Phase 3 | 10% | Render FPS, pixel fill rate |
| **All Combined** | Phase 4 | 10% | Concurrent performance |
| **Thermals** | All phases | 100% | Temp (°C), throttling events |

---

## 🎬 Phase 1: VPU Testing (Video Processing Unit)

### Duration
**40%** of total test time (~48 minutes for 2-hour test)

### Purpose
Test **hardware video encoding** capabilities using NVENC (NVIDIA Encoder).

### Why Video Encoding?
```
Real-world GPU usage:
• Security cameras (24/7 encoding)
• Video conferencing
• Live streaming
• Content creation
• Embedded vision systems

NVENC = Dedicated hardware, isolated from CUDA cores
→ Can fail independently ❌
```

---

### Test Architecture

```bash
┌─────────────────────────────────────────────────────────┐
│                  GStreamer Pipeline                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  videotestsrc (Pattern Generator)                      │
│         ↓                                               │
│  3840×2160 @ 30fps (4K UHD)                            │
│         ↓                                               │
│  nvvidconv (Color Space Conversion - GPU accelerated)   │
│         ↓                                               │
│  nvv4l2h264enc OR nvv4l2h265enc (NVENC Hardware)       │
│     • Bitrate: 20 Mbps                                 │
│     • Profile: High                                     │
│     • Preset: medium                                    │
│         ↓                                               │
│  h264parse / h265parse (Stream validation)             │
│         ↓                                               │
│  filesink → /tmp/test_video.mp4                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### Multi-Codec Testing

#### Codec 1: H.264 (AVC)
```bash
gst-launch-1.0 -e \
  videotestsrc pattern=smpte is-live=true ! \
  'video/x-raw,format=I420,width=3840,height=2160,framerate=30/1' ! \
  nvvidconv ! \
  'video/x-raw(memory:NVMM),format=NV12' ! \
  nvv4l2h264enc bitrate=20000000 ! \
  h264parse ! \
  qtmux ! \
  filesink location=/tmp/test_h264.mp4
```

**Why H.264?**
- Most widely used codec
- Hardware support guaranteed
- Baseline for encoder health

#### Codec 2: H.265 (HEVC)
```bash
gst-launch-1.0 -e \
  videotestsrc pattern=circular is-live=true ! \
  'video/x-raw,format=I420,width=3840,height=2160,framerate=30/1' ! \
  nvvidconv ! \
  'video/x-raw(memory:NVMM),format=NV12' ! \
  nvv4l2h265enc bitrate=20000000 ! \
  h265parse ! \
  qtmux ! \
  filesink location=/tmp/test_h265.mp4
```

**Why H.265?**
- 50% better compression than H.264
- More complex encoding (heavier GPU load)
- Tests advanced encoder features

---

### Encoding Patterns

```
Pattern 1: SMPTE Color Bars (H.264)
┌─────────┬─────────┬─────────┬─────────┐
│  WHITE  │ YELLOW  │  CYAN   │  GREEN  │  ← Standard test pattern
├─────────┼─────────┼─────────┼─────────┤
│ MAGENTA │   RED   │  BLUE   │  BLACK  │
└─────────┴─────────┴─────────┴─────────┘

Purpose: Static pattern, easy to encode
→ Baseline performance check

Pattern 2: Circular Motion (H.265)
   ╭───╮      ←──┐
  ╱     ╲        │ Rotating
 │   ●   │       │ circles
  ╲     ╱        │
   ╰───╯      ←──┘

Purpose: Complex motion, worst-case scenario
→ Maximum encoder stress
```

---

### Metrics Collected

```python
# Real-time monitoring
while encoding:
    current_fps = count_frames_per_second()
    bitrate = measure_output_bitrate()
    gpu_load = read_gpu_utilization()

    if current_fps < 28:  # Expected: 30 FPS
        log_warning(f"Frame rate drop: {current_fps} FPS")
        vpu_warnings += 1
```

#### Expected Values
```
4K @ 30 FPS H.264 Encoding:
• Frame Rate: 30 FPS (±1)
• Bitrate: 20 Mbps (target)
• GPU Utilization: 30-50%
• Encoder Latency: <33ms per frame

4K @ 30 FPS H.265 Encoding:
• Frame Rate: 30 FPS (±1)
• Bitrate: 20 Mbps (target)
• GPU Utilization: 40-60%
• Encoder Latency: <50ms per frame
```

---

### Failure Modes

#### 1. Frame Drops
```
Expected: 30 FPS continuous
Actual:   30, 30, 28, 25, 30, 30, 27, ...
                ↑   ↑         ↑
              DROPS!

Causes:
❌ Encoder hardware malfunction
❌ Thermal throttling
❌ Memory bandwidth saturation
❌ Power delivery issue
```

#### 2. Encoding Artifacts
```
Original Frame:  Clean image
Encoded Frame:   Blocky, color banding, macroblock errors

Causes:
❌ Encoder logic error
❌ Memory corruption
❌ Bitstream generation fault
```

#### 3. Pipeline Stall
```
Pipeline runs for 30 seconds → FREEZE → No output

Causes:
❌ NVENC hardware hang
❌ Memory leak
❌ Driver crash
```

---

### Scoring
```bash
if [ $VPU_WARNINGS -eq 0 ] && [ $ENCODING_ERRORS -eq 0 ]; then
    VPU_SCORE=100  # ✅ Perfect
elif [ $VPU_WARNINGS -le 5 ]; then
    VPU_SCORE=80   # ✅ Acceptable (minor drops)
else
    VPU_SCORE=0    # ❌ Failed
fi
```

---

## ⚡ Phase 2: CUDA Testing

### Duration
**40%** of total test time (~48 minutes for 2-hour test)

### Purpose
Test **CUDA compute cores** through diverse kernel workloads.

### Why Multiple Kernel Types?
```
CUDA cores handle different operations:
• Matrix math (AI/ML workloads)
• Memory transfers (bandwidth)
• Floating-point precision (FP16, FP32, FP64)
• Integer operations

Single test = incomplete coverage ❌
Multiple tests = comprehensive ✅
```

---

### Test 2.1: Matrix Multiplication (GEMM)

```cuda
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
```

**Configuration:**
```
Matrix Size: 2048 × 2048 (FP32)
Grid: 64 × 64 blocks
Threads per Block: 32 × 32 = 1024 threads
Total Threads: 4,194,304 threads

Operations: 2048³ × 2 = 17.2 billion FLOPs per iteration
```

**Metrics:**
```bash
GFLOPS = (Operations / Time) / 1e9

Example:
17.2 billion ops in 50ms = 344 GFLOPS

Jetson Orin theoretical peak: ~5,000 GFLOPS (FP32)
Achievable in real code: 1,000-2,000 GFLOPS (20-40% efficiency)
```

---

### Test 2.2: Memory Bandwidth

```cuda
// Host to Device transfer
cudaMemcpy(d_data, h_data, SIZE, cudaMemcpyHostToDevice);
auto start = std::chrono::high_resolution_clock::now();
// ... measure ...
auto end = std::chrono::high_resolution_clock::now();
bandwidth_h2d = SIZE / elapsed_seconds / 1e9;  // GB/s

// Device to Host transfer
cudaMemcpy(h_data, d_data, SIZE, cudaMemcpyDeviceToHost);
bandwidth_d2h = SIZE / elapsed_seconds / 1e9;  // GB/s

// Device to Device copy
cudaMemcpy(d_data2, d_data1, SIZE, cudaMemcpyDeviceToDevice);
bandwidth_d2d = SIZE / elapsed_seconds / 1e9;  // GB/s
```

**Expected Values:**
```
Jetson Orin (Unified Memory Architecture):

Host → Device: 25-35 GB/s   (PCIe-like speed)
Device → Host: 25-35 GB/s
Device → Device: 150-200 GB/s (internal bandwidth)

Theoretical max: ~200 GB/s (LPDDR5-6400)
```

---

### Test 2.3: Precision Tests

#### FP16 (Half Precision)
```cuda
__global__ void fp16_kernel(__half *data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        __half val = data[idx];
        val = __hadd(val, __float2half(1.0f));  // FP16 add
        data[idx] = val;
    }
}
```

**Why FP16?**
- 2× throughput vs FP32
- AI/ML standard precision
- Tensor Core acceleration

#### FP32 (Single Precision)
```cuda
__global__ void fp32_kernel(float *data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        data[idx] = data[idx] * 2.0f + 1.0f;  // FMAC
    }
}
```

**Why FP32?**
- Standard GPU precision
- Graphics rendering
- General compute

#### FP64 (Double Precision)
```cuda
__global__ void fp64_kernel(double *data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        data[idx] = data[idx] * 2.0 + 1.0;  // Double precision
    }
}
```

**Why FP64?**
- Scientific computing
- High-precision requirements
- Typically 1/32 speed of FP32 on consumer GPUs

---

### Expected Performance Ratios
```
Relative Throughput (Jetson Orin):

FP16: 4,000-8,000 GFLOPS (with Tensor Cores)
FP32: 2,000-4,000 GFLOPS (baseline)
FP64:   60-120 GFLOPS   (1/32 of FP32)

FP16:FP32:FP64 ≈ 4:2:0.06
```

---

### Test 2.4: Concurrent Kernel Execution

```cpp
// Launch multiple kernels concurrently
cudaStream_t stream1, stream2, stream3;
cudaStreamCreate(&stream1);
cudaStreamCreate(&stream2);
cudaStreamCreate(&stream3);

// All run simultaneously on different SMs
matrixMul<<<grid, block, 0, stream1>>>(A1, B1, C1, N);
vectorAdd<<<grid, block, 0, stream2>>>(X1, Y1, Z1, N);
reduction<<<grid, block, 0, stream3>>>(data, result, N);

cudaDeviceSynchronize();
```

**Why Concurrent?**
- Tests SM (Streaming Multiprocessor) scheduler
- Real-world workloads are rarely sequential
- Detects resource contention issues

---

### CUDA Scoring
```bash
if [ $CUDA_GFLOPS -ge $EXPECTED_GFLOPS ] && \
   [ $MEMORY_BW_GBPS -ge $EXPECTED_BW ] && \
   [ $CUDA_ERRORS -eq 0 ]; then
    CUDA_SCORE=100  # ✅ Excellent
else
    CUDA_SCORE=0    # ❌ Failed
fi
```

---

## 🖼️ Phase 3: Graphics Testing

### Duration
**10%** of total test time (~12 minutes for 2-hour test)

### Purpose
Test **graphics pipeline** (rasterization, texture units, ROPs) through EGL-based headless rendering.

### Why Headless?
```
Jetson in production:
• Often no display attached
• Headless server mode
• Docker containers

EGL = OpenGL ES without X11/Wayland
→ Can test graphics without monitor ✅
```

---

### EGL Initialization

```c
// Create EGL context (no display needed!)
EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
eglInitialize(display, NULL, NULL);

EGLConfig config;
eglChooseConfig(display, configAttribs, &config, 1, &numConfigs);

EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, ctxAttribs);

// Create offscreen surface (render to memory)
EGLSurface surface = eglCreatePbufferSurface(display, config, pbufferAttribs);

eglMakeCurrent(display, surface, surface, context);
```

---

### OpenGL ES Rendering Test

```c
// Vertex shader
const char* vertexShaderSource = R"(
    #version 320 es
    layout(location = 0) in vec3 aPos;
    layout(location = 1) in vec3 aColor;
    out vec3 ourColor;
    uniform mat4 transform;

    void main() {
        gl_Position = transform * vec4(aPos, 1.0);
        ourColor = aColor;
    }
)";

// Fragment shader
const char* fragmentShaderSource = R"(
    #version 320 es
    precision mediump float;
    in vec3 ourColor;
    out vec4 FragColor;

    void main() {
        FragColor = vec4(ourColor, 1.0);
    }
)";

// Render loop
for (int frame = 0; frame < 10000; frame++) {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Update transform (rotation)
    glUniformMatrix4fv(transformLoc, 1, GL_FALSE, glm::value_ptr(transform));

    // Draw geometry
    glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_INT, 0);

    glFinish();  // Wait for completion

    frame_count++;
}
```

---

### Graphics Metrics

```
Render Resolution: 1920×1080 (Full HD)
Geometry: 100,000 triangles per frame
Textures: Multiple 2K textures
Target FPS: 60 FPS

Measured:
• Render time per frame (ms)
• Vertex throughput (vertices/sec)
• Pixel fill rate (pixels/sec)
• Texture sampling rate
```

**Expected Values:**
```
Frame Time: <16ms (60 FPS)
Vertex Throughput: 1-2 billion vertices/sec
Pixel Fill Rate: 10-20 gigapixels/sec
```

---

### Graphics Failure Modes

#### 1. Render Artifacts
```
Expected: Smooth gradient colors
Actual: Color banding, z-fighting, texture corruption

Causes:
❌ Rasterizer defect
❌ Texture unit failure
❌ ROP (Render Output Unit) error
```

#### 2. Performance Degradation
```
Frame 1-100: 16ms each (60 FPS) ✅
Frame 101-200: 32ms each (30 FPS) ❌ Sudden drop!

Causes:
❌ Thermal throttling
❌ Memory fragmentation
❌ Driver issue
```

#### 3. Context Creation Failure
```
eglCreateContext() returns EGL_NO_CONTEXT

Causes:
❌ Graphics hardware disabled
❌ Driver not loaded
❌ Out of GPU memory
```

---

## 🔥 Phase 4: Combined Testing

### Duration
**10%** of total test time (~12 minutes for 2-hour test)

### Purpose
Run **VPU + CUDA + Graphics simultaneously** to test:
- Resource contention
- Power delivery under maximum load
- Thermal management at peak
- Scheduler robustness

---

### Combined Workload Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Combined GPU Load (All Active)              │
├────────────────┬─────────────────────┬───────────────────┤
│   Thread 1     │     Thread 2        │    Thread 3       │
│                │                     │                   │
│   NVENC        │   CUDA Kernels      │   OpenGL ES       │
│   Encoding     │   Matrix Multiply   │   Rendering       │
│   4K H.265     │   Memory Bandwidth  │   1080p60         │
│                │   FP32 Compute      │   Textured Geo    │
│                │                     │                   │
│   GPU: 30%     │   GPU: 50%          │   GPU: 20%        │
└────────────────┴─────────────────────┴───────────────────┘
         │                 │                    │
         └─────────────────┴────────────────────┘
                           │
                  Combined: ~100% GPU
                  Power: 50-60W
                  Temp: 70-85°C
```

---

### Expected Behavior

```
Normal (Healthy GPU):
• All three workloads run simultaneously ✅
• No performance degradation <10% ✅
• Temperature stable at 75-85°C ✅
• No component failures ✅

Defective GPU:
• One or more workloads stall ❌
• >30% performance drop ❌
• Temperature >95°C or thermal shutdown ❌
• Driver crashes ❌
```

---

### Contention Points

#### 1. Memory Bandwidth
```
VPU: Reads raw video frames (30 MB/s @ 4K30)
CUDA: Reads/writes matrices (50 GB/s)
Graphics: Reads textures, writes framebuffer (10 GB/s)

Total bandwidth demand: ~60 GB/s
Available: 200 GB/s
Utilization: 30% → Safe ✅

If combined >80% → Performance loss ❌
```

#### 2. Power Budget
```
Individual Components:
NVENC: 5-8W
CUDA: 30-40W
Graphics: 8-12W

Combined: 43-60W (peak)
TDP limit: 60W (varies by SKU)

If exceeds TDP → Throttling ❌
```

#### 3. Thermal Limits
```
Temperature rise:
VPU only: +15°C
CUDA only: +30°C
Graphics only: +10°C

Combined: +40-45°C → May hit 85°C throttle point ⚠️
```

---

## 🌡️ Power & Thermal Monitoring

### Real-Time Monitoring

```bash
# GPU temperature
cat /sys/devices/virtual/thermal/thermal_zone1/temp

# GPU frequency
cat /sys/devices/gpu.0/devfreq/17000000.gv11b/cur_freq

# Power consumption (if available via INA3221)
cat /sys/bus/i2c/drivers/ina3221x/1-0040/iio:device0/in_power0_input
```

---

### Throttling Detection

```python
def detect_throttling():
    freq_max = 1300500  # kHz (max GPU frequency)
    freq_current = read_gpu_frequency()

    if freq_current < freq_max * 0.9:  # <90% of max
        log_warning(f"GPU throttling: {freq_current}kHz (max: {freq_max}kHz)")
        return True

    return False
```

---

### Expected Thermal Profile

```
Time:     0min → 5min → 10min → 20min → 60min
Temp:     35°C → 55°C → 68°C  → 75°C  → 78°C (stable)
Frequency: 100% → 100% → 100%  → 100%  → 100%

Good Cooling: Stabilizes at 75-80°C, no throttling ✅
Poor Cooling: Exceeds 85°C, throttles to 85% frequency ❌
```

---

## 🚀 Usage Guide

### Basic Usage
```bash
# Default: 2-hour test
./jetson_gpu_test.sh 192.168.55.69 orin password 2

# Quick test: 30 minutes
./jetson_gpu_test.sh 192.168.55.69 orin password 0.5

# Extended: 4 hours
./jetson_gpu_test.sh 192.168.55.69 orin password 4
```

---

## 📊 Result Interpretation

### Pass Criteria
```
✅ PASS if:
  - VPU: 0 encoding errors, sustained 30 FPS
  - CUDA: GFLOPS within 80% of expected
  - Graphics: Sustained 60 FPS rendering
  - Combined: All components functional
  - Thermal: No throttling events
  - No crashes or hangs

❌ FAIL if:
  - Any component fails
  - >5 throttling events
  - Performance <60% expected
  - System crash
```

---

## 🔧 Troubleshooting

### Issue: Low CUDA Performance

**Solution:**
```bash
# Check GPU clock locked
sudo jetson_clocks

# Verify CUDA available
nvidia-smi  # Should show GPU
```

### Issue: Video Encoding Fails

**Solution:**
```bash
# Check GStreamer plugins
gst-inspect-1.0 nvv4l2h264enc

# Verify video encoder
ls /dev/nvhost-* # Should list nvenc devices
```

---

**END OF GPU TEST DOCUMENTATION**
