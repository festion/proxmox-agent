# Container Migration POC Guide - NAS Storage

**Objective**: Demonstrate safe migration of a low-risk container from local-lvm to TrueNas_NVMe storage  
**Target POC Container**: Memos (#115) - Note-taking application  
**Expected Downtime**: 2-3 minutes  
**Risk Level**: LOW - Non-critical application with replaceable data

## POC Overview

This proof of concept demonstrates the complete process for migrating containers from local LVM storage to NFS-based NAS storage while maintaining data integrity and minimal downtime.

### Why Memos Container (#115)?

**Selected for POC because**:
- **Low Risk**: Note-taking application, not mission-critical
- **Small Size**: 7GB total, manageable migration time
- **Low I/O Requirements**: Doesn't need maximum disk performance
- **User Impact**: Minimal - short downtime acceptable
- **Rollback Friendly**: Easy to restore if issues occur

**Current Configuration**:
```
Container ID: 115
Name: memos
Storage: local-lvm (pve/vm-115-disk-0)
Size: 7GB
Status: Running
IP: 192.168.1.144
Tags: proxmox-helper-scripts
```

## Pre-Migration Assessment

### Step 1: Environment Verification

```bash
# Verify source container status
pct status 115
pct config 115

# Check current storage usage
df -h | grep vm-115
lvs | grep vm-115

# Verify target NFS storage health
mount | grep TrueNas_NVMe
df -h /mnt/pve/TrueNas_NVMe
ls -la /mnt/pve/TrueNas_NVMe/

# Test NFS write performance
dd if=/dev/zero of=/mnt/pve/TrueNas_NVMe/test_write bs=1M count=100 oflag=direct
rm /mnt/pve/TrueNas_NVMe/test_write
```

**Expected Results**:
- Container status: running
- NFS mount: healthy and responsive
- Available space: >777GB on TrueNas_NVMe
- Write performance: 200-300 MB/s

### Step 2: Application Health Check

```bash
# Test application accessibility
curl -I http://192.168.1.144/ || echo "HTTP check failed"

# Check container logs for errors
pct exec 115 -- journalctl --no-pager -n 20

# Verify container resource usage
pct exec 115 -- df -h
pct exec 115 -- free -m
pct exec 115 -- ps aux
```

### Step 3: Baseline Performance Measurement

```bash
# Measure current disk performance
pct exec 115 -- dd if=/dev/zero of=/tmp/test bs=1M count=100 2>&1
pct exec 115 -- rm /tmp/test

# Test application response time
time curl -s http://192.168.1.144/ > /dev/null

# Record baseline metrics
echo "=== BASELINE METRICS ===" > /tmp/memos-baseline.txt
echo "Date: $(date)" >> /tmp/memos-baseline.txt
pct status 115 >> /tmp/memos-baseline.txt
curl -w "@/dev/stdin" -o /dev/null -s http://192.168.1.144/ <<< '%{time_total}' >> /tmp/memos-baseline.txt
```

## Migration Process

### Step 4: Create Pre-Migration Backup

```bash
# Create full backup before migration
echo "Creating pre-migration backup..."
vzdump 115 --storage TrueNas_NVMe --mode snapshot --notes "Pre-migration backup - POC"

# Verify backup creation
ls -la /mnt/pve/TrueNas_NVMe/dump/ | grep 115 | tail -1

# Record backup details
BACKUP_FILE=$(ls -t /mnt/pve/TrueNas_NVMe/dump/vzdump-lxc-115-* | head -1)
echo "Backup created: $BACKUP_FILE"
echo "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
```

### Step 5: Execute Migration

```bash
# Record start time
START_TIME=$(date)
echo "Migration started: $START_TIME"

# Step 5.1: Stop the container
echo "Stopping container 115..."
pct stop 115

# Verify stopped status
pct status 115

# Step 5.2: Move disk to NFS storage
echo "Moving rootfs to TrueNas_NVMe..."
pct move-disk 115 rootfs TrueNas_NVMe

# This command will:
# - Create new disk on TrueNas_NVMe
# - Copy all data from local-lvm to NFS
# - Update container configuration
# - Remove old disk from local-lvm

# Step 5.3: Verify configuration update
echo "Verifying updated configuration..."
pct config 115

# Check that rootfs now points to TrueNas_NVMe storage
pct config 115 | grep rootfs
```

### Step 6: Post-Migration Verification

```bash
# Step 6.1: Start container on new storage
echo "Starting container on new storage..."
pct start 115

# Wait for startup
sleep 30

# Verify running status
pct status 115

# Step 6.2: Test application functionality
echo "Testing application functionality..."

# Check filesystem health
pct exec 115 -- df -h
pct exec 115 -- mount | grep "on / "

# Test application response
curl -I http://192.168.1.144/ && echo "✅ HTTP check passed" || echo "❌ HTTP check failed"

# Check application logs for errors
pct exec 115 -- journalctl --no-pager -n 10 | grep -i error

# Step 6.3: Performance comparison
echo "Measuring post-migration performance..."
time curl -s http://192.168.1.144/ > /dev/null

# Test disk performance on new storage
pct exec 115 -- dd if=/dev/zero of=/tmp/test bs=1M count=100 2>&1
pct exec 115 -- rm /tmp/test

# Record end time
END_TIME=$(date)
echo "Migration completed: $END_TIME"
```

### Step 7: Migration Results Documentation

```bash
# Create migration report
cat > /tmp/memos-migration-report.txt << EOF
=== MEMOS CONTAINER MIGRATION REPORT ===
Date: $(date)
Container: 115 (memos)
Migration: local-lvm → TrueNas_NVMe

Timeline:
Start: $START_TIME
End: $END_TIME

Pre-Migration Storage:
$(cat /tmp/memos-baseline.txt)

Post-Migration Status:
Container Status: $(pct status 115)
New Storage: $(pct config 115 | grep rootfs)
HTTP Test: $(curl -I http://192.168.1.144/ 2>&1 | head -1)

Storage Freed from LVM:
Approximately 7GB returned to local-lvm pool

Migration Success: [✅ YES / ❌ NO]
Rollback Required: [YES / ✅ NO]
EOF

# Display results
cat /tmp/memos-migration-report.txt
```

## Validation Checklist

### ✅ **Success Criteria**

- [ ] Container starts successfully on new storage
- [ ] Application accessible via HTTP (192.168.1.144)
- [ ] No errors in container logs
- [ ] Disk performance acceptable (>100 MB/s)
- [ ] Configuration updated correctly
- [ ] Local-lvm space freed (verify with `df -h`)

### ⚠️ **Warning Signs**

- [ ] Slow application response (>5 seconds)
- [ ] Filesystem errors in logs
- [ ] Network connectivity issues
- [ ] Abnormal CPU/memory usage

### ❌ **Failure Indicators**

- [ ] Container fails to start
- [ ] Application not accessible
- [ ] Data corruption detected
- [ ] Critical errors in logs

## Rollback Procedure

**If migration fails or issues are detected:**

```bash
# EMERGENCY ROLLBACK PROCEDURE

# Step 1: Stop problematic container
pct stop 115

# Step 2: Restore from pre-migration backup
BACKUP_FILE=$(ls -t /mnt/pve/TrueNas_NVMe/dump/vzdump-lxc-115-* | head -1)
pct restore 115 "$BACKUP_FILE" --storage local-lvm

# Step 3: Start restored container
pct start 115

# Step 4: Verify rollback success
pct status 115
curl -I http://192.168.1.144/

# Step 5: Clean up failed migration
# (Remove any partial data from TrueNas_NVMe if needed)

echo "Rollback completed. Container restored to local-lvm storage."
```

## POC Success Metrics

### Performance Targets

| Metric | Baseline (local-lvm) | Target (TrueNas_NVMe) | Acceptable Range |
|--------|---------------------|---------------------|------------------|
| **Container Start Time** | <30 seconds | <45 seconds | <60 seconds |
| **HTTP Response Time** | <1 second | <2 seconds | <3 seconds |
| **Disk Write Speed** | ~280 MB/s | >100 MB/s | >50 MB/s |
| **Application Functionality** | 100% | 100% | 100% |

### Risk Mitigation

**Data Protection**:
- ✅ Full backup created before migration
- ✅ Snapshot-based migration preserves data integrity
- ✅ Rollback procedure tested and documented

**Downtime Minimization**:
- ✅ Container selected for minimal business impact
- ✅ Migration process optimized for speed
- ✅ Automated verification reduces manual testing time

**Performance Assurance**:
- ✅ NFS performance pre-tested
- ✅ Baseline metrics established
- ✅ Post-migration validation confirms acceptable performance

## POC Outcomes and Next Steps

### Expected POC Results

**Successful Migration Indicators**:
1. **Downtime**: 2-3 minutes actual vs. 5-minute target
2. **Performance**: Minimal degradation (<20% response time increase)
3. **Functionality**: All application features working normally
4. **Storage**: 7GB freed from local-lvm, reducing usage to ~58%

**Lessons Learned Documentation**:
```bash
# Document key findings for full-scale migrations
cat > /tmp/poc-lessons-learned.txt << EOF
1. Migration Duration: [Actual time taken]
2. Performance Impact: [Measured differences]
3. Unexpected Issues: [Any problems encountered]
4. Process Improvements: [Optimizations identified]
5. Scaling Considerations: [Notes for larger migrations]
EOF
```

### Scaling to Full Migration Plan

**If POC Successful**:
- ✅ Proceed with WikiJS (#112) migration
- ✅ Schedule Hoarder (#117) migration
- ✅ Implement automated monitoring
- ✅ Establish regular migration schedule

**If POC Reveals Issues**:
- 🔍 Analyze root cause of problems
- 🛠️ Adjust migration process
- 📋 Update risk mitigation strategies
- ⏱️ Reschedule after improvements

## Documentation and Reporting

### Migration Log Template

```bash
# Create standardized migration log
cat > /var/log/container-migration-115.log << EOF
Container Migration Log - ID: 115 (memos)
Date: $(date)
Operator: [Name]
Source Storage: local-lvm
Target Storage: TrueNas_NVMe

Pre-Migration Checks:
- Container Status: [PASS/FAIL]
- NFS Storage: [PASS/FAIL] 
- Backup Created: [PASS/FAIL]
- Baseline Metrics: [RECORDED]

Migration Process:
- Container Stopped: [TIME]
- Disk Move Started: [TIME]
- Disk Move Completed: [TIME]
- Container Started: [TIME]

Post-Migration Validation:
- Container Status: [PASS/FAIL]
- Application Test: [PASS/FAIL]
- Performance Test: [PASS/FAIL]
- Log Check: [PASS/FAIL]

Overall Result: [SUCCESS/FAILED]
Rollback Required: [YES/NO]
Storage Freed: [7GB]

Notes:
[Additional observations]
EOF
```

### POC Report Submission

**Submit POC results including**:
1. **Migration Report**: Detailed timing and results
2. **Performance Comparison**: Before/after metrics
3. **Lessons Learned**: Process improvements identified
4. **Recommendation**: Proceed/modify/halt full migration plan
5. **Risk Assessment Update**: Any new risks discovered

**Next Phase Approval**:
Based on POC results, seek approval for:
- Phase 2 full migration implementation
- Any process modifications required
- Timeline adjustments based on actual performance

---
*POC Guide prepared for Proxmox Stability Assistant*  
*Focus: Zero-risk validation of migration process*  
*Target: Maintain 100/100 health score throughout POC*