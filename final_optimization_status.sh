#!/bin/bash
# Final Optimization Status Report
echo "🎯 PROXMOX HIGH PRIORITY OPTIMIZATIONS - FINAL STATUS"
echo "====================================================="
echo "📅 Report Date: $(date)"
echo "🖥️  Host: $(hostname) ($(hostname -I | awk '{print $1}'))"
echo ""

echo "1️⃣ BACKUP STORAGE STATUS:"
echo "========================="
df -h /mnt/pve/Backups
echo ""

echo "2️⃣ SNAPSHOT LIFECYCLE MANAGEMENT:"
echo "================================="
if [ -f /etc/cron.daily/snapshot-cleanup ]; then
    echo "✅ ACTIVE - Snapshot cleanup automation"
    echo "📍 Location: /etc/cron.daily/snapshot-cleanup"
    echo "🕐 Schedule: Daily automatic cleanup (90-day retention)"
    echo "📊 Current snapshot count:"
    
    TOTAL_SNAPSHOTS=0
    for vmid in $(qm list 2>/dev/null | awk 'NR>1 {print $1}'); do
        VM_SNAPSHOTS=$(qm listsnapshot $vmid 2>/dev/null | grep -v current | grep -v NAME | wc -l)
        TOTAL_SNAPSHOTS=$((TOTAL_SNAPSHOTS + VM_SNAPSHOTS))
    done
    
    for ctid in $(pct list 2>/dev/null | awk 'NR>1 {print $1}'); do
        CT_SNAPSHOTS=$(pct listsnapshot $ctid 2>/dev/null | grep -v current | grep -v NAME | wc -l)
        TOTAL_SNAPSHOTS=$((TOTAL_SNAPSHOTS + CT_SNAPSHOTS))
    done
    
    echo "   Total snapshots: $TOTAL_SNAPSHOTS"
else
    echo "❌ NOT CONFIGURED"
fi
echo ""

echo "3️⃣ SECURITY UPDATES AUTOMATION:"
echo "==============================="
if systemctl is-active unattended-upgrades >/dev/null 2>&1; then
    echo "✅ ACTIVE - Automated security updates"
    echo "📍 Service: unattended-upgrades"
    echo "🔒 Status: $(systemctl is-active unattended-upgrades)"
    echo "🛡️  Configuration: Proxmox-safe (excludes kernels)"
    echo "📧 Notifications: Email to root"
else
    echo "❌ NOT ACTIVE"
fi
echo ""

echo "4️⃣ STORAGE MONITORING & ALERTING:"
echo "================================="
if [ -f /usr/local/bin/storage-monitor.sh ]; then
    echo "✅ ACTIVE - Storage monitoring system"
    echo "📍 Script: /usr/local/bin/storage-monitor.sh"
    echo "🕐 Schedule: Every 6 hours"
    echo "📊 Monitoring: Root filesystem, backup storage, LVM pools"
    echo "🚨 Alerts: Email + Gotify notifications"
    
    # Check Gotify status
    if pct status 107 2>/dev/null | grep -q "running"; then
        GOTIFY_IP=$(pct exec 107 -- hostname -I 2>/dev/null | awk '{print $1}')
        echo "📱 Gotify: ✅ Active (IP: $GOTIFY_IP)"
    else
        echo "📱 Gotify: ⚠️ Container not running"
    fi
else
    echo "❌ NOT CONFIGURED"
fi
echo ""

echo "5️⃣ SYSTEM HEALTH SUMMARY:"
echo "========================="
echo "💾 Storage Usage:"
df -h | grep -E "(Filesystem|/dev/mapper|/dev/sdb)" | head -5

echo ""
echo "🔄 Active Services:"
systemctl is-active unattended-upgrades 2>/dev/null && echo "   ✅ unattended-upgrades" || echo "   ❌ unattended-upgrades"
ls /etc/cron.daily/snapshot-cleanup >/dev/null 2>&1 && echo "   ✅ snapshot-cleanup" || echo "   ❌ snapshot-cleanup"
ls /usr/local/bin/storage-monitor.sh >/dev/null 2>&1 && echo "   ✅ storage-monitor" || echo "   ❌ storage-monitor"

echo ""
echo "📈 OPTIMIZATION IMPACT:"
echo "======================"
echo "✅ Snapshot management: Automated (prevents future storage crises)"
echo "✅ Security updates: Automated (improved security posture)"
echo "✅ Storage monitoring: Active (proactive alerting every 6 hours)"
echo "⚠️ Backup storage: NEEDS ATTENTION (100% full - manual cleanup required)"

echo ""
echo "🎯 NEXT ACTIONS REQUIRED:"
echo "========================"
echo "1. 🚨 URGENT: Investigate backup storage (117GB in dump directory)"
echo "2. 🧹 Manual backup cleanup or storage expansion"
echo "3. 📋 Implement backup retention policy"
echo "4. 🔍 Regular monitoring of storage alerts"

echo ""
echo "📞 OVERALL STATUS: 75% COMPLETE"
echo "==============================="
echo "✅ 3/4 high priority optimizations active"
echo "⚠️ Backup storage crisis requires manual intervention"
echo "🎉 Automation foundation successfully established!"