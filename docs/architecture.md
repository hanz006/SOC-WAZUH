# Detail Arsitektur

## Komponen

### 1. Wazuh Manager (VM-1)
- **Role:** SIEM core, indexer, dashboard
- **Service:** wazuh-manager, wazuh-indexer, wazuh-dashboard, filebeat
- **Port terbuka:**
  - `1514/tcp` agent communication
  - `1515/tcp` agent enrollment
  - `9200/tcp` indexer API
  - `55000/tcp` Wazuh API
  - `443/tcp` dashboard
# Tambah key teman ke semua VM
az vm user update --resource-group rg-wazuh --name wazuh-manager --username azureuser --ssh-key-value "$(Get-Content ~/.ssh/teman.pub)"
az vm user update --resource-group rg-wazuh --name wazuh-agent-1 --username azureuser --ssh-key-value "$(Get-Content ~/.ssh/teman.pub)"
az vm user update --resource-group rg-wazuh --name wazuh-agent-2 --username azureuser --ssh-key-value "$(Get-Content ~/.ssh/teman.pub)"

### 2. Wazuh Agent + Target (VM-2 & VM-3)
- **Role:** Endpoint yang dipantau + target serangan
- **Service:** wazuh-agent, nginx
- **Forwarding:** log Nginx (`/var/log/nginx/*.log`) → Wazuh agent → manager
- **Komunikasi:** outbound `1514/tcp` ke manager

### 3. Attacker (opsional)
- VM/Laptop terpisah yang menjalankan `hping3`, `ab`, atau `slowhttptest`
- Tidak ada agent — hanya generator trafik

## Alur Data

```
Nginx access.log ──► Wazuh agent (localfile) ──► TCP 1514 ──► Wazuh Manager
                                                                    │
                                                                    ▼
                                                            Decoder + Rule Engine
                                                                    │
                                                                    ▼
                                                          Wazuh Indexer (alerts)
                                                                    │
                                                                    ▼
                                                            Wazuh Dashboard
```

## Logging Density & Distribution

| Komponen | Lokasi log | Volume estimasi (saat normal) | Saat DDoS |
|----------|-----------|------------------------------|-----------|
| Nginx access log | `/var/log/nginx/access.log` | ~1 KB/req | bisa MB/s |
| Wazuh agent → manager | TCP 1514 | ~100 events/min/agent | ribuan events/menit |
| Manager alerts.json | `/var/ossec/logs/alerts/` | ~MB/hari | bisa ratusan MB/hari |

**Rekomendasi:**
- Pakai `<protocol>tcp</protocol>` (lebih reliable saat trafik tinggi).
- Aktifkan rotasi log Wazuh: `logrotate` sudah default.
- Untuk PoC, batasi durasi serangan agar disk indexer tidak penuh.