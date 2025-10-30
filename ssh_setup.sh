#!/bin/bash

# Host'tan Seri Port Üzerinden Orin'de SSH Kurulum Script
# Picocom kullanarak otomatik kurulum

set -e

echo "=== Seri Port Üzerinden SSH Kurulum (Picocom) ==="
echo ""

# Parametreler
SERIAL_PORT="${1:-/dev/ttyUSB0}"
BAUD_RATE="${2:-115200}"
ORIN_USER="${3:-nvidia}"
ORIN_PASS="${4}"

# Kullanım bilgisi
if [ -z "$ORIN_PASS" ]; then
    echo "Kullanım: $0 <serial_port> <baud_rate> <orin_user> <orin_password>"
    echo ""
    echo "Örnek: $0 /dev/ttyUSB0 115200 nvidia password123"
    echo ""
    echo "Varsayılan:"
    echo "  Serial Port: /dev/ttyUSB0"
    echo "  Baud Rate: 115200"
    echo "  Kullanıcı: nvidia"
    echo ""
    read -sp "Orin şifresi girin: " ORIN_PASS
    echo ""
fi

# Picocom kontrolü
if ! command -v picocom &> /dev/null; then
    echo "HATA: 'picocom' bulunamadı"
    exit 1
fi

# Expect kontrolü
if ! command -v expect &> /dev/null; then
    echo "UYARI: 'expect' yüklü değil. Expect ile daha güvenilir otomasyon sağlanır."
    echo "Kurmak için: sudo dnf install expect   (veya: sudo yum install expect)"
    echo ""
    read -p "Expect olmadan devam edilsin mi? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    USE_EXPECT=false
else
    USE_EXPECT=true
fi

# Serial port kontrolü
if [ ! -e "$SERIAL_PORT" ]; then
    echo "HATA: Serial port bulunamadı: $SERIAL_PORT"
    echo ""
    echo "Mevcut serial portlar:"
    ls -l /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* 2>/dev/null || echo "  Hiç serial port bulunamadı"
    exit 1
fi

echo "Ayarlar:"
echo "  Serial Port: $SERIAL_PORT"
echo "  Baud Rate: $BAUD_RATE"
echo "  Kullanıcı: $ORIN_USER"
echo "  Yöntem: $([ "$USE_EXPECT" = true ] && echo "Expect (tam otomatik)" || echo "Picocom (yarı-otomatik)")"
echo ""

# Orin'de çalışacak SSH kurulum scripti oluştur
REMOTE_SCRIPT="/tmp/setup_ssh_orin.sh"
cat > /tmp/setup_ssh_local.sh << 'SSHSETUP'
#!/bin/bash
echo "=== Orin'de SSH Kurulumu Başlatılıyor ==="
echo ""

# Root kontrolü
echo "[1/5] Sudo erişimi kontrol ediliyor..."

# SSH kontrolü
echo "[2/5] SSH paketi kontrol ediliyor..."
if dpkg -l | grep -q openssh-server; then
    echo "✓ SSH zaten kurulu"
else
    echo "SSH yüklü değil, kuruluyor..."
    sudo apt-get update
    sudo apt-get install -y openssh-server
    echo "✓ SSH kuruldu"
fi

# SSH yapılandırma
echo "[3/5] SSH yapılandırması..."
sudo systemctl enable ssh
echo "✓ SSH otomatik başlatma aktif"

# SSH servisini başlat
echo "[4/5] SSH servisi başlatılıyor..."
sudo systemctl restart ssh

# Kontrol
if sudo systemctl is-active --quiet ssh; then
    echo "✓ SSH servisi çalışıyor"
else
    echo "✗ UYARI: SSH servisi başlatılamadı"
fi

# Network bilgisi
echo "[5/5] Network bilgisi..."
echo ""
echo "=========================================="
echo "SSH Kurulumu Tamamlandı!"
echo "=========================================="
echo ""
echo "IP Adresleri:"
hostname -I
echo ""
echo "Bağlanmak için:"
echo "  ssh $(whoami)@$(hostname -I | awk '{print $1}')"
echo ""
SSHSETUP

