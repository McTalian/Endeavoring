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

## File Path Convention

Always use forward slashes (`/`) for file paths regardless of OS. The WoW client correctly interprets them on all platforms.

## Development Status

**Current Phase**: Phase 4 (In-Game Testing)
**Next Phase**: Phase 2 (Options UI) or Leaderboard UI

See [Development Status](docs/development-status.md) for detailed progress tracking and roadmap.

### Recent Major Work (February 2026)

**MessageCodec Bug Fix (Feb 7)** ✅
- Fixed critical bug: WoW addon message API corrupts raw binary data
- Root cause: Compressed binary contains patterns that break transmission
- Solution: Three-step encoding (CBOR → Compress → Base64)
- Base64 converts binary to safe ASCII for reliable transmission
- Tested multiple approaches (plain CBOR, double-CBOR wrapping) before finding solution
- Compression still effective: ~16% total size reduction (115→96 bytes typical)
- Ready for Phase 4 in-game testing

**Leaderboard POC (Untested)** 📊
- CLI leaderboard via `/endeavoring leaderboard [all|today|week]`
- Aggregates activity log by player with time filtering
- Async event-driven data fetching pattern
- Ready for UI integration (same pattern for panel)
- Documentation: [testing-phase4.md](docs/testing-phase4.md)

**Message Codec (CBOR + Compression)** ✅
- Implemented CBOR serialization for structured, type-safe messages
- Automatic Deflate compression for messages >100 bytes (40-60% size reduction)
- Protocol versioning with version + flags bytes for future evolution
- Single-character message type identifiers (M, R, A, C) for wire efficiency
- Defense-in-depth error handling: size validation + return code checking
- Comprehensive error messages for test users to identify sync issues
- Full V1 removal - clean break to CBOR-only (0 users, alpha phase)
- Documentation: [message-codec.md](docs/message-codec.md)

**Phase 3.5 - Gossip Protocol** ✅
- Implemented opportunistic profile propagation via gossip
- BattleTag-based tracking (handles alt-swapping elegantly)
- Per-session gossip limits (no time-based cooldowns)
- Rate limiting: Max 3 profiles per MANIFEST received
- Gossip statistics via `/endeavoring sync gossip`

**Phase 3 - Direct Sync** ✅
- Database service with authoritative `myProfile` and synced `profiles`
- Character registration on login  
- Alias management via `/endeavoring alias <name>`
- Timestamp-based delta sync strategy (`aliasUpdatedAt` and `charsUpdatedAt`)
- Architecture cleanup: Services/ for WoW APIs, Data/ for persistence
- Full sync protocol implementation (MANIFEST broadcast, whisper-based requests/responses)
- Guild roster update triggering with debouncing and random delay
- Realm handling fix with GetNormalizedRealmName() fallback

**Code Quality Improvements** ✅
- Verbose debug mode toggle (`/endeavoring sync verbose`)
- Slash commands refactored to Commands.lua with discrete handlers
- Message prefix constants (INFO, ERROR, WARN) in Bootstrap.lua

## Architecture & Conventions

The addon follows a clear separation of concerns:

- **Services/** - WoW API abstractions (anything that could change between patches)
- **Data/** - Data persistence and access (SavedVariables management)
- **Features/** - UI components and feature implementations  
- **Integrations/** - Optional hooks into other addons or Blizzard frames

**Sync Protocol Notes:**
- MANIFEST broadcasts to GUILD channel on login and guild roster updates
- Alias synced directly from MANIFEST (no separate REQUEST_ALIAS needed)
- REQUEST_CHARS and CHARS_UPDATE use WHISPER to reduce guild spam
- Guild roster updates trigger manifests with 5s debounce + 2-10s random delay

**Key Convention - Guard Clauses:**
- ✅ Use guards for external/optional dependencies (Blizzard APIs, other addons, runtime state)
- ❌ Don't use guards for our own code (fail fast if load order is broken)

Example:
```lua
-- Good - external API guard
if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo then
  return C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
end

-- Good - no guard for our own code (fail fast)
ns.DB.Init()
ns.Tasks.Refresh()

-- Bad - unnecessary guard hides load order bugs
if ns.DB and ns.DB.Init then
  ns.DB.Init()
end
```

See [Architecture](docs/architecture.md) for complete conventions and directory structure.

## Technical Documentation

Detailed technical documentation is available in `.github/docs/`:

- **[Database Schema](docs/database-schema.md)** - Data structure, timestamp strategy, access patterns
- **[Sync Protocol](docs/sync-protocol.md)** - Communication protocol design for player profile syncing  
- **[Architecture](docs/architecture.md)** - Project structure, conventions, coding standards
- **[Development Status](docs/development-status.md)** - Progress tracking, roadmap, recent decisions

Reference these documents when:
- Working on data access or persistence
- Implementing communication/sync features
- Needing context on architectural decisions
- Planning new features or refactoring

## WoW Contextual Terminology

- **Neighborhood**: A group of housing plots in the WoW world where players can own a home, participate in quests and events around the neighborhood, and interact with their neighbors.
- **Endeavors**: A Time-based challenge (I believe Monthly) for the whole neighborhood to complete together. Rewards include a currency item (Community Coupons) that can be used to purchase various decor items for the players' homes. An Endeavor has Milestones which will unlock new decor items at the Endeavor vendor. Completing the entire Endeavor rewards a relatively large sum of the currency. A neighborhood leader will choose which Endeavor the neighborhood will pursue from a selection of 3 available Endeavors, each with a different theme and associated tasks.
- **Endeavor Tasks**: Small tasks that each player can complete to contribute to the neighborhood's progress on the Endeavor. Tasks can include things like "Complete 5 quests in the zone" or "Kill 10 monsters of a certain type in the zone" as well as objectives around the neighborhood itself like tidying up the neighborhood or repairing structures. Each task rewards a certain number of points towards the neighborhood's progress on the Endeavor, House XP for the player to upgrade their house, and some currency. These tasks vary in terms of their requirements and rewards, and can be completed by players at their own pace throughout the duration of the Endeavor. At the time of writing, the tasks are repeatable.
- **Activity**: A log of completed Endeavor Tasks within the neighborhood. Each activity entry includes details about the task that was completed and the player who completed it, though the API seems to provide the `taskName`, `playerName`, `taskID`, `amount` (of points contributed to the endeavor by this task completion), and `completionTime`.

## Features Under Consideration

- **Sorting Endeavor Tasks** Currently tasks are loosely grouped by the location that they need to be completed in (the neighborhood, the zone associated with the Endeavor "theme"), but there is no way to sort or filter the list of tasks. Adding sorting and filtering options could help players find the tasks that are most relevant to them and complete them more efficiently. Some tasks "overlap" in that they can be completed in the same activity (for example, killing raid bosses in the associated zone may also contribute towards the general "kill raid bosses" task), and being able to easily identify these overlapping tasks and complete them together could be a nice quality of life improvement.
- **Leaderboard**: Adding a leaderboard to the Endeavoring addon could help foster a sense of friendly competition among neighbors and encourage more active participation in the Endeavors system. Currently, the Activity Log entries are associated with the "player name," but with the Endeavoring addon, we could associate them with the player's BattleTag instead (as long as a given character was using the Endeavoring addon when logged in). This would allow us to create a leaderboard that ranks players based on their contributions to the neighborhood's progress on the Endeavor, and could include additional features such as filtering by time period (this week, today, etc.) or by specific tasks completed. A leaderboard could also provide an additional incentive for players to complete more tasks and contribute more to the neighborhood's progress, which could help create a more engaging and rewarding experience for users of the Endeavoring addon.
