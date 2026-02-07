---
name: park
description: Save session progress and generate handoff summary for context transfer
agent: agent
tools: ['vscode', 'read', 'edit', 'search', 'todo']
---

# Park Session - Context Handoff

You are preparing to hand off this development session to a fresh agent context. Your goal is to:

1. **Update project documentation** with accomplishments from this session
2. **Generate a handoff summary** for seamless continuation in a new session

## Step 1: Review Current Session

Analyze the conversation history and identify:
- Files created, modified, or deleted
- Features implemented or bugs fixed
- Architectural decisions made
- Tests run and their results
- Any in-progress work or blockers
- Important insights or discoveries

## Step 2: Update Documentation

Update the following files as appropriate based on session accomplishments:

### [copilot-instructions.md](../copilot-instructions.md)
- Update "Development Status" section with current phase
- Update "Recent Major Work" with new accomplishments (prepend, keep it concise)
- Add any new "Features Under Consideration" discovered during discussion
- Update any changed conventions or architecture decisions

### [development-status.md](../docs/development-status.md)
- Mark completed tasks with ✅
- Update phase progress percentages
- Add new tasks or phases if identified
- Document any blockers or decisions made
- Update "Next Steps" section

### Other docs (if applicable):
- **[architecture.md](../docs/architecture.md)** - New services, conventions, or structural changes
- **[database-schema.md](../docs/database-schema.md)** - Schema changes or new data patterns
- **[sync-protocol.md](../docs/sync-protocol.md)** - Protocol changes or new message types

**Important**: Only update docs that are actually relevant to this session's work. Don't make changes just for the sake of it.

## Step 3: Generate Handoff Summary

Create a comprehensive handoff summary with these sections:

### 📋 Session Overview
- Brief description of the session's main goal
- Date and approximate duration

### ✅ Completed Work
List each accomplishment with:
- What was done
- Files affected (with line references if useful)
- Any important implementation details

### 🚧 In-Progress Work
If work was left incomplete:
- What was started but not finished
- Current state and what remains
- Any blockers or challenges discovered

### 💡 Key Insights & Decisions
- Architectural decisions made and why
- Important discoveries about the codebase or APIs
- Trade-offs considered
- Issues encountered and how they were resolved

### 📦 Files Modified
Comprehensive list organized by change type:
- **Created**: New files
- **Modified**: Changed files with brief description of changes
- **Deleted**: Removed files

### 🧪 Testing Status
- Tests run (if any)
- Results and any failures
- Manual testing performed
- Known issues or edge cases

### 🎯 Recommended Next Steps
Prioritized list of what should be tackled next:
1. Immediate follow-ups from this session
2. Related tasks that emerged
3. Longer-term items to consider

### 📝 Context to Preserve
Any important context that might not be obvious from the code:
- Why certain approaches were chosen
- What was tried and didn't work
- Quirks or limitations discovered
- Open questions or areas needing investigation

### 🚀 Quick Start for Next Session
A literal prompt or command the next agent can use to dive right in:
```
Example: "Continue implementing the leaderboard feature. The database schema has been updated in Database.lua (lines 45-67) to support activity tracking by BattleTag. Next, implement the UI component in Features/Leaderboard.lua following the patterns established in Features/Tasks.lua."
```

## Output Format

First, show the documentation updates you're making (you should actually apply these changes using the appropriate tools).

Then, present the handoff summary in a clean, copy-paste-ready format that starts with a clear heading like:

```
═══════════════════════════════════════════════
🅿️  PARKED SESSION HANDOFF
═══════════════════════════════════════════════
```

Make the summary comprehensive enough that the next agent (or you in a new session) can pick up seamlessly without having to dig through the full conversation history.
