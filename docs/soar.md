# SOAR Integration untuk Wazuh

Dokumentasi penambahan fitur **SOAR** (Security Orchestration, Automation, and Response) ke deployment Wazuh PoC. Fokus utama: otomasi response terhadap serangan DDoS.

---

## 🤔 Apa itu SOAR?

**SOAR** = Security Orchestration, Automation, and Response — kemampuan platform keamanan untuk:

| Pillar | Maksud | Contoh di kasus DDoS |
|--------|--------|----------------------|
| **Orchestration** | Hubungkan banyak tool jadi satu workflow | Wazuh → Firewall → Notifikasi |
| **Automation** | Eksekusi response tanpa intervensi manusia | Auto-block IP attacker |
| **Response** | Tindakan konkret pasca-deteksi | Drop traffic, isolate host, notifikasi tim |

Tujuannya: **Mean Time To Respond (MTTR) turun dari menit/jam → detik**.

---

## 🎯 Skenario SOAR di PoC ini

```
┌─────────────────┐
│ Attacker (DDoS) │
└────────┬────────┘
         │ HTTP flood
         ▼
┌─────────────────┐    log     ┌──────────────────┐
│ Nginx (Agent)   │───────────▶│  Wazuh Manager   │
└────────┬────────┘            │  (Detection)     │
         │                     └────────┬─────────┘
         │                              │ rule.level >= 10
         │                              │
         │   ┌──────────────────────────┼─────────────────────┐
         │   │                          │                     │
         │   ▼                          ▼                     ▼
         │ Active Response       Webhook Notif         Shuffle Workflow
         │ (block via iptables)  (Discord/Slack)       (TheHive case +
         │                                              VirusTotal lookup)
         ▼
   IP attacker ter-block di firewall agent
```

3 lapisan otomasi yang akan dipasang:

| Layer | Tool | Scope | Latency |
|-------|------|-------|---------|
| **L1 — Native Active Response** | Wazuh built-in | Block IP via iptables di agent | < 5 detik |
| **L2 — Notification Webhook** | Custom integration | Push alert ke Discord/Slack | < 10 detik |
| **L3 — Full SOAR Workflow** | Shuffle (open-source) | Multi-step playbook + ticketing | 30-60 detik |

---

## ⚙️ Layer 1 — Wazuh Active Response (auto-block IP)

Wazuh punya fitur built-in `active-response` yang bisa eksekusi script di agent ketika rule tertentu match.

### Cara kerja
1. Manager mendeteksi DDoS (rule custom `100100` level 10).
2. Manager kirim perintah ke agent target.
3. Agent menjalankan `firewall-drop` script → block IP via iptables.
4. Setelah X detik (default 600), block otomatis di-revert.

### Setup

**Di Wazuh Manager**, edit `/var/ossec/etc/ossec.conf`:

```xml
<!-- Tambahkan di dalam <ossec_config> -->
<command>
  <name>firewall-drop</name>
  <executable>firewall-drop</executable>
  <timeout_allowed>yes</timeout_allowed>
</command>

<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>100100,100101,100103</rules_id>
  <timeout>600</timeout>
</active-response>
```

Lalu restart manager:
```bash
sudo systemctl restart wazuh-manager
```

`firewall-drop` sudah pre-installed di setiap agent di `/var/ossec/active-response/bin/firewall-drop`.

### Verifikasi
Setelah simulasi DDoS, di VM agent jalankan:
```bash
sudo iptables -L -n --line-numbers | grep DROP
sudo cat /var/ossec/logs/active-responses.log
```

Akan muncul rule iptables `DROP` untuk IP attacker, dan log eksekusi.

---

## 📢 Layer 2 — Webhook Notification (Discord / Slack)

Wazuh bisa push alert ke endpoint webhook eksternal via fitur `<integration>`.

### Setup Discord webhook

1. Buat webhook di Discord channel: **Settings → Integrations → Webhooks → New Webhook** → copy URL.

2. Di **Manager**, edit `/var/ossec/etc/ossec.conf`:

```xml
<integration>
  <name>custom-discord</name>
  <hook_url>https://discord.com/api/webhooks/XXXX/YYYY</hook_url>
  <level>10</level>
  <group>ddos,attack,authentication_failed</group>
  <alert_format>json</alert_format>
</integration>
```

3. Buat script integrasi `/var/ossec/integrations/custom-discord` (lihat `scripts/soar/custom-discord` di repo ini), set permission:

```bash
sudo cp custom-discord /var/ossec/integrations/
sudo chmod 750 /var/ossec/integrations/custom-discord
sudo chown root:wazuh /var/ossec/integrations/custom-discord
sudo systemctl restart wazuh-manager
```

### Setup Slack (alternatif)

Slack lebih gampang karena built-in:
```xml
<integration>
  <name>slack</name>
  <hook_url>https://hooks.slack.com/services/XXX/YYY/ZZZ</hook_url>
  <level>10</level>
  <alert_format>json</alert_format>
</integration>
```

Tidak perlu script tambahan, langsung kerja.

---

## 🔧 Layer 3 — Shuffle SOAR (full workflow)

[Shuffle](https://shuffler.io) = SOAR open-source berbasis no-code, mirip Zapier untuk security. Cocok untuk workflow kompleks: enrichment → ticketing → response.

### Arsitektur

```
Wazuh Manager  ──webhook──▶  Shuffle  ──▶  VirusTotal (cek reputasi IP)
                                │
                                ├──▶  TheHive (buat case)
                                │
                                ├──▶  Wazuh API (block agent)
                                │
                                └──▶  Discord/Email (notif)
```

### Deploy Shuffle (di VM manager atau VM terpisah)

```bash
# Install Docker + Compose
curl -fsSL https://get.docker.com | sudo sh
sudo apt install -y docker-compose-plugin

# Clone Shuffle
git clone https://github.com/shuffle/Shuffle
cd Shuffle
sudo mkdir -p shuffle-database
sudo chown -R 1000:1000 shuffle-database
sudo docker compose up -d
```

Akses UI di `http://<VM_IP>:3001` (default: admin/admin → ganti password).

### Hubungkan Wazuh ke Shuffle

1. Di Shuffle UI: **Workflows → New Workflow → Trigger: Webhook** → copy URL webhook.

2. Di **Wazuh Manager** `/var/ossec/etc/ossec.conf`:

```xml
<integration>
  <name>shuffle</name>
  <hook_url>http://<SHUFFLE_IP>:3001/api/v1/hooks/webhook_xxx</hook_url>
  <level>8</level>
  <alert_format>json</alert_format>
</integration>
```

3. Restart manager. Setiap alert level ≥ 8 akan trigger workflow Shuffle.

### Contoh playbook: DDoS auto-mitigation

```
Webhook (alert dari Wazuh)
    ↓
HTTP node (cek IP di VirusTotal)
    ↓
Conditional: VT score >= 5?
   ├── YES → Wazuh API: active-response firewall-drop
   │        + TheHive: create case (severity HIGH)
   │        + Discord: notif tim
   │
   └── NO  → Discord: notif "low confidence, manual review"
```

---

## 🧪 Testing SOAR Workflow

Setelah semua layer terpasang, lakukan PoC:

```bash
# Dari attacker
TARGET=<agent-public-ip> MODE=http DURATION=60 ./scripts/05-ddos-simulation.sh
```

Yang harus terjadi:
1. ⚡ **< 5 detik**: IP attacker masuk iptables DROP di agent (Layer 1).
2. 📨 **< 10 detik**: Notif Discord muncul (Layer 2).
3. 📋 **< 60 detik**: Case otomatis dibuat di TheHive + enrichment VirusTotal (Layer 3).

### Verifikasi tiap layer

| Layer | Cara cek |
|-------|----------|
| L1 | Di agent: `sudo iptables -L INPUT -n` → ada rule DROP |
| L1 | Di manager: `tail /var/ossec/logs/active-responses.log` |
| L2 | Cek channel Discord/Slack |
| L3 | Cek dashboard Shuffle → workflow run history |

---

## 📊 Metrik untuk Laporan

| Metrik | Sebelum SOAR | Sesudah SOAR |
|--------|--------------|--------------|
| Mean Time To Detect (MTTD) | ~5 dtk | ~5 dtk (sama) |
| Mean Time To Respond (MTTR) | manual (menit-jam) | < 10 detik |
| False positive handling | manual | otomatis (filter VT) |
| Audit trail | log Wazuh saja | Wazuh + TheHive case |

---

## ⚠️ Catatan Keamanan SOAR

- **Whitelist IP penting** sebelum aktifkan auto-block, jangan sampai self-DoS (block IP admin).
- **Test dulu di staging**: active-response yang salah konfigurasi bisa block legitimate user.
- **Set timeout wajar**: rule `<timeout>600</timeout>` artinya block 10 menit. Untuk PoC pakai pendek.
- **Monitor false positive**: review weekly, tune rules jika terlalu agresif.
- **Secret management**: hook URL Discord & API key VirusTotal jangan commit ke git.

---

## 📁 File terkait di repo

```
scripts/soar/
├── 07-setup-active-response.sh    # Konfigurasi Layer 1
├── 08-setup-discord-webhook.sh    # Konfigurasi Layer 2
├── 09-deploy-shuffle.sh           # Deploy Shuffle SOAR
├── custom-discord                 # Script integrasi Discord (dipanggil Wazuh)
└── custom-discord.py              # Backend Python untuk format payload

wazuh/
├── ossec-soar-snippet.xml         # Snippet config untuk dimasukkan ke ossec.conf
└── local_rules.xml                # Sudah berisi rule DDoS (100100-100103)
```

---

## 📚 Referensi

- Wazuh Active Response: https://documentation.wazuh.com/current/user-manual/capabilities/active-response/
- Wazuh Integration: https://documentation.wazuh.com/current/user-manual/manager/manual-integration.html
- Shuffle: https://shuffler.io/docs
- TheHive: https://docs.strangebee.com/thehive/
