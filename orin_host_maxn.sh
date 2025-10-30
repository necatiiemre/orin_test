#!/bin/bash

# Jetson Orin MAXN Performance Mode Script
# Sets Jetson to maximum performance with all cores enabled

set -e

echo "=========================================="
echo " JETSON ORIN MAXN PERFORMANCE MODE"
echo "=========================================="
echo ""

# Parameters
ORIN_IP="${1:-192.168.55.69}"
ORIN_USER="${2:-orin}"
ORIN_PASS="${3}"

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: $0 [orin_ip] [orin_user] [password]"
    echo ""
    echo "Example: $0 192.168.55.69 orin mypassword"
    exit 0
fi

if [ -z "$ORIN_PASS" ]; then
    read -sp "Orin password ($ORIN_USER@$ORIN_IP): " ORIN_PASS
    echo ""
fi

if ! command -v sshpass &> /dev/null; then
    echo "ERROR: 'sshpass' not installed"
    exit 1
fi

echo "Target: $ORIN_USER@$ORIN_IP"
echo ""

# SSH connection check
echo "Checking SSH connection..."
if ! sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'OK'" 2>/dev/null; then
    echo "ERROR: SSH connection failed"
    exit 1
fi
echo "✓ SSH connection successful"
echo ""

#############################################
# STEP 1: APPLY MAXN SETTINGS
#############################################
echo "=========================================="
echo " STEP 1: APPLYING MAXN SETTINGS"
echo "=========================================="
echo ""

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "export ORIN_PASS='$ORIN_PASS'; bash -s" << 'ENDSTEP1'

echo "[1] Installing expect if needed..."
if ! command -v expect &>/dev/null; then
    echo "$ORIN_PASS" | sudo -S apt-get update -qq
    echo "$ORIN_PASS" | sudo -S apt-get install -y -qq expect
fi
echo "✓ expect ready"
echo ""

echo "[2] Setting power mode to MAXN (mode 0)..."
cat > /tmp/set_maxn.exp << 'ENDEXP'
#!/usr/bin/expect -f
set timeout 20
set password [lindex $argv 0]
spawn sudo nvpmodel -m 0
expect {
    "password" { send "$password\r"; exp_continue }
    "YES/yes" { send "YES\r"; expect eof }
    "REBOOT NOW" { send "YES\r"; expect eof }
    timeout { exit 1 }
    eof
}
ENDEXP

chmod +x /tmp/set_maxn.exp
/tmp/set_maxn.exp "$ORIN_PASS"
rm -f /tmp/set_maxn.exp

echo "✓ MAXN mode command executed"
echo ""

echo "[3] Enabling all 12 CPU cores..."
for cpu_num in {0..11}; do
    CPU_ONLINE="/sys/devices/system/cpu/cpu${cpu_num}/online"
    if [ -f "$CPU_ONLINE" ]; then
        echo "$ORIN_PASS" | sudo -S bash -c "echo 1 > $CPU_ONLINE" 2>/dev/null || true
    fi
done
echo "✓ All CPUs enabled"
echo ""

echo "[4] Enabling jetson_clocks..."
echo "$ORIN_PASS" | sudo -S jetson_clocks 2>/dev/null
echo "✓ jetson_clocks enabled"
echo ""

echo "[5] Setting CPU governor to performance..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        echo "$ORIN_PASS" | sudo -S bash -c "echo performance > $cpu" 2>/dev/null || true
    fi
done
echo "✓ CPU governor set"
echo ""

echo "[6] System will reboot now..."
echo "$ORIN_PASS" | sudo -S reboot &

ENDSTEP1

echo "✓ Reboot command sent"
echo ""

#############################################
# STEP 2: WAIT FOR REBOOT
#############################################
echo "=========================================="
echo " STEP 2: WAITING FOR REBOOT"
echo "=========================================="
echo ""

echo "Waiting for system to go down..."
sleep 10

echo "Waiting for system to come back online..."
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'OK'" 2>/dev/null; then
        echo ""
        echo "✓ System is back online!"
        break
    fi
    printf "\r  Waiting... %ds / %ds " "$ELAPSED" "$MAX_WAIT"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo ""
    echo "ERROR: Timeout waiting for system"
    exit 1
fi

echo ""
sleep 5

#############################################
# STEP 3: VERIFY SETTINGS AFTER REBOOT
#############################################
echo "=========================================="
echo " STEP 3: VERIFYING SETTINGS"
echo "=========================================="
echo ""

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "export ORIN_PASS='$ORIN_PASS'; bash -s" << 'ENDSTEP3'

