#!/bin/bash
# Comprehensive Backup Storage Analysis and Cleanup Strategy
echo "💾 BACKUP STORAGE ANALYSIS & CLEANUP STRATEGY"
echo "=============================================="

BACKUP_DIR="/mnt/pve/Backups/dump"
echo "📍 Analyzing: $BACKUP_DIR"

echo ""
echo "1️⃣ CURRENT STORAGE STATUS:"
echo "=========================="
df -h /mnt/pve/Backups
echo ""

echo "2️⃣ BACKUP FILE ANALYSIS:"
echo "========================"
cd "$BACKUP_DIR"

echo "📊 Total files by type:"
echo "VMA files (VM backups): $(find . -name "*.vma.zst" | wc -l)"
echo "TAR files (Container backups): $(find . -name "*.tar.zst" | wc -l)"
echo "Log files: $(find . -name "*.log" | wc -l)"
echo "Note files: $(find . -name "*.notes" | wc -l)"
echo "Temp directories: $(find . -name "*.tmp" -type d | wc -l)"

echo ""
echo "3️⃣ STORAGE BREAKDOWN BY CONTAINER/VM:"
echo "====================================="
echo "Analyzing backup sizes by VM/Container ID..."

# Group by VM/Container ID and show sizes
for id in $(ls | grep -E "(vzdump-lxc-|vzdump-qemu-)" | sed -E 's/.*-(lxc|qemu)-([0-9]+)-.*/\2/' | sort -n | uniq); do
    echo "📦 ID $id:"
    
    # LXC backups for this ID
    LXC_FILES=$(find . -name "*lxc-$id-*" -name "*.tar.zst" | wc -l)
    if [ $LXC_FILES -gt 0 ]; then
        LXC_SIZE=$(find . -name "*lxc-$id-*" -name "*.tar.zst" -exec du -ch {} + | tail -1 | cut -f1)
        echo "   📁 LXC Container: $LXC_FILES backups, Total: $LXC_SIZE"
        
        # Show dates for this LXC
        echo "   📅 Date range:"
        find . -name "*lxc-$id-*" -name "*.tar.zst" -printf '      %TY-%Tm-%Td\n' | sort | head -1 | xargs echo "      Oldest:"
        find . -name "*lxc-$id-*" -name "*.tar.zst" -printf '      %TY-%Tm-%Td\n' | sort | tail -1 | xargs echo "      Newest:"
    fi
    
    # VM backups for this ID
    VM_FILES=$(find . -name "*qemu-$id-*" -name "*.vma.zst" | wc -l)
    if [ $VM_FILES -gt 0 ]; then
        VM_SIZE=$(find . -name "*qemu-$id-*" -name "*.vma.zst" -exec du -ch {} + | tail -1 | cut -f1)
        echo "   🖥️  VM: $VM_FILES backups, Total: $VM_SIZE"
        
        # Show dates for this VM
        echo "   📅 Date range:"
        find . -name "*qemu-$id-*" -name "*.vma.zst" -printf '      %TY-%Tm-%Td\n' | sort | head -1 | xargs echo "      Oldest:"
        find . -name "*qemu-$id-*" -name "*.vma.zst" -printf '      %TY-%Tm-%Td\n' | sort | tail -1 | xargs echo "      Newest:"
    fi
    
    echo ""
done

echo ""
echo "4️⃣ LARGEST BACKUP FILES:"
echo "========================"
echo "Top 10 largest backup files:"
find . -name "*.tar.zst" -o -name "*.vma.zst" | xargs du -h | sort -hr | head -10

echo ""
echo "5️⃣ OLD BACKUP IDENTIFICATION:"
echo "============================="
echo "Backups older than 30 days:"
find . -name "*.tar.zst" -o -name "*.vma.zst" -mtime +30 -exec du -h {} \; | sort -hr

echo ""
echo "6️⃣ BACKUP RETENTION ANALYSIS:"
echo "============================="
echo "Current backup pattern analysis:"

