#!/usr/bin/env bash
# =============================================================
# 99-cleanup.sh
# Hapus semua resource Azure agar credit tidak terus terpakai.
# =============================================================
set -euo pipefail
RG="${RG:-rg-wazuh-poc}"

echo "Akan menghapus resource group: $RG"
read -rp "Ketik nama RG untuk konfirmasi: " confirm
[ "$confirm" = "$RG" ] || { echo "Dibatalkan."; exit 0; }

az group delete --name "$RG" --yes --no-wait
echo "✅ Penghapusan dijalankan async. Cek dengan: az group show -n $RG"
