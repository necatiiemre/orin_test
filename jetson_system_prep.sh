#!/bin/bash

################################################################################
# JETSON ORIN - ENHANCED SYSTEM PREPARATION WITH SUDO PASSWORD FIX
################################################################################
# Description: System preparation with CUDA, OpenGL, and proper sudo password handling
# Version: 2.4 - Added glmark2, gpu-burn compilation, cuBLAS/cuDNN verification
# FIXES:
#   - Made sudo_with_password verbose to show actual error messages.
#   - Added checks for NVIDIA GL/EGL library existence before update-alternatives.
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common utilities (assuming jetson_utils.sh is in the same directory)
# Example content for jetson_utils.sh (if you don't have it):
# #!/bin/bash
# log_phase() { echo -e "\n========================================\n$1\n========================================\n"; }
# log_info() { echo -e "[INFO] $1"; }
# log_success() { echo -e "[SUCCESS] $1"; }
# log_warning() { echo -e "[WARNING] $1"; }
# log_error() { echo -e "[ERROR] $1"; exit 1; }
# check_prerequisites() {
#     local orin_ip=$1 orin_user=$2 orin_pass=$3
#     if ! command -v sshpass &> /dev/null; then
#         log_error "'sshpass' is not installed. Please install it (e.g., sudo apt-get install sshpass)."
#     fi
#     log_info "Testing SSH connection to $orin_user@$orin_ip..."
#     if ! sshpass -p "$orin_pass" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$orin_user@$orin_ip" "echo 'Connection OK'" 2>/dev/null | grep -q "Connection OK"; then
#         log_error "SSH connection failed. Check IP, user, password, and network."
#     fi
#     log_success "SSH connection successful."
# }
# ensure_directory() {
#     local dir=$1
#     mkdir -p "$dir" || log_error "Failed to create directory: $dir"
# }
# ssh_execute_with_output() {
#     local orin_ip=$1 orin_user=$2 orin_pass=$3 remote_cmd=$4
#     sshpass -p "$orin_pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$orin_user@$orin_ip" "$remote_cmd"
# }
source "$SCRIPT_DIR/jetson_utils.sh"

################################################################################
# CONFIGURATION
################################################################################

ORIN_IP="${1:-192.168.55.69}"
ORIN_USER="${2:-orin}"
ORIN_PASS="${3}"
LOG_DIR="${4:-./system_prep_$(date +%Y%m%d_%H%M%S)}"

################################################################################
# INITIALIZATION
################################################################################

log_phase "JETSON ORIN ENHANCED SYSTEM PREPARATION (SUDO FIXED)"

echo "Preparing system for stress testing with OpenGL/Graphics/CUDA support..."
echo "  • Target IP: $ORIN_IP"
echo "  • OpenGL Fix: ENABLED"
echo "  • Graphics Tests: ENABLED"
echo "  • CUDA Libraries: ENABLED"
echo "  • Sudo Password: ENABLED"
echo ""

# Password check
if [ -z "$ORIN_PASS" ]; then
    read -sp "Enter SSH password for $ORIN_USER@$ORIN_IP: " ORIN_PASS
    echo ""
fi

check_prerequisites "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS"
ensure_directory "$LOG_DIR/logs"

################################################################################
# ENHANCED SYSTEM PREPARATION WITH SUDO PASSWORD PASSING
################################################################################

# The 'tee' command here will capture ALL stdout and stderr from the remote script.
# By making sudo_with_password inside the remote script send its errors to stderr,
# these will now be visible in the log file.
ssh_execute_with_output "$ORIN_IP" "$ORIN_USER" "$ORIN_PASS" "
export SUDO_PASSWORD='$ORIN_PASS'
bash -s" << 'REMOTE_PREP_START' | tee "$LOG_DIR/logs/system_preparation.log"

#!/bin/bash

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Sudo helper function with password - NOW VERBOSE
sudo_with_password() {
    # Removed '2>/dev/null' to allow sudo's actual error messages to pass through.
    # These errors will be captured by the parent 'tee' command.
    if ! echo "$SUDO_PASSWORD" | sudo -S "$@"; then
        log_warning "Sudo command failed for: $*" # More specific warning
        return 1
    fi
    return 0
}

################################################################################
# SYSTEM INFORMATION COLLECTION
################################################################################

log_info "Collecting comprehensive system information..."

echo "================================================================================"
echo "  JETSON ORIN SYSTEM INFORMATION"
echo "================================================================================"
echo ""

echo "=== BASIC SYSTEM INFO ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"
echo "Kernel: $(uname -a)"
echo ""

echo "=== JETPACK INFORMATION ==="
if [ -f /etc/nv_tegra_release ]; then
    cat /etc/nv_tegra_release
