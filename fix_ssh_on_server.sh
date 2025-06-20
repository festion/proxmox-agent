#!/bin/bash
# Fix SSH Key Authentication on Server
echo "🔧 FIXING SSH KEY AUTHENTICATION ON SERVER"
echo "=========================================="

echo "1️⃣ Current authorized_keys content:"
echo "File: /etc/pve/priv/authorized_keys"
if [ -f /etc/pve/priv/authorized_keys ]; then
    wc -l /etc/pve/priv/authorized_keys
    echo "Last 3 lines:"
    tail -3 /etc/pve/priv/authorized_keys
else
    echo "❌ authorized_keys file not found!"
fi

echo ""
echo "2️⃣ Backup current file:"
cp /etc/pve/priv/authorized_keys /etc/pve/priv/authorized_keys.backup.$(date +%Y%m%d-%H%M%S)
echo "✅ Backup created"

echo ""
echo "3️⃣ Clean authorized_keys and add correct key:"
cat > /etc/pve/priv/authorized_keys << 'EOF'
# Claude Code SSH Key - Fixed $(date)
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8A97tj/fHwDnHskLNNdJKF+yyzrkq7PwfHK8uXFcyF1S04Gcue0kCOJrrOnip/GecDQJ4aoyIvw/16a0fDGuq7mosyP3deJMC0t4rNg4EVkCJtiK3YxyzRHbd1muFnLwmQeGwFNWAggkN2eKp9dkAoemBiH7c0x9BvMHGYqtv0xXYVOztVbifUuc+Pur1HLDSJWFohAHuUdH+xR2fbJjjB1FnVKVXt1effrtsXz5fkS6lUz+9rvo95F6MPIUK4WAtXTrR9XVTGiak5tUIxDzRwGO+9DCzGOoUsjCCY0trgApQujpChzEj56ny1HbaoxtBgGglV4iBwoI6Vl59f55PUHD6xFTFfuzx1In54hcNiZtJtCa+HYwAcxOs+mkMpb+Sdnh5m+CipgGiaItAuHFKQ3KSIPhCaZ96yly9d5M/B6AevYbxM+VDIbs3/oQNc3FiN5PfKs6DrOg6hsWVOzOxcDPpOOUURrCYkZDx6ZuTrl34+ZRfYP8n8McPkwzl/i/H3R7RBgOrjV2C/u3+/dAv9+q/JivkJEvnZ3S/2PimqDCzaJhPZTxAu43FBWL4HJwP5yN3wowrbaWTPC+8ClcQ4a8nmwNVCOHxVmgjGyx+9Tbp9aeHHTMjEvXUI5Qx9/2j7JgrGL8DRSixXIUsujzAycEv785UsqIx4BKFnBtjAw== jeremy.ames@outlook.com
EOF

echo ""
echo "4️⃣ Set correct permissions:"
chmod 600 /etc/pve/priv/authorized_keys
chown root:www-data /etc/pve/priv/authorized_keys
ls -la /etc/pve/priv/authorized_keys

echo ""
echo "5️⃣ Verify key fingerprint:"
ssh-keygen -lf /etc/pve/priv/authorized_keys

echo ""
echo "6️⃣ Check SSH daemon config:"
echo "SSH config relevant lines:"
grep -E "(PubkeyAuthentication|AuthorizedKeysFile|PermitRootLogin)" /etc/ssh/sshd_config

echo ""
echo "7️⃣ Restart SSH service:"
systemctl restart ssh
echo "SSH service status:"
systemctl is-active ssh

echo ""
echo "8️⃣ Test SSH server logs:"
echo "Checking for any SSH errors:"
journalctl -u ssh --since "1 minute ago" --no-pager | tail -5

echo ""
echo "✅ SSH KEY AUTHENTICATION FIX COMPLETED"
echo "======================================="
echo "The server should now accept your RSA key."
echo "Test from client: ssh -v root@192.168.1.137"