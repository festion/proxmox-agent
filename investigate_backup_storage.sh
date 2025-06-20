#!/bin/bash
# Investigate Backup Storage - Deep Analysis
echo "🔍 DEEP BACKUP STORAGE INVESTIGATION"
echo "===================================="

BACKUP_DIR="/mnt/pve/Backups"
echo "📍 Investigating: $BACKUP_DIR"

echo ""
echo "📊 Storage overview:"
df -h "$BACKUP_DIR"

echo ""
echo "🗂️ Directory structure:"
ls -la "$BACKUP_DIR"

echo ""
echo "📁 Investigating dump directory (117GB):"
cd "$BACKUP_DIR/dump"
echo "Current directory: $(pwd)"

echo ""
echo "📋 Contents of dump directory:"
ls -la

echo ""
echo "📊 Size breakdown by subdirectory/file:"
du -sh * 2>/dev/null | sort -hr

echo ""
echo "🔍 Looking for backup files:"
echo "=== TAR files ==="
find . -name "*.tar*" -ls 2>/dev/null

echo ""
echo "=== VMA files ==="
find . -name "*.vma*" -ls 2>/dev/null

echo ""
echo "=== Log files ==="
find . -name "*.log" -ls 2>/dev/null

echo ""
echo "=== Temporary files ==="
find . -name "*.tmp" -ls 2>/dev/null

echo ""
echo "🗃️ All files larger than 100MB:"
find . -size +100M -ls 2>/dev/null

echo ""
echo "📅 Files by modification time (last 20):"
find . -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -20

echo ""
echo "🧹 SAFE CLEANUP OPPORTUNITIES:"
echo "=============================="

echo "1. Temporary files older than 1 day:"
find . -name "*.tmp" -mtime +1 -ls 2>/dev/null

echo ""
echo "2. Log files older than 30 days:"
find . -name "*.log" -mtime +30 -ls 2>/dev/null

echo ""
echo "3. Files with 'old' in name:"
find . -name "*old*" -ls 2>/dev/null

echo ""
echo "💡 MANUAL CLEANUP COMMANDS:"
echo "=========================="
echo "# Remove temp files older than 1 day:"
echo "find $BACKUP_DIR/dump -name '*.tmp' -mtime +1 -delete"
echo ""
echo "# Remove old log files:"
echo "find $BACKUP_DIR/dump -name '*.log' -mtime +30 -delete"
echo ""
echo "# Show largest files for manual review:"
echo "find $BACKUP_DIR/dump -type f -exec ls -lh {} \\; | sort -k5 -hr | head -10"

echo ""
echo "🎯 INVESTIGATION COMPLETE"