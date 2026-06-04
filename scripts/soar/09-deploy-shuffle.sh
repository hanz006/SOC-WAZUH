#!/usr/bin/env bash
# =============================================================
# 09-deploy-shuffle.sh
# Layer 3 SOAR — deploy Shuffle (open-source SOAR) via Docker.
# Bisa di VM manager (kalau RAM cukup) atau VM terpisah.
# =============================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo."; exit 1; }

echo "==> Install Docker (kalau belum ada)"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
if ! docker compose version >/dev/null 2>&1; then
  apt-get install -y docker-compose-plugin
fi

INSTALL_DIR="/opt/Shuffle"
if [ ! -d "$INSTALL_DIR" ]; then
  echo "==> Clone Shuffle"
  git clone https://github.com/shuffle/Shuffle "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

echo "==> Siapkan database directory"
mkdir -p shuffle-database
chown -R 1000:1000 shuffle-database

# Naikkan vm.max_map_count buat OpenSearch (dependency Shuffle)
echo "==> Tune kernel parameter"
sysctl -w vm.max_map_count=262144
grep -q "vm.max_map_count" /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf

echo "==> Start Shuffle stack"
docker compose up -d

echo
echo "✅ Shuffle berjalan."
echo "   UI: http://$(curl -s ifconfig.me):3001"
echo "   Default login: admin / (akan di-set saat first login)"
echo
echo "Langkah berikutnya:"
echo "  1. Login Shuffle, buat workflow baru."
echo "  2. Tambah trigger 'Webhook' → copy URL webhook."
echo "  3. Di Wazuh manager, tambahkan <integration> dengan hook_url tersebut."
echo "  4. Restart wazuh-manager."
