#!/usr/bin/env bash
# =============================================================
# 07-setup-active-response.sh
# Layer 1 SOAR — aktifkan Active Response (auto-block IP DDoS)
# Jalankan di VM Wazuh Manager dengan sudo.
# =============================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo."; exit 1; }

OSSEC_CONF="/var/ossec/etc/ossec.conf"
BACKUP="${OSSEC_CONF}.bak.$(date +%s)"

echo "==> Backup ossec.conf → $BACKUP"
cp "$OSSEC_CONF" "$BACKUP"

if grep -q "<name>firewall-drop</name>" "$OSSEC_CONF"; then
  echo "✓ Active response 'firewall-drop' sudah dikonfigurasi sebelumnya."
else
  echo "==> Menambahkan blok command + active-response"
  AR_BLOCK='
  <!-- ====== SOAR: Active Response (auto-block) ====== -->
  <command>
    <name>firewall-drop</name>
    <executable>firewall-drop</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <active-response>
    <command>firewall-drop</command>
    <location>local</location>
    <rules_id>100100,100101,100102,100103</rules_id>
    <timeout>600</timeout>
  </active-response>
  <!-- ================================================ -->
'
  # Sisipkan sebelum </ossec_config>
  awk -v block="$AR_BLOCK" '
    /<\/ossec_config>/ { print block }
    { print }
  ' "$BACKUP" > "$OSSEC_CONF"
fi

echo "==> Validasi konfigurasi"
if /var/ossec/bin/wazuh-control configtest 2>/dev/null; then
  echo "   ✓ Config valid."
else
  /var/ossec/bin/wazuh-control configtest || true
fi

echo "==> Restart wazuh-manager"
systemctl restart wazuh-manager

echo
echo "✅ Active Response aktif untuk rule 100100-100103."
echo "   Block timeout: 600 detik."
echo "   Cek log eksekusi: tail -f /var/ossec/logs/active-responses.log"
