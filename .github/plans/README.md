# Implementation Plans

This directory contains detailed implementation plans for GitHub issues, created by the `/plan #issue` workflow.

## Purpose

When using `/plan #42` to plan a feature from a GitHub issue, the resulting implementation plan is saved here as `issue-42.md`. This allows the `/implement #42` workflow to automatically load and follow the plan when executing the implementation.

## Workflow

```bash
# 1. Plan from issue
/plan #42
→ Creates .github/plans/issue-42.md

# 2. Implement using the plan
/implement #42
→ Loads issue-42.md and executes according to plan

# 3. Clean up after implementation
[delete issue-42.md after merging PR]
```

## File Naming Convention

Plans are named: `issue-{number}.md` where `{number}` is the GitHub issue number.

Examples:
- `issue-42.md` - Plan for issue #42
- `issue-137.md` - Plan for issue #137

## Lifecycle

Plans should be:
- **Created**: During `/plan #issue` workflow
- **Referenced**: During `/implement #issue` workflow
- **Updated**: If implementation reveals new requirements or blockers
- **Deleted**: After successful implementation and PR merge

## Plan Structure

Each plan document includes:

```markdown
# Feature Plan: [Issue Title]

**Issue**: #42
**Created**: [Date]
**Status**: Planning | In Progress | Implemented

## Overview
[Problem statement and solution summary]

## User Experience
[What users will see/do]

## Technical Approach
**Data Model**: [Schema changes]
**API Dependencies**: [WoW APIs needed]
**Architecture Changes**: [Files/modules affected]

## Implementation Phases
[Step-by-step roadmap with tasks]

## Risks & Mitigations
[Potential challenges and solutions]

## Testing Approach
[How to validate it works]

## Open Questions
[Things to investigate/decide]
```

## Maintenance

- Keep this directory clean - delete plans after implementation is merged
- If plans accumulate, archive completed ones to `archived/` subdirectory
- Update plans if requirements change during implementation
- Reference plan document URL in issue comments for visibility

## Alternative Storage

If you prefer not to commit plans to the repository:
- Save plans as issue comments instead
- Use GitHub Discussions for planning
- Store in project wiki

The `/implement` workflow can work without saved plans (it will offer to create one or implement directly from issue description).
