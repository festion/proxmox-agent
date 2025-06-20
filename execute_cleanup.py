#!/usr/bin/env python3
"""
Proxmox Storage Cleanup Execution Tool
Safely executes snapshot deletions with monitoring
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

class ProxmoxCleanupExecutor:
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
            
    async def get_storage_status(self):
        """Get current storage status"""
        try:
            async with self.session.get(f"{self.base_url}/nodes/{self.node_name}/storage/local-lvm/status") as response:
                if response.status == 200:
                    result = await response.json()
                    return result['data']
                else:
                    print(f"⚠️  Failed to get storage status: {response.status}")
                    return None
        except Exception as e:
            print(f"⚠️  Storage status error: {e}")
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
        
    async def delete_snapshot(self, vm_type, vmid, snapshot_name):
        """Delete a specific snapshot"""
        endpoint = f"nodes/{self.node_name}/{vm_type}/{vmid}/snapshot/{snapshot_name}"
        
        try:
            async with self.session.delete(f"{self.base_url}/{endpoint}") as response:
                if response.status == 200:
                    return True, "Success"
                else:
                    error_text = await response.text()
                    return False, f"HTTP {response.status}: {error_text}"
        except Exception as e:
            return False, f"Error: {e}"
            
    async def execute_phase_1_deletions(self):
        """Execute Phase 1: Delete April 18 snapshots (62+ days old)"""
        print("\n🚀 PHASE 1: Deleting April 18 snapshots (62+ days old)")
        print("="*60)
        
        # Get initial storage status
        initial_status = await self.get_storage_status()
        if initial_status:
            used = initial_status.get('used', 0)
            total = initial_status.get('total', 1)
            print(f"📊 Initial Storage: {self.format_bytes(used)} / {self.format_bytes(total)} ({self.format_percentage(used, total)})")
        
        # Define Phase 1 deletions (April 18, 2025 snapshots)
        phase1_deletions = [
            # VM 114 snapshots
            ("qemu", "114", "Update_20250418_141936", "VM 114 (Home Assistant)"),
            ("qemu", "114", "Before_reinstall_Z2M", "VM 114 (Home Assistant)"),
            ("qemu", "114", "Before_rsync", "VM 114 (Home Assistant)"),
            
            # Container snapshots from April 18
            ("lxc", "113", "Update_20250418_141442", "CT 113 (lldap)"),
            ("lxc", "118", "Update_20250418_141636", "CT 118 (alpine-nextcloud)"),
            ("lxc", "125", "Update_20250418_141855", "CT 125 (adguard)"),
            ("lxc", "105", "Update_20250418_141111", "CT 105 (nginxproxymanager)"),
            ("lxc", "109", "Update_20250418_141237", "CT 109 (uptimekuma)"),
            ("lxc", "116", "Update_20250418_141533", "CT 116 (debian)"),
            ("lxc", "110", "Update_20250418_141259", "CT 110 (homepage)"),
            ("lxc", "107", "Update_20250418_141154", "CT 107 (gotify)"),
            ("lxc", "120", "Update_20250418_141725", "CT 120 (alpine-it-tools)"),
            ("lxc", "104", "Update_20250418_141050", "CT 104 (myspeed)"),
            ("lxc", "108", "Update_20250418_141214", "CT 108 (tandoor)"),
            ("lxc", "103", "Update_20250418_141028", "CT 103 (watchyourlan)"),
            ("lxc", "115", "Update_20250418_141504", "CT 115 (memos)"),
            ("lxc", "123", "Update_20250418_141813", "CT 123 (gitopsdashboard)"),
            ("lxc", "123", "Update_20250413_165127", "CT 123 (gitopsdashboard)"),
            ("lxc", "124", "Update_20250418_141834", "CT 124 (mqtt)"),
            ("lxc", "122", "Update_20250418_141754", "CT 122 (zigbee2mqtt)"),
            ("lxc", "126", "Update_20250418_141916", "CT 126 (vikunja)"),
            ("lxc", "101", "Update_20250418_140946", "CT 101 (grafana)"),
            ("lxc", "121", "Update_20250418_141733", "CT 121 (pocketid)"),
            ("lxc", "102", "Update_20250418_141007", "CT 102 (cloudflared)"),
            ("lxc", "106", "Update_20250418_141133", "CT 106 (pairdrop)"),
        ]
        
        successful_deletions = 0
        failed_deletions = []
        
        print(f"\n🗑️  Deleting {len(phase1_deletions)} snapshots...")
        
        for vm_type, vmid, snapshot_name, description in phase1_deletions:
            print(f"   Deleting: {description} snapshot '{snapshot_name}'...", end=" ")
            
            success, message = await self.delete_snapshot(vm_type, vmid, snapshot_name)
            
            if success:
                print("✅ Success")
                successful_deletions += 1
            else:
                print(f"❌ Failed: {message}")
                failed_deletions.append((vm_type, vmid, snapshot_name, description, message))
                
            # Small delay to avoid overwhelming the API
            await asyncio.sleep(0.5)
        
        # Check storage status after Phase 1
        print(f"\n📊 Phase 1 Results:")
        print(f"   ✅ Successful deletions: {successful_deletions}")
        print(f"   ❌ Failed deletions: {len(failed_deletions)}")
        
        if failed_deletions:
            print(f"\n❌ Failed Deletions:")
            for vm_type, vmid, snapshot_name, description, error in failed_deletions:
                print(f"   - {description} '{snapshot_name}': {error}")
        
        # Get updated storage status
        updated_status = await self.get_storage_status()
        if updated_status:
            used = updated_status.get('used', 0)
            total = updated_status.get('total', 1)
            print(f"\n📊 Updated Storage: {self.format_bytes(used)} / {self.format_bytes(total)} ({self.format_percentage(used, total)})")
            
            if initial_status:
                space_freed = initial_status.get('used', 0) - used
                if space_freed > 0:
                    print(f"🎉 Space freed: {self.format_bytes(space_freed)}")
                else:
                    print("⚠️  No significant space freed yet (snapshots may take time to clear)")
        
        return successful_deletions, failed_deletions
        
    async def execute_phase_2_deletions(self):
        """Execute Phase 2: Delete May 15 snapshots (35 days old)"""
        print("\n🚀 PHASE 2: Deleting May 15 snapshots (35 days old)")
        print("="*60)
        
        # Get storage status before Phase 2
        initial_status = await self.get_storage_status()
        if initial_status:
            used = initial_status.get('used', 0)
            total = initial_status.get('total', 1)
            print(f"📊 Storage before Phase 2: {self.format_bytes(used)} / {self.format_bytes(total)} ({self.format_percentage(used, total)})")
        
        # Define Phase 2 deletions (May 15, 2025 snapshots)
        phase2_deletions = [
            # VM 114
            ("qemu", "114", "Update_20250515_100300", "VM 114 (Home Assistant)"),
            
            # Container snapshots from May 15
            ("lxc", "113", "Update_20250515_095504", "CT 113 (lldap)"),
            ("lxc", "118", "Update_20250515_095753", "CT 118 (alpine-nextcloud)"),
            ("lxc", "125", "Update_20250515_100121", "CT 125 (adguard)"),
            ("lxc", "105", "Update_20250515_094923", "CT 105 (nginxproxymanager)"),
            ("lxc", "109", "Update_20250515_095139", "CT 109 (uptimekuma)"),
            ("lxc", "116", "Update_20250515_095628", "CT 116 (debian)"),
            ("lxc", "110", "Update_20250515_095223", "CT 110 (homepage)"),
            ("lxc", "107", "Update_20250515_095036", "CT 107 (gotify)"),
            ("lxc", "127", "Update_20250515_100223", "CT 127 (infisical)"),
            ("lxc", "100", "Update_20250515_094701", "CT 100 (influxdb)"),
            ("lxc", "100", "Update_20250515_100422", "CT 100 (influxdb)"),
            ("lxc", "120", "Update_20250515_095833", "CT 120 (alpine-it-tools)"),
            ("lxc", "117", "Update_20250515_095654", "CT 117 (hoarder)"),
            ("lxc", "104", "Update_20250515_094843", "CT 104 (myspeed)"),
            ("lxc", "108", "Update_20250515_095102", "CT 108 (tandoor)"),
            ("lxc", "103", "Update_20250515_094818", "CT 103 (watchyourlan)"),
            ("lxc", "115", "Update_20250515_095535", "CT 115 (memos)"),
            ("lxc", "123", "Update_20250515_100022", "CT 123 (gitopsdashboard)"),
            ("lxc", "124", "Update_20250515_100048", "CT 124 (mqtt)"),
            ("lxc", "122", "Update_20250515_095943", "CT 122 (zigbee2mqtt)"),
            ("lxc", "126", "Update_20250515_100145", "CT 126 (vikunja)"),
            ("lxc", "101", "Update_20250515_094727", "CT 101 (grafana)"),
            ("lxc", "121", "Update_20250515_095904", "CT 121 (pocketid)"),
            ("lxc", "102", "Update_20250515_094752", "CT 102 (cloudflared)"),
            ("lxc", "106", "Update_20250515_094949", "CT 106 (pairdrop)"),
        ]
        
        successful_deletions = 0
        failed_deletions = []
        
        print(f"\n🗑️  Deleting {len(phase2_deletions)} snapshots...")
        
        for vm_type, vmid, snapshot_name, description in phase2_deletions:
            print(f"   Deleting: {description} snapshot '{snapshot_name}'...", end=" ")
            
            success, message = await self.delete_snapshot(vm_type, vmid, snapshot_name)
            
            if success:
                print("✅ Success")
                successful_deletions += 1
            else:
                print(f"❌ Failed: {message}")
                failed_deletions.append((vm_type, vmid, snapshot_name, description, message))
                
            # Small delay to avoid overwhelming the API
            await asyncio.sleep(0.5)
        
        # Check storage status after Phase 2
        print(f"\n📊 Phase 2 Results:")
        print(f"   ✅ Successful deletions: {successful_deletions}")
        print(f"   ❌ Failed deletions: {len(failed_deletions)}")
        
        if failed_deletions:
            print(f"\n❌ Failed Deletions:")
            for vm_type, vmid, snapshot_name, description, error in failed_deletions:
                print(f"   - {description} '{snapshot_name}': {error}")
        
        # Get final storage status
        final_status = await self.get_storage_status()
        if final_status:
            used = final_status.get('used', 0)
            total = final_status.get('total', 1)
            print(f"\n📊 Final Storage: {self.format_bytes(used)} / {self.format_bytes(total)} ({self.format_percentage(used, total)})")
            
            if initial_status:
                space_freed = initial_status.get('used', 0) - used
                if space_freed > 0:
                    print(f"🎉 Space freed in Phase 2: {self.format_bytes(space_freed)}")
        
        return successful_deletions, failed_deletions
        
    async def execute_cleanup(self):
        """Main cleanup execution routine"""
        try:
            await self.create_session()
            
            print("🔐 Authenticating with Proxmox...")
            if not await self.authenticate():
                return False
                
            print("✅ Authentication successful")
            
            # Get initial storage status
            print("\n📊 INITIAL STORAGE STATUS")
            print("="*40)
            initial_status = await self.get_storage_status()
            if initial_status:
                used = initial_status.get('used', 0)
                total = initial_status.get('total', 1)
                usage_pct = (used/total)*100 if total > 0 else 0
                print(f"Storage: {self.format_bytes(used)} / {self.format_bytes(total)} ({usage_pct:.1f}%)")
                
                if usage_pct > 95:
                    print("🚨 CRITICAL: Storage usage > 95%")
                elif usage_pct > 90:
                    print("⚠️  WARNING: Storage usage > 90%")
            
            # Execute Phase 1
            phase1_success, phase1_failed = await self.execute_phase_1_deletions()
            
            # Wait a moment for storage to update
            print("\n⏳ Waiting for storage to update...")
            await asyncio.sleep(10)
            
            # Execute Phase 2
            phase2_success, phase2_failed = await self.execute_phase_2_deletions()
            
            # Wait for final storage update
            print("\n⏳ Waiting for final storage update...")
            await asyncio.sleep(15)
            
            # Final summary
            print("\n" + "="*80)
            print("🎉 CLEANUP EXECUTION COMPLETE")
            print("="*80)
            print(f"📊 Total snapshots deleted: {phase1_success + phase2_success}")
            print(f"❌ Total failed deletions: {len(phase1_failed) + len(phase2_failed)}")
            
            # Get final storage status
            final_status = await self.get_storage_status()
            if final_status and initial_status:
                initial_used = initial_status.get('used', 0)
                final_used = final_status.get('used', 0)
                total = final_status.get('total', 1)
                
                space_freed = initial_used - final_used
                final_usage_pct = (final_used/total)*100 if total > 0 else 0
                
                print(f"\n📊 STORAGE IMPACT:")
                print(f"   Before: {self.format_bytes(initial_used)} / {self.format_bytes(total)} ({(initial_used/total)*100:.1f}%)")
                print(f"   After:  {self.format_bytes(final_used)} / {self.format_bytes(total)} ({final_usage_pct:.1f}%)")
                
                if space_freed > 0:
                    print(f"   🎉 Space freed: {self.format_bytes(space_freed)}")
                    
                if final_usage_pct < 90:
                    print("   ✅ Storage usage now in safe range!")
                elif final_usage_pct < 95:
                    print("   ⚠️  Storage usage improved but still high")
                else:
                    print("   🚨 Storage still critical - may need additional cleanup")
            
            # Log results
            cleanup_log = {
                'timestamp': datetime.now().isoformat(),
                'phase1_success': phase1_success,
                'phase1_failed': len(phase1_failed),
                'phase2_success': phase2_success,
                'phase2_failed': len(phase2_failed),
                'total_deleted': phase1_success + phase2_success,
                'failed_deletions': phase1_failed + phase2_failed,
                'initial_status': initial_status,
                'final_status': final_status
            }
            
            with open('cleanup_execution_log.json', 'w') as f:
                json.dump(cleanup_log, f, indent=2, default=str)
                
            print(f"\n💾 Cleanup log saved to: cleanup_execution_log.json")
            print("="*80)
            return True
            
        except Exception as e:
            print(f"❌ Cleanup execution failed: {e}")
            return False
        finally:
            if self.session:
                await self.session.close()

async def main():
    """Main function"""
    executor = ProxmoxCleanupExecutor()
    success = await executor.execute_cleanup()
    
    if success:
        print("\n🎉 Cleanup execution completed!")
    else:
        print("\n💥 Cleanup execution failed!")
        sys.exit(1)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Cleanup interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        sys.exit(1)