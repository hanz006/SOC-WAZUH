#!/usr/bin/env bash
# =============================================================
# 03-install-wazuh-agent.sh
# Install Wazuh Agent dan registrasikan ke manager.
# Env yang dibutuhkan:
#   MANAGER_IP : IP private/public manager
#   AGENT_NAME : nama agent (default: hostname)
# Contoh:
#   sudo MANAGER_IP=10.10.1.4 AGENT_NAME=agent-01 bash 03-install-wazuh-agent.sh
# =============================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo."; exit 1; }
: "${MANAGER_IP:?Set MANAGER_IP environment variable}"
AGENT_NAME="${AGENT_NAME:-$(hostname)}"
WAZUH_VER="4.9"

echo "==> Tambah repo Wazuh"
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list

apt-get update -y

echo "==> Install wazuh-agent"
WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_NAME="$AGENT_NAME" \
  apt-get install -y wazuh-agent

echo "==> Lock paket biar tidak auto-upgrade"
apt-mark hold wazuh-agent

echo "==> Enable & start service"
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

sleep 5
systemctl status wazuh-agent --no-pager | head -n 15

echo
echo "✅ Agent '$AGENT_NAME' terdaftar ke manager $MANAGER_IP"
echo "   Verifikasi di dashboard: Agents → status Active"