echo "[1] Re-applying optimizations after reboot..."
echo ""

# Enable all CPUs again
echo "  • Enabling all 12 CPU cores..."
for cpu_num in {0..11}; do
    CPU_ONLINE="/sys/devices/system/cpu/cpu${cpu_num}/online"
    if [ -f "$CPU_ONLINE" ]; then
        echo "$ORIN_PASS" | sudo -S bash -c "echo 1 > $CPU_ONLINE" 2>/dev/null || true
    fi
done

# Enable jetson_clocks
echo "  • Enabling jetson_clocks..."
echo "$ORIN_PASS" | sudo -S jetson_clocks 2>/dev/null

# Set governor
echo "  • Setting CPU governor to performance..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        echo "$ORIN_PASS" | sudo -S bash -c "echo performance > $cpu" 2>/dev/null || true
    fi
done

echo ""
echo "[2] Verification Results:"
echo ""

# Check power mode
echo "Power Mode:"
POWER_MODE=$(echo "$ORIN_PASS" | sudo -S nvpmodel -q 2>/dev/null | grep "NV Power Mode")
echo "  $POWER_MODE"
if echo "$POWER_MODE" | grep -q "MAXN"; then
    echo "  ✅ MAXN mode active"
elif echo "$POWER_MODE" | grep -q "MODE_0"; then
    echo "  ✅ MAXN mode active (Mode 0)"
else
    MODE_NUM=$(echo "$POWER_MODE" | grep -oP 'MODE_\K\d+')
    if [ "$MODE_NUM" = "0" ]; then
        echo "  ✅ MAXN mode active"
    else
        echo "  ❌ NOT in MAXN mode (current: Mode $MODE_NUM)"
    fi
fi
echo ""

# Check online CPUs
ONLINE_CPUS=$(nproc)
TOTAL_CPUS=$(nproc --all)
echo "CPU Cores:"
echo "  Online: $ONLINE_CPUS / $TOTAL_CPUS"
if [ "$ONLINE_CPUS" = "$TOTAL_CPUS" ]; then
    echo "  ✅ All cores enabled"
else
    echo "  ⚠️  Only $ONLINE_CPUS cores online"
fi
echo ""

# Check CPU frequencies
echo "CPU Frequencies:"
MIN_FREQ=9999
MAX_FREQ=0
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
    if [ -f "$cpu" ]; then
        FREQ=$(cat $cpu 2>/dev/null)
        if [ -n "$FREQ" ]; then
            FREQ_MHZ=$((FREQ / 1000))
            CPU_NUM=$(echo $cpu | grep -oP 'cpu\K[0-9]+')
            printf "  CPU%-2s: %4d MHz\n" "$CPU_NUM" "$FREQ_MHZ"
            
            if [ $FREQ_MHZ -lt $MIN_FREQ ]; then MIN_FREQ=$FREQ_MHZ; fi
            if [ $FREQ_MHZ -gt $MAX_FREQ ]; then MAX_FREQ=$FREQ_MHZ; fi
        fi
    fi
done
if [ $MIN_FREQ -ge 2000 ]; then
    echo "  ✅ All CPUs at maximum frequency"
else
    echo "  ⚠️  Some CPUs at lower frequency (min: ${MIN_FREQ} MHz)"
fi
echo ""

# Check governor
echo "CPU Governor:"
PERF_COUNT=0
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$gov" ] && grep -q "performance" "$gov" 2>/dev/null; then
        PERF_COUNT=$((PERF_COUNT + 1))
    fi
done
echo "  Performance mode: $PERF_COUNT / $ONLINE_CPUS cores"
if [ "$PERF_COUNT" = "$ONLINE_CPUS" ]; then
    echo "  ✅ All cores in performance mode"
else
    echo "  ⚠️  Not all cores in performance mode"
fi
echo ""

# Show temperatures
echo "Temperatures:"
for zone in /sys/devices/virtual/thermal/thermal_zone*/temp; do
    if [ -f "$zone" ]; then
        temp=$(cat $zone 2>/dev/null || echo "0")
        if [ "$temp" != "0" ]; then
            temp=$((temp / 1000))
            zone_type=$(cat $(dirname $zone)/type 2>/dev/null || echo "unknown")
            printf "  %-15s: %d°C\n" "$zone_type" "$temp"
        fi
    fi
done

ENDSTEP3

echo ""
echo "=========================================="
echo " ✅ MAXN CONFIGURATION COMPLETED!"
echo "=========================================="
echo ""
echo "Your Jetson Orin is now configured for maximum performance."
echo ""