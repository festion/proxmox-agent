#!/bin/bash
# Emergency Backup Storage Fix
echo "🚨 EMERGENCY BACKUP STORAGE INTERVENTION"
echo "========================================"

BACKUP_DIR="/mnt/pve/Backups"
echo "📍 Target: $BACKUP_DIR"

echo ""
echo "📊 Current storage status:"
df -h "$BACKUP_DIR"

echo ""
echo "📋 Current backup files:"
cd "$BACKUP_DIR"
ls -lhat *.{tar,tar.gz,tar.lzo,vma,vma.gz,vma.lzo} 2>/dev/null | head -20

echo ""
echo "🔍 Analyzing backup files by size:"
du -sh * 2>/dev/null | sort -hr | head -10

echo ""
echo "📅 Files by age (newest first):"
ls -lt | head -15

echo ""
echo "🗑️ AGGRESSIVE CLEANUP - removing 30+ day old backups:"
echo "Before:"
df -h "$BACKUP_DIR"

# More aggressive cleanup
find . -name "*.tar.gz" -mtime +30 -ls
find . -name "*.tar.lzo" -mtime +30 -ls
find . -name "*.vma.gz" -mtime +30 -ls
find . -name "*.vma.lzo" -mtime +30 -ls

echo ""
echo "⚠️ Proceeding with 30-day cleanup..."
find . -name "*.tar.gz" -mtime +30 -delete
find . -name "*.tar.lzo" -mtime +30 -delete
find . -name "*.vma.gz" -mtime +30 -delete
find . -name "*.vma.lzo" -mtime +30 -delete
find . -name "*.log" -mtime +7 -delete
find . -name "*.tmp" -mtime +1 -delete

echo ""
echo "📊 After 30-day cleanup:"
df -h "$BACKUP_DIR"

# If still critical, suggest manual intervention
USAGE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$USAGE" -gt 95 ]; then
    echo ""
    echo "🆘 STILL CRITICAL - Manual intervention required!"
    echo "================================================"
    echo ""
    echo "📋 All remaining files:"
    ls -lh
    echo ""
    echo "💡 Manual cleanup options:"
    echo "   1. Remove specific large backup files manually"
    echo "   2. Move backups to external storage"
    echo "   3. Expand backup storage capacity"
    echo ""
    echo "⚠️ EMERGENCY COMMANDS (use carefully):"
    echo "   # Remove 15+ day old backups:"
    echo "   find . -name '*.tar.gz' -mtime +15 -delete"
    echo "   find . -name '*.vma.gz' -mtime +15 -delete"
    echo ""
    echo "   # Remove oldest 50% of backups:"
    echo "   ls -t *.{tar.gz,vma.gz} | tail -n +\$((\$(ls -1 *.{tar.gz,vma.gz} | wc -l) / 2 + 1)) | xargs rm"
else
    echo "✅ Backup storage usage now acceptable ($USAGE%)"
fi

echo ""
echo "🎯 Next steps:"
echo "   1. Implement automated backup retention policy"
echo "   2. Consider expanding backup storage"
echo "   3. Monitor backup storage regularly"