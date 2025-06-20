#!/bin/bash
# Fix SSH Key Mismatch Issue
echo "🔧 SSH KEY MISMATCH REPAIR"
echo "========================="

echo "1️⃣ Current client key fingerprint:"
ssh-keygen -lf ~/.ssh/id_rsa.pub

echo ""
echo "2️⃣ Server authorized_keys fingerprints:"
ssh-keygen -lf /etc/pve/priv/authorized_keys

echo ""
echo "3️⃣ Your actual public key content:"
cat ~/.ssh/id_rsa.pub

echo ""
echo "4️⃣ Current authorized_keys content:"
cat /etc/pve/priv/authorized_keys

echo ""
echo "5️⃣ Backing up and replacing authorized_keys:"
cp /etc/pve/priv/authorized_keys /etc/pve/priv/authorized_keys.backup.$(date +%Y%m%d-%H%M%S)

echo ""
echo "6️⃣ Adding correct client key to authorized_keys:"
echo "# Claude Code SSH Key - Correct client key $(date)" >> /etc/pve/priv/authorized_keys
cat ~/.ssh/id_rsa.pub >> /etc/pve/priv/authorized_keys

echo ""
echo "7️⃣ Setting correct permissions:"
chmod 600 /etc/pve/priv/authorized_keys
chown root:www-data /etc/pve/priv/authorized_keys

echo ""
echo "8️⃣ Verifying new key fingerprint:"
echo "Client key:"
ssh-keygen -lf ~/.ssh/id_rsa.pub
echo "Last key in authorized_keys:"
tail -1 /etc/pve/priv/authorized_keys | ssh-keygen -lf -

echo ""
echo "9️⃣ Restarting SSH service:"
systemctl restart ssh
systemctl status ssh --no-pager -l | head -5

echo ""
echo "✅ SSH KEY MISMATCH REPAIR COMPLETED"
echo "==================================="
echo "Your client key should now match what's in authorized_keys"
echo "Test with: ssh -v root@192.168.1.137"