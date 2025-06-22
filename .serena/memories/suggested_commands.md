# Suggested Commands for Proxmox Agent Development

## Python Environment Management
```bash
# Activate virtual environment
source venv/bin/activate  # On Linux/WSL
# or
./venv/bin/python  # Direct execution

# Install packages
./venv/bin/pip install package_name

# List installed packages
./venv/bin/pip list

# Deactivate environment
deactivate
```

## Development Workflow
```bash
# Run Python scripts
./venv/bin/python script_name.py

# Check Python version
./venv/bin/python --version
```

## Git Commands
```bash
# Standard git workflow
git status
git add .
git commit -m "message [Gemini-Reviewed]"
git push

# View changes
git diff
git log --oneline
```

## System Commands (Linux/WSL)
```bash
# File operations
ls -la
find . -name "*.py" -not -path "./venv/*"
grep -r "pattern" . --exclude-dir=venv

# Process management
ps aux | grep python
htop
```

## Proxmox-Specific Commands (when implemented)
```bash
# These will be implemented in the agent:
# - VM status checks
# - Container management
# - Storage monitoring
# - Backup verification
# - System health checks
```

## Code Review (MANDATORY)
```bash
# Before ANY code implementation:
mcp__gemini-collab__gemini_code_review
  code: "[YOUR CODE HERE]"
  focus: "stability and reliability for Proxmox infrastructure"
```

## Project Structure Commands
```bash
# View project structure
tree -I venv

# Find configuration files
find . -name "*.yml" -o -name "*.yaml" -o -name "*.json"

# Check environment variables
cat .env  # (be careful with credentials)
```

## Testing Commands (to be implemented)
```bash
# When test framework is added:
# pytest
# python -m unittest
# Coverage analysis
```

## Monitoring Commands (to be implemented)
```bash
# When monitoring is implemented:
# tail -f logs/proxmox-agent.log
# systemctl status proxmox-agent
```

**Note**: Many commands are placeholders for future implementation as the project currently has no source code.