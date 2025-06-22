# Code Style and Conventions

## Project Status
**Note**: The project currently has no source code files, so conventions are inferred from system prompts and project setup.

## Inferred Style Guidelines

### Python Conventions
- **Python Version**: 3.11+
- **Async/Await**: Heavy use of asyncio for Proxmox API interactions
- **Type Hints**: Expected (based on modern Python dependencies)
- **Environment Configuration**: Use .env files with python-dotenv

### Code Quality Requirements
- **Mandatory Code Review**: ALL code must be reviewed using Gemini MCP before implementation
- **Focus**: Stability and reliability over features
- **Error Handling**: Robust error handling required for all system interactions
- **Documentation**: All changes must be documented

### File Organization
- **Environment**: .env file for Proxmox credentials (not committed)
- **Virtual Environment**: ./venv/ (excluded from git)
- **Prompts**: .prompts/ directory for system prompts and workflows
- **Configuration**: .serena/ for project configuration

### Security Practices
- **Secrets Management**: Use .env files, never commit credentials
- **Input Validation**: All inputs must be validated and sanitized
- **Privilege Escalation**: Assess risks carefully
- **SSL Verification**: Currently disabled for Proxmox (PROXMOX_VERIFY_SSL=false)

### Stability-First Approach
- **Conservative Changes**: Make incremental, well-tested modifications
- **Backup-First**: Ensure backups exist before any maintenance
- **Risk Assessment**: Every change must consider impact on uptime
- **Rollback Plans**: Always have rollback procedures defined