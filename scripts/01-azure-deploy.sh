#!/usr/bin/env bash
# =============================================================
# 01-azure-deploy.sh
# Provision infrastruktur Wazuh PoC di Azure (Student Free Tier)
# - 1 Resource Group
# - 1 VNet + Subnet
# - 1 NSG (port 22, 80, 443, 1514, 1515, 9200, 55000)
# - 3 VM Ubuntu 22.04 (manager + 2 agent)
# =============================================================
set -euo pipefail

# ---- Config (ubah sesuai kebutuhan) -------------------------
RG="rg-wazuh"
LOCATION="southeastasia"
VNET="vnet-wazuh"
SUBNET="snet-wazuh"
NSG="nsg-wazuh"
ADMIN_USER="azureuser"
SSH_KEY="${HOME}/.ssh/id_rsa.pub"
IMAGE="Ubuntu2204"


MANAGER_NAME="wazuh-manager"
MANAGER_SIZE="Standard_B2s"     # 2 vCPU, 4GB RAM
AGENT_SIZE="Standard_B1s"       # 1 vCPU, 1GB RAM
AGENT_NAMES=("wazuh-agent-1" "wazuh-agent-2")

INVENTORY="inventory.txt"
# -------------------------------------------------------------

command -v az >/dev/null || { echo "Azure CLI belum terinstall."; exit 1; }
[ -f "$SSH_KEY" ] || { echo "SSH public key tidak ditemukan di $SSH_KEY"; exit 1; }

echo "==> Cek login Azure"
az account show >/dev/null 2>&1 || az login

echo "==> Membuat resource group: $RG"
az group create --name "$RG" --location "$LOCATION" --output none

echo "==> Membuat VNet & Subnet"
az network vnet create \
  --resource-group "$RG" \
  --name "$VNET" \
  --address-prefix 10.10.0.0/16 \
  --subnet-name "$SUBNET" \
  --subnet-prefix 10.10.1.0/24 \
  --output none

echo "==> Membuat Network Security Group"
az network nsg create --resource-group "$RG" --name "$NSG" --output none

declare -A RULES=(
  [allow-ssh]="22"
  [allow-http]="80"
  [allow-https]="443"
  [allow-wazuh-agent]="1514"
  [allow-wazuh-enroll]="1515"
  [allow-indexer]="9200"
  [allow-wazuh-api]="55000"
)

PRIORITY=1000
for name in "${!RULES[@]}"; do
  port="${RULES[$name]}"
  az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name "$NSG" \
    --name "$name" \
    --priority "$PRIORITY" \
    --access Allow --protocol Tcp --direction Inbound \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges "$port" \
    --output none
  PRIORITY=$((PRIORITY+10))
done

# Helper buat VM
create_vm () {
  local NAME=$1 SIZE=$2
  echo "==> Provision VM: $NAME ($SIZE)"
  az vm create \
    --resource-group "$RG" \
    --name "$NAME" \
    --image "$IMAGE" \
    --size "$SIZE" \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values "$SSH_KEY" \
    --vnet-name "$VNET" \
    --subnet "$SUBNET" \
    --nsg "$NSG" \
    --public-ip-sku Standard \
    --os-disk-size-gb 30 \
    --output none
}

create_vm "$MANAGER_NAME" "$MANAGER_SIZE"
for a in "${AGENT_NAMES[@]}"; do
  create_vm "$a" "$AGENT_SIZE"
done

echo "==> Mengumpulkan public IP"
: > "$INVENTORY"
for vm in "$MANAGER_NAME" "${AGENT_NAMES[@]}"; do
  IP=$(az vm show -d -g "$RG" -n "$vm" --query publicIps -o tsv)
  PRIV=$(az vm show -d -g "$RG" -n "$vm" --query privateIps -o tsv)
  echo "$vm  public=$IP  private=$PRIV" | tee -a "$INVENTORY"
done

echo
echo "✅ Selesai. Inventaris ditulis ke: $INVENTORY"
echo "   SSH: ssh ${ADMIN_USER}@<public-ip>"