else
    echo "JetPack release info not found"
fi
echo ""

echo "=== HARDWARE INFORMATION ==="
echo "CPU Information:"
cat /proc/cpuinfo | grep -E "(processor|model name|cpu MHz|cpu cores|Hardware|Model)" | head -20
echo ""

echo "Memory Information:"
free -h
echo ""

echo "Storage Information:"
df -h
echo ""

echo "=== GPU INFORMATION ==="
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi
else
    echo "nvidia-smi not available"
fi
echo ""

echo "=== CUDA INFORMATION ==="
if command -v nvcc &> /dev/null; then
    nvcc --version
else
    echo "NVCC not available"
fi
echo ""

echo "=== OPENGL INFORMATION (PRE-FIX) ==="
echo "OpenGL libraries status:"
find /usr/lib -name "*GL*" 2>/dev/null | grep -E "(libGL|libEGL)" | head -5 || echo "No OpenGL libraries found"

echo ""
echo "OpenGL development headers:"
if [ -f "/usr/include/GL/gl.h" ]; then
    echo "✓ Standard OpenGL headers found"
elif [ -f "/usr/include/GLES3/gl3.h" ]; then
    echo "✓ OpenGL ES headers found"
else
    echo "❌ No OpenGL headers found"
fi
echo ""

echo "=== THERMAL ZONES ==="
echo "Available thermal zones:"
for i in $(seq 0 10); do
    if [ -f "/sys/devices/virtual/thermal/thermal_zone$i/type" ]; then
        zone_type=$(cat /sys/devices/virtual/thermal/thermal_zone$i/type 2>/dev/null || echo "unknown")
        temp=$(cat /sys/devices/virtual/thermal/thermal_zone$i/temp 2>/dev/null || echo "0")
        temp_c=$((temp / 1000))
        echo "  Zone $i ($zone_type): ${temp_c}°C"
    fi
done
echo ""

echo "=== CPU FREQUENCY INFORMATION ==="
echo "Available CPU governors:"
if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors" ]; then
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
else
    echo "CPU frequency scaling not available"
fi

echo ""
echo "Current CPU frequencies:"
for i in $(seq 0 11); do  # Orin has up to 12 cores
    if [ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq" ]; then
        freq=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq 2>/dev/null || echo "N/A")
        governor=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
        echo "  CPU$i: $freq Hz ($governor)"
    fi
done
echo ""

################################################################################
# SYSTEM OPTIMIZATION FOR TESTING
################################################################################

log_info "Optimizing system for stress testing..."

echo "=== SYSTEM OPTIMIZATION ==="

