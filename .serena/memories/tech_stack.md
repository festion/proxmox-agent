# Technology Stack

## Core Technologies
- **Language**: Python 3.11+
- **HTTP Client**: aiohttp 3.12.13 (for Proxmox API communication)
- **Configuration**: python-dotenv 1.1.0 (environment variable management)
- **Async Support**: asyncio-throttle 1.0.2 (rate limiting)

## Development Environment
- **Virtual Environment**: venv (located in ./venv/)
- **Platform**: Linux (WSL2 on Windows)
- **Git**: Version control enabled
- **IDE Integration**: .gitignore configured for common IDEs (.vscode/, .idea/)

## Installed Dependencies
- aiohappyeyeballs 2.6.1
- aiohttp 3.12.13
- aiosignal 1.3.2
- asyncio-throttle 1.0.2
- attrs 25.3.0
- frozenlist 1.7.0
- idna 3.10
- multidict 6.5.0
- propcache 0.3.2
- python-dotenv 1.1.0
- yarl 1.20.1

## Target Platform
- **Proxmox VE** (Virtual Environment)
- **Management Tools**: Proxmox web interface, CLI tools (qm, pct, pvesh)
- **Storage**: ZFS/LVM storage management
- **Networking**: Bridge networking, VLANs, firewall rules