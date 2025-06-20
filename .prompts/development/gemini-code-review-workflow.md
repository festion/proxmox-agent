# Proxmox Code Review Workflow with Gemini MCP

## Mandatory Review Process

**⚠️ CRITICAL**: All code changes for the Proxmox infrastructure MUST be reviewed using Gemini MCP before implementation.

## Review Command

Use this exact command for all code reviews:

```bash
mcp__gemini-collab__gemini_code_review
  code: "[PASTE YOUR CODE HERE]"
  focus: "stability and reliability for Proxmox infrastructure"
```

## Review Criteria

### 🔍 Primary Focus Areas

1. **System Stability Impact**
   - Will this change affect VM or container availability?
   - Could this impact the Proxmox host at 192.167.1.137?
   - Are there potential memory leaks or resource consumption issues?

2. **Reliability Assessment**
   - Does the code handle errors gracefully?
   - Are there appropriate fallback mechanisms?
   - Is the code resilient to unexpected system states?

3. **Uptime Preservation**
   - Will this require service restarts or system reboots?
   - Are there mechanisms to minimize downtime?
   - Can changes be applied without affecting running VMs?

4. **Risk Evaluation**
   - What could go wrong with this implementation?
   - Are there adequate safeguards and validation checks?
   - Is there a clear rollback strategy?

### 🛡️ Security Considerations
- Input validation and sanitization
- Privilege escalation risks
- Network security implications
- Configuration file security

### 📊 Performance Impact
- Resource utilization (CPU, memory, disk I/O)
- Impact on virtualization performance
- Scalability considerations
- Monitoring and logging overhead

## Review Workflow

### Step 1: Pre-Review Preparation
```bash
# Before requesting review, ensure you have:
# - Clear understanding of the change purpose
# - Identified potential risks
# - Prepared rollback plan
# - Tested in non-production environment (if possible)
# - Plan to use concurrent tool calls for efficiency
```

### Step 2: Gemini Review Request
```bash
mcp__gemini-collab__gemini_code_review
  code: """
  [YOUR CODE HERE - Include context and comments]
  """
  focus: "Proxmox infrastructure stability, reliability, and uptime preservation"
```

### Step 3: Review Analysis
Ask Gemini to specifically evaluate:
- **Stability risks**: Could this destabilize the system?
- **Performance impact**: Will this affect VM performance?
- **Error handling**: Are all failure modes covered?
- **Recovery procedures**: Can the system recover from failures?

### Step 4: Implementation Decision
**✅ Proceed if Gemini confirms:**
- Low risk to system stability
- Proper error handling implemented
- Minimal impact on running services
- Clear rollback procedures available

**🛑 STOP and revise if Gemini identifies:**
- High risk to system stability
- Potential for extended downtime
- Insufficient error handling
- Complex changes without clear benefits

## Specific Review Templates

### For Configuration Changes
```bash
mcp__gemini-collab__gemini_code_review
  code: "[CONFIG FILE CHANGES]"
  focus: "Proxmox configuration safety, validation of syntax, and impact on running VMs at 192.167.1.137"
```

### For Script Automation
```bash
mcp__gemini-collab__gemini_code_review
  code: "[AUTOMATION SCRIPT]"
  focus: "Script reliability, error handling, and safety for Proxmox automation tasks"
```

### For Monitoring Code
```bash
mcp__gemini-collab__gemini_code_review
  code: "[MONITORING CODE]"
  focus: "Monitoring efficiency, resource usage, and reliability for Proxmox infrastructure"
```

### For Backup/Recovery Scripts
```bash
mcp__gemini-collab__gemini_code_review
  code: "[BACKUP SCRIPT]"
  focus: "Data integrity, backup reliability, and recovery procedures for Proxmox environment"
```

## Post-Review Actions

### If Gemini Approves
1. Document the review outcome
2. Implement changes during appropriate maintenance window
3. Monitor system after implementation
4. Update documentation

### If Gemini Raises Concerns
1. **STOP** implementation immediately
2. Address identified issues
3. Revise code based on feedback
4. Re-submit for review
5. Do not proceed until approval is received

## Emergency Override Process

### When Review Can Be Bypassed
**ONLY in critical emergencies where:**
- System is down and immediate action required
- Security breach requiring urgent response
- Data loss prevention measures needed

### Emergency Documentation
If bypassing review:
1. Document the emergency nature
2. Explain why review was bypassed
3. Schedule post-incident review with Gemini
4. Plan proper implementation for permanent fix

## Integration with Development Workflow

### Before Every Commit
```bash
# 1. Stage your changes
git add .

# 2. Review with Gemini (use concurrent operations when possible)
mcp__gemini-collab__gemini_code_review
  code: "$(git diff --cached)"
  focus: "Proxmox stability and reliability"

# 3. Only commit after Gemini approval
git commit -m "Your commit message [Gemini-Reviewed]"
```

### Concurrent Tool Usage Best Practices
- **Batch diagnostic commands** when troubleshooting issues
- **Run multiple health checks** simultaneously during pre-change verification
- **Execute parallel file operations** when safe to do so
- **Combine related tool calls** in single responses for efficiency

### Pull Request Process
- Include Gemini review results in PR description
- Tag commits with "[Gemini-Reviewed]"
- Reference specific stability concerns addressed

## Quality Gates

### Mandatory Approval Criteria
- ✅ Gemini confirms low stability risk
- ✅ Error handling validated
- ✅ Resource impact assessed
- ✅ Rollback procedure defined
- ✅ Documentation updated

### Red Flags for Rejection
- 🚫 High complexity without clear benefits
- 🚫 Insufficient error handling
- 🚫 Potential for extended downtime
- 🚫 Unclear or missing rollback procedures
- 🚫 Unnecessary system modifications

---

**Remember**: The goal is zero unplanned downtime for the Proxmox infrastructure at 192.167.1.137. Use Gemini MCP as your safety net to catch potential issues before they impact production systems.

**Last Updated**: 2025-06-19