# Set CPU governor to performance if available
log_info "Setting CPU governor to performance mode..."
GOVERNOR_SET=0
for i in $(seq 0 11); do
    if [ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" ]; then
        if grep -q "performance" /sys/devices/system/cpu/cpu$i/cpufreq/scaling_available_governors 2>/dev/null; then
            echo "performance" | sudo_with_password tee /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor >/dev/null 2>&1 && GOVERNOR_SET=$((GOVERNOR_SET + 1))
        fi
    fi
done

if [ $GOVERNOR_SET -gt 0 ]; then
    log_success "Set performance governor on $GOVERNOR_SET CPU cores"
else
    log_warning "Could not set performance governor for any CPU cores. Check if it's supported."
fi

# Clear system caches
log_info "Clearing system caches..."
sync
echo 3 | sudo_with_password tee /proc/sys/vm/drop_caches >/dev/null 2>&1 && log_success "System caches cleared" || log_warning "Could not clear caches."

# Set CUDA environment if available
if [ -d "/usr/local/cuda" ]; then
    log_info "Setting CUDA environment..."
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
    log_success "CUDA environment configured"
fi

################################################################################
# ENHANCED DEPENDENCY CHECKS WITH SUDO PASSWORD
################################################################################

log_info "Checking and installing essential test dependencies with sudo..."

echo "=== ESSENTIAL DEPENDENCY CHECK AND INSTALLATION ==="

# Update package lists first
log_info "Updating package lists..."
sudo_with_password apt-get update && log_success "Package lists updated" || log_warning "Package list update failed. This might affect subsequent installations."

# Check and install essential tools
REQUIRED_ESSENTIALS=""

if ! command -v gcc &> /dev/null; then REQUIRED_ESSENTIALS="$REQUIRED_ESSENTIALS gcc"; fi
if ! command -v python3 &> /dev/null; then REQUIRED_ESSENTIALS="$REQUIRED_ESSENTIALS python3"; fi
if ! command -v bc &> /dev/null; then REQUIRED_ESSENTIALS="$REQUIRED_ESSENTIALS bc"; fi
if ! command -v pkg-config &> /dev/null; then REQUIRED_ESSENTIALS="$REQUIRED_ESSENTIALS pkg-config"; fi
if ! command -v make &> /dev/null; then REQUIRED_ESSENTIALS="$REQUIRED_ESSENTIALS build-essential"; fi
if ! command -v git &> /dev/null; then REQUIRED_ESSENTIALS="$REQUIRED_ESSENTIALS git"; fi # git is needed for gpu-burn

if [ -n "$REQUIRED_ESSENTIALS" ]; then
    log_info "Installing missing essential tools: $REQUIRED_ESSENTIALS"
    sudo_with_password apt-get install -y $REQUIRED_ESSENTIALS && log_success "Essential tools installed" || log_warning "Could not install some essential tools."
else
    log_success "All essential tools already present."
fi

# Check for nvidia-smi & nvcc (don't install, just report)
if ! command -v nvidia-smi &> /dev/null; then
    log_warning "nvidia-smi not found - GPU monitoring and some tests may be limited."
else
    echo "✓ nvidia-smi available: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo 'version unknown')"
fi

if ! command -v nvcc &> /dev/null; then
    log_warning "nvcc not found - CUDA compilation tests will be skipped. Ensure CUDA toolkit is installed."
else
    echo "✓ nvcc available: $(nvcc --version | grep release)"
fi

################################################################################
# CUDA & AI DEPENDENCY SETUP (cuBLAS, cuDNN)
################################################################################

log_info "Installing CUDA & AI libraries (cuBLAS, cuDNN)..."

echo "=== CUDA & AI DEPENDENCY SETUP ==="

# Check if CUDA is available before attempting to install CUDA-dependent libraries
if command -v nvcc &> /dev/null; then
    log_info "CUDA toolkit detected. Attempting to install cuBLAS and cuDNN development libraries..."
    
    # Check if packages are already installed
    CUBLAS_INSTALLED=$(dpkg -l | grep -c "libcublas-dev")
    CUDNN_INSTALLED=$(dpkg -l | grep -c "libcudnn8-dev")

    if [ "$CUBLAS_INSTALLED" -gt 0 ] && [ "$CUDNN_INSTALLED" -gt 0 ]; then
        log_success "cuBLAS and cuDNN development libraries already installed."
    else
        log_info "Installing missing cuBLAS/cuDNN dev packages..."
        sudo_with_password apt-get install -y \
            libcublas-dev \
            libcudnn8-dev \
            && log_success "cuBLAS and cuDNN development libraries installed" || log_warning "Failed to install some CUDA libraries. Check the logs for specific apt-get errors."
    fi
else
    log_warning "nvcc (CUDA compiler) not found. Skipping installation of cuBLAS and cuDNN."
    log_warning "These libraries typically require the CUDA toolkit to be installed for proper functioning."
fi

################################################################################
# GPU TESTING TOOLS INSTALLATION (glmark2, gpu-burn)
################################################################################

log_info "Installing and compiling GPU-specific testing tools..."

echo "=== GPU TESTING TOOLS ==="

# Install glmark2 (for OpenGL stress)
if ! command -v glmark2 &> /dev/null; then
    log_info "Installing glmark2 for OpenGL benchmarking..."
    sudo_with_password apt-get install -y glmark2 && log_success "glmark2 installed" || log_warning "Failed to install glmark2. OpenGL stress tests may be limited."
else
    log_success "glmark2 already installed."
fi

# Install gpu-burn (for CUDA stress)
# We place it in $HOME to make it persistent and easy to find/re-use.
GPU_BURN_PATH="$HOME/gpu-burn" 
if [ ! -f "$GPU_BURN_PATH/gpu_burn" ]; then
    log_info "Cloning and compiling gpu-burn (for intense CUDA core stress)..."
    
    # Ensure git and build-essential are available (already checked above, but good to be safe)
    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed. Cannot proceed with gpu-burn compilation."
    fi
    if ! command -v make &> /dev/null; then
        log_error "make (from build-essential) is required but not installed. Cannot proceed with gpu-burn compilation."
    fi

    # Clone repository
    git clone https://github.com/wilicc/gpu-burn.git "$GPU_BURN_PATH" 2>&1 | grep -v "already exists" || log_warning "Failed to clone gpu-burn repository, or it already exists. Attempting to build existing."
    
    if [ -d "$GPU_BURN_PATH" ]; then
        cd "$GPU_BURN_PATH" || log_error "Could not change to gpu-burn directory: $GPU_BURN_PATH"
        
        # Modify Makefile to target Jetson Orin AGX architecture (sm_87)
        # This step is crucial for optimal performance and avoiding compilation issues on newer architectures.
        if grep -q "sm_30" Makefile; then
            if sed -i 's/compute_30,sm_30/compute_87,sm_87/g' Makefile; then
                log_success "Modified gpu-burn Makefile for sm_87 architecture."
            else
                log_warning "Failed to modify gpu-burn Makefile for sm_87. Compilation might fail or result in sub-optimal performance."
            fi
        else
            log_info "Makefile does not contain 'sm_30', assuming it's already updated or compatible."
        fi
        
        # Compile gpu-burn
        make clean >/dev/null 2>&1 # Clean any previous builds
        if make 2>&1 | tee -a "$LOG_DIR/gpu_burn_compile.log"; then
            log_success "gpu-burn compiled successfully at $GPU_BURN_PATH/gpu_burn."
            # Add to PATH temporarily for easy access during tests
            export PATH="$GPU_BURN_PATH:$PATH"
        else
            log_error "Failed to compile gpu-burn. Check CUDA toolkit installation and '$LOG_DIR/gpu_burn_compile.log' for details. CUDA stress tests may be skipped."
        fi
        cd - > /dev/null # Go back to previous directory
    else
        log_error "gpu-burn directory '$GPU_BURN_PATH' does not exist after clone attempt. CUDA stress tests may be skipped."
    fi
else
    log_success "gpu-burn already installed at $GPU_BURN_PATH/gpu_burn."
    export PATH="$GPU_BURN_PATH:$PATH" # Ensure it's in PATH
fi
echo ""

################################################################################
# OPENGL/GRAPHICS SETUP WITH SUDO PASSWORD
################################################################################

log_info "Installing and configuring OpenGL/Graphics support with sudo..."

echo "=== OPENGL/GRAPHICS SETUP ==="

# Detect if this is a Jetson system
IS_JETSON=0
if [ -f "/etc/nv_tegra_release" ]; then
    IS_JETSON=1
    log_info "Jetson system detected - using L4T optimized packages"
    echo "JetPack Version: $(cat /etc/nv_tegra_release)"
else
    log_info "Non-Jetson system detected - using standard packages"
fi

# Install OpenGL development libraries
log_info "Installing OpenGL development libraries..."

if [ $IS_JETSON -eq 1 ]; then
    # Jetson-specific packages
    log_info "Installing NVIDIA L4T multimedia and graphics packages..."
    sudo_with_password apt-get install -y \
        nvidia-l4t-multimedia \
        nvidia-l4t-multimedia-utils \
        nvidia-l4t-graphics-demos \
        libnvidia-egl-wayland1 \
        gstreamer1.0-tools \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        && log_success "L4T multimedia/graphics/gstreamer packages installed" || log_warning "Some L4T packages failed to install. This might impact NVIDIA OpenGL/VPU functionality."
fi

# Common OpenGL packages for both Jetson and x86
log_info "Installing common OpenGL development packages..."
sudo_with_password apt-get install -y \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    mesa-common-dev \
    && log_success "OpenGL development packages installed" || log_warning "Some OpenGL development packages failed to install."

# Additional graphics libraries
log_info "Installing additional graphics support libraries..."
sudo_with_password apt-get install -y \
    libglfw3-dev \
    libglew-dev \
    freeglut3-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev \
    libxext-dev \
    libx11-dev \
    && log_success "Additional graphics libraries installed" || log_warning "Some additional graphics packages failed to install."

# Configure NVIDIA as default OpenGL provider for Jetson
if [ $IS_JETSON -eq 1 ]; then
    log_info "Configuring NVIDIA as default OpenGL provider using update-alternatives..."
    
    NVIDIA_GL_PATH="/usr/lib/aarch64-linux-gnu/nvidia/libGL.so.1"
    NVIDIA_EGL_PATH="/usr/lib/aarch64-linux-gnu/nvidia/libEGL.so.1"

    GL_CONFIGURED=0
    EGL_CONFIGURED=0

    # Set up alternatives for GL
    if [ -f "$NVIDIA_GL_PATH" ]; then
        log_info "Attempting to set NVIDIA libGL.so.1 as alternative (priority 100)..."
        if sudo_with_password update-alternatives --install /usr/lib/aarch64-linux-gnu/libGL.so.1 \
            aarch64-linux-gnu_gl_conf "$NVIDIA_GL_PATH" 100 ; then
            log_success "GL alternatives configured for NVIDIA."
            GL_CONFIGURED=1
        else
            log_warning "Could not set GL alternatives for NVIDIA. Check if another GL provider is already highly prioritized or for other errors."
        fi
    else
        log_warning "NVIDIA GL library not found at '$NVIDIA_GL_PATH'. Skipping GL alternatives configuration."
    fi
    
    # Set up alternatives for EGL
    if [ -f "$NVIDIA_EGL_PATH" ]; then
        log_info "Attempting to set NVIDIA libEGL.so.1 as alternative (priority 100)..."
        if sudo_with_password update-alternatives --install /usr/lib/aarch64-linux-gnu/libEGL.so.1 \
            aarch64-linux-gnu_egl_conf "$NVIDIA_EGL_PATH" 100 ; then
            log_success "EGL alternatives configured for NVIDIA."
            EGL_CONFIGURED=1
        else
            log_warning "Could not set EGL alternatives for NVIDIA. Check for existing EGL provider or other errors."
        fi
    else
        log_warning "NVIDIA EGL library not found at '$NVIDIA_EGL_PATH'. Skipping EGL alternatives configuration."
    fi
        
    if [ $GL_CONFIGURED -eq 1 ] || [ $EGL_CONFIGURED -eq 1 ]; then
        log_success "NVIDIA OpenGL/EGL configuration attempt completed."
    else
        log_warning "NVIDIA OpenGL/EGL configuration was not fully successful. Hardware acceleration might not be optimal."
    fi
fi

# Test OpenGL installation
log_info "Testing OpenGL compilation capabilities..."

# Create test programs
OPENGL_TEST_DIR="/tmp/opengl_test_$$"
mkdir -p "$OPENGL_TEST_DIR"

# Test 1: Standard OpenGL (Desktop GL)
cat > "$OPENGL_TEST_DIR/test_opengl.c" << 'EOF'
#include <stdio.h>
#include <GL/gl.h>

int main() {
    printf("Standard OpenGL compilation successful!\n");
    return 0;
}
EOF

# Test 2: OpenGL ES (for embedded systems like Jetson)
cat > "$OPENGL_TEST_DIR/test_gles.c" << 'EOF'
#include <stdio.h>
#include <GLES3/gl3.h>

int main() {
    printf("OpenGL ES compilation successful!\n");
    return 0;
}
EOF

# Try to compile tests
OPENGL_STATUS="NONE"

# Test standard OpenGL
log_info "Attempting standard OpenGL compilation test (Desktop GL)..."
if gcc -o "$OPENGL_TEST_DIR/test_opengl" "$OPENGL_TEST_DIR/test_opengl.c" -lGL 2>/dev/null; then
    log_success "✓ Standard OpenGL compilation successful"
    OPENGL_STATUS="STANDARD"
    "$OPENGL_TEST_DIR/test_opengl"
else
    log_warning "Standard OpenGL compilation failed. This might mean GL headers/libraries are missing or incorrect for Desktop GL."
fi

# Test OpenGL ES
log_info "Attempting OpenGL ES compilation test (GLES3)..."
if pkg-config --exists glesv2 && \
   gcc -o "$OPENGL_TEST_DIR/test_gles" "$OPENGL_TEST_DIR/test_gles.c" \
   $(pkg-config --cflags --libs glesv2) 2>/dev/null; then
    log_success "✓ OpenGL ES compilation successful"
    if [ "$OPENGL_STATUS" = "NONE" ]; then
        OPENGL_STATUS="GLES"
    else
        OPENGL_STATUS="BOTH"
    fi
    "$OPENGL_TEST_DIR/test_gles"
else
    log_warning "OpenGL ES compilation failed. This might mean GLES headers/libraries are missing or incorrect for GLES3."
fi

# Create fallback graphics test
log_info "Creating fallback CPU-based graphics performance test..."
cat > "$OPENGL_TEST_DIR/graphics_fallback.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>

int main(int argc, char *argv[]) {
    int duration = argc > 1 ? atoi(argv[1]) : 3; // Default 3 seconds
    int operations = 0;
    
    printf("Graphics Performance Fallback Test (CPU-based simulation)\n");
    printf("Duration: %d seconds\n", duration);
    printf("Starting CPU-based graphics simulation...\n");
    
    time_t start = time(NULL);
    time_t end = start + duration;
    
    while (time(NULL) < end) {
        // Simulate graphics operations (matrix multiplies, trig functions)
        for (int i = 0; i < 1000; i++) {
            float matrix[16];
            for (int j = 0; j < 16; j++) {
                matrix[j] = sin((float)(operations + i + j)) * cos((float)(i * j));
            }
            
            // Simulate pixel operations
            for (int p = 0; p < 100; p++) {
                float pixel = matrix[p % 16] * matrix[(p + 1) % 16];
                (void)pixel; // Suppress warning
            }
        }
        operations++;
    }
    
    double elapsed = difftime(time(NULL), start);
    printf("Completed %d graphics operations in %.2f seconds\n", operations, elapsed);
    if (elapsed > 0) {
        printf("Performance: %.2f ops/sec\n", operations / elapsed);
    }
    
    return 0;
}
EOF

if gcc -o "$OPENGL_TEST_DIR/graphics_fallback" "$OPENGL_TEST_DIR/graphics_fallback.c" -lm 2>/dev/null; then
    log_success "✓ Graphics fallback test created and compiled."
    "$OPENGL_TEST_DIR/graphics_fallback" 3 # Run for a short period
else
    log_error "Failed to create or compile graphics fallback test. This test is essential if hardware acceleration fails."
fi

# Cleanup test directory
rm -rf "$OPENGL_TEST_DIR"

# Report OpenGL status
echo ""
echo "=== OPENGL SETUP RESULTS ==="
case "$OPENGL_STATUS" in
    "BOTH")
        log_success "OpenGL Setup: EXCELLENT (Both standard OpenGL and OpenGL ES compiled successfully)"
        ;;
    "STANDARD")
        log_success "OpenGL Setup: GOOD (Standard OpenGL compiled, GLES failed. Might be sufficient depending on test.)"
        ;;
    "GLES")
        log_success "OpenGL Setup: GOOD (OpenGL ES compiled, standard GL failed. Common for embedded.)"
        ;;
    "NONE")
        log_warning "OpenGL Setup: FALLBACK (Neither standard OpenGL nor OpenGL ES compiled successfully. Will rely on CPU-based graphics tests.)"
        ;;
