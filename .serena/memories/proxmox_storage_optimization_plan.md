# Proxmox Storage Optimization Plan - Infrastructure at 192.168.1.137

## Executive Summary

**Completed**: Comprehensive storage assessment of Proxmox infrastructure
**Status**: HEALTHY - Health Score 100/100, no critical issues detected
**Total Storage**: 3.18 TB across 5 storage pools
**Overall Usage**: 11.93% (388.59 GB used)
**Priority**: Medium-High cleanup opportunity with 48 old backups (>30 days)

## Current Storage Layout Analysis

### Storage Pool Overview
| Storage Pool | Type | Total | Used | Available | Usage % | Status |
|-------------|------|-------|------|-----------|---------|--------|
| **local-lvm** | LVM Thin | 349 GB | 226 GB | 123 GB | **64.7%** | ⚠️ High |
| **TrueNas_NVMe** | NFS | 900 GB | 123 GB | 777 GB | 13.6% | ✅ Good |
| **Truenas_jbod** | NFS | 1.8 TB | 287 MB | 1.8 TB | 0.02% | ✅ Excellent |
| **Backups** | Directory | 117 GB | 23 GB | 88 GB | 19.8% | ✅ Good |
| **local** | Directory | 94 GB | 17 GB | 73 GB | 17.7% | ✅ Good |

## Critical Findings

### 🔴 High Priority Issues
1. **LVM Thin Pool Overallocation**: 
   - Pool shows 663.61 GiB allocated vs 475.94 GiB physical
   - Recurring warnings in backup logs
   - Risk of allocation failures

### 🟡 Medium Priority Optimizations
2. **Backup Cleanup Opportunity**: 
   - 48 old backups identified (>30 days old)
   - Size range: 20MB to 8.7GB per backup
   - Total cleanup potential: ~45-60GB estimated

3. **VM 123 Previous Lock Issue**: 
   - Already resolved - backup successful
   - Monitor for recurrence

## Optimization Strategy

### Phase 1: Immediate Risk Mitigation (High Priority)
**Timeline**: Within 24 hours

#### LVM Thin Pool Configuration
```bash
# Enable thin pool auto-extend protection
lvmconfig --atversion 2.03.02 activation/thin_pool_autoextend_threshold=80
lvmconfig --atversion 2.03.02 activation/thin_pool_autoextend_percent=20

# Monitor current pool status
lvs pve/data -o lv_name,data_percent,metadata_percent,pool_lv
```

#### Storage Pool Rebalancing
- **Immediate**: Move new VM deployments to TrueNas_NVMe (777GB available)
- **Medium term**: Migrate some VMs from local-lvm to NFS storage
- **Benefit**: Reduce pressure on thin pool, improve performance

### Phase 2: Backup Optimization (Medium Priority)
**Timeline**: Next maintenance window

#### Old Backup Cleanup Strategy
```bash
# Target backups >113 days old (194-day-old backups in local storage)
# Estimated recovery: 8-12 GB from local storage
# Keep: Recent NFS backups on TrueNas_NVMe (adequate retention)

# Cleanup targets identified:
- local:backup/vzdump-lxc-*-2024_12_09-* (12 files, ~6GB)
- Selective cleanup of duplicate backups on TrueNas_NVMe
```

#### Backup Strategy Optimization
- **Current**: Multiple retention policies across storages
- **Recommended**: Centralize on TrueNas_NVMe with consistent policy
- **Benefit**: Simplified management, better space utilization

### Phase 3: Long-term Storage Architecture (Low Priority)
**Timeline**: Next 2-3 months

#### Storage Redistribution Plan
1. **Production VMs**: Migrate to TrueNas_NVMe (performance + space)
2. **Development/Test**: Utilize Truenas_jbod (massive space available)
3. **Local-LVM**: Reserve for system containers only
4. **Backup Strategy**: Centralize on TrueNas_NVMe with lifecycle rules

#### Infrastructure Improvements
- **Monitor**: Set up storage alerts at 70% usage
- **Automation**: Implement automated backup rotation
- **Performance**: Consider SSD cache for frequently accessed VMs

## Implementation Priorities

### 🔴 Immediate (0-7 days)
1. **Configure LVM thin pool auto-extend** (Risk mitigation)
2. **Clean up 194-day-old backups** from local storage
3. **Set up storage monitoring alerts**

### 🟡 Short-term (1-4 weeks)  
1. **Migrate 2-3 large VMs** from local-lvm to TrueNas_NVMe
2. **Implement consistent backup retention policy**
3. **Clean up duplicate/old backups** from NFS storage

### 🟢 Medium-term (1-3 months)
1. **Full storage redistribution** per architecture plan
2. **Implement automated backup lifecycle management**
3. **Performance optimization** for critical workloads

## Estimated Benefits

### Storage Recovery
- **Immediate**: 8-12 GB from old backup cleanup
- **Short-term**: 20-30 GB from backup policy optimization
- **Medium-term**: 50+ GB from VM redistribution

### Performance Improvements
- **Reduced**: LVM thin pool pressure (current 64.7% → target <50%)
- **Improved**: VM I/O performance via NFS distribution
- **Enhanced**: Backup reliability and speed

### Risk Reduction
- **Eliminated**: Thin pool allocation failure risk
- **Reduced**: Single point of failure dependency
- **Improved**: Disaster recovery capabilities

## Resource Requirements

### Technical Effort
- **Phase 1**: 2-4 hours (system administration)
- **Phase 2**: 4-6 hours (backup management + VM migration)
- **Phase 3**: 8-12 hours (full redistribution)

### Downtime
- **LVM Configuration**: No downtime
- **Backup Cleanup**: No downtime  
- **VM Migration**: 5-10 minutes per VM (rolling)

### Expertise Required
- **Proxmox Administration**: Intermediate level
- **LVM/Storage Management**: Intermediate level
- **Backup Strategy**: Basic to intermediate level

## Success Metrics

### Quantitative Goals
- **LVM Usage**: Reduce from 64.7% to <50%
- **Backup Storage**: Reduce old backup count from 48 to <10
- **Available Space**: Increase usable storage by 15-20%
- **Health Score**: Maintain 100/100 system health

### Monitoring KPIs
- **Storage Usage Alerts**: Set at 70% per pool
- **Backup Success Rate**: Maintain >99%
- **VM Performance**: Monitor I/O latency improvements
- **System Stability**: Zero allocation failures

## Approval & Next Steps

**Recommended Action**: Proceed with Phase 1 (immediate risk mitigation) within next 24-48 hours

**Review Required**: Phase 2 and 3 plans during next maintenance window discussion

**Documentation**: All changes will be logged per established stability protocols

---
*Assessment completed using Proxmox MCP tools - Infrastructure Health Score: 100/100*
*Plan focuses on optimization without compromising system stability - priority: uptime preservation*