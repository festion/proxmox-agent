#!/bin/bash
# Install Missing Optimizations (Snapshot Management + Security Updates)
echo "🔧 Installing Missing High Priority Optimizations"
echo "================================================"

echo ""
echo "1️⃣ Installing Snapshot Lifecycle Management:"
echo "--------------------------------------------"

# Create snapshot cleanup script
cat > /etc/cron.daily/snapshot-cleanup << 'EOF'
#!/bin/bash
# Automated Snapshot Cleanup

LOG_FILE="/var/log/snapshot-cleanup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting snapshot cleanup" >> "$LOG_FILE"

# Clean VM snapshots older than 90 days
for vmid in $(qm list | awk 'NR>1 {print $1}'); do
    qm listsnapshot $vmid 2>/dev/null | grep -v current | grep -v NAME | while read snapshot_line; do
        snapshot_name=$(echo "$snapshot_line" | awk '{print $1}')
        snapshot_time=$(echo "$snapshot_line" | awk '{print $3}')
        
        if [ -n "$snapshot_time" ] && [ "$snapshot_time" != "0" ]; then
            age_seconds=$(($(date +%s) - snapshot_time))
            age_days=$((age_seconds / 86400))
            
            if [ $age_days -gt 90 ]; then
                echo "[$DATE] Deleting old VM $vmid snapshot '$snapshot_name' (${age_days} days)" >> "$LOG_FILE"
                qm delsnapshot $vmid "$snapshot_name" --force 2>/dev/null
            fi
        fi
    done
done

# Clean container snapshots older than 90 days
for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    pct listsnapshot $ctid 2>/dev/null | grep -v current | grep -v NAME | while read snapshot_line; do
        snapshot_name=$(echo "$snapshot_line" | awk '{print $1}')
        snapshot_time=$(echo "$snapshot_line" | awk '{print $3}')
        
        if [ -n "$snapshot_time" ] && [ "$snapshot_time" != "0" ]; then
            age_seconds=$(($(date +%s) - snapshot_time))
            age_days=$((age_seconds / 86400))
            
            if [ $age_days -gt 90 ]; then
                echo "[$DATE] Deleting old CT $ctid snapshot '$snapshot_name' (${age_days} days)" >> "$LOG_FILE"
                pct delsnapshot $ctid "$snapshot_name" --force 2>/dev/null
            fi
        fi
    done
done

echo "[$DATE] Snapshot cleanup completed" >> "$LOG_FILE"
EOF

chmod +x /etc/cron.daily/snapshot-cleanup
echo "✅ Snapshot cleanup script installed"

echo ""
echo "2️⃣ Installing Security Updates Automation:"
echo "------------------------------------------"

# Install unattended-upgrades
apt update
apt install -y unattended-upgrades apt-listchanges

# Configure unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
    "Proxmox:${distro_codename}";
};

Unattended-Upgrade::Package-Blacklist {
    "linux-.*";
    ".*-kernel-.*";
    "pve-kernel-.*";
    "proxmox-ve";
    "pve-manager";
};

Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
EOF

# Enable automatic updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Enable service
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

echo "✅ Security updates automation configured"

echo ""
echo "3️⃣ URGENT: Backup Storage Cleanup:"
echo "----------------------------------"
echo "⚠️  Backup storage is 100% full! Cleaning now..."

# Find and clean backup storage
BACKUP_DIR="/mnt/pve/Backups"
if [ -d "$BACKUP_DIR" ]; then
    cd "$BACKUP_DIR"
    echo "📊 BEFORE cleanup:"
    df -h "$BACKUP_DIR"
    
    echo "🗑️ Removing backups older than 60 days..."
    find . -name "*.tar.gz" -mtime +60 -delete
    find . -name "*.tar.lzo" -mtime +60 -delete
    find . -name "*.vma.gz" -mtime +60 -delete
    find . -name "*.vma.lzo" -mtime +60 -delete
    find . -name "*.log" -mtime +30 -delete
    
    echo "📊 AFTER cleanup:"
    df -h "$BACKUP_DIR"
else
    echo "❌ Backup directory not found at $BACKUP_DIR"
fi

echo ""
echo "✅ All missing optimizations installed!"
echo "======================================"

echo "📋 Summary:"
echo "   ✅ Snapshot cleanup: /etc/cron.daily/snapshot-cleanup"
echo "   ✅ Security updates: unattended-upgrades service"
echo "   ✅ Backup cleanup: Executed for immediate relief"
echo ""
echo "🔍 Verify with:"
echo "   systemctl status unattended-upgrades"
echo "   ls -la /etc/cron.daily/snapshot-cleanup"
echo "   df -h"