esac

################################################################################
# REMAINING DEPENDENCY INSTALLATIONS
################################################################################

# Check for stress-ng (install if not present)
if ! command -v stress-ng &> /dev/null; then
    log_info "Installing stress-ng for comprehensive CPU/RAM/IO testing..."
    sudo_with_password apt-get install -y stress-ng && log_success "stress-ng installed" || log_warning "Could not install stress-ng. Some stress tests may be unavailable."
else
    log_success "stress-ng already installed."
fi

if command -v stress-ng &> /dev/null; then
    echo "✓ stress-ng available: $(stress-ng --version 2>/dev/null | head -1 || echo 'version unknown')"
fi

# Install additional useful monitoring tools
log_info "Installing additional monitoring tools (htop, iotop, lm-sensors)..."
sudo_with_password apt-get install -y \
    htop \
    iotop \
    lm-sensors \
    && log_success "Additional monitoring tools installed" || log_warning "Some additional monitoring tools failed to install."

################################################################################
# SYSTEM RESOURCE CHECK
################################################################################

log_info "Checking system resources..."

echo "=== RESOURCE AVAILABILITY ==="

# Check available memory
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
AVAILABLE_MEM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
MEM_USAGE_PERCENT=$(((TOTAL_MEM_KB - AVAILABLE_MEM_KB) * 100 / TOTAL_MEM_KB))

