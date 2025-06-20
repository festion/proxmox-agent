#!/bin/bash
# Verify High Priority Optimizations Implementation
echo "📊 PROXMOX OPTIMIZATION VERIFICATION REPORT"
echo "============================================"
echo "📅 Generated: $(date)"
echo ""

echo "1️⃣ BACKUP STORAGE STATUS:"
echo "-------------------------"
df -h /var/lib/vz/dump 2>/dev/null || df -h /mnt/pve/Backups 2>/dev/null || echo "Backup storage not found at standard locations"
echo ""

echo "2️⃣ SNAPSHOT LIFECYCLE MANAGEMENT:"
echo "---------------------------------"
if [ -f /etc/cron.daily/snapshot-cleanup ]; then
    echo "✅ Snapshot cleanup script installed"
    ls -la /etc/cron.daily/snapshot-cleanup
    echo "Script preview:"
    head -10 /etc/cron.daily/snapshot-cleanup
else
    echo "❌ Snapshot cleanup script not found"
fi
echo ""

echo "3️⃣ SECURITY UPDATES AUTOMATION:"
echo "-------------------------------"
if command -v unattended-upgrades >/dev/null 2>&1; then
    echo "✅ unattended-upgrades installed"
    systemctl status unattended-upgrades --no-pager
    echo ""
    echo "Configuration check:"
    ls -la /etc/apt/apt.conf.d/*unattended* /etc/apt/apt.conf.d/*auto-upgrades*
else
    echo "❌ unattended-upgrades not installed"
fi
echo ""

echo "4️⃣ STORAGE MONITORING & ALERTING:"
echo "---------------------------------"
if [ -f /usr/local/bin/storage-monitor.sh ]; then
    echo "✅ Storage monitoring script installed"
    ls -la /usr/local/bin/storage-monitor.sh
else
    echo "❌ Storage monitoring script not found"
fi

if [ -f /usr/local/bin/storage-status.sh ]; then
    echo "✅ Storage status script installed"
    ls -la /usr/local/bin/storage-status.sh
else
    echo "❌ Storage status script not found"
fi

if [ -f /etc/cron.d/storage-monitoring ]; then
    echo "✅ Storage monitoring cron job configured"
    cat /etc/cron.d/storage-monitoring
else
    echo "❌ Storage monitoring cron job not found"
fi
echo ""

echo "5️⃣ CRON JOBS SUMMARY:"
echo "--------------------"
echo "System cron jobs:"
ls -la /etc/cron.daily/ | grep -E "(snapshot|storage)"
ls -la /etc/cron.d/ | grep -E "(monitoring|storage|security)"
echo ""

echo "6️⃣ CURRENT SYSTEM STATUS:"
echo "-------------------------"
echo "📊 Overall storage usage:"
df -h | grep -E "(Filesystem|/dev|tmpfs)" | head -10
echo ""

echo "📸 Current snapshot count:"
TOTAL_SNAPSHOTS=0
for vmid in $(qm list 2>/dev/null | awk 'NR>1 {print $1}'); do
    VM_SNAPSHOTS=$(qm listsnapshot $vmid 2>/dev/null | grep -v current | grep -v NAME | wc -l)
    TOTAL_SNAPSHOTS=$((TOTAL_SNAPSHOTS + VM_SNAPSHOTS))
done

for ctid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
    CT_SNAPSHOTS=$(pct listsnapshot $ctid 2>/dev/null | grep -v current | grep -v NAME | wc -l)
    TOTAL_SNAPSHOTS=$((TOTAL_SNAPSHOTS + CT_SNAPSHOTS))
done

echo "Total snapshots: $TOTAL_SNAPSHOTS"
echo ""

echo "🔒 Security update service status:"
systemctl is-enabled unattended-upgrades 2>/dev/null || echo "Service status unknown"
echo ""

echo "📧 Mail system check:"
which mail >/dev/null 2>&1 && echo "✅ Mail system available" || echo "⚠️ Mail system not configured"
echo ""

echo "📱 Gotify notification check:"
if pct status 107 2>/dev/null | grep -q "running"; then
    echo "✅ Gotify container (107) is running"
    GOTIFY_IP=$(pct exec 107 -- hostname -I 2>/dev/null | awk '{print $1}')
    echo "Gotify IP: $GOTIFY_IP"
else
    echo "⚠️ Gotify container (107) not running"
fi
echo ""

echo "✅ OPTIMIZATION VERIFICATION COMPLETED"
echo "======================================"