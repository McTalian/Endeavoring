# WoW & Endeavoring Terminology

Quick reference for World of Warcraft and Endeavoring addon terminology.

## WoW Game Concepts

### Neighborhood
A group of housing plots in the WoW world where players can own a home, participate in quests and events around the neighborhood, and interact with their neighbors.

### Endeavors (aka "Initiatives" in API)
A time-based challenge (currently Monthly) for the whole neighborhood to complete together.

**Key Points:**
- Selected by neighborhood leader from 3 available options
- Each has a different theme and associated tasks
- Rewards include Community Coupons (currency for decor items)
- Has Milestones that unlock new decor items at the Endeavor vendor
- Completing the entire Endeavor rewards a relatively large sum of currency

**Important Naming Note:** While players see "Endeavors" in-game, all API documentation and code references use the term "Initiatives." Entry points in the Blizzard code typically use "Initiative."

### Endeavor Tasks
Small repeatable tasks that each player can complete to contribute to the neighborhood's progress.

**Task Types:**
- Zone-based objectives: "Complete 5 quests in the zone"
- Combat objectives: "Kill 10 monsters of a certain type"
- Neighborhood objectives: Tidying up, repairing structures

**Rewards per Task:**
- Points toward neighborhood's Endeavor progress
- House XP for the player to upgrade their house
- Currency (Community Coupons)

**Overlap:** Some tasks can be completed simultaneously (e.g., killing raid bosses in the zone may contribute to both zone-specific and general raid boss tasks).

### Activity (Activity Log)
A log of completed Endeavor Tasks within the neighborhood.

**API Data per Entry:**
- `taskName` - Name of the completed task
- `playerName` - Character who completed it
- `taskID` - Unique task identifier
- `amount` - Points contributed to the Endeavor
- `completionTime` - When the task was completed

## Addon Concepts

### BattleTag
Blizzard's account-wide unique identifier (e.g., `McTalian#1234`). The Endeavoring addon uses BattleTag to aggregate contributions across all of a player's characters.

### Alias
User-defined display name for their BattleTag. Makes leaderboards and activity logs more friendly than showing BattleTag numbers.

### Profile
In Endeavoring, a profile represents one player (BattleTag) and includes:
- Alias (if set)
- List of registered characters
- Timestamps for tracking changes

### My Profile vs Synced Profiles
- **My Profile** (`myProfile`): Authoritative data for the local player, immune to sync tampering
- **Synced Profiles** (`profiles`): Data received from other players via the sync protocol

### Sync Protocol
The communication system that shares player profiles across the guild:
- **MANIFEST**: Broadcast of basic profile info (alias, timestamps)
- **REQUEST_CHARS**: Whisper request for character list
- **CHARS_UPDATE**: Whisper response with character data
- **ALIAS_UPDATE**: Correction message when stale alias detected

### Gossip
Opportunistic profile propagation - when receiving a MANIFEST, proactively send profiles to players who may not have them yet. Includes bidirectional correction (sending back correct data when stale data is detected).

### Character Cache
O(1) lookup structure mapping character names to BattleTags for efficient leaderboard aggregation.

## Technical Terms

### CBOR
Concise Binary Object Representation - efficient binary serialization format used for encoding sync messages.

### Message Codec
The encoding pipeline for sync messages: CBOR → Deflate Compression → Base64 (for safe transmission).

### Chunking
Splitting large character lists into multiple messages to avoid exceeding WoW's addon message size limits (currently 5 characters per CHARS_UPDATE message).

### Delta Sync
Only syncing data that has changed since the last sync, using timestamps to determine what's new.

### TOC File
Table of Contents - WoW addon manifest file that lists all Lua/XML files to load and addon metadata.

## See Also

- [Resources](resources.md) - WoW API documentation and helpful references
- [Sync Protocol](sync-protocol.md) - Detailed communication protocol design
- [Database Schema](database-schema.md) - Data structure and storage
