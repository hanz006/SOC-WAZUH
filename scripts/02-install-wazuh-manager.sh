#!/usr/bin/env bash
# =============================================================
# 02-install-wazuh-manager.sh
# Install Wazuh All-in-One (Manager + Indexer + Dashboard)
# Jalankan di VM "wazuh-manager" dengan sudo.
# =============================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo."; exit 1; }

echo "==> Update sistem"
apt-get update -y
apt-get install -y curl gnupg apt-transport-https ca-certificates lsb-release

echo "==> Download Wazuh installer"
WAZUH_VER="4.9"
curl -sO "https://packages.wazuh.com/${WAZUH_VER}/wazuh-install.sh"
curl -sO "https://packages.wazuh.com/${WAZUH_VER}/config.yml"

echo "==> Patch config.yml dengan IP private VM ini"
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "   IP private terdeteksi: $PRIVATE_IP"
sed -i "s/<indexer-node-ip>/$PRIVATE_IP/g" config.yml
sed -i "s/<wazuh-manager-ip>/$PRIVATE_IP/g" config.yml
sed -i "s/<dashboard-node-ip>/$PRIVATE_IP/g" config.yml

echo "==> Generate config files"
bash wazuh-install.sh --generate-config-files

echo "==> Install Wazuh Indexer"
bash wazuh-install.sh --wazuh-indexer node-1

echo "==> Start cluster indexer"
bash wazuh-install.sh --start-cluster

echo "==> Install Wazuh Server (Manager + Filebeat)"
bash wazuh-install.sh --wazuh-server wazuh-1

echo "==> Install Wazuh Dashboard"
bash wazuh-install.sh --wazuh-dashboard dashboard

echo
echo "============================================================"
echo "✅ Wazuh terinstall."
echo "Akses dashboard: https://<PUBLIC_IP>"
echo
echo "Credential admin tersimpan di:"
echo "  /root/wazuh-install-files/wazuh-passwords.tool.sh"
echo
echo "Tampilkan password admin:"
echo "  sudo tar -xvf wazuh-install-files.tar"
echo "  sudo cat wazuh-install-files/wazuh-passwords.txt | grep -A1 'admin'"
echo "============================================================"
