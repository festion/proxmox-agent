#!/usr/bin/env python3
"""
Proxmox Initial Assessment Tool
Performs comprehensive health check and system assessment
"""

import os
import sys
import json
import asyncio
import aiohttp
import ssl
from datetime import datetime
from urllib.parse import urljoin
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class ProxmoxAssessment:
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
                    
                    # Set session headers for authenticated requests
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
            
    async def gather_system_info(self):
        """Gather comprehensive system information using concurrent requests"""
        print("🔍 Gathering system information...")
        
        # Define all API endpoints to query concurrently
        endpoints = [
            ('nodes', 'nodes'),
            ('version', 'version'),
            ('cluster/status', 'cluster_status'),
            ('cluster/resources', 'cluster_resources'),
            ('storage', 'storage'),
            ('access/users', 'users'),
            ('pools', 'pools'),
        ]
        
        # Execute all API calls concurrently
        tasks = [self.get_api_data(endpoint) for _, endpoint in endpoints]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Organize results
        system_info = {}
        for (name, _), result in zip(endpoints, results):
            if isinstance(result, Exception):
                print(f"❌ Failed to get {name}: {result}")
                system_info[name] = None
            else:
                system_info[name] = result
                
        return system_info
        
    async def get_node_details(self, node_name):
        """Get detailed information for a specific node"""
        print(f"📊 Getting detailed info for node: {node_name}")
        
        node_endpoints = [
            f'nodes/{node_name}/status',
            f'nodes/{node_name}/version',
            f'nodes/{node_name}/qemu',
            f'nodes/{node_name}/lxc',
            f'nodes/{node_name}/storage',
            f'nodes/{node_name}/disks',
            f'nodes/{node_name}/network',
            f'nodes/{node_name}/services',
        ]
        
        # Execute node-specific queries concurrently
        tasks = [self.get_api_data(endpoint) for endpoint in node_endpoints]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        node_details = {}
        endpoint_names = ['status', 'version', 'vms', 'containers', 'storage', 'disks', 'network', 'services']
        
        for name, result in zip(endpoint_names, results):
            if isinstance(result, Exception):
                print(f"❌ Failed to get node {name}: {result}")
                node_details[name] = None
            else:
                node_details[name] = result
                
        return node_details
        
    def format_bytes(self, bytes_value):
        """Format bytes to human readable format"""
        if bytes_value is None:
            return "N/A"
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
        
    async def print_assessment_report(self, system_info, node_details):
        """Print comprehensive assessment report"""
        print("\n" + "="*80)
        print("🏥 PROXMOX SYSTEM HEALTH ASSESSMENT REPORT")
        print("="*80)
        print(f"📅 Assessment Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🖥️  Proxmox Host: {self.host}:{self.port}")
        
        # Version Information
        if system_info.get('version'):
            version_data = system_info['version']['data']
            print(f"\n📋 SYSTEM VERSION")
            print(f"   Proxmox VE: {version_data.get('version', 'Unknown')}")
            print(f"   Release: {version_data.get('release', 'Unknown')}")
            print(f"   Kernel: {version_data.get('kversion', 'Unknown')}")
            
        # Node Information
        if system_info.get('nodes'):
            print(f"\n🖥️  NODES STATUS")
            for node in system_info['nodes']['data']:
                status_icon = "🟢" if node['status'] == 'online' else "🔴"
                print(f"   {status_icon} {node['node']} ({node['type']}) - {node['status']}")
                
        # Cluster Status
        if system_info.get('cluster_status'):
            print(f"\n🔗 CLUSTER STATUS")
            for item in system_info['cluster_status']['data']:
                if item['type'] == 'cluster':
                    print(f"   Cluster: {item['name']} (Nodes: {item.get('nodes', 'N/A')})")
                    
        # Resource Overview
        if system_info.get('cluster_resources'):
            print(f"\n📊 RESOURCE OVERVIEW")
            vms = containers = 0
            for resource in system_info['cluster_resources']['data']:
                if resource['type'] == 'qemu':
                    vms += 1
                elif resource['type'] == 'lxc':
                    containers += 1
            print(f"   Virtual Machines: {vms}")
            print(f"   Containers: {containers}")
            
        # Node Details
        if node_details:
            print(f"\n💾 NODE DETAILS")
            
            # Node Status
            if node_details.get('status'):
                status = node_details['status']['data']
                print(f"   CPU Usage: {status.get('cpu', 0)*100:.1f}%")
                print(f"   Memory: {self.format_bytes(status.get('memory', {}).get('used', 0))} / "
                      f"{self.format_bytes(status.get('memory', {}).get('total', 0))} "
                      f"({self.format_percentage(status.get('memory', {}).get('used', 0), status.get('memory', {}).get('total', 1))})")
                print(f"   Uptime: {status.get('uptime', 'Unknown')} seconds")
                print(f"   Load Average: {status.get('loadavg', ['N/A', 'N/A', 'N/A'])}")
                
            # Storage
            if node_details.get('storage'):
                print(f"\n💽 STORAGE STATUS")
                for storage in node_details['storage']['data']:
                    if storage.get('total'):
                        used_pct = self.format_percentage(storage.get('used', 0), storage.get('total', 1))
                        print(f"   📁 {storage['storage']}: {self.format_bytes(storage.get('used', 0))} / "
                              f"{self.format_bytes(storage.get('total', 0))} ({used_pct})")
                    else:
                        print(f"   📁 {storage['storage']}: Available")
                        
            # VMs and Containers
            if node_details.get('vms'):
                print(f"\n🖥️  VIRTUAL MACHINES")
                for vm in node_details['vms']['data']:
                    status_icon = "🟢" if vm['status'] == 'running' else "🔴" if vm['status'] == 'stopped' else "🟡"
                    print(f"   {status_icon} VM {vm['vmid']}: {vm.get('name', 'Unknown')} ({vm['status']})")
                    
            if node_details.get('containers'):
                print(f"\n📦 CONTAINERS")
                for ct in node_details['containers']['data']:
                    status_icon = "🟢" if ct['status'] == 'running' else "🔴" if ct['status'] == 'stopped' else "🟡"
                    print(f"   {status_icon} CT {ct['vmid']}: {ct.get('name', 'Unknown')} ({ct['status']})")
                    
            # Services
            if node_details.get('services'):
                print(f"\n🔧 CRITICAL SERVICES")
                critical_services = ['pve-cluster', 'pvedaemon', 'pveproxy', 'pvestatd']
                for service in node_details['services']['data']:
                    if service['name'] in critical_services:
                        status_icon = "🟢" if service['state'] == 'running' else "🔴"
                        print(f"   {status_icon} {service['name']}: {service['state']}")
                        
        # Health Summary
        print(f"\n🏥 HEALTH SUMMARY")
        health_issues = []
        
        # Check for any stopped VMs or containers
        if node_details and node_details.get('vms'):
            stopped_vms = [vm for vm in node_details['vms']['data'] if vm['status'] == 'stopped']
            if stopped_vms:
                health_issues.append(f"{len(stopped_vms)} VMs are stopped")
                
        if node_details and node_details.get('containers'):
            stopped_cts = [ct for ct in node_details['containers']['data'] if ct['status'] == 'stopped']
            if stopped_cts:
                health_issues.append(f"{len(stopped_cts)} containers are stopped")
                
        # Check memory usage
        if node_details and node_details.get('status'):
            memory = node_details['status']['data'].get('memory', {})
            if memory.get('total') and memory.get('used'):
                mem_usage = (memory['used'] / memory['total']) * 100
                if mem_usage > 90:
                    health_issues.append(f"High memory usage: {mem_usage:.1f}%")
                elif mem_usage > 80:
                    health_issues.append(f"Elevated memory usage: {mem_usage:.1f}%")
                    
        if health_issues:
            print("   ⚠️  Issues found:")
            for issue in health_issues:
                print(f"      - {issue}")
        else:
            print("   ✅ No critical issues detected")
            
        print("="*80)
        
    async def run_assessment(self):
        """Main assessment routine"""
        try:
            await self.create_session()
            
            print("🔐 Authenticating with Proxmox...")
            if not await self.authenticate():
                print("❌ Authentication failed")
                return False
                
            print("✅ Authentication successful")
            
            # Gather system information
            system_info = await self.gather_system_info()
            
            # Get node details (assuming single node for now)
            node_details = None
            if system_info.get('nodes') and system_info['nodes']['data']:
                node_name = system_info['nodes']['data'][0]['node']
                node_details = await self.get_node_details(node_name)
                
            # Generate assessment report
            await self.print_assessment_report(system_info, node_details)
            
            # Save raw data for further analysis
            assessment_data = {
                'timestamp': datetime.now().isoformat(),
                'system_info': system_info,
                'node_details': node_details
            }
            
            with open('proxmox_assessment_data.json', 'w') as f:
                json.dump(assessment_data, f, indent=2, default=str)
                
            print("\n💾 Raw assessment data saved to: proxmox_assessment_data.json")
            return True
            
        except Exception as e:
            print(f"❌ Assessment failed: {e}")
            return False
        finally:
            if self.session:
                await self.session.close()

async def main():
    """Main function"""
    assessment = ProxmoxAssessment()
    success = await assessment.run_assessment()
    
    if success:
        print("\n🎉 Assessment completed successfully!")
    else:
        print("\n💥 Assessment failed!")
        sys.exit(1)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Assessment interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        sys.exit(1)