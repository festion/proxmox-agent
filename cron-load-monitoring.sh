#!/bin/bash
# Automated Load Monitoring Cron Setup
# Sets up monitoring and remediation for IO delays and CPU load spikes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/scripts/io-load-monitor.sh"
REMEDIATION_SCRIPT="$SCRIPT_DIR/load-spike-remediation.sh"

# Make scripts executable
chmod +x "$MONITOR_SCRIPT" "$REMEDIATION_SCRIPT" 2>/dev/null

# Function to check if script exists
check_script() {
    if [ ! -f "$1" ]; then
        echo "ERROR: Script not found: $1"
        echo "Please ensure the monitoring scripts are in the correct location."
        exit 1
    fi
}

# Validate scripts exist
check_script "$MONITOR_SCRIPT"
check_script "$REMEDIATION_SCRIPT"

echo "Setting up load monitoring and remediation cron jobs..."

# Create temporary cron file
TEMP_CRON=$(mktemp)

# Get existing crontab (suppress error if no crontab exists)
crontab -l 2>/dev/null > "$TEMP_CRON" || touch "$TEMP_CRON"

# Remove any existing load monitoring entries
sed -i '/io-load-monitor\|load-spike-remediation/d' "$TEMP_CRON"

# Add new monitoring entries
cat >> "$TEMP_CRON" << EOF

# Proxmox Load Monitoring (every 2 minutes)
*/2 * * * * $MONITOR_SCRIPT monitor >/dev/null 2>&1

# Load spike remediation check (every 5 minutes)
*/5 * * * * LOAD=\$(cat /proc/loadavg | cut -d' ' -f1); if [ \$(echo "\$LOAD > 3.0" | bc -l 2>/dev/null) = 1 ]; then $REMEDIATION_SCRIPT remediate >/dev/null 2>&1; fi

# Daily load trends report (at 6 AM)
0 6 * * * $MONITOR_SCRIPT trends | mail -s "Daily Load Report - \$(hostname)" admin@local 2>/dev/null || logger -t load-monitor "Daily trends: \$($MONITOR_SCRIPT trends | tail -5)"

# Cleanup old logs (weekly at 2 AM Sunday)
0 2 * * 0 find /var/log/proxmox-agent -name "*.log" -mtime +30 -delete 2>/dev/null; find /var/log/proxmox-agent -name "*.csv" -mtime +60 -delete 2>/dev/null

EOF

# Install the new crontab
if crontab "$TEMP_CRON"; then
    echo "✓ Cron jobs installed successfully"
    echo ""
    echo "Monitoring schedule:"
    echo "  - System monitoring: Every 2 minutes"
    echo "  - Remediation check: Every 5 minutes (when load > 3.0)"
    echo "  - Daily report: 6:00 AM"
    echo "  - Log cleanup: Weekly on Sunday 2:00 AM"
    echo ""
    echo "Log files location: /var/log/proxmox-agent/"
    echo ""
    echo "To view current monitoring:"
    echo "  $MONITOR_SCRIPT trends"
    echo ""
    echo "To manually run remediation:"
    echo "  $REMEDIATION_SCRIPT remediate"
else
    echo "ERROR: Failed to install cron jobs"
    rm -f "$TEMP_CRON"
    exit 1
fi

# Cleanup
rm -f "$TEMP_CRON"

# Install dependencies
echo "Installing monitoring dependencies..."
$MONITOR_SCRIPT install-deps

# Initial monitoring run
echo "Running initial monitoring check..."
$MONITOR_SCRIPT monitor

echo ""
echo "Load monitoring setup complete!"
echo ""
echo "Current system status:"
echo "Load average: $(cat /proc/loadavg | cut -d' ' -f1-3)"
echo "Memory usage: $(free | awk '/^Mem:/ {printf "%.1f%%", $3/$2*100}')"

# Show current crontab for verification
echo ""
echo "Installed cron jobs:"
crontab -l | grep -E "(io-load-monitor|load-spike-remediation|proxmox-agent)" | sed 's/^/  /'