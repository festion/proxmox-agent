# 🎯 FINAL CLEANUP: Root Filesystem (/dev/sda3)

## 📊 **Current Status Summary**

### ✅ **COMPLETED: Local-LVM Storage Cleanup**
- **Before:** 334.51 GB / 348.82 GB (95.9% - CRITICAL)
- **After:** 200.53 GB / 348.82 GB (57.5% - SAFE)
- **🎉 Space freed:** 133.98 GB from snapshot deletion

### ❌ **REMAINING ISSUE: Root Filesystem (/dev/sda3)**
- **Current:** ~12.89 GB free (as shown in Proxmox GUI)
- **Total:** 93.93 GB 
- **Issue:** System logs, package cache, temporary files consuming space

---

## 🔧 **IMMEDIATE ACTION REQUIRED**

### **Step 1: SSH into Proxmox**
```bash
ssh root@192.168.1.137
# Enter password: redflower805
```

### **Step 2: Check Current Space**
```bash
df -h /
```

### **Step 3: Execute Safe Cleanup Commands**

#### 🟢 **SAFE Commands (Execute Immediately):**

```bash
# 1. Clean system logs (1-5 GB potential savings)
echo "🗑️ Cleaning system logs..."
journalctl --vacuum-time=7d
find /var/log -type f -name '*.log.*' -mtime +7 -delete 2>/dev/null
find /var/log -type f -name '*.gz' -mtime +14 -delete 2>/dev/null

# Check space after logs
df -h /

# 2. Clean package cache (500MB-2GB potential savings)
echo "🗑️ Cleaning package cache..."
apt clean
apt autoclean
apt autoremove -y

# Check space after packages
df -h /

# 3. Clean temporary files (100MB-1GB potential savings)
echo "🗑️ Cleaning temporary files..."
find /tmp -type f -mtime +7 -delete 2>/dev/null
find /var/tmp -type f -mtime +7 -delete 2>/dev/null

# Check space after temp cleanup
df -h /

# 4. Clean core dumps
echo "🗑️ Cleaning core dumps..."
find / -name 'core.*' -delete 2>/dev/null
find / -name '*.core' -delete 2>/dev/null

# Final space check
echo "📊 Final space after safe cleanup:"
df -h /
```

### **Step 4: If More Space Needed (Medium Risk)**

```bash
# 5. Clean old Proxmox logs (500MB-3GB potential)
echo "⚠️ Cleaning Proxmox logs (review first)..."
find /var/log/pve* -type f -mtime +30 -delete 2>/dev/null
logrotate -f /etc/logrotate.conf

# 6. Remove old kernels (1-3GB potential)
echo "⚠️ Checking old kernels..."
dpkg --list | grep linux-image
echo "To remove old kernels: apt autoremove --purge"
```

---

## 🔍 **Diagnostic Commands (Run First)**

If you want to see exactly what's using space:

```bash
# See largest directories
du -sh /* 2>/dev/null | sort -hr | head -10

# Check specific areas
du -sh /var/* 2>/dev/null | sort -hr | head -10
du -sh /var/log/* 2>/dev/null | sort -hr | head -10

# Check journal size
journalctl --disk-usage

# Check package cache
du -sh /var/cache/apt/
```

---

## 📈 **Expected Results**

### **Conservative Estimate (Safe Commands Only):**
- **System logs cleanup:** 2-4 GB
- **Package cache cleanup:** 1-2 GB  
- **Temporary files:** 0.5-1 GB
- **Total expected:** **3.5-7 GB freed**

### **If Medium Risk Commands Used:**
- **Additional Proxmox logs:** 1-3 GB
- **Old kernels:** 1-3 GB
- **Total potential:** **5.5-13 GB freed**

### **Target Result:**
- **Current:** ~12.89 GB free
- **After cleanup:** **16-26 GB free** (sufficient for operations)

---

## ✅ **Success Criteria**

After cleanup, you should see:
- **Root filesystem:** >20 GB free space
- **Proxmox GUI:** Shows healthy disk usage
- **Both storage pools:** Operating in safe ranges

---

## 🚨 **Important Notes**

1. **Two Different Storage Systems:**
   - ✅ **Local-LVM:** 148 GB free (VM/container storage)
   - ❌ **Root filesystem:** Needs cleanup (OS/system storage)

2. **Both must be maintained** for Proxmox to operate properly

3. **After cleanup:** Set up monitoring to prevent future issues

---

## 📞 **Status Check**

After running the cleanup commands, the Proxmox GUI should show significantly more free space on /dev/sda3. This will resolve the low disk space warnings you're seeing in the interface.

**Run the safe commands first, check results, then proceed with medium-risk commands if needed.**