#!/bin/bash

# Host'tan Orin'e İnternet Paylaşımı
# SSH üzerinden host'un internetini Orin'e yönlendirir

set -e

echo "=========================================="
echo "  ORIN İNTERNET PAYLAŞIM KURULUMU"
echo "=========================================="
echo ""

# Parametreler
ORIN_IP="${1:-192.168.55.69}"
ORIN_USER="${2:-orin}"
ORIN_PASS="${3}"
HOST_INTERNET_IF="${4}"  # Host'un internet interface'i (opsiyonel)

# Kullanım bilgisi
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Kullanım: $0 [orin_ip] [orin_user] [password] [host_internet_interface]"
    echo ""
    echo "Varsayılan:"
    echo "  IP: 192.168.55.69"
    echo "  Kullanıcı: orin"
    echo "  Interface: Otomatik tespit"
    echo ""
    echo "Örnek:"
    echo "  $0 192.168.55.69 orin mypass"
    echo "  $0 192.168.55.69 orin mypass eth0"
    echo ""
    echo "STOP komutu ile durdurabilirsiniz:"
    echo "  $0 STOP"
    exit 0
fi

# STOP komutu kontrolü
if [ "$1" == "STOP" ] || [ "$1" == "stop" ]; then
    echo "İnternet paylaşımı durduruluyor..."
    
    # IP forwarding kapat
    echo "IP forwarding kapatılıyor..."
    sudo sysctl -w net.ipv4.ip_forward=0
    
    # iptables kurallarını temizle
    echo "iptables kuralları temizleniyor..."
    sudo iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null || true
    sudo iptables -D FORWARD -j ACCEPT 2>/dev/null || true
    
    echo ""
    echo "✓ İnternet paylaşımı durduruldu"
    exit 0
fi

# Şifre kontrolü
if [ -z "$ORIN_PASS" ]; then
    read -sp "Orin şifresi ($ORIN_USER@$ORIN_IP): " ORIN_PASS
    echo ""
fi

# sshpass kontrolü
if ! command -v sshpass &> /dev/null; then
    echo "HATA: 'sshpass' yüklü değil"
    echo "Rocky Linux'ta: sudo dnf install epel-release && sudo dnf install sshpass"
    exit 1
fi

echo "Ayarlar:"
echo "  Orin IP: $ORIN_IP"
echo "  Kullanıcı: $ORIN_USER"
echo ""

# SSH bağlantı kontrolü
echo "[1/6] SSH bağlantısı kontrol ediliyor..."
if ! sshpass -p "$ORIN_PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "echo 'OK'" &>/dev/null; then
    echo "HATA: SSH bağlantısı kurulamadı"
    exit 1
fi
echo "✓ SSH bağlantısı başarılı"
echo ""

# Host'un internet interface'ini tespit et
echo "[2/6] Host network interface tespit ediliyor..."
if [ -z "$HOST_INTERNET_IF" ]; then
    # Varsayılan gateway olan interface'i bul
    HOST_INTERNET_IF=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -z "$HOST_INTERNET_IF" ]; then
        echo "HATA: Host'un internet interface'i tespit edilemedi"
        echo "Manuel olarak belirtin: $0 $ORIN_IP $ORIN_USER $ORIN_PASS <interface>"
        echo ""
        echo "Mevcut interface'ler:"
        ip -br addr show
        exit 1
    fi
fi

