#!/usr/bin/env python3
"""
Proxmox Storage Cleanup Analysis Tool
Identifies safe deletion candidates for local-lvm storage
"""

import os
import sys
import json
import asyncio
import aiohttp
import ssl
from datetime import datetime, timedelta
from urllib.parse import urljoin
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class StorageCleanupAnalysis:
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
        self.node_name = None
        
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
                    print(f"Authentication failed: {response.status}")
                    return False
        except Exception as e:
            print(f"Authentication error: {e}")
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
            
    async def get_node_name(self):
        """Get the node name for API calls"""
        nodes_data = await self.get_api_data('nodes')
        if nodes_data and nodes_data['data']:
            self.node_name = nodes_data['data'][0]['node']
            return self.node_name
        return None
        
    async def analyze_storage_usage(self):
        """Analyze detailed storage usage on local-lvm"""
        print("🔍 Analyzing local-lvm storage usage...")
        
        if not self.node_name:
            await self.get_node_name()
            
        # Get detailed storage information
        endpoints = [
            f'nodes/{self.node_name}/storage/local-lvm/content',
            f'nodes/{self.node_name}/storage/local-lvm/status',
            f'nodes/{self.node_name}/qemu',
            f'nodes/{self.node_name}/lxc',
        ]
        
        tasks = [self.get_api_data(endpoint) for endpoint in endpoints]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        storage_content, storage_status, vms, containers = results
        
        analysis = {
            'storage_content': storage_content,
            'storage_status': storage_status,
            'vms': vms,
            'containers': containers,
            'cleanup_candidates': []
        }
        
        return analysis
        
    async def get_vm_snapshots(self, vmid):
        """Get snapshots for a specific VM"""
        return await self.get_api_data(f'nodes/{self.node_name}/qemu/{vmid}/snapshot')
        
    async def get_container_snapshots(self, ctid):
        """Get snapshots for a specific container"""
        return await self.get_api_data(f'nodes/{self.node_name}/lxc/{ctid}/snapshot')
        
    async def analyze_snapshots(self, vms, containers):
        """Analyze all snapshots for VMs and containers"""
        print("📸 Analyzing snapshots...")
        
        snapshot_tasks = []
        vm_snapshot_map = {}
        ct_snapshot_map = {}
        
        # Get VM snapshots
        if vms and vms.get('data'):
            for vm in vms['data']:
                vmid = vm['vmid']
                task = self.get_vm_snapshots(vmid)
                snapshot_tasks.append(('vm', vmid, task))
                
        # Get container snapshots  
        if containers and containers.get('data'):
            for ct in containers['data']:
                ctid = ct['vmid']
                task = self.get_container_snapshots(ctid)
                snapshot_tasks.append(('ct', ctid, task))
                
        # Execute all snapshot queries concurrently
        tasks = [task for _, _, task in snapshot_tasks]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Process results
        for (vm_type, vmid, _), result in zip(snapshot_tasks, results):
            if not isinstance(result, Exception) and result:
                if vm_type == 'vm':
                    vm_snapshot_map[vmid] = result
                else:
                    ct_snapshot_map[vmid] = result
                    
        return vm_snapshot_map, ct_snapshot_map
        
    def calculate_age_days(self, timestamp):
        """Calculate age in days from timestamp"""
        try:
            if isinstance(timestamp, (int, float)):
                dt = datetime.fromtimestamp(timestamp)
            else:
                dt = datetime.fromisoformat(str(timestamp).replace('Z', '+00:00'))
            return (datetime.now() - dt.replace(tzinfo=None)).days
        except:
            return 0
            
    def format_bytes(self, bytes_value):
        """Format bytes to human readable format"""
        if bytes_value is None:
            return "Unknown"
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_value < 1024.0:
                return f"{bytes_value:.2f} {unit}"
            bytes_value /= 1024.0
        return f"{bytes_value:.2f} PB"
        
    def assess_cleanup_risk(self, item_type, item_data, age_days):
        """Assess the risk level of deleting an item"""
        if item_type == 'snapshot':
            if age_days > 30:
                return 'LOW', 'Snapshot older than 30 days'
            elif age_days > 14:
                return 'MEDIUM', 'Snapshot older than 2 weeks'
            elif age_days > 7:
                return 'MEDIUM', 'Snapshot older than 1 week'
            else:
                return 'HIGH', 'Recent snapshot (< 7 days)'
                
        elif item_type == 'backup':
            if age_days > 60:
                return 'LOW', 'Very old backup (>60 days)'
            elif age_days > 30:
                return 'MEDIUM', 'Old backup (>30 days)'
            else:
                return 'HIGH', 'Recent backup'
                
        elif item_type == 'template':
            return 'HIGH', 'Template - verify not in use before deletion'
            
        elif item_type == 'image':
            if 'unused' in str(item_data).lower():
                return 'LOW', 'Unused disk image'
            else:
                return 'HIGH', 'Active disk image'
                
        return 'UNKNOWN', 'Unable to assess risk'
        
    async def create_cleanup_recommendations(self, analysis, vm_snapshots, ct_snapshots):
        """Create detailed cleanup recommendations"""
        print("📋 Creating cleanup recommendations...")
        
        recommendations = {
            'high_impact_low_risk': [],
            'medium_impact_medium_risk': [],
            'low_impact_high_risk': [],
            'total_potential_savings': 0
        }
        
        # Analyze storage content
        if analysis['storage_content'] and analysis['storage_content'].get('data'):
            for item in analysis['storage_content']['data']:
                content_type = item.get('content', 'unknown')
                size = item.get('size', 0)
                volid = item.get('volid', 'unknown')
                
                # Extract timestamp if available
                ctime = item.get('ctime', 0)
                age_days = self.calculate_age_days(ctime) if ctime else 0
                
                risk_level, risk_reason = self.assess_cleanup_risk(content_type, item, age_days)
                
                cleanup_item = {
                    'type': content_type,
                    'volid': volid,
                    'size': size,
                    'size_human': self.format_bytes(size),
                    'age_days': age_days,
                    'risk_level': risk_level,
                    'risk_reason': risk_reason,
                    'vmid': item.get('vmid', 'N/A'),
                    'details': item
                }
                
                # Categorize by risk and impact
                if risk_level == 'LOW' and size > 1024*1024*1024:  # > 1GB
                    recommendations['high_impact_low_risk'].append(cleanup_item)
                elif risk_level == 'MEDIUM':
                    recommendations['medium_impact_medium_risk'].append(cleanup_item)
                else:
                    recommendations['low_impact_high_risk'].append(cleanup_item)
                    
                recommendations['total_potential_savings'] += size
                
        # Analyze snapshots
        for vmid, snapshots in vm_snapshots.items():
            if snapshots and snapshots.get('data'):
                for snapshot in snapshots['data']:
                    if snapshot['name'] == 'current':
                        continue  # Skip current state
                        
                    snap_time = snapshot.get('snaptime', 0)
                    age_days = self.calculate_age_days(snap_time) if snap_time else 0
                    
                    risk_level, risk_reason = self.assess_cleanup_risk('snapshot', snapshot, age_days)
                    
                    cleanup_item = {
                        'type': 'vm_snapshot',
                        'volid': f"VM {vmid} snapshot '{snapshot['name']}'",
                        'size': 0,  # Snapshot size not directly available
                        'size_human': 'Unknown',
                        'age_days': age_days,
                        'risk_level': risk_level,
                        'risk_reason': risk_reason,
                        'vmid': vmid,
                        'snapshot_name': snapshot['name'],
                        'details': snapshot
                    }
                    
                    if risk_level == 'LOW':
                        recommendations['high_impact_low_risk'].append(cleanup_item)
                    elif risk_level == 'MEDIUM':
                        recommendations['medium_impact_medium_risk'].append(cleanup_item)
                    else:
                        recommendations['low_impact_high_risk'].append(cleanup_item)
                        
        # Analyze container snapshots
        for ctid, snapshots in ct_snapshots.items():
            if snapshots and snapshots.get('data'):
                for snapshot in snapshots['data']:
                    if snapshot['name'] == 'current':
                        continue
                        
                    snap_time = snapshot.get('snaptime', 0)
                    age_days = self.calculate_age_days(snap_time) if snap_time else 0
                    
                    risk_level, risk_reason = self.assess_cleanup_risk('snapshot', snapshot, age_days)
                    
                    cleanup_item = {
                        'type': 'ct_snapshot',
                        'volid': f"CT {ctid} snapshot '{snapshot['name']}'",
                        'size': 0,
                        'size_human': 'Unknown',
                        'age_days': age_days,
                        'risk_level': risk_level,
                        'risk_reason': risk_reason,
                        'vmid': ctid,
                        'snapshot_name': snapshot['name'],
                        'details': snapshot
                    }
                    
                    if risk_level == 'LOW':
                        recommendations['high_impact_low_risk'].append(cleanup_item)
                    elif risk_level == 'MEDIUM':
                        recommendations['medium_impact_medium_risk'].append(cleanup_item)
                    else:
                        recommendations['low_impact_high_risk'].append(cleanup_item)
                        
        return recommendations
        
    def print_cleanup_report(self, recommendations):
        """Print detailed cleanup recommendations"""
        print("\n" + "="*80)
        print("🧹 LOCAL-LVM STORAGE CLEANUP ANALYSIS")
        print("="*80)
        print(f"📅 Analysis Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        total_savings = self.format_bytes(recommendations['total_potential_savings'])
        print(f"💾 Total Potential Savings: {total_savings}")
        
        # High Impact, Low Risk items
        print(f"\n🟢 HIGH IMPACT, LOW RISK DELETIONS ({len(recommendations['high_impact_low_risk'])} items)")
        print("   ✅ SAFE TO DELETE - Immediate space recovery")
        print("   " + "-"*60)
        
        for item in sorted(recommendations['high_impact_low_risk'], key=lambda x: x['size'], reverse=True):
            age_info = f"({item['age_days']} days old)" if item['age_days'] > 0 else ""
            print(f"   📁 {item['volid']}")
            print(f"      Size: {item['size_human']} | Type: {item['type']} {age_info}")
            print(f"      Risk: {item['risk_reason']}")
            if item['type'] in ['vm_snapshot', 'ct_snapshot']:
                print(f"      Command: pvesh delete /nodes/{self.node_name}/{item['type'].split('_')[0]}/{item['vmid']}/snapshot/{item['snapshot_name']}")
            print()
            
        # Medium Impact, Medium Risk items
        print(f"\n🟡 MEDIUM IMPACT, MEDIUM RISK DELETIONS ({len(recommendations['medium_impact_medium_risk'])} items)")
        print("   ⚠️  REVIEW BEFORE DELETING - Verify not needed")
        print("   " + "-"*60)
        
        for item in sorted(recommendations['medium_impact_medium_risk'], key=lambda x: x['size'], reverse=True):
            age_info = f"({item['age_days']} days old)" if item['age_days'] > 0 else ""
            print(f"   📁 {item['volid']}")
            print(f"      Size: {item['size_human']} | Type: {item['type']} {age_info}")
            print(f"      Risk: {item['risk_reason']}")
            print()
            
        # High Risk items
        print(f"\n🔴 LOW IMPACT, HIGH RISK ITEMS ({len(recommendations['low_impact_high_risk'])} items)")
        print("   🚫 DO NOT DELETE WITHOUT CAREFUL CONSIDERATION")
        print("   " + "-"*60)
        
        for item in recommendations['low_impact_high_risk'][:5]:  # Show only first 5
            age_info = f"({item['age_days']} days old)" if item['age_days'] > 0 else ""
            print(f"   📁 {item['volid']}")
            print(f"      Size: {item['size_human']} | Type: {item['type']} {age_info}")
            print(f"      Risk: {item['risk_reason']}")
            print()
            
        if len(recommendations['low_impact_high_risk']) > 5:
            print(f"   ... and {len(recommendations['low_impact_high_risk']) - 5} more high-risk items")
            
        # Immediate Action Plan
        print(f"\n📋 IMMEDIATE ACTION PLAN")
        print("="*50)
        
        safe_deletions = [item for item in recommendations['high_impact_low_risk'] if item['size'] > 100*1024*1024]  # > 100MB
        total_safe_savings = sum(item['size'] for item in safe_deletions)
        
        print(f"🎯 PHASE 1: Safe Deletions (Immediate)")
        print(f"   Items to delete: {len(safe_deletions)}")
        print(f"   Space to recover: {self.format_bytes(total_safe_savings)}")
        print(f"   Risk level: MINIMAL")
        
        if safe_deletions:
            print(f"\n   Commands to execute:")
            for item in safe_deletions[:3]:  # Show first 3 commands
                if item['type'] in ['vm_snapshot', 'ct_snapshot']:
                    vm_type = 'qemu' if item['type'] == 'vm_snapshot' else 'lxc'
                    print(f"   pvesh delete /nodes/{self.node_name}/{vm_type}/{item['vmid']}/snapshot/{item['snapshot_name']}")
                    
        review_items = [item for item in recommendations['medium_impact_medium_risk'] if item['size'] > 500*1024*1024]  # > 500MB
        if review_items:
            print(f"\n🎯 PHASE 2: Review and Delete (After verification)")
            print(f"   Items to review: {len(review_items)}")
            total_review_savings = sum(item['size'] for item in review_items)
            print(f"   Potential space: {self.format_bytes(total_review_savings)}")
            print(f"   Risk level: MEDIUM - Verify before deletion")
            
        print("="*80)
        
    async def run_analysis(self):
        """Main analysis routine"""
        try:
            await self.create_session()
            
            print("🔐 Authenticating with Proxmox...")
            if not await self.authenticate():
                print("❌ Authentication failed")
                return False
                
            print("✅ Authentication successful")
            
            # Perform storage analysis
            analysis = await self.analyze_storage_usage()
            
            # Analyze snapshots
            vm_snapshots, ct_snapshots = await self.analyze_snapshots(
                analysis['vms'], analysis['containers']
            )
            
            # Create recommendations
            recommendations = await self.create_cleanup_recommendations(
                analysis, vm_snapshots, ct_snapshots
            )
            
            # Print report
            self.print_cleanup_report(recommendations)
            
            # Save detailed analysis
            cleanup_data = {
                'timestamp': datetime.now().isoformat(),
                'analysis': analysis,
                'vm_snapshots': vm_snapshots,
                'ct_snapshots': ct_snapshots,
                'recommendations': recommendations
            }
            
            with open('storage_cleanup_analysis.json', 'w') as f:
                json.dump(cleanup_data, f, indent=2, default=str)
                
            print(f"\n💾 Detailed analysis saved to: storage_cleanup_analysis.json")
            return True
            
        except Exception as e:
            print(f"❌ Analysis failed: {e}")
            return False
        finally:
            if self.session:
                await self.session.close()

async def main():
    """Main function"""
    analyzer = StorageCleanupAnalysis()
    success = await analyzer.run_analysis()
    
    if success:
        print("\n🎉 Storage cleanup analysis completed!")
    else:
        print("\n💥 Analysis failed!")
        sys.exit(1)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Analysis interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        sys.exit(1)