#!/bin/bash
# Clean Temporary Backup Directories
echo "🧹 CLEANING TEMPORARY BACKUP DIRECTORIES"
echo "========================================"

BACKUP_DIR="/mnt/pve/Backups/dump"
echo "📍 Target: $BACKUP_DIR"

echo ""
echo "📊 BEFORE cleanup:"
df -h "$BACKUP_DIR"

echo ""
echo "🔍 Identifying temporary directories:"
ls -la "$BACKUP_DIR" | grep "\.tmp"

echo ""
echo "📋 Temporary directory details:"
du -sh "$BACKUP_DIR"/*.tmp 2>/dev/null

echo ""
echo "🗑️ REMOVING temporary directories:"
echo "   - vzdump-lxc-102-2025_02_24-08_56_11.tmp (232MB)"
echo "   - vzdump-lxc-111-2025_02_24-08_47_22.tmp (147MB)"

# Remove the temporary directories
rm -rf "$BACKUP_DIR/vzdump-lxc-102-2025_02_24-08_56_11.tmp"
rm -rf "$BACKUP_DIR/vzdump-lxc-111-2025_02_24-08_47_22.tmp"

echo "✅ Temporary directories removed"

echo ""
echo "📊 AFTER cleanup:"
df -h "$BACKUP_DIR"

echo ""
echo "🎯 Space freed calculation:"
USAGE_BEFORE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
echo "Expected space freed: ~379MB"

echo ""
echo "✅ CLEANUP COMPLETED!"
echo "========================"
echo "🗂️ Removed failed backup attempts from February 2025"
echo "💾 This should free approximately 379MB of space"
echo "📈 Storage usage should decrease slightly"