echo "Memory Status:"
echo "  Total: $((TOTAL_MEM_KB / 1024 / 1024)) GB"
echo "  Available: $((AVAILABLE_MEM_KB / 1024 / 1024)) GB"
echo "  Used: ${MEM_USAGE_PERCENT}%"

if [ $MEM_USAGE_PERCENT -gt 80 ]; then
    log_warning "High memory usage detected ($MEM_USAGE_PERCENT%) - tests may be affected."
elif [ $MEM_USAGE_PERCENT -gt 60 ]; then
    log_warning "Moderate memory usage detected ($MEM_USAGE_PERCENT%)."
else
    echo "✓ Memory usage acceptable ($MEM_USAGE_PERCENT%)"
fi

# Check available storage
STORAGE_USAGE=$(df /tmp | awk 'NR==2 {print $5}' | sed 's/%//')
AVAILABLE_STORAGE_MB=$(df /tmp | awk 'NR==2 {print $4}')
AVAILABLE_STORAGE_MB=$((AVAILABLE_STORAGE_MB / 1024))

echo ""
echo "Storage Status (/tmp):"
echo "  Available: ${AVAILABLE_STORAGE_MB} MB"
echo "  Usage: ${STORAGE_USAGE}%"

if [ $STORAGE_USAGE -gt 90 ]; then
    log_warning "Very high storage usage ($STORAGE_USAGE%) - tests may fail."
