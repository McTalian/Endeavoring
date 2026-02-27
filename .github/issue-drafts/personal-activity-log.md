# Personal Activity Log

## Feature Description

Track and display per-character activity history and statistics for endeavor contributions, allowing players to see their personal progress and patterns over time.

### Current Behavior
The addon shows guild-wide leaderboards and current endeavor progress, but doesn't maintain historical data about individual character contributions across multiple endeavor cycles.

### Proposed Enhancement
Add a dedicated UI panel showing:

**Per Endeavor History:**
- List of past endeavors with completion dates
- Personal contribution amount for each
- Rank within guild for that endeavor
- Which milestones were reached
- Activities completed

**Overall Statistics:**
- Total endeavors participated in
- Total contribution amount across all endeavors
- Average contribution per endeavor
- Most frequent activity types
- Streak tracking (consecutive weeks with contributions)

**UI Access:**
- New tab/button in the Endeavoring frame
- Or dropdown menu option: "View My History"

### Implementation Approach
1. Create new database schema for personal activity log
2. Hook into activity completion events to record contributions
3. Store historical data in per-character SavedVariables
4. Create UI panel with scrollable history list
5. Add summary statistics view
6. Consider data retention policy (keep last N endeavors? configurable?)

### Data to Track
```lua
{
  endeavorID = number,
  endeavorName = string,
  startDate = timestamp,
  endDate = timestamp,
  personalContribution = number,
  personalRank = number,
  milestonesReached = table,
  activitiesCompleted = {
    [activityID] = contributionAmount
  },
  chestClaimed = boolean
}
```

## Complexity
**High** - Requires new database schema, event tracking, data retention strategy, and substantial UI work.

## Additional Context

### Benefits
- Provides players with personal sense of achievement and progress
- Enables comparison of performance across endeavors
- Helps identify most effective activities for future planning
- Creates engagement through statistics and history tracking

### Challenges
- Database size management (old data cleanup)
- Retroactive data - can only track forward from implementation
- Cross-character data (should it aggregate account-wide?)
- UI complexity - need clean, readable history display

### Considerations
- Should we track data for characters that didn't contribute to an endeavor?
- How to handle endeavors that were abandoned/not completed?
- Export functionality for data analysis?
- Integration with leaderboard to show "vs. my average" comparisons?

### Related Files
- `Endeavoring/Data/Database.lua` - Data persistence layer
- `Endeavoring/Cache/ActivityLogCache.lua` - May need extension for personal tracking
- New file: `Endeavoring/Features/ActivityHistory.lua` - UI and logic

### Possible Extensions (Post-v1)
- Weekly/monthly digest notifications
- Achievement-style milestones for personal contributions
- Compare performance to guild averages
- Visual graphs/charts of contribution trends

## Labels
`enhancement`, `high-complexity`, `new-feature`, `post-v1.0`
