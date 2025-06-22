# Project Structure

## Current Directory Layout
```
proxmox-agent/
├── .env                    # Proxmox connection credentials (not committed)
├── .git/                   # Git repository 
├── .gitignore             # Standard Python .gitignore
├── .prompts/              # System prompts and workflows
│   ├── development/
│   │   └── gemini-code-review-workflow.md
│   └── system-prompts/
│       └── proxmox-stability-assistant.md
├── .serena/               # Serena project configuration
│   └── project.yml
└── venv/                  # Python virtual environment (not committed)
    └── [standard venv structure]
```

## Key Configuration Files

### .env
Contains Proxmox connection details:
- PROXMOX_HOST=192.168.1.137
- PROXMOX_PORT=8006
- PROXMOX_USERNAME=root
- PROXMOX_PASSWORD=[redacted]
- PROXMOX_VERIFY_SSL=false
- PROXMOX_TIMEOUT=30
- PROXMOX_REALM=pam

### .serena/project.yml
Serena configuration:
- Language: Python
- Git integration enabled
- Read-write mode enabled

## Expected Future Structure
```
proxmox-agent/
├── src/                   # Source code (to be created)
│   ├── __init__.py
│   ├── api/              # Proxmox API client
│   ├── monitoring/       # System monitoring
│   ├── maintenance/      # Maintenance tasks
│   └── utils/           # Utility functions
├── tests/                # Test files (to be created)
├── requirements.txt      # Dependencies (to be created)
├── README.md            # Project documentation (to be created)
├── setup.py or pyproject.toml  # Package configuration
└── config/              # Configuration files
```

## Ignored Files (.gitignore)
- Environment variables (.env*)
- Python cache (__pycache__, *.pyc)
- Virtual environments (venv/, .venv/)
- IDE files (.vscode/, .idea/)
- Build artifacts (build/, dist/, *.egg-info/)
- Logs (*.log, logs/)
- Test artifacts (htmlcov/, .coverage, .pytest_cache/)