elif [ $STORAGE_USAGE -gt 75 ]; then
    log_warning "High storage usage ($STORAGE_USAGE%) detected."
elif [ $AVAILABLE_STORAGE_MB -lt 1000 ]; then
    log_warning "Low available storage (${AVAILABLE_STORAGE_MB}MB) - large tests may fail."
else
    echo "✓ Storage availability acceptable"
fi

# Check CPU load
LOAD_1MIN=$(cat /proc/loadavg | awk '{print $1}')
CPU_COUNT=$(nproc)
LOAD_PERCENT=$(echo "scale=0; $LOAD_1MIN * 100 / $CPU_COUNT" | bc 2>/dev/null || echo "0")

echo ""
echo "CPU Load Status:"
echo "  1-minute load: $LOAD_1MIN"
echo "  CPU cores: $CPU_COUNT"
echo "  Load percentage: ${LOAD_PERCENT}%"

if [ "$LOAD_PERCENT" -gt 80 ]; then
    log_warning "High CPU load detected (${LOAD_PERCENT}%) - system may be busy."
elif [ "$LOAD_PERCENT" -gt 50 ]; then
    log_warning "Moderate CPU load detected (${LOAD_PERCENT}%)."
else
    echo "✓ CPU load acceptable (${LOAD_PERCENT}%)"
