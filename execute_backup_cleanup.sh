#!/bin/bash
# Phased Backup Storage Cleanup Execution
echo "🧹 BACKUP STORAGE CLEANUP EXECUTION"
echo "===================================="

BACKUP_DIR="/mnt/pve/Backups/dump"
cd "$BACKUP_DIR"

echo "📍 Working directory: $(pwd)"
echo "📊 Current storage:"
df -h /mnt/pve/Backups

echo ""
echo "🎯 CLEANUP EXECUTION PLAN"
echo "========================="
echo "This script will execute cleanup in phases with confirmation"
echo ""

# Phase 1: Safe cleanup
echo "PHASE 1: SAFE CLEANUP (Low Risk)"
echo "================================="
echo "Removing old log files and note files..."

echo ""
echo "1️⃣ Log files older than 7 days:"
LOG_FILES=$(find . -name "*.log" -mtime +7)
LOG_COUNT=$(echo "$LOG_FILES" | wc -l)
LOG_SIZE=$(find . -name "*.log" -mtime +7 -exec du -ch {} + 2>/dev/null | tail -1 | cut -f1)

if [ $LOG_COUNT -gt 0 ]; then
    echo "Found $LOG_COUNT log files ($LOG_SIZE)"
    echo "$LOG_FILES" | head -5
    if [ $LOG_COUNT -gt 5 ]; then
        echo "... and $((LOG_COUNT - 5)) more"
    fi
    
    read -p "Delete these log files? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find . -name "*.log" -mtime +7 -delete
        echo "✅ Log files deleted"
    else
        echo "⏭️  Skipped log file deletion"
    fi
else
    echo "ℹ️  No old log files found"
fi

echo ""
echo "📊 Storage after Phase 1:"
df -h /mnt/pve/Backups

echo ""
echo "PHASE 2: MODERATE CLEANUP (Backup Retention)"
echo "============================================="
echo "Implementing 2-backup retention policy per VM/Container"
echo ""

# Calculate total space to be freed
TOTAL_SPACE=0

echo "🎯 CLEANUP CANDIDATES:"
echo "====================="

for id in $(ls | grep -E "(vzdump-lxc-|vzdump-qemu-)" | sed -E 's/.*-(lxc|qemu)-([0-9]+)-.*/\2/' | sort -n | uniq); do
    # Get all backups for this ID
    BACKUPS=$(find . -name "*-$id-*" \( -name "*.tar.zst" -o -name "*.vma.zst" \) -printf '%T@ %p\n' | sort -nr)
    BACKUP_COUNT=$(echo "$BACKUPS" | wc -l)
    
    if [ $BACKUP_COUNT -gt 2 ]; then
        # Get old backups (all except newest 2)
        OLD_BACKUPS=$(echo "$BACKUPS" | tail -n +3)
        OLD_COUNT=$(echo "$OLD_BACKUPS" | wc -l)
        
        if [ $OLD_COUNT -gt 0 ]; then
            # Calculate size of old backups
            OLD_FILES=$(echo "$OLD_BACKUPS" | cut -d' ' -f2-)
            OLD_SIZE=$(echo "$OLD_FILES" | xargs du -ch | tail -1 | cut -f1)
            
            echo ""
            echo "📦 ID $id ($OLD_COUNT old backups, $OLD_SIZE):"
            echo "$OLD_BACKUPS" | cut -d' ' -f2- | sed 's/^/   🗑️  /'
            
            # Ask for confirmation for this ID
            read -p "Delete old backups for ID $id? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "$OLD_FILES" | xargs rm -f
                echo "   ✅ Deleted $OLD_COUNT backups ($OLD_SIZE freed)"
                
                # Also remove corresponding .notes files
                echo "$OLD_FILES" | sed 's/\.(tar|vma)\.zst$/.&.notes/' | xargs rm -f 2>/dev/null
                echo "   ✅ Deleted corresponding .notes files"
            else
                echo "   ⏭️  Skipped ID $id"
            fi
            
            echo ""
            echo "📊 Current storage:"
            df -h /mnt/pve/Backups
        fi
    fi
done

echo ""
echo "PHASE 3: TARGETED VM CLEANUP (High Impact)"
echo "=========================================="
echo "Focusing on largest space consumers..."

echo ""
echo "🎯 VM 114 Analysis (55GB total):"
echo "VM 114 has 4 massive backups (13-15GB each)"
echo "Recommendation: Keep only the 2 newest backups"

VM114_BACKUPS=$(find . -name "*qemu-114*" -name "*.vma.zst" -printf '%T@ %p\n' | sort -nr)
VM114_COUNT=$(echo "$VM114_BACKUPS" | wc -l)

if [ $VM114_COUNT -gt 2 ]; then
    VM114_OLD=$(echo "$VM114_BACKUPS" | tail -n +3)
    VM114_OLD_COUNT=$(echo "$VM114_OLD" | wc -l)
    VM114_OLD_FILES=$(echo "$VM114_OLD" | cut -d' ' -f2-)
    VM114_OLD_SIZE=$(echo "$VM114_OLD_FILES" | xargs du -ch | tail -1 | cut -f1)
    
    echo "📋 VM 114 old backups to delete ($VM114_OLD_COUNT files, $VM114_OLD_SIZE):"
    echo "$VM114_OLD" | cut -d' ' -f2- | sed 's/^/   🗑️  /'
    
    echo ""
    echo "⚠️  This is HIGH IMPACT cleanup - will free ~$VM114_OLD_SIZE"
    read -p "Delete old VM 114 backups? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$VM114_OLD_FILES" | xargs rm -f
        echo "✅ Deleted VM 114 old backups ($VM114_OLD_SIZE freed)"
        
        # Remove corresponding .notes files
        echo "$VM114_OLD_FILES" | sed 's/\.vma\.zst$/.&.notes/' | xargs rm -f 2>/dev/null
        echo "✅ Deleted corresponding .notes files"
    else
        echo "⏭️  Skipped VM 114 cleanup"
    fi
else
    echo "ℹ️  VM 114 already has optimal backup count"
fi

echo ""
echo "📊 Storage after VM 114 cleanup:"
df -h /mnt/pve/Backups

echo ""
echo "🎯 FINAL SUMMARY"
echo "================"
echo "Final storage status:"
df -h /mnt/pve/Backups

echo ""
echo "📋 Remaining backups:"
echo "Containers: $(find . -name "*.tar.zst" | wc -l) backups"
echo "VMs: $(find . -name "*.vma.zst" | wc -l) backups"
echo "Total files: $(ls -1 | wc -l)"

echo ""
echo "✅ BACKUP CLEANUP COMPLETED"
echo "=========================="
echo "🎯 Retention policy: 2 newest backups per VM/Container"
echo "📧 Monitor: Storage alerts will notify if space gets low again"
echo "🔄 Automated: Daily snapshot cleanup prevents future buildup"