#!/usr/bin/env bash
# =============================================================
# 08-setup-discord-webhook.sh
# Layer 2 SOAR — kirim alert Wazuh ke Discord webhook.
# Jalankan di VM Wazuh Manager dengan sudo.
#
# Env wajib:
#   DISCORD_WEBHOOK : URL webhook Discord
# Contoh:
#   sudo DISCORD_WEBHOOK="https://discord.com/api/webhooks/..." bash 08-setup-discord-webhook.sh
# =============================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo."; exit 1; }
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-https://discord.com/api/webhooks/1508513149979070616/XexVKj3_6c9Aw6bVUYQvBpmibvFdEJqzC_utW5qrE2i2xYq2jAHhpP7zI1iiiL5E2woo}"

OSSEC_CONF="/var/ossec/etc/ossec.conf"
INTEG_DIR="/var/ossec/integrations"
SCRIPT_BIN="$INTEG_DIR/custom-discord"
SCRIPT_PY="$INTEG_DIR/custom-discord.py"

echo "==> Tulis backend Python (custom-discord.py)"
cat > "$SCRIPT_PY" <<'PYEOF'
#!/usr/bin/env python3
"""Wazuh -> Discord integration. Dipanggil oleh wazuh-manager."""
import json, sys, os, requests
from datetime import datetime

if len(sys.argv) < 4:
    sys.exit(0)

alert_file = sys.argv[1]
hook_url   = sys.argv[3]

with open(alert_file) as f:
    alert = json.load(f)

rule = alert.get("rule", {})
agent = alert.get("agent", {})
data = alert.get("data", {})
level = rule.get("level", 0)

# Warna sesuai severity
if level >= 12:
    color = 0xFF0000  # merah
elif level >= 7:
    color = 0xFFA500  # oranye
else:
    color = 0x36A64F  # hijau

embed = {
    "title": f"🚨 Wazuh Alert (level {level})",
    "description": rule.get("description", "-"),
    "color": color,
    "fields": [
        {"name": "Rule ID", "value": str(rule.get("id", "-")), "inline": True},
        {"name": "Agent",   "value": agent.get("name", "-"),  "inline": True},
        {"name": "Source IP", "value": data.get("srcip", "-"), "inline": True},
        {"name": "Groups",  "value": ", ".join(rule.get("groups", []) or ["-"])},
    ],
    "footer": {"text": f"Wazuh • {datetime.utcnow().isoformat()}Z"},
}

payload = {"username": "Wazuh SIEM", "embeds": [embed]}
try:
    r = requests.post(hook_url, json=payload, timeout=10)
    r.raise_for_status()
except Exception as e:
    sys.stderr.write(f"discord webhook error: {e}\n")
    sys.exit(1)
PYEOF

echo "==> Tulis launcher shell (custom-discord)"
cat > "$SCRIPT_BIN" <<'SHEOF'
#!/bin/sh
WPYTHON_BIN="framework/python/bin/python3"
SCRIPT_PATH_NAME="$0"
DIR_NAME="$(cd $(dirname ${SCRIPT_PATH_NAME}); pwd -P)"
SCRIPT_NAME="$(basename ${SCRIPT_PATH_NAME})"

# Coba python wazuh, fallback ke system python3
if [ -x "/var/ossec/${WPYTHON_BIN}" ]; then
  /var/ossec/${WPYTHON_BIN} "${DIR_NAME}/${SCRIPT_NAME}.py" "$@"
else
  /usr/bin/env python3 "${DIR_NAME}/${SCRIPT_NAME}.py" "$@"
fi
SHEOF

chmod 750 "$SCRIPT_BIN" "$SCRIPT_PY"
chown root:wazuh "$SCRIPT_BIN" "$SCRIPT_PY"

echo "==> Pastikan modul requests tersedia"
if ! python3 -c "import requests" 2>/dev/null; then
  apt-get install -y python3-requests || pip3 install requests
fi

echo "==> Tambahkan blok <integration> ke ossec.conf"
if grep -q "custom-discord" "$OSSEC_CONF"; then
  echo "   ✓ Sudah dikonfigurasi sebelumnya. Update hook URL saja."
  sed -i "s|<hook_url>https://discord.com/api/webhooks/[^<]*</hook_url>|<hook_url>${DISCORD_WEBHOOK}</hook_url>|" "$OSSEC_CONF"
else
  BLOCK="
  <!-- SOAR: Discord notification -->
  <integration>
    <name>custom-discord</name>
    <hook_url>${DISCORD_WEBHOOK}</hook_url>
    <level>10</level>
    <group>ddos,attack,authentication_failed,web</group>
    <alert_format>json</alert_format>
  </integration>
"
  awk -v block="$BLOCK" '
    /<\/ossec_config>/ { print block }
    { print }
  ' "$OSSEC_CONF" > "${OSSEC_CONF}.tmp" && mv "${OSSEC_CONF}.tmp" "$OSSEC_CONF"
fi

echo "==> Restart wazuh-manager"
systemctl restart wazuh-manager

echo
echo "✅ Discord webhook aktif."
echo "   Trigger threshold: alert level >= 10"
echo "   Test: jalankan simulasi DDoS, cek channel Discord."