# Check backup frequency
echo "📊 Backup frequency per container/VM (last 30 days):"
for id in $(ls | grep -E "(vzdump-lxc-|vzdump-qemu-)" | sed -E 's/.*-(lxc|qemu)-([0-9]+)-.*/\2/' | sort -n | uniq); do
    RECENT_COUNT=$(find . -name "*-$id-*" \( -name "*.tar.zst" -o -name "*.vma.zst" \) -mtime -30 | wc -l)
    if [ $RECENT_COUNT -gt 0 ]; then
        echo "   ID $id: $RECENT_COUNT backups in last 30 days"
    fi
done

echo ""
echo "7️⃣ SAFE CLEANUP RECOMMENDATIONS:"
echo "================================"

echo "🟢 SAFE TO DELETE (Low Risk):"
echo "------------------------------"
# Log files older than 7 days
LOG_COUNT=$(find . -name "*.log" -mtime +7 | wc -l)
LOG_SIZE=$(find . -name "*.log" -mtime +7 -exec du -ch {} + 2>/dev/null | tail -1 | cut -f1)
echo "📝 Old log files (>7 days): $LOG_COUNT files, $LOG_SIZE"

# Note files (small metadata files)
NOTE_COUNT=$(find . -name "*.notes" | wc -l)
NOTE_SIZE=$(find . -name "*.notes" -exec du -ch {} + 2>/dev/null | tail -1 | cut -f1)
echo "📄 Note files: $NOTE_COUNT files, $NOTE_SIZE"

echo ""
echo "🟡 MODERATE RISK (Recommended with caution):"
echo "--------------------------------------------"
# Backups older than 60 days, keeping newest 2 per VM/Container
echo "📦 Backup candidates for deletion (keeping 2 newest per VM/Container):"

for id in $(ls | grep -E "(vzdump-lxc-|vzdump-qemu-)" | sed -E 's/.*-(lxc|qemu)-([0-9]+)-.*/\2/' | sort -n | uniq); do
    # Count total backups for this ID
    TOTAL_BACKUPS=$(find . -name "*-$id-*" \( -name "*.tar.zst" -o -name "*.vma.zst" \) | wc -l)
    
    if [ $TOTAL_BACKUPS -gt 3 ]; then
        # Find old backups (keep newest 2)
        OLD_BACKUPS=$(find . -name "*-$id-*" \( -name "*.tar.zst" -o -name "*.vma.zst" \) -printf '%T@ %p\n' | sort -n | head -n -2 | wc -l)
        if [ $OLD_BACKUPS -gt 0 ]; then
            OLD_SIZE=$(find . -name "*-$id-*" \( -name "*.tar.zst" -o -name "*.vma.zst" \) -printf '%T@ %p\n' | sort -n | head -n -2 | cut -d' ' -f2- | xargs du -ch | tail -1 | cut -f1)
            echo "   ID $id: $OLD_BACKUPS old backups, $OLD_SIZE (keeping 2 newest)"
        fi
    fi
done

echo ""
echo "8️⃣ CLEANUP IMPACT CALCULATION:"
echo "=============================="

# Calculate total space that could be freed
SAFE_SPACE=$(find . -name "*.log" -mtime +7 -exec du -ch {} + 2>/dev/null | tail -1 | cut -f1)
echo "🟢 Safe cleanup (logs): $SAFE_SPACE"

# Calculate moderate risk cleanup
echo "🟡 Calculating moderate risk cleanup potential..."
MODERATE_TOTAL=0

echo ""
echo "9️⃣ RECOMMENDED ACTION PLAN:"
echo "=========================="
echo "Phase 1 (SAFE - Execute immediately):"
echo "   ✅ Delete log files older than 7 days"
echo "   ✅ Clean up .notes files if needed"
echo "   💾 Estimated space freed: ~$SAFE_SPACE"
echo ""
echo "Phase 2 (MODERATE - Execute with backup verification):"
echo "   ⚠️  Implement retention policy: Keep 2 newest backups per VM/Container"
echo "   ⚠️  Delete backups older than 60 days (except newest 2)"
echo "   💾 Estimated additional space freed: 20-40GB"
echo ""
echo "Phase 3 (ADVANCED - If still needed):"
echo "   🔴 Review large VM backups (qemu-114, qemu-117)"
echo "   🔴 Consider backup schedule optimization"
echo "   🔴 Evaluate storage expansion needs"

echo ""
echo "✅ ANALYSIS COMPLETED"
echo "===================="
echo "Next step: Review recommendations and execute cleanup phases"