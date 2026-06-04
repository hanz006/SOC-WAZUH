#!/usr/bin/env bash
# =============================================================
# 06-analyze-alerts.sh
# Helper analisis alert di Wazuh Manager.
# Jalankan di VM manager dengan sudo.
# =============================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Jalankan dengan sudo."; exit 1; }

ALERTS="/var/ossec/logs/alerts/alerts.json"
[ -f "$ALERTS" ] || { echo "File alerts tidak ditemukan: $ALERTS"; exit 1; }

echo "============================================================"
echo " Ringkasan Alert (24 jam terakhir)"
echo "============================================================"

if ! command -v jq >/dev/null; then
  apt-get install -y jq >/dev/null
fi

SINCE=$(date -d '24 hours ago' +%s)

echo
echo "📊 Top 10 rule.description:"
tail -n 50000 "$ALERTS" | jq -r --argjson since "$SINCE" '
  select((.timestamp | sub("\\.[0-9]+\\+0000$";"Z") | fromdateiso8601) >= $since)
  | .rule.description' 2>/dev/null \
  | sort | uniq -c | sort -rn | head -10

echo
echo "📊 Top 10 srcip:"
tail -n 50000 "$ALERTS" | jq -r --argjson since "$SINCE" '
  select((.timestamp | sub("\\.[0-9]+\\+0000$";"Z") | fromdateiso8601) >= $since)
  | .data.srcip // empty' 2>/dev/null \
  | sort | uniq -c | sort -rn | head -10

echo
echo "📊 Distribusi level alert:"
tail -n 50000 "$ALERTS" | jq -r '.rule.level' 2>/dev/null \
  | sort | uniq -c | sort -rn

echo
echo "📌 Lihat alert level >= 10 (high severity) terbaru:"
tail -n 50000 "$ALERTS" | jq -c 'select(.rule.level >= 10) | {time:.timestamp, level:.rule.level, desc:.rule.description, srcip:.data.srcip}' 2>/dev/null \
  | tail -20