echo "✓ Host internet interface: $HOST_INTERNET_IF"
HOST_IP=$(ip -4 addr show $HOST_INTERNET_IF | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "  Host IP: $HOST_IP"
echo ""

# Host'ta IP forwarding aktifleştir
echo "[3/6] Host'ta IP forwarding aktifleştiriliyor..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "✓ IP forwarding aktif"
echo ""

# Host'ta NAT kuralları ekle
echo "[4/6] Host'ta NAT kuralları ekleniyor..."

# Eski kuralları temizle
sudo iptables -t nat -D POSTROUTING -s $ORIN_IP -o $HOST_INTERNET_IF -j MASQUERADE 2>/dev/null || true
sudo iptables -D FORWARD -s $ORIN_IP -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -d $ORIN_IP -j ACCEPT 2>/dev/null || true

# Yeni kurallar ekle
sudo iptables -t nat -A POSTROUTING -s $ORIN_IP -o $HOST_INTERNET_IF -j MASQUERADE
sudo iptables -A FORWARD -s $ORIN_IP -j ACCEPT
sudo iptables -A FORWARD -d $ORIN_IP -j ACCEPT

echo "✓ NAT kuralları eklendi"
echo ""

# Orin'de gateway ayarla
echo "[5/6] Orin'de network ayarları yapılandırılıyor..."

# Host'un Orin network'teki IP'sini bul
ORIN_NETWORK=$(echo $ORIN_IP | cut -d. -f1-3)
HOST_ORIN_GATEWAY=$(ip -4 addr show | grep "$ORIN_NETWORK" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

if [ -z "$HOST_ORIN_GATEWAY" ]; then
    echo "UYARI: Host'un Orin network'teki IP'si bulunamadı"
    echo "Host IP: $HOST_IP kullanılacak (alternatif yol)"
    HOST_ORIN_GATEWAY=$HOST_IP
fi

echo "  Gateway IP: $HOST_ORIN_GATEWAY"

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "PASS='$ORIN_PASS' GATEWAY='$HOST_ORIN_GATEWAY' bash -s" << 'ORIN_SETUP'
#!/bin/bash

echo "Orin'de network yapılandırması..."

# Mevcut default gateway'i sil
echo "$PASS" | sudo -S ip route del default 2>/dev/null || true

# Yeni gateway ekle
echo "$PASS" | sudo -S ip route add default via $GATEWAY

# DNS ayarları
echo "DNS ayarları yapılıyor..."
echo "$PASS" | sudo -S bash -c "cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF"

# Test
echo ""
echo "Network yapılandırması:"
ip route show
echo ""
echo "DNS yapılandırması:"
cat /etc/resolv.conf
echo ""
echo "✓ Orin network yapılandırması tamamlandı"
ORIN_SETUP

echo ""

# İnternet bağlantısını test et
echo "[6/6] İnternet bağlantısı test ediliyor..."
echo ""

sshpass -p "$ORIN_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $ORIN_USER@$ORIN_IP "bash -s" << 'ORIN_TEST'
#!/bin/bash

echo "İnternet bağlantısı test ediliyor..."
echo ""

# Ping testi
echo "1. Ping testi (8.8.8.8):"
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    echo "   ✓ Ping başarılı"
else
    echo "   ✗ Ping başarısız"
fi

# DNS testi
echo "2. DNS testi (google.com):"
if ping -c 3 google.com > /dev/null 2>&1; then
    echo "   ✓ DNS çözümleme başarılı"
else
    echo "   ✗ DNS çözümleme başarısız"
fi

# HTTP testi
echo "3. HTTP testi (google.com):"
if curl -s --connect-timeout 5 http://google.com > /dev/null 2>&1; then
    echo "   ✓ HTTP bağlantısı başarılı"
else
    echo "   ✗ HTTP bağlantısı başarısız"
fi

echo ""
echo "Traceroute (ilk 3 hop):"
traceroute -m 3 8.8.8.8 2>/dev/null || echo "traceroute yüklü değil"
ORIN_TEST

echo ""
echo "=========================================="
echo "  KURULUM TAMAMLANDI!"
echo "=========================================="
echo ""
echo "Orin artık host'un internetini kullanabilir:"
echo "  ✓ Gateway: $HOST_ORIN_GATEWAY"
echo "  ✓ DNS: 8.8.8.8, 8.8.4.4, 1.1.1.1"
echo "  ✓ NAT: Aktif"
echo ""
echo "Orin'de paket kurmak için:"
echo "  ssh $ORIN_USER@$ORIN_IP"
echo "  sudo apt-get update"
echo "  sudo apt-get install <paket_adi>"
echo ""
echo "Durdurmak için:"
echo "  $0 STOP"
echo ""
echo "NOT: Bu ayarlar geçici! Orin yeniden başlatılınca sıfırlanır."
echo "     Kalıcı yapmak için /etc/netplan/ veya /etc/network/interfaces düzenleyin."
echo ""