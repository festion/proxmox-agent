#!/bin/bash
# SSH Access Troubleshooting for Proxmox
echo "🔍 SSH ACCESS TROUBLESHOOTING"
echo "============================"

echo "1️⃣ Checking SSH key in Proxmox authorized_keys:"
echo "File: /etc/pve/priv/authorized_keys"
echo "Current key count: $(wc -l < /etc/pve/priv/authorized_keys)"
echo ""
echo "Last few keys:"
tail -3 /etc/pve/priv/authorized_keys
echo ""

echo "2️⃣ Checking SSH daemon configuration:"
echo "SSH config file: /etc/ssh/sshd_config"
grep -E "^(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin|AuthorizedKeysFile)" /etc/ssh/sshd_config
echo ""

echo "3️⃣ Checking SSH service status:"
systemctl status ssh --no-pager -l
echo ""

echo "4️⃣ Checking file permissions:"
echo "Proxmox authorized_keys permissions:"
ls -la /etc/pve/priv/authorized_keys
echo ""
echo "SSH directory permissions:"
ls -la /root/.ssh/
echo ""

echo "5️⃣ Checking for SSH authentication logs:"
echo "Recent SSH auth attempts:"
journalctl -u ssh --since "1 hour ago" | grep -E "(auth|key|Failed|Accepted)" | tail -10
echo ""

echo "6️⃣ Verifying key format:"
echo "Checking if SSH key is properly formatted:"
ssh-keygen -l -f /etc/pve/priv/authorized_keys | tail -1
echo ""

echo "7️⃣ Testing SSH configuration:"
echo "SSH daemon config test:"
sshd -t && echo "✅ SSH config is valid" || echo "❌ SSH config has errors"
echo ""

echo "8️⃣ Current SSH connections:"
who
echo ""

echo "9️⃣ Firewall status:"
iptables -L INPUT | grep -E "(ssh|22)" | head -3
echo ""

echo "🔧 POTENTIAL FIXES:"
echo "=================="
echo "1. Restart SSH service: systemctl restart ssh"
echo "2. Check if key needs different format"
echo "3. Verify SSH client is using correct private key"
echo "4. Check if Proxmox requires specific SSH key configuration"