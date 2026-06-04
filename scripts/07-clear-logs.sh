#!/usr/bin/env bash
# =============================================================
# 07-clear-logs.sh
# Clear Wazuh manager and agent logs
# =============================================================

echo "🗑️  Clearing logs..."

# Find and clear Wazuh logs
if [ -d "/var/ossec/logs" ]; then
    echo "Clearing Wazuh logs in /var/ossec/logs..."
    sudo find /var/ossec/logs -type f -name "*.log" -exec truncate -s 0 {} \;
    echo "✅ Wazuh logs cleared"
else
    echo "⚠️  Wazuh logs directory not found"
fi

# Clear system journal logs
echo "Clearing system journal logs..."
sudo journalctl --vacuum-time=1s
echo "✅ Journal logs cleared"

# Optional: Clear specific application logs
if [ -d "/var/log" ]; then
    echo "Clearing application logs..."
    sudo find /var/log -type f -name "*.log" -newer /tmp 2>/dev/null | while read logfile; do
        sudo truncate -s 0 "$logfile" 2>/dev/null
    done
    echo "✅ Application logs cleared"
fi

echo "✅ All log clearing complete!"