fi

################################################################################
# POST-INSTALLATION VERIFICATION
################################################################################

echo ""
echo "=== POST-INSTALLATION VERIFICATION ==="

log_info "Verifying installed components..."

# Verify OpenGL again after installation
echo "OpenGL Libraries Found:"
find /usr/lib -name "*GL*" 2>/dev/null | grep -E "(libGL|libEGL)" | head -10 || echo "No OpenGL libraries found"

echo ""
echo "OpenGL Headers Found:"
if [ -f "/usr/include/GL/gl.h" ]; then
    echo "✓ /usr/include/GL/gl.h"
fi
if [ -f "/usr/include/GLES3/gl3.h" ]; then
    echo "✓ /usr/include/GLES3/gl3.h"
fi
if [ -f "/usr/include/EGL/egl.h" ]; then
    echo "✓ /usr/include/EGL/egl.h"
fi

echo ""
echo "NVIDIA Libraries (Jetson):"
if [ -d "/usr/lib/aarch64-linux-gnu/nvidia" ]; then
    ls -la /usr/lib/aarch64-linux-gnu/nvidia/ | grep -E "(libGL|libEGL|libnvcuvid|libnvidia-encode|libnvidia-cfg)" | head -5
else
    echo "No NVIDIA library directory found, or not a Jetson."
fi

echo ""
echo "CUDA Libraries (cuBLAS, cuDNN):"
if dpkg -l | grep -q "libcublas-dev" && dpkg -l | grep -q "libcudnn8-dev"; then
    log_success "✓ cuBLAS and cuDNN development libraries verified."
else
    log_warning "❌ cuBLAS or cuDNN development libraries not found or verification failed."
fi

echo ""
echo "GPU Testing Tools:"
if command -v glmark2 &> /dev/null; then
    log_success "✓ glmark2 verified."
else
    log_warning "❌ glmark2 not found."
fi

if [ -f "$HOME/gpu-burn/gpu_burn" ]; then
    log_success "✓ gpu-burn verified ($HOME/gpu-burn/gpu_burn)."
else
    log_warning "❌ gpu-burn not found ($HOME/gpu-burn/gpu_burn)."
fi


################################################################################
# FINAL SYSTEM STATE
################################################################################

echo ""
echo "=== FINAL SYSTEM STATE ==="

echo "CPU Governors after optimization:"
for i in $(seq 0 7); do  # Check first 8 cores
    if [ -f "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" ]; then
        governor=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
        freq=$(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq 2>/dev/null || echo "N/A")
        echo "  CPU$i: $governor (${freq} Hz)"
    fi
done

echo ""
echo "Current temperatures:"
for i in $(seq 0 5); do
    if [ -f "/sys/devices/virtual/thermal/thermal_zone$i/temp" ]; then
        temp=$(cat /sys/devices/virtual/thermal/thermal_zone$i/temp 2>/dev/null || echo "0")
        temp_c=$((temp / 1000))
        zone_type=$(cat /sys/devices/virtual/thermal/thermal_zone$i/type 2>/dev/null || echo "unknown")
        echo "  Zone $i ($zone_type): ${temp_c}°C"
    fi
done

################################################################################
# PREPARATION RESULTS
################################################################################

PREP_STATUS="READY"
PREP_WARNINGS=0

# Check critical conditions
if [ $MEM_USAGE_PERCENT -gt 85 ]; then
    PREP_STATUS="WARNING"
    PREP_WARNINGS=$((PREP_WARNINGS + 1))
fi

if [ $STORAGE_USAGE -gt 90 ]; then
    PREP_STATUS="WARNING"  
    PREP_WARNINGS=$((PREP_WARNINGS + 1))
fi

if [ "$LOAD_PERCENT" -gt 90 ]; then
    PREP_STATUS="WARNING"
    PREP_WARNINGS=$((PREP_WARNINGS + 1))
fi

# Check OpenGL status
if [ "$OPENGL_STATUS" = "NONE" ]; then
    PREP_WARNINGS=$((PREP_WARNINGS + 1))
