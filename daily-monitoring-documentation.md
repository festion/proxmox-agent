# Daily Storage Monitoring System Documentation

**Date:** July 12, 2025  
**Version:** 1.0  
**Phase:** 4.1 - Daily Monitoring Setup

## System Overview

The Daily Storage Monitoring System provides comprehensive automated monitoring of Proxmox storage infrastructure with proactive alerting and systematic maintenance procedures to ensure optimal performance and early detection of issues.

## Core Components

### 1. Daily Storage Monitoring Script
- **Location:** `/usr/local/bin/daily-storage-monitoring.sh`
- **Schedule:** Daily at 7:00 AM via cron
- **Functions:**
  - Comprehensive storage health checks
  - Automated alert generation  
  - Daily report generation
  - KPI data collection
  - Web dashboard updates

### 2. Morning Checklist Script
- **Location:** `/usr/local/bin/morning-storage-checklist.sh`
- **Schedule:** Daily at 8:00 AM via cron
- **Functions:**
  - Quick 6-point status verification
  - Action item identification
  - Color-coded status summary
  - Critical issue flagging

### 3. Weekly Maintenance Script
- **Location:** `/usr/local/bin/weekly-storage-maintenance.sh`
- **Schedule:** Weekly on Sunday at 6:00 AM via cron
- **Functions:**
  - Storage cleanup operations
  - Policy compliance checks
  - Capacity trend analysis
  - Documentation updates

### 4. Monitoring Dashboard
- **Location:** `/usr/local/bin/monitoring-dashboard.sh`
- **Usage:** On-demand execution
- **Functions:**
  - Real-time status display
  - Color-coded alerts and warnings
  - Comprehensive recommendations
  - Available monitoring tools overview

## Daily Operational Procedures

### Morning Routine (8:00 AM)
- [ ] Review morning checklist output
- [ ] Address any CRITICAL alerts immediately
- [ ] Note any WARNING conditions for monitoring
- [ ] Verify backup completion status
- [ ] Check NFS mount health

### Midday Check (12:00 PM)
- [ ] Run monitoring dashboard: `/usr/local/bin/monitoring-dashboard.sh`
- [ ] Review system performance metrics
- [ ] Monitor ongoing issues
- [ ] Check for any new alerts

### Evening Review (6:00 PM)
- [ ] Review daily monitoring report in `/var/log/daily-storage-report.log`
- [ ] Check KPI trends
- [ ] Plan any needed maintenance actions
- [ ] Update issue tracking documentation

## Alert Thresholds

### Storage Capacity
- **WARNING:** >75% usage
- **CRITICAL:** >85% usage

### LVM Data Pool
- **WARNING:** >70% usage  
- **CRITICAL:** >80% usage

### System Performance
- **WARNING:** Load average >4, I/O wait >20%
- **CRITICAL:** Load average >8, I/O wait >30%

### Backups
- **WARNING:** Any backup failures
- **CRITICAL:** >3 recent backup failures

## Monitoring Files

### Log Files
- `/var/log/daily-storage-monitoring.log`
- `/var/log/morning-storage-checklist.log`
- `/var/log/weekly-storage-maintenance.log`
- `/var/log/daily-storage-report.log`
- `/var/log/weekly-maintenance-report.log`

### Reports
- **Daily:** `/var/log/daily-storage-report.log`
- **Weekly:** `/var/log/weekly-maintenance-report.log`
- **Web Dashboard:** `/var/www/html/daily-status.html`

## Management Commands

### Daily Operations
```bash
# Morning checklist
/usr/local/bin/morning-storage-checklist.sh

# Daily monitoring
/usr/local/bin/daily-storage-monitoring.sh

# Live dashboard
/usr/local/bin/monitoring-dashboard.sh
```

### Continuous Monitoring
```bash
# Live updates every 30 seconds
watch -n 30 /usr/local/bin/monitoring-dashboard.sh
```

### Weekly Operations
```bash
# Weekly maintenance
/usr/local/bin/weekly-storage-maintenance.sh
```

## Cron Schedule

```bash
# Daily storage monitoring at 7:00 AM
0 7 * * * root /usr/local/bin/daily-storage-monitoring.sh

# Morning checklist at 8:00 AM  
0 8 * * * root /usr/local/bin/morning-storage-checklist.sh

# Weekly maintenance on Sunday at 6:00 AM
0 6 * * 0 root /usr/local/bin/weekly-storage-maintenance.sh
```

## Troubleshooting Guide

### High Storage Usage (>85%)
1. Run: `pvesm status`
2. Identify critical storage pools
3. Migrate VMs to lower-usage storage
4. Clean old snapshots and backups
5. Review storage allocation policies

### Backup Failures
1. Check: `pvenode task list --type backup`
2. Review backup job configurations
3. Verify target storage accessibility
4. Check available space on backup targets
5. Restart failed backup jobs manually

### NFS Mount Issues
1. Check: `df -h | grep nfs`
2. Test: `ping 192.168.1.98` (NFS server)
3. Remount: `mount -a`
4. Check NFS server logs
5. Verify network connectivity

### System Performance Issues
1. Check: `top`, `iotop`, `htop`
2. Identify high I/O processes
3. Review storage performance
4. Check for hardware issues
5. Consider load balancing

## Emergency Procedures

### CRITICAL Storage (>90%)
**IMMEDIATE ACTIONS:**
1. Stop non-essential VMs
2. Migrate critical VMs to other storage
3. Clean temporary files and logs
4. Expand storage capacity if possible
5. Contact system administrator

### NFS Server Failure
**IMMEDIATE ACTIONS:**
1. Switch backups to local storage
2. Verify VM data integrity
3. Contact NFS server administrator
4. Plan temporary storage allocation
5. Document incident for post-mortem

### Multiple System Failures
**IMMEDIATE ACTIONS:**
1. Escalate to senior administrator
2. Document all error conditions
3. Follow disaster recovery procedures
4. Prioritize critical service restoration
5. Communicate status to stakeholders

## Benefits of Daily Monitoring

- Proactive issue detection before failures
- Systematic approach to storage management
- Consistent monitoring and reporting
- Historical trend analysis
- Automated maintenance scheduling
- Comprehensive audit trail

## Success Metrics

- Zero unplanned storage outages
- <5% of storage pools exceeding 85% capacity
- 100% backup success rate
- <24 hour resolution time for issues
- 99.9% NFS availability

## Customization Notes

- Alert thresholds can be adjusted in each script
- Email notifications require mail server configuration
- Web dashboard can be integrated with monitoring systems
- Scripts can be extended for additional checks
- KPI thresholds should be reviewed quarterly

## Next Steps

1. Configure email notifications for alerts
2. Integrate with external monitoring tools
3. Set up automated storage expansion triggers
4. Implement capacity planning automation
5. Schedule regular review meetings

---

**System Status:** Ready for production daily monitoring operations  
**Documentation Created:** July 12, 2025  
**Phase 4.1 Complete:** ✅