if [ "$USE_EXPECT" = true ]; then
    # EXPECT İLE TAM OTOMATİK KURULUM
    echo "Expect ile otomatik kurulum başlatılıyor..."
    
    TEMP_EXPECT=$(mktemp)
    cat > "$TEMP_EXPECT" << 'EXPECTEOF'
#!/usr/bin/expect -f

set timeout 120
set port [lindex $argv 0]
set baud [lindex $argv 1]
set user [lindex $argv 2]
set pass [lindex $argv 3]

spawn picocom -b $baud $port

send_user "\n=== Picocom ile bağlanıldı ===\n"
sleep 2

# Enter gönder
send "\r"
sleep 1

# Login kontrolü
expect {
    "login:" {
        send "$user\r"
        expect "assword:"
        send "$pass\r"
        expect -re ".*@.*:"
    }
    -re ".*@.*:" {
        send_user "Zaten login olunmuş\n"
    }
    timeout {
        send_user "HATA: Login prompt bulunamadı\n"
        exit 1
    }
}

send_user "\n=== Script oluşturuluyor ===\n"

# Script oluştur
send "cat > /tmp/setup_ssh.sh << 'SSHEOF'\r"
sleep 1
send "#!/bin/bash\r"
send "echo '=== SSH Kurulumu Başlatılıyor ==='\r"
send "sudo apt-get update && sudo apt-get install -y openssh-server\r"
send "sudo systemctl enable ssh\r"
send "sudo systemctl restart ssh\r"
send "sudo systemctl status ssh --no-pager\r"
send "echo ''\r"
send "echo 'IP Adresleri:'\r"
send "hostname -I\r"
send "echo 'SSH ile bağlanmak için: ssh $user@'\$(hostname -I | awk '{print \$1}')\r"
send "SSHEOF\r"
expect -re ".*@.*:"

send "chmod +x /tmp/setup_ssh.sh\r"
expect -re ".*@.*:"

send_user "\n=== SSH kurulum scripti çalıştırılıyor ===\n"
send "echo $pass | sudo -S /tmp/setup_ssh.sh\r"

expect {
    -re "SSH ile bağlanmak için:.*" {
        send_user "\n=== Kurulum başarılı! ===\n"
    }
    timeout {
        send_user "\nUYARI: Kurulum uzun sürdü\n"
    }
}

send_user "\n========================================\n"
send_user "Kurulum tamamlandı!\n"
send_user "Picocom'dan çıkmak için: Ctrl+A Ctrl+X\n"
send_user "========================================\n\n"

# Interactive moda geç
interact
EXPECTEOF

    chmod +x "$TEMP_EXPECT"
    $TEMP_EXPECT "$SERIAL_PORT" "$BAUD_RATE" "$ORIN_USER" "$ORIN_PASS"
    rm -f "$TEMP_EXPECT"

else
    # PICOCOM İLE YARI-OTOMATİK KURULUM
    echo "=========================================="
    echo "PICOCOM BAŞLATILIYOR..."
    echo "=========================================="
    echo ""
    echo "Şimdi picocom açılacak. Aşağıdaki komutları sırayla çalıştırın:"
    echo ""
    echo "1) Login olun (kullanıcı: $ORIN_USER)"
    echo ""
    echo "2) Aşağıdaki komutları kopyalayın ve picocom'a yapıştırın:"
    echo ""
    echo "---[ BAŞLANGIÇ ]---"
    cat /tmp/setup_ssh_local.sh
    echo "---[ BİTİŞ ]---"
    echo ""
    echo "3) Çıkmak için: Ctrl+A ardından Ctrl+X"
    echo ""
    read -p "Devam etmek için Enter'a basın..." 
    
    picocom -b "$BAUD_RATE" "$SERIAL_PORT"
fi

# Temizlik
rm -f /tmp/setup_ssh_local.sh

echo ""
echo "Script tamamlandı!"