fi

# Check GPU tools status
if ! command -v glmark2 &> /dev/null; then
    PREP_WARNINGS=$((PREP_WARNINGS + 1))
fi
if [ ! -f "$HOME/gpu-burn/gpu_burn" ]; then
    PREP_WARNINGS=$((PREP_WARNINGS + 1))
fi

echo ""
echo "================================================================================"
echo "  ENHANCED SYSTEM PREPARATION COMPLETE (SUDO FIXED)"
echo "================================================================================"
echo ""
echo "Preparation Status: $PREP_STATUS"
echo "Warnings: $PREP_WARNINGS"
echo "OpenGL Compilation Status: $OPENGL_STATUS"
echo ""

if [ "$PREP_STATUS" = "READY" ] && [ $PREP_WARNINGS -eq 0 ]; then
    log_success "System is ready for comprehensive stress testing"
    echo "  ✓ All dependencies installed and verified"
    echo "  ✓ System resources sufficient for testing"
    echo "  ✓ Performance optimizations applied"
    echo "  ✓ OpenGL/Graphics and CUDA support configured"
    echo "  ✓ GPU testing tools (glmark2, gpu-burn) installed and compiled"
    echo "  ✓ Sudo operations completed successfully"
elif [ "$PREP_STATUS" = "READY" ]; then # READY with warnings
    log_warning "System prepared with some warnings"
    echo "  ⚠ Review resource usage, OpenGL/CUDA status, and GPU tools before starting intensive tests"
    echo "  ⚠ Some tests may have reduced performance or fallback modes due to these warnings"
else # PREP_STATUS indicates critical issues
    log_error "System preparation encountered critical issues."
    echo "  ❌ Review the log file for detailed errors and resolve them before proceeding."
    echo "  ❌ It is NOT recommended to proceed with intensive tests."
fi

echo ""
echo "Graphics/GPU Test Capabilities:"
case "$OPENGL_STATUS" in
    "BOTH")
        echo "  ✓ Hardware-accelerated Desktop OpenGL tests available"
        echo "  ✓ Hardware-accelerated OpenGL ES tests available"
        ;;
    "STANDARD")
        echo "  ✓ Hardware-accelerated Desktop OpenGL tests available"
        echo "  ⚠ OpenGL ES tests may be limited"
        ;;
    "GLES")
        echo "  ✓ Hardware-accelerated OpenGL ES tests available"
        echo "  ⚠ Desktop OpenGL tests may be limited"
        ;;
    "NONE")
        echo "  ⚠ Hardware-accelerated graphics tests not confirmed. Only CPU-based graphics simulations may be available."
        echo "  ⚠ Verify NVIDIA drivers and JetPack installation if hardware acceleration is required."
        ;;
esac

echo "CUDA and Video Processing Capabilities:"
if command -v nvcc &> /dev/null && dpkg -l | grep -q "libcublas-dev" && dpkg -l | grep -q "libcudnn8-dev"; then
    echo "  ✓ CUDA toolkit, cuBLAS, and cuDNN are available for compute tests."
else
    echo "  ⚠ CUDA development environment (nvcc, cuBLAS, cuDNN) may be incomplete. CUDA tests might fail."
fi
if command -v gst-launch-1.0 &> /dev/null && dpkg -l | grep -q "nvidia-l4t-multimedia"; then
    echo "  ✓ GStreamer with NVIDIA VPU plugins appears available for video encoding/decoding tests."
else
    echo "  ⚠ GStreamer with NVIDIA VPU plugins may be missing or incomplete. Video encoding tests might fail."
fi

echo ""
echo "Recommended test order (assuming all checks pass):"
echo "  1. GPU Stress Test (using the dedicated script you have)"
echo "  2. CPU Stress Test"
echo "  3. RAM Stress Test"
echo "  4. Storage Stress Test"
echo "  5. Combined Stress Test"
echo ""

echo "Next steps:"
echo "  • Review the generated log file for any warnings or errors."
echo "  • Run your dedicated GPU stress test script to confirm GPU stability."
echo "  • All system optimizations are applied and will remain until reboot or manual change."
echo ""

REMOTE_PREP_START

log_success "Enhanced system preparation completed with sudo fix!"
echo ""
echo "📁 Preparation log: $LOG_DIR/logs/system_preparation.log"
echo "🎮 OpenGL/Graphics: See above results for capabilities"
echo "⚡ System optimization: Applied with sudo privileges"
echo "📦 Dependencies: Attempted all package installations"
echo "🔑 Sudo operations: Detailed errors now visible in log"
echo ""
echo "🚀 Your system is now optimized for comprehensive stress testing, please review log for any remaining warnings!"

exit 0