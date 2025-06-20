#!/usr/bin/env python3
"""
Verify Storage Cleanup - Cross-check actual disk usage
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

class StorageVerification:
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

    async def execute_shell_command(self, command):
        """Execute a shell command on the Proxmox node"""
        try:
            async with self.session.post(
                f"{self.base_url}/nodes/{self.node_name}/execute",
                data={'command': command}
            ) as response:
                if response.status == 200:
                    result = await response.json()
                    return result.get('data', '')
                else:
                    return f"Command failed with status {response.status}"
        except Exception as e:
            return f"Command error: {e}"

    async def verify_disk_usage(self):
        """Verify actual disk usage using multiple methods"""
        print("🔍 COMPREHENSIVE STORAGE VERIFICATION")
        print("="*60)
        
        # Method 1: Proxmox API storage status
        print("\n📊 Method 1: Proxmox API Storage Status")
        print("-" * 40)
        
        storage_apis = [
            'nodes/proxmox/storage',
            'nodes/proxmox/storage/local-lvm/status',
            'nodes/proxmox/storage/local-lvm/content'
        ]
        
        for api in storage_apis:
            result = await self.get_api_data(api)
            if result:
                if 'local-lvm' in api and 'status' in api:
                    data = result.get('data', {})
                    used = data.get('used', 0)
                    total = data.get('total', 0)
                    avail = data.get('avail', 0)
                    print(f"API Storage Status:")
                    print(f"  Used: {self.format_bytes(used)}")
                    print(f"  Total: {self.format_bytes(total)}")
                    print(f"  Available: {self.format_bytes(avail)}")
                    print(f"  Usage: {self.format_percentage(used, total)}")
        
        # Method 2: LVM status
        print("\n💾 Method 2: LVM Volume Group Status")
        print("-" * 40)
        
        lvm_commands = [
            'vgs',  # Volume group summary
            'lvs',  # Logical volume summary
            'df -h /dev/mapper/*local--lvm*',  # Filesystem usage
            'lvdisplay pve/data',  # Detailed LV info
            'vgdisplay pve'  # Detailed VG info
        ]
        
        for cmd in lvm_commands:
            print(f"\n🔧 Command: {cmd}")
            # Note: These would need SSH access to work properly
            # For now, let's try the API approach
            
        # Method 3: Disk usage via system info
        print("\n💿 Method 3: System Disk Information")
        print("-" * 40)
        
        # Get node status which includes disk info
        node_status = await self.get_api_data(f'nodes/{self.node_name}/status')
        if node_status:
            data = node_status.get('data', {})
            if 'rootfs' in data:
                rootfs = data['rootfs']
                used = rootfs.get('used', 0)
                total = rootfs.get('total', 0)
                avail = rootfs.get('avail', 0)
                print(f"Root Filesystem (/dev/sda3):")
                print(f"  Used: {self.format_bytes(used)}")
                print(f"  Total: {self.format_bytes(total)}")
                print(f"  Available: {self.format_bytes(avail)}")
                print(f"  Usage: {self.format_percentage(used, total)}")
        
        # Method 4: Check actual snapshot count
        print("\n📸 Method 4: Current Snapshot Verification")
        print("-" * 40)
        
        # Get current VMs and containers
        vms = await self.get_api_data(f'nodes/{self.node_name}/qemu')
        containers = await self.get_api_data(f'nodes/{self.node_name}/lxc')
        
        total_snapshots = 0
        
        if vms and vms.get('data'):
            for vm in vms['data']:
                vmid = vm['vmid']
                snapshots = await self.get_api_data(f'nodes/{self.node_name}/qemu/{vmid}/snapshot')
                if snapshots and snapshots.get('data'):
                    vm_snaps = len([s for s in snapshots['data'] if s['name'] != 'current'])
                    total_snapshots += vm_snaps
                    print(f"  VM {vmid}: {vm_snaps} snapshots")
        
        if containers and containers.get('data'):
            for ct in containers['data']:
                ctid = ct['vmid']
                snapshots = await self.get_api_data(f'nodes/{self.node_name}/lxc/{ctid}/snapshot')
                if snapshots and snapshots.get('data'):
                    ct_snaps = len([s for s in snapshots['data'] if s['name'] != 'current'])
                    total_snapshots += ct_snaps
                    print(f"  CT {ctid}: {ct_snaps} snapshots")
        
        print(f"\nTotal remaining snapshots: {total_snapshots}")
        
        # Method 5: Storage content analysis
        print("\n📁 Method 5: Storage Content Analysis")
        print("-" * 40)
        
        content = await self.get_api_data(f'nodes/{self.node_name}/storage/local-lvm/content')
        if content and content.get('data'):
            total_content_size = 0
            content_by_type = {}
            
            for item in content['data']:
                content_type = item.get('content', 'unknown')
                size = item.get('size', 0)
                total_content_size += size
                
                if content_type not in content_by_type:
                    content_by_type[content_type] = {'count': 0, 'size': 0}
                content_by_type[content_type]['count'] += 1
                content_by_type[content_type]['size'] += size
            
            print(f"Content breakdown:")
            for ctype, data in content_by_type.items():
                print(f"  {ctype}: {data['count']} items, {self.format_bytes(data['size'])}")
            
            print(f"\nTotal content size: {self.format_bytes(total_content_size)}")
        
        # Method 6: Check for pending operations
        print("\n⏳ Method 6: Checking for Pending Operations")
        print("-" * 40)
        
        tasks = await self.get_api_data('cluster/tasks')
        if tasks and tasks.get('data'):
            active_tasks = [t for t in tasks['data'] if t.get('status') == 'running']
            recent_tasks = [t for t in tasks['data'] if 'snapshot' in t.get('type', '').lower()][:5]
            
            print(f"Active tasks: {len(active_tasks)}")
            if recent_tasks:
                print("Recent snapshot-related tasks:")
                for task in recent_tasks:
                    print(f"  {task.get('type')} - {task.get('status')} - {task.get('starttime')}")

    async def run_verification(self):
        """Main verification routine"""
        try:
            await self.create_session()
            
            print("🔐 Authenticating with Proxmox...")
            if not await self.authenticate():
                return False
                
            print("✅ Authentication successful")
            
            await self.verify_disk_usage()
            
            print("\n" + "="*80)
            print("🔍 ANALYSIS COMPLETE")
            print("="*80)
            print("\n💡 RECOMMENDATIONS:")
            print("1. Check Proxmox GUI for any background tasks")
            print("2. Verify /dev/sda3 vs local-lvm storage pool relationship")
            print("3. Consider running 'lvs' and 'vgs' commands via SSH for detailed LVM status")
            print("4. Check if snapshot deletion is still processing")
            print("5. Verify thin pool utilization vs filesystem usage")
            
            return True
            
        except Exception as e:
            print(f"❌ Verification failed: {e}")
            return False
        finally:
            if self.session:
                await self.session.close()

async def main():
    """Main function"""
    verifier = StorageVerification()
    success = await verifier.run_verification()
    
    if success:
        print("\n🎉 Verification completed!")
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