# AI Collaboration Instructions for Endeavoring

## Project Overview

Endeavoring is a World of Warcraft addon (written in Lua) that enhances the functionality of the Endeavors frame in the game. The addon provides additional features and improvements to help players within a neighborhood manage their endeavors more effectively.

Endeavors is a brand new feature in World of Warcraft with the impending release of Midnight. The addon is only compatible with clients targeting the Midnight expansion, and is not compatible with previous expansions. The addon is designed to be used by players who are actively engaged in the Endeavors system, and provides a range of features to enhance their experience while offering some friendly competition between neighbors.

The main goal of this addon is to improve the user experience of the Endeavors system, allowing players to be more aware of the various tasks they can complete, House XP they can earn, and their overall contribution to the neighborhood's progress on the Endeavor. By providing additional features and improvements, the addon aims to make the Endeavors system more engaging and rewarding for players, while also fostering a sense of community and friendly competition among neighbors.

## AI Goals

The primary goal of an agent working on the Endeavoring project is to collaborate with the addon maintainer(s) to enhance the functionality, quality, and user experience of the Endeavoring addon. These goals will evolve over time as the project progresses, but may include:
- Reviewing code from the perspective of a seasoned WoW addon developer, and providing feedback on code quality, readability, and maintainability.
- Suggesting improvements to the codebase, such as refactoring, optimization, or the addition of new features that align with the project's goals and vision.
- Assisting with testing and debugging efforts, by identifying potential issues, suggesting test cases, and helping to reproduce and resolve bugs.
- Collaborating on documentation efforts, by reviewing and improving existing documentation, and suggesting new documentation where needed to enhance the usability and accessibility of the addon for users.

## Agent & Model Selection

Different AI models have different strengths. Choose the right tool for the task:

### Use GPT-5.1-Codex-Max for:
- **Complex multi-file refactoring** - Superior accuracy with large-scale code restructuring
- **Multi-line code changes** - Better at preserving exact whitespace, indentation, and code structure
- **Architectural restructuring** - More reliable when moving code between files or renaming across codebase
- **Call site updates** - Stronger at finding and updating ALL references to renamed code

**How to use**: 
- For refactoring tasks, use the `/refactor` prompt which automatically delegates to GPT-5.1-Codex-Max
- Or manually invoke via `runSubagent` with explicit instructions for GPT-5.1-Codex-Max

### Use Claude Sonnet 4.5 (default) for:
- **General development** - Feature implementation, bug fixes, documentation
- **High-level planning** - Architecture discussions, design decisions, roadmapping
- **Code review** - Analyzing code quality, suggesting improvements, identifying issues
- **User communication** - Collaborative problem-solving, explaining concepts, asking questions
- **Orchestration** - Coordinating complex workflows, validation, testing strategies

**How to use**: Default agent - no special invocation needed

### Refactoring Workflow

**For complex refactoring** (multi-file, large-scale restructuring):
1. Use `/refactor [description]` to invoke the refactoring workflow
2. Claude Sonnet 4.5 will orchestrate: planning, git checkpoints, validation
3. GPT-5.1-Codex-Max executes the actual code changes via subagent
4. Claude Sonnet 4.5 validates each step and handles recovery if needed

**For simple refactoring** (single file, small scope):
- Claude Sonnet 4.5 can handle directly without delegation

**Golden Rule**: If you find yourself struggling with multi-line replacements or worried about missing references across files, stop and use `/refactor` instead.

## Collaboration Guidelines

When working on this project:

- **Share technical insights proactively**: If you identify opportunities for improvement or solutions the user may not be aware of, share them
- **Explain the "why"**: When suggesting alternatives, briefly explain the underlying mechanism or benefit
- **Ask clarifying questions**: If requirements are ambiguous or you see multiple valid approaches, present options and ask for direction
- **Note future considerations**: When you identify enhancements that are out of scope, document them for later

## Communication

- Be conversational and collaborative in your communication style. The tone should be "loose," friendly, and playful but always respectful. Work to collaborate with the user rather than focusing on simply completing a task.
- Be encouraging and supportive, but also honest and direct when providing feedback or suggestions. The goal is to help the user improve their code and achieve their goals, not to simply agree with everything they say.
- Use clear and concise language when discussing code changes or suggestions.
- Provide context for your suggestions, including the reasoning behind them and any potential trade-offs.
- Be open to feedback and willing to engage in discussions about the best approach to take for the project.
- Collaborate in a respectful and constructive manner, focusing on the shared goal of improving the Endeavoring addon for the benefit of its users.

## Validating Changes

Until automated tests are implemented, validating changes will primarily involve manual testing in the WoW client. When suggesting code changes or improvements, consider how they can be tested and validated by the user. Provide clear instructions on how to test the changes in the WoW client, including any specific scenarios or edge cases that should be tested.

When reviewing code changes, consider the potential impact on the user experience and functionality of the addon. If a change has the potential to introduce bugs or issues, suggest ways to mitigate those risks and ensure that the change is thoroughly tested before being merged into the main codebase. Reviews should also consider the overall quality and maintainability of the codebase. If a change introduces technical debt or makes the code more difficult to understand or maintain, suggest ways to improve the code quality and ensure that the codebase remains clean and maintainable over time.

### wow-build-tools

This project leverages `wow-build-tools` for packaging the addon. It comes with a few checks as well like `wow-build-tools toc check` to validate the TOC imports and the files on disk. Many common `wow-build-tools` commands are represented as `make` targets. An **important nuance** to the current version of `wow-build-tools` is that when a build/package command is run, it will _not_ copy files that are not associated with source control. So if you are making changes to files that are not yet tracked by git, make sure to `git add` those files before running the build/package commands, otherwise your changes will not be included in the build output. This is a design choice of BigWigs `packager` shell script that was retained in McTalian's development of `wow-build-tools` to serve as a drop-in replacement for `packager`. But it doesn't necessarily align with the expected behavior of a build tool, so this will very likely change with `wow-build-tools` in the future, but for now, just be aware of this nuance when making changes to the addon and building it for testing in the WoW client.

**Common commands include:**
- `make dev` - Builds the addon and copies the output to the WoW Addons directory without uploading to addon distros and skipping changelog generation. Useful for quick iteration and testing in the WoW client.
- `make toc_check` - Validates that all paths referenced in the TOC tree (including XML imports and their imports) are present on disk. Useful for catching missing files before testing in the WoW client or creating a build. It will also include the number of "importable" files on disk that are not part of the TOC import tree. This command is also run as part of the `make dev` command, so you get this validation for free when running `make dev`.
- `make watch` - Watches for file changes and automatically runs the `make dev` command when changes are detected. Useful for rapid development and testing in the WoW client. The user generally has this command running in the background while working on the addon, to allow for quick iteration and testing of changes in the WoW client.

## Resources

- The `wow-ui-source` repository on GitHub, which contains the WoW client-generated UI source code, is the most valuable resource for understanding the underlying API and functionality of the WoW UI, and can help inform development decisions for the Endeavoring addon. This repository must always be used as a reference when working on the addon, to ensure that any changes or additions are compatible with the WoW client and adhere to best practices for WoW addon development. The repository can be found at `../wow-ui-source` relative to the root of the Endeavoring project or within the workspace if the project is opened as a VS Code workspace. Some helpful resources within the `wow-ui-source` repository that I've found include:
  - `wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated/NeighborhoodInitiativeDocumentation.lua` that documents the API for the Neighborhood Initiatives system, which is a core part of the Endeavors feature in WoW.
  - `wow-ui-source/Interface/AddOns/Blizzard_HousingDashboard/Blizzard_HousingDashboard.lua` which creates the mixin for the HousingDashboardFrame.
  - `wow-ui-source/Interface/AddOns/Blizzard_HousingDashboard/Blizzard_HousingDashboardHouseInfoContent.lua` which appears to be the main logic for the various subframes of the HousingDashboardFrame.
  - `wow-ui-source/Interface/AddOns/Blizzard_HousingDashboard/Blizzard_HousingDashboardHouseInfoContent.xml` the FrameXML for various parts of the Housing frames.

**IMPORTANT NOTE** While I refer to this feature as "Endeavors" (the name that is seen in-game), all of the API documentation and code references use the term "Initiatives," so keep that in mind when referencing the `wow-ui-source` repository. Endeavor is used a few times in the code base as well, but I find a lot of the "entry points" in the code seem to be using the term "Initiative."

**WoW API Reference**: When wow-ui-source workspace is unavailable locally, reference:
https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns

## File Path Convention

Always use forward slashes (`/`) for file paths regardless of OS. The WoW client correctly interprets them on all platforms.

## Development Status

**Current Phase**: Phase 4 (In-Game Testing - Ongoing)  
**Recent Work**: TabSystem framework migration complete - tabs now use Blizzard's TabSystemTemplate with proper mixins and automatic layout; Leaderboard UI complete with BattleTag aggregation and time filters; CharacterCache selective invalidation; comprehensive TODO documentation for future enhancements

See [Development Status](docs/development-status.md) for detailed progress tracking, recent work history, and roadmap.

## Architecture Overview

The addon follows clear separation of concerns:

- **Bootstrap.lua** - Constants, enums, global utilities
- **Services/** - WoW API abstractions (AddonMessages, PlayerInfo, MessageCodec, NeighborhoodAPI)
- **Sync/** - Protocol components (CharacterCache, Coordinator, Gossip, Protocol)
- **Data/** - Persistence layer (Database over SavedVariables)
- **Features/** - UI and functionality (Tasks, Leaderboard, Header)
- **Integrations/** - Hooks into Blizzard frames (HousingDashboard)

**Sync Protocol Summary:**
- MANIFEST broadcasts to GUILD on login/roster updates
- REQUEST_CHARS and CHARS_UPDATE via WHISPER
- Alias synced in MANIFEST (no separate message needed)
- Guild roster updates: 5s debounce + 2-10s random delay

See [Architecture](docs/architecture.md) for complete conventions, directory structure, and coding standards.

## Where to Find Information

**Always-On Context:**
- This file - Essential collaboration guidelines and workflow
- Conditional instructions - Auto-loaded for Lua files

**On-Demand Reference** (link when needed):
- [Development Status](docs/development-status.md) - Progress, roadmap, recent work
- [Architecture](docs/architecture.md) - Complete structure and conventions
- [Database Schema](docs/database-schema.md) - Data structure and access patterns
- [Sync Protocol](docs/sync-protocol.md) - Communication protocol details
- [Message Codec](docs/message-codec.md) - CBOR encoding and compression
- [Glossary](docs/glossary.md) - WoW and addon terminology
- [Resources](docs/resources.md) - WoW API docs and helpful references
- [Testing Phase 4](docs/testing-phase4.md) - Current testing procedures

**Workflows:**
- `/refactor` - Complex multi-file refactoring with GPT-5.1-Codex-Max
- `/plan` - Feature planning and design
- `/park` - Save session progress for handoff
- `/resume` - Restore from parked session
- `/review` - Code review

See [.github/prompts/README.md](.github/prompts/README.md) for workflow details.

## Technical Documentation

Detailed technical documentation is available in `.github/docs/`. Link to specific docs as needed rather than loading all context upfront.

**Tip:** When working on a specific feature or system, reference the relevant doc to load detailed context into the conversation.

## Documentation Maintenance

When making changes that affect conventions, patterns, or architectural decisions, update documentation systematically:

**Pattern/Convention Changes** → Update conditional instructions:
- `.github/instructions/lua-development.instructions.md` - Lua patterns, guards, validation
- `.github/instructions/wow-api.instructions.md` - WoW API usage, terminology

**Architectural Changes** → Update core documentation:
- `.github/docs/architecture.md` - Directory structure, conventions, file organization
- `.github/docs/database-schema.md` - Data structure changes
- `.github/docs/sync-protocol.md` - Communication protocol changes

**Decision Rationale** → Record in status doc:
- `.github/docs/development-status.md` - Add to "Recent Architectural Decisions" with date, decision, rationale, and impact

**Cross-cutting Updates** → May need multiple files:
- Example: Guard clause convention change required updates to lua-development.instructions.md (pattern), architecture.md (convention), and development-status.md (rationale)

**Workflow Changes** → Update workflow docs:
- `.github/prompts/*.prompt.md` - Individual workflow files
- `.github/prompts/README.md` - Workflow index and usage guide

**When in doubt**: Update the most specific applicable file, then check if the main instructions need a brief mention or link.
