#!/bin/bash
# Deployment script for load monitoring system
# Handles privilege escalation and proper setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/proxmox-agent"
TEMP_LOG_DIR="./logs"

echo "=== Proxmox Load Monitoring Deployment ==="
echo "Script directory: $SCRIPT_DIR"
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "✓ Running as root - can create system directories"
    USE_SYSTEM_LOGS=true
    ACTUAL_LOG_DIR="$LOG_DIR"
else
    echo "⚠ Not running as root - using local log directory"
    USE_SYSTEM_LOGS=false
    ACTUAL_LOG_DIR="$TEMP_LOG_DIR"
fi

# Create log directory
echo "Creating log directory: $ACTUAL_LOG_DIR"
mkdir -p "$ACTUAL_LOG_DIR" || {
    echo "ERROR: Cannot create log directory $ACTUAL_LOG_DIR"
    exit 1
}

# Update scripts to use correct log directory
echo "Updating scripts for log directory: $ACTUAL_LOG_DIR"

# Create modified version of io-load-monitor.sh with correct paths
sed "s|LOG_DIR=\"/var/log/proxmox-agent\"|LOG_DIR=\"$ACTUAL_LOG_DIR\"|g" \
    "$SCRIPT_DIR/scripts/io-load-monitor.sh" > "$ACTUAL_LOG_DIR/io-load-monitor-local.sh"

# Create modified version of remediation script
sed "s|LOG_FILE=\"/var/log/proxmox-agent/remediation.log\"|LOG_FILE=\"$ACTUAL_LOG_DIR/remediation.log\"|g; \
     s|BACKUP_DIR=\"/var/log/proxmox-agent/backups\"|BACKUP_DIR=\"$ACTUAL_LOG_DIR/backups\"|g" \
    "$SCRIPT_DIR/load-spike-remediation.sh" > "$ACTUAL_LOG_DIR/load-spike-remediation-local.sh"

# Make scripts executable
chmod +x "$ACTUAL_LOG_DIR/io-load-monitor-local.sh" "$ACTUAL_LOG_DIR/load-spike-remediation-local.sh"

# Install iostat if possible
echo "Checking for iostat availability..."
if command -v iostat >/dev/null 2>&1; then
    echo "✓ iostat already available"
elif [ "$EUID" -eq 0 ]; then
    echo "Installing sysstat package..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y sysstat
    elif command -v yum >/dev/null 2>&1; then
        yum install -y sysstat
    else
        echo "⚠ Cannot determine package manager - please install sysstat manually"
    fi
else
    echo "⚠ Cannot install iostat without root privileges"
    echo "  Please run 'sudo apt-get install sysstat' manually"
fi

# Create cron setup script with correct paths
cat > "$ACTUAL_LOG_DIR/setup-cron.sh" << EOF
#!/bin/bash
# Cron setup for load monitoring

MONITOR_SCRIPT="$ACTUAL_LOG_DIR/io-load-monitor-local.sh"
REMEDIATION_SCRIPT="$ACTUAL_LOG_DIR/load-spike-remediation-local.sh"

# Create temporary cron file
TEMP_CRON=\$(mktemp)

# Get existing crontab
crontab -l 2>/dev/null > "\$TEMP_CRON" || touch "\$TEMP_CRON"

# Remove existing entries
sed -i '/io-load-monitor\|load-spike-remediation/d' "\$TEMP_CRON"

# Add new entries
cat >> "\$TEMP_CRON" << 'CRONEOF'

# Proxmox Load Monitoring (every 2 minutes)
*/2 * * * * $ACTUAL_LOG_DIR/io-load-monitor-local.sh monitor >/dev/null 2>&1

# Load spike remediation check (every 5 minutes)
*/5 * * * * LOAD=\\\$(cat /proc/loadavg | cut -d' ' -f1); if [ \\\$(echo "\\\$LOAD > 3.0" | bc -l 2>/dev/null) = 1 ]; then $ACTUAL_LOG_DIR/load-spike-remediation-local.sh remediate >/dev/null 2>&1; fi

# Daily trends report (at 6 AM)
0 6 * * * $ACTUAL_LOG_DIR/io-load-monitor-local.sh trends >> $ACTUAL_LOG_DIR/daily-trends.log 2>&1

CRONEOF

# Install the crontab
crontab "\$TEMP_CRON" && echo "✓ Cron jobs installed" || echo "✗ Failed to install cron jobs"
rm -f "\$TEMP_CRON"
EOF

chmod +x "$ACTUAL_LOG_DIR/setup-cron.sh"

# Run initial monitoring test
echo "Running initial monitoring test..."
"$ACTUAL_LOG_DIR/io-load-monitor-local.sh" monitor

echo
echo "=== Deployment Summary ==="
echo "Log directory: $ACTUAL_LOG_DIR"
echo "Monitor script: $ACTUAL_LOG_DIR/io-load-monitor-local.sh"
echo "Remediation script: $ACTUAL_LOG_DIR/load-spike-remediation-local.sh"
echo "Cron setup: $ACTUAL_LOG_DIR/setup-cron.sh"
echo

if [ "$USE_SYSTEM_LOGS" = "true" ]; then
    echo "✓ System-wide deployment ready"
    echo "To activate cron monitoring: $ACTUAL_LOG_DIR/setup-cron.sh"
else
    echo "⚠ Local deployment (no root privileges)"
    echo "To activate cron monitoring: $ACTUAL_LOG_DIR/setup-cron.sh"
    echo "For system-wide deployment, run as root: sudo $0"
fi

echo
echo "Manual usage:"
echo "  Monitor: $ACTUAL_LOG_DIR/io-load-monitor-local.sh monitor"
echo "  Trends:  $ACTUAL_LOG_DIR/io-load-monitor-local.sh trends"
echo "  Remedy:  $ACTUAL_LOG_DIR/load-spike-remediation-local.sh remediate"

# Show current system status
echo
echo "Current system status:"
echo "Load averages: $(cat /proc/loadavg | cut -d' ' -f1-3)"
if command -v free >/dev/null 2>&1; then
    echo "Memory usage: $(free | awk '/^Mem:/ {printf "%.1f%%", $3/$2*100}')"
fi

# Check if we can detect high load
CURRENT_LOAD=$(cat /proc/loadavg | cut -d' ' -f1)
if [ $(echo "$CURRENT_LOAD > 2.0" | bc -l 2>/dev/null) = 1 ]; then
    echo "⚠ Current load ($CURRENT_LOAD) is elevated - monitoring is recommended"
else
    echo "✓ Current load ($CURRENT_LOAD) is within normal range"
fi