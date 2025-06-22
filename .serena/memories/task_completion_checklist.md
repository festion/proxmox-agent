# Task Completion Checklist

## Mandatory Steps When Completing Any Task

### 1. Code Review (CRITICAL)
**⚠️ MANDATORY**: All code changes MUST be reviewed using Gemini MCP before implementation.

```bash
mcp__gemini-collab__gemini_code_review
  code: "[YOUR CODE HERE]"
  focus: "stability and reliability for Proxmox infrastructure"
```

### 2. Pre-Implementation Checklist
- [ ] Verify current system health
- [ ] Create configuration backups
- [ ] Ensure VM/container backups are current
- [ ] Plan rollback procedures
- [ ] Document all planned modifications
- [ ] Use concurrent tool calls for efficiency

### 3. Implementation Guidelines
- [ ] Test changes in non-production environment when possible
- [ ] Monitor system during changes
- [ ] Apply changes incrementally
- [ ] Validate functionality after each change
- [ ] Document actual changes made

### 4. Post-Implementation Verification
- [ ] Confirm all services are operational
- [ ] Monitor system performance
- [ ] Update documentation
- [ ] Verify no unintended side effects
- [ ] Update monitoring baselines if needed

### 5. Documentation Requirements
- [ ] Update change logs with timestamps
- [ ] Document any issues encountered and resolutions
- [ ] Update procedure documentation
- [ ] Record configuration changes

### 6. Quality Gates
- [ ] **Gemini Review**: Confirmed low stability risk
- [ ] **Error Handling**: Validated and tested
- [ ] **Resource Impact**: Assessed and acceptable
- [ ] **Rollback Procedure**: Defined and tested
- [ ] **Documentation**: Updated and complete

### 7. Git Workflow
```bash
# After Gemini approval:
git add .
git commit -m "Description of changes [Gemini-Reviewed]"
git push  # Only after thorough testing
```

### 8. Emergency Override (RARE)
Only bypass review process if:
- System is down and immediate action required
- Security breach requiring urgent response
- Data loss prevention measures needed

**If bypassed**: Document emergency nature and schedule post-incident review.

## Success Criteria
- [ ] System uptime maintained (>99.9% target)
- [ ] No unintended service disruptions
- [ ] All functionality working as expected
- [ ] Monitoring shows healthy system state
- [ ] Documentation complete and accurate

## Rollback Procedure (If Issues Occur)
1. **Immediate Assessment**: Determine scope of issue
2. **Rapid Response**: Implement temporary stabilization
3. **Recovery**: Use known-good configurations
4. **Documentation**: Record incident and resolution steps
5. **Analysis**: Conduct post-incident review