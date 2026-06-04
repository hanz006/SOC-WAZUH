#!/usr/bin/env bash
# =============================================================
# 04-setup-target-service.sh
# Setup Nginx sebagai target service & teruskan log ke Wazuh.
# Jalankan di VM agent dengan sudo.
# =============================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo."; exit 1; }

echo "==> Install Nginx"
apt-get update -y
apt-get install -y nginx

systemctl enable nginx
systemctl start nginx

echo "==> Pastikan log akses ada di /var/log/nginx/access.log"
ls -lh /var/log/nginx/access.log

OSSEC_CONF="/var/ossec/etc/ossec.conf"
if [ ! -f "$OSSEC_CONF" ]; then
  echo "Wazuh agent belum terinstall, jalankan 03-install-wazuh-agent.sh dulu."
  exit 1
fi

echo "==> Tambah konfigurasi localfile untuk Nginx"
if ! grep -q "/var/log/nginx/access.log" "$OSSEC_CONF"; then
  # Sisipkan sebelum </ossec_config>
  sed -i 's#</ossec_config>#  <localfile>\n    <log_format>apache</log_format>\n    <location>/var/log/nginx/access.log</location>\n  </localfile>\n  <localfile>\n    <log_format>apache</log_format>\n    <location>/var/log/nginx/error.log</location>\n  </localfile>\n</ossec_config>#' "$OSSEC_CONF"
  echo "   ✓ Blok localfile ditambahkan."
else
  echo "   ✓ Sudah dikonfigurasi sebelumnya."
fi

echo "==> Restart Wazuh agent"
systemctl restart wazuh-agent

echo
echo "✅ Nginx aktif di http://$(curl -s ifconfig.me)"
echo "   Log akses Nginx sekarang dipantau Wazuh."
