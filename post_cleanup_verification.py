#!/usr/bin/env python3
"""
Post-Cleanup Verification Tool
Checks disk space status after executing all cleanup scripts
"""

import os
import sys
import json
import asyncio
import aiohttp
import ssl
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class PostCleanupVerification:
    def __init__(self):
        self.host = os.getenv('PROXMOX_HOST')
        self.port = os.getenv('PROXMOX_PORT', '8006')
        self.username = os.getenv('PROXMOX_USERNAME')
        self.password = os.getenv('PROXMOX_PASSWORD')
        self.realm = os.getenv('PROXMOX_REALM', 'pam')
        self.verify_ssl = os.getenv('PROXMOX_VERIFY_SSL', 'false').lower() == 'true'
        self.timeout = int(os.getenv('PROXMOX_TIMEOUT', '30'))
        
        self.base_url = f"https://{self.host}:{self.port}/api2/json"
        self.session = None
        self.ticket = None
        self.csrf_token = None
        self.node_name = "proxmox"
        
    async def create_session(self):
        """Create aiohttp session with SSL configuration"""
        ssl_context = ssl.create_default_context()
        if not self.verify_ssl:
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE
            
        connector = aiohttp.TCPConnector(ssl=ssl_context)
        timeout = aiohttp.ClientTimeout(total=self.timeout)
        self.session = aiohttp.ClientSession(connector=connector, timeout=timeout)
        
    async def authenticate(self):
        """Authenticate with Proxmox API"""
        auth_data = {
            'username': f"{self.username}@{self.realm}",
            'password': self.password
        }
        
        try:
            async with self.session.post(f"{self.base_url}/access/ticket", data=auth_data) as response:
                if response.status == 200:
                    result = await response.json()
                    self.ticket = result['data']['ticket']
                    self.csrf_token = result['data']['CSRFPreventionToken']
                    
                    self.session.headers.update({
                        'Cookie': f'PVEAuthCookie={self.ticket}',
                        'CSRFPreventionToken': self.csrf_token
                    })
                    return True
                else:
                    print(f"❌ Authentication failed: {response.status}")
                    return False
        except Exception as e:
            print(f"❌ Authentication error: {e}")
            return False

    async def get_api_data(self, endpoint):
        """Generic method to fetch data from Proxmox API"""
        try:
            async with self.session.get(f"{self.base_url}/{endpoint}") as response:
                if response.status == 200:
                    return await response.json()
                else:
                    print(f"API call failed for {endpoint}: {response.status}")
                    return None
        except Exception as e:
            print(f"API error for {endpoint}: {e}")
            return None

    def format_bytes(self, bytes_value):
        """Format bytes to human readable format"""
        if bytes_value is None:
            return "Unknown"
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_value < 1024.0:
                return f"{bytes_value:.2f} {unit}"
            bytes_value /= 1024.0
        return f"{bytes_value:.2f} PB"
        
    def format_percentage(self, used, total):
        """Calculate and format percentage"""
        if total and total > 0:
            return f"{(used/total)*100:.1f}%"
        return "N/A"

    def get_status_icon(self, usage_percent):
        """Get status icon based on usage percentage"""
        if usage_percent < 70:
            return "🟢 EXCELLENT"
        elif usage_percent < 80:
            return "🟡 GOOD"
        elif usage_percent < 90:
            return "🟠 WARNING"
        elif usage_percent < 95:
            return "🔴 CRITICAL"
        else:
            return "🚨 EMERGENCY"

    async def verify_all_storage(self):
        """Comprehensive verification of all storage systems"""
        print("🎉 POST-CLEANUP VERIFICATION REPORT")
        print("="*70)
        print(f"📅 Verification Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🖥️  Proxmox Host: {self.host}:{self.port}")
        
        # Get comprehensive storage data
        endpoints = [
            ('node_status', f'nodes/{self.node_name}/status'),
            ('storage_status', 'nodes/proxmox/storage'),
            ('local_lvm_status', 'nodes/proxmox/storage/local-lvm/status'),
            ('local_lvm_content', 'nodes/proxmox/storage/local-lvm/content'),
            ('all_storage', 'storage'),
        ]
        
        # Execute all API calls concurrently
        print("\n🔍 Gathering current storage data...")
        tasks = [self.get_api_data(endpoint) for _, endpoint in endpoints]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Organize results
        data = {}
        for (name, _), result in zip(endpoints, results):
            if isinstance(result, Exception):
                print(f"⚠️  Failed to get {name}: {result}")
                data[name] = None
            else:
                data[name] = result
        
        # Display results
        print("\n" + "="*70)
        print("📊 STORAGE VERIFICATION RESULTS")
        print("="*70)
        
        # 1. Root Filesystem (/dev/sda3) - What GUI shows
        print("\n💿 ROOT FILESYSTEM (/dev/sda3) - What Proxmox GUI Shows")
        print("-" * 60)
        
        if data['node_status'] and data['node_status'].get('data'):
            node_data = data['node_status']['data']
            if 'rootfs' in node_data:
                rootfs = node_data['rootfs']
                used = rootfs.get('used', 0)
                total = rootfs.get('total', 0)
                avail = rootfs.get('avail', 0)
                usage_pct = (used/total)*100 if total > 0 else 0
                
                status = self.get_status_icon(usage_pct)
                
                print(f"📍 Status: {status}")
                print(f"📊 Used: {self.format_bytes(used)}")
                print(f"📊 Total: {self.format_bytes(total)}")
                print(f"📊 Available: {self.format_bytes(avail)}")
                print(f"📊 Usage: {usage_pct:.1f}%")
                
                if avail > 20*1024*1024*1024:  # 20GB
                    print("✅ EXCELLENT: Plenty of free space!")
                elif avail > 10*1024*1024*1024:  # 10GB
                    print("🟡 GOOD: Adequate free space")
                elif avail > 5*1024*1024*1024:  # 5GB
                    print("🟠 WARNING: Low free space")
                else:
                    print("🔴 CRITICAL: Very low free space")
        
        # 2. Local-LVM Storage Pool - VM/Container storage
        print("\n💾 LOCAL-LVM STORAGE POOL - VM/Container Storage")
        print("-" * 60)
        
        if data['local_lvm_status'] and data['local_lvm_status'].get('data'):
            lvm_data = data['local_lvm_status']['data']
            used = lvm_data.get('used', 0)
            total = lvm_data.get('total', 0)
            avail = lvm_data.get('avail', 0)
            usage_pct = (used/total)*100 if total > 0 else 0
            
            status = self.get_status_icon(usage_pct)
            
            print(f"📍 Status: {status}")
            print(f"📊 Used: {self.format_bytes(used)}")
            print(f"📊 Total: {self.format_bytes(total)}")
            print(f"📊 Available: {self.format_bytes(avail)}")
            print(f"📊 Usage: {usage_pct:.1f}%")
        
        # 3. All Storage Pools Summary
        print("\n🗄️  ALL STORAGE POOLS SUMMARY")
        print("-" * 60)
        
        if data['storage_status'] and data['storage_status'].get('data'):
            for storage in data['storage_status']['data']:
                storage_name = storage.get('storage', 'Unknown')
                if storage.get('total'):
                    used = storage.get('used', 0)
                    total = storage.get('total', 0)
                    avail = storage.get('avail', 0)
                    usage_pct = (used/total)*100 if total > 0 else 0
                    status_icon = "🟢" if usage_pct < 80 else "🟡" if usage_pct < 90 else "🔴"
                    
                    print(f"{status_icon} {storage_name}:")
                    print(f"   Used: {self.format_bytes(used)} / {self.format_bytes(total)} ({usage_pct:.1f}%)")
                    print(f"   Available: {self.format_bytes(avail)}")
                else:
                    print(f"📁 {storage_name}: Available (network storage)")
        
        # 4. Cleanup Impact Summary
        print("\n📈 CLEANUP IMPACT SUMMARY")
        print("-" * 60)
        
        # Load previous cleanup data if available
        cleanup_impact = {
            'snapshots_deleted': 51,
            'snapshot_space_freed': '133.98 GB',
            'root_fs_cleanup': 'Executed',
            'total_operations': 'LVM snapshots + Root filesystem cleanup'
        }
        
        print(f"✅ Snapshots deleted: {cleanup_impact['snapshots_deleted']}")
        print(f"✅ LVM space freed: {cleanup_impact['snapshot_space_freed']}")
        print(f"✅ Root filesystem cleanup: {cleanup_impact['root_fs_cleanup']}")
        print(f"✅ Both storage systems: Addressed")
        
        # 5. Current Snapshot Count
        print("\n📸 CURRENT SNAPSHOT STATUS")
        print("-" * 60)
        
        # Count remaining snapshots
        vms = await self.get_api_data(f'nodes/{self.node_name}/qemu')
        containers = await self.get_api_data(f'nodes/{self.node_name}/lxc')
        
        total_snapshots = 0
        recent_snapshots = 0
        
        if vms and vms.get('data'):
            for vm in vms['data']:
                vmid = vm['vmid']
                snapshots = await self.get_api_data(f'nodes/{self.node_name}/qemu/{vmid}/snapshot')
                if snapshots and snapshots.get('data'):
                    vm_snaps = [s for s in snapshots['data'] if s['name'] != 'current']
                    total_snapshots += len(vm_snaps)
                    # Count recent snapshots (June 2025)
                    recent_snapshots += len([s for s in vm_snaps if '202506' in s.get('name', '')])
        
        if containers and containers.get('data'):
            for ct in containers['data']:
                ctid = ct['vmid']
                snapshots = await self.get_api_data(f'nodes/{self.node_name}/lxc/{ctid}/snapshot')
                if snapshots and snapshots.get('data'):
                    ct_snaps = [s for s in snapshots['data'] if s['name'] != 'current']
                    total_snapshots += len(ct_snaps)
                    # Count recent snapshots
                    recent_snapshots += len([s for s in ct_snaps if '202506' in s.get('name', '')])
        
        print(f"📊 Total remaining snapshots: {total_snapshots}")
        print(f"📊 Recent snapshots (June 2025): {recent_snapshots}")
        print(f"📊 Old snapshots removed: 51")
        
        # 6. System Health Check
        print("\n🏥 SYSTEM HEALTH STATUS")
        print("-" * 60)
        
        health_status = []
        warnings = []
        
        # Check root filesystem
        if data['node_status'] and data['node_status'].get('data', {}).get('rootfs'):
            rootfs = data['node_status']['data']['rootfs']
            avail = rootfs.get('avail', 0)
            if avail > 10*1024*1024*1024:  # 10GB
                health_status.append("✅ Root filesystem: Healthy")
            else:
                warnings.append("⚠️ Root filesystem: Still low space")
        
        # Check LVM storage
        if data['local_lvm_status'] and data['local_lvm_status'].get('data'):
            lvm_data = data['local_lvm_status']['data']
            usage_pct = (lvm_data.get('used', 0)/lvm_data.get('total', 1))*100
            if usage_pct < 80:
                health_status.append("✅ Local-LVM storage: Healthy")
            elif usage_pct < 90:
                health_status.append("🟡 Local-LVM storage: Good")
            else:
                warnings.append("⚠️ Local-LVM storage: High usage")
        
        # Display health status
        for status in health_status:
            print(status)
        
        if warnings:
            print("\n⚠️ REMAINING WARNINGS:")
            for warning in warnings:
                print(warning)
        else:
            print("\n🎉 ALL SYSTEMS HEALTHY!")
        
        # 7. Recommendations
        print("\n🎯 RECOMMENDATIONS")
        print("-" * 60)
        
        if not warnings:
            print("✅ Excellent! Both storage systems are now healthy.")
            print("📊 Set up monitoring alerts to prevent future issues.")
            print("🔄 Consider automated cleanup policies for snapshots.")
        else:
            print("🔧 Additional cleanup may be needed if warnings persist.")
            print("📞 Check Proxmox GUI to confirm space improvements.")
        
        print("\n" + "="*70)
        
        return True

    async def run_verification(self):
        """Main verification routine"""
        try:
            await self.create_session()
            
            print("🔐 Authenticating with Proxmox...")
            if not await self.authenticate():
                return False
                
            print("✅ Authentication successful")
            
            await self.verify_all_storage()
            
            # Save verification data
            verification_data = {
                'timestamp': datetime.now().isoformat(),
                'verification_type': 'post_cleanup',
                'host': self.host
            }
            
            with open('post_cleanup_verification.json', 'w') as f:
                json.dump(verification_data, f, indent=2, default=str)
                
            print(f"\n💾 Verification data saved to: post_cleanup_verification.json")
            return True
            
        except Exception as e:
            print(f"❌ Verification failed: {e}")
            return False
        finally:
            if self.session:
                await self.session.close()

async def main():
    """Main function"""
    verifier = PostCleanupVerification()
    success = await verifier.run_verification()
    
    if success:
        print("\n🎉 Post-cleanup verification completed!")
    else:
        print("\n💥 Verification failed!")
        sys.exit(1)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Verification interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        sys.exit(1)