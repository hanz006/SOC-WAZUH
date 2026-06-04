# SOC-WAZUH

## Anggota Tim

| No | Nama                       | NRP        |
| -- | -------------------------- | ---------- |
| 1  | Mochamad Rizki Nasrullah   | 5027241038 |
| 2  | M Alfaeran Auriga Ruswandi | 5027241115 |

---

## Deskripsi Project

Project ini merupakan implementasi dan pengujian **Security Information and Event Management (SIEM)** menggunakan **Wazuh** pada infrastruktur **Microsoft Azure Cloud**. Sistem dibangun untuk memonitor aktivitas keamanan secara real-time serta mendeteksi serangan yang menargetkan layanan web berbasis Nginx.

Pengujian dilakukan melalui simulasi beberapa jenis serangan DDoS, yaitu **HTTP Flood**, **SYN Flood**, dan **Slowloris**, untuk membuktikan kemampuan Wazuh dalam mengumpulkan log, melakukan analisis keamanan, serta menghasilkan alert secara otomatis.

---

# Link Video Demo
| Demo |
|--------|
| (nanti link video dimasukin sini)) |

---

## Daftar Isi

* [Link Video Demo](#link-video-demo)
* [Arsitektur Sistem](#arsitektur-sistem)
* [Deployment Azure](#deployment-azure)
* [Konfigurasi Wazuh](#konfigurasi-wazuh)
* [Simulasi DDoS](#simulasi-ddos)
* [Analisis Detection](#analisis-detection)
* [Kendala](#kendala)
* [Solusi](#solusi)
* [Kesimpulan](#kesimpulan)

---

# Arsitektur Sistem

Wazuh merupakan platform SIEM open-source yang menggabungkan kemampuan:

* Host-based Intrusion Detection System (HIDS)
* Log Analysis
* Compliance Monitoring

Arsitektur yang dibangun menggunakan:

* 1 Wazuh Manager (All-in-One)
* 2 Wazuh Agent
* Infrastruktur Azure Cloud dalam satu Virtual Network (VNet)

### Tujuan

Membuktikan kemampuan Wazuh dalam mendeteksi serangan DDoS terhadap layanan web Nginx secara real-time.

### Topologi

* 3 VM berada dalam satu private VNet
* Agent mengirim log ke Manager melalui port TCP 1514
* Dashboard diakses melalui HTTPS (443)
* Attacker melakukan serangan melalui Public IP target

---

# Deployment Azure

Deployment dilakukan menggunakan:

* Azure Virtual Network (VNet)
* Azure Network Security Group (NSG)
* 3 Virtual Machine

Konfigurasi utama:

* Komunikasi Agent ↔ Manager menggunakan Private IP
* NSG digunakan untuk mengatur akses inbound dari internet
* Infrastruktur dibuat sederhana untuk kebutuhan Proof of Concept (PoC)

---

# Konfigurasi Wazuh

## Stack Wazuh

Implementasi menggunakan stack:

* Wazuh Manager
* Wazuh Indexer (OpenSearch)
* Wazuh Dashboard
* Wazuh Agent
* Filebeat

Alur data:

1. Agent mengumpulkan log.
2. Manager melakukan decoding dan rule matching.
3. Filebeat mengirim alert ke Indexer.
4. Dashboard menampilkan hasil monitoring.

---

## Enrollment Agent

Pendaftaran agent dilakukan secara otomatis menggunakan:

```bash
WAZUH_MANAGER
WAZUH_AGENT_NAME
```

Keuntungan:

* Tidak perlu distribusi key manual
* Memanfaatkan auto-enrollment pada port 1515
* Status agent dapat diverifikasi melalui Dashboard

---

## Konfigurasi Log Forwarding

Wazuh Agent dikonfigurasi untuk membaca log Nginx menggunakan tag:

```xml
<localfile>
```

Fungsi konfigurasi:

* Membaca access log Nginx
* Mengirim log ke Manager
* Melakukan parsing otomatis terhadap:

  * Source IP
  * URL Request
  * Status Code
  * User Agent

---

# Simulasi DDoS

Simulasi dilakukan menggunakan tiga metode serangan:

1. HTTP Flood
2. SYN Flood
3. Slowloris (Slow HTTP Attack)

Tujuan simulasi:

* Menguji ketahanan layanan web
* Menghasilkan trafik abnormal
* Memvalidasi kemampuan deteksi Wazuh

---

## DDoS Simulation Script

Fitur utama script:

* Menentukan target serangan
* Menentukan mode serangan
* Menentukan durasi serangan
* Validasi konfirmasi sebelum eksekusi
* Instalasi dependensi otomatis
* Penghentian otomatis menggunakan timeout

Tools yang digunakan:

* ApacheBench (ab)
* hping3
* SlowHTTPTest

---

# Analisis Detection

Hasil monitoring menunjukkan:

* Terjadi lonjakan log selama simulasi DDoS
* Wazuh berhasil menghasilkan alert keamanan
* Rule khusus DDoS berhasil dipicu
* Rule 5710 mendeteksi percobaan login ilegal
* Modul GeoIP berhasil mengidentifikasi lokasi IP penyerang

Manfaat:

* Monitoring real-time
* Korelasi event keamanan
* Investigasi insiden lebih cepat

---

## Hasil Simulasi

Target yang diuji:

```bash
4.194.3.48
20.212.25.217
```

Hasil:

* ApacheBench berhasil menghasilkan trafik HTTP Flood selama 60 detik
* SIEM berhasil menangkap IP penyerang
* GeoIP berhasil memetakan lokasi penyerang ke wilayah Indonesia
* Alert berhasil muncul pada dashboard Wazuh

---

## Alert Testing

Pengujian alert menunjukkan:

* Terjadi lonjakan event authentication_failed
* Aktivitas sshd meningkat selama simulasi
* Rule 5710 berhasil mendeteksi percobaan login ilegal
* Sistem mampu mengagregasi dan menampilkan log secara real-time

---

# Kendala

Beberapa kendala yang ditemukan:

1. Keterbatasan Azure Free Tier

   * RAM terbatas
   * Storage 30GB cepat penuh
   * Indexer sempat crash akibat lonjakan log

2. Konfigurasi Network Security Group (NSG)

   * Port TCP 1514 belum terbuka
   * Agent gagal mengirim log ke Manager

---

# Solusi

Solusi yang diterapkan:

1. Membatasi durasi simulasi DDoS menjadi maksimal 60 detik.
2. Membersihkan log arsip secara berkala.
3. Menambahkan Inbound Rule pada Azure NSG.
4. Membuka port TCP 1514 untuk komunikasi Agent dan Manager.

---

# Kesimpulan

Implementasi Wazuh SIEM pada Azure Cloud berhasil memberikan kemampuan monitoring dan deteksi keamanan secara real-time.

Melalui simulasi HTTP Flood, SYN Flood, dan Slowloris, sistem mampu:

* Mengumpulkan log secara terpusat
* Mendeteksi aktivitas anomali
* Menghasilkan alert otomatis
* Mengidentifikasi sumber serangan
* Memberikan visibilitas keamanan yang komprehensif

Meskipun terdapat keterbatasan pada Azure Free Tier, arsitektur yang dibangun tetap mampu membuktikan efektivitas Wazuh sebagai platform SIEM untuk kebutuhan deteksi dini dan mitigasi insiden keamanan.
