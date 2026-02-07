# Phase 4: In-Game Testing Plan

**Target**: PTR/Beta Midnight Client  
**Codec Version**: V1 (CBOR + Compression)  
**Test Accounts Required**: 2 (3-5 characters each recommended)

## Pre-Test Setup

### Account A Setup
1. Copy `.release/Endeavoring-<hash>.zip` to `_retail_/Interface/AddOns/`
2. Extract to `Endeavoring/` folder
3. Launch client, log into Character 1
4. Enable verbose debug: `/endeavoring sync verbose`
5. Set alias: `/endeavoring alias AccountA`

### Account B Setup
1. Repeat steps 1-3 with Character 1
2. Enable verbose debug: `/endeavoring sync verbose`
3. Set alias: `/endeavoring alias AccountB`

## Test Suite

### Test 1: Initial Profile Sync ✅

**Goal**: Verify MANIFEST broadcast and basic profile exchange

**Steps**:
1. Both accounts logged in (Character 1 each)
2. Account A: `/endeavoring sync stats`
   - Should show: Own profile + Account B's profile
3. Account B: `/endeavoring sync stats`
   - Should show: Own profile + Account A's profile
4. Check verbose output for:
   - "Sending X byte message on channel GUILD"
   - "compressed" indicator if message >100 bytes

**Expected Behavior**:
- Both accounts see each other in stats
- Aliases display correctly (AccountA, AccountB)
- Character counts match (1 each initially)
- Messages <255 bytes

**Pass Criteria**:
- ✅ No Lua errors
- ✅ Profiles synchronized within 10 seconds
- ✅ Aliases visible in stats output
- ✅ Message sizes logged in verbose mode

---

### Test 2: Alias Updates ✅

**Goal**: Verify ALIAS_UPDATE message propagation

**Steps**:
1. Account A: `/endeavoring alias TestPlayerOne`
2. Wait 3-5 seconds
3. Account B: `/endeavoring sync stats`
   - Should show "TestPlayerOne" instead of "AccountA"
4. Account B: `/endeavoring alias TestPlayerTwo`
5. Account A: `/endeavoring sync stats`
   - Should show "TestPlayerTwo" instead of "AccountB"

**Expected Behavior**:
- Alias changes propagate to other account
- Update happens within 5 seconds
- No need to reload UI or relog

**Pass Criteria**:
- ✅ Both accounts see updated aliases
- ✅ No Lua errors during update
- ✅ Verbose output shows "Sending X byte message" for ALIAS_UPDATE

---

### Test 3: Character Registration (Alt Swapping) ✅

**Goal**: Verify CHARS_UPDATE sync when switching characters

**Steps**:
1. Account A: Note current character count in stats
2. Account A: Log out, log into Character 2
3. Account A: `/endeavoring sync verbose` (re-enable)
4. Account A: `/endeavoring sync stats`
   - Should show 2 characters now
5. Account B: Wait for MANIFEST, then check stats
   - Should see Account A has 2 characters
6. Repeat with Character 3, 4, 5 on Account A

**Expected Behavior**:
- Each new character adds to Account A's character list
- Character list syncs to Account B automatically
- MANIFEST sent on login (verbose shows this)
- Account B may send REQUEST_CHARS whisper

**Pass Criteria**:
- ✅ Character count increases each login
- ✅ Account B sees updated character count within 10 seconds
- ✅ Verbose shows MANIFEST broadcast on each login
- ✅ No duplicate character entries

---

### Test 4: Compression Behavior 🔍

**Goal**: Verify compression triggers at ~100 bytes

**Steps**:
1. Account A: Log in with 1 character
   - Verbose output: Note message size
2. Account A: Add 5 more characters (log in with each)
3. Account A: `/endeavoring sync broadcast`
   - Verbose output: Note message size
4. Account A: Add 5 more characters (10 total)
5. Account A: `/endeavoring sync broadcast`
   - Verbose output: Note message size + "compressed" indicator

**Expected Behavior**:
- 1-3 characters: ~40-80 bytes, no compression
- 5-10 characters: ~100-200 bytes, **compression should trigger**
- Verbose output shows "compressed" when active
- All messages stay well under 255 bytes

**Pass Criteria**:
- ✅ Small profiles (<100 bytes) not compressed
- ✅ Medium profiles (>100 bytes) show "compressed"
- ✅ Compressed messages stay under 255 bytes
- ✅ No compression errors in output

---

### Test 5: Gossip Protocol 🔍

**Goal**: Verify opportunistic profile propagation

**Steps**:
1. Account A: 5+ characters registered
2. Account B: 3+ characters registered
3. Account A: `/endeavoring sync broadcast`
4. Account B: Check verbose output
   - Should see "Gossiping X profiles" if applicable
5. Account B: `/endeavoring sync gossip`
   - Should show profiles sent/received this session

**Expected Behavior**:
- Account B gossips 0-3 profiles back to Account A
- Gossip happens automatically (no manual trigger)
- Rate limited to max 3 profiles per MANIFEST
- Stats show gossip activity

**Pass Criteria**:
- ✅ Gossip triggers on MANIFEST received
- ✅ Max 3 profiles gossiped per event
- ✅ `/endeavoring sync gossip` shows activity
- ✅ No spam or excessive chatter

---

### Test 6: Message Size Limits ⚠️

**Goal**: Verify size limit enforcement and error messages

**Setup**: This test requires manipulating SavedVariables to create an oversized profile

**Steps**:
1. Log out of game
2. Edit `WTF/Account/<AccountName>/SavedVariables/EndeavoringDB.lua`
3. Manually add 50+ dummy characters to `myProfile.chars`:
   ```lua
   ["chars"] = {
     ["Char1-Realm"] = { registeredAt = 1234567890 },
     ["Char2-Realm"] = { registeredAt = 1234567890 },
     -- ... add 48 more ...
   }
   ```
4. Log back in
5. Attempt to broadcast: `/endeavoring sync broadcast`

**Expected Behavior**:
- **Red error message**: "Message size (XXX bytes) exceeds API limit (255 bytes)! Message NOT sent."
- **Follow-up message**: "This likely means you have too many characters. Please report this issue!"
- Message is **blocked** (not sent)
- Verbose output shows pre-flight validation failure

**Pass Criteria**:
- ✅ Oversized message blocked before send
- ✅ Clear, visible error message in chat
- ✅ Error includes actual size vs. limit
- ✅ Helpful guidance to report issue

---

### Test 7: Guild Roster Update Trigger 📋

**Goal**: Verify MANIFEST broadcasts on guild roster changes

**Steps**:
1. Account A: Log in, join guild (if not already)
2. Account B: Log in same guild
3. Account A: Note last MANIFEST time in verbose output
4. Outside player: Join or leave guild
5. Account A: Check verbose output
   - Should see "Guild roster updated" event
   - Should see debounce delay (5s) message
   - Should see MANIFEST broadcast after 7-15 seconds

**Expected Behavior**:
- Guild roster changes trigger MANIFEST
- Debounce prevents spam (5s minimum between updates)
- Random delay (2-10s) after debounce before sending
- Verbose output logs the event and timing

**Pass Criteria**:
- ✅ MANIFEST sends 7-15 seconds after roster change
- ✅ Multiple rapid changes don't spam (debounced)
- ✅ Verbose shows "debouncing" and delay messages
- ✅ No errors from roster update event

---

### Test 8: Error Code Validation 🔍

**Goal**: Verify SendAddonMessage return code handling

**Setup**: These errors are hard to trigger naturally, but we can validate the code paths

**Potential Scenarios**:
1. **AddonMessageThrottle**: Send many broadcasts rapidly
   - `/endeavoring sync broadcast` 10+ times quickly
   - Should see throttle error after ~5-10 messages
2. **NotInGuild**: Leave guild temporarily
   - `/endeavoring sync broadcast`
   - Should see "NotInGuild" error
3. **TargetOffline**: Whisper to offline player (internal sync only)
   - Requires inspecting Lua errors (hard to trigger manually)

**Expected Behavior**:
- Error messages show:
  - Error name (e.g., "AddonMessageThrottle")
  - Error code (numeric)
  - Channel (GUILD, WHISPER, etc.)
  - Message size
  - Target (if WHISPER)

**Pass Criteria**:
- ✅ Errors are clearly reported (not silent)
- ✅ Error messages include full context
- ✅ No Lua stack traces for expected errors
- ✅ Users know what went wrong

---

## Quick Smoke Test (5 Minutes)

If you're short on time, run this minimal test:

1. Load addon on both accounts
2. `/endeavoring sync verbose` on both
3. `/endeavoring alias TestAccount` on each (different names)
4. Log in with 2-3 alts on each account
5. `/endeavoring sync stats` on both
6. **Verify**: Both accounts see each other with correct aliases and character counts

**If this passes**, core sync protocol is working. Extended tests validate edge cases.

---

## Test Results Template

```
Date: 2026-02-07
Tester: <Your Name>
Accounts: 2
Characters: Account A (X chars), Account B (Y chars)

Test 1 (Initial Sync): PASS/FAIL - Notes
Test 2 (Alias Updates): PASS/FAIL - Notes
Test 3 (Alt Swapping): PASS/FAIL - Notes
Test 4 (Compression): PASS/FAIL - Notes
Test 5 (Gossip): PASS/FAIL - Notes
Test 6 (Size Limits): PASS/FAIL - Notes
Test 7 (Roster Update): PASS/FAIL - Notes
Test 8 (Error Codes): PASS/FAIL - Notes

Overall: PASS/FAIL

Issues Found:
- Issue 1: Description
- Issue 2: Description

Observations:
- Compression triggered at X bytes
- Average sync latency: X seconds
- Message sizes: Min X, Max Y, Avg Z bytes
```

---

## Known Limitations (Expected Behavior)

These are **not bugs** - they're documented constraints:

1. **50+ characters will hit size limit**: Working as designed, chunking not yet implemented
2. **Sync requires guild membership**: GUILD channel is primary communication method
3. **No sync between different guilds**: Profile data is guild-scoped
4. **Gossip is session-limited**: Stats reset on reload/relog
5. **No persistence of remote profiles yet**: Lost on UI reload (Phase 3.8 feature)

---

## What to Report

### Critical Issues (Block Testing)
- Lua errors or stack traces
- Addon fails to load
- Messages never sync between accounts
- Errors on every login

### High Priority (Fix Before Guildie Testing)
- Messages consistently exceed 255 bytes
- Compression never triggers
- Alias updates don't propagate
- Character lists don't sync

### Medium Priority (Polish Before Release)
- Verbose output unclear or missing
- Error messages confusing
- Sync takes >15 seconds consistently
- Gossip never triggers

### Low Priority (Nice to Have)
- Stats output formatting
- Command help text clarity
- Verbose mode too noisy
- Minor timing inconsistencies

---

## Next Steps After Testing

Once testing passes:

1. **Document results** using template above
2. **Report any issues** with reproduction steps
3. **Share logs** if errors occur (verbose output + Lua errors)
4. **Proceed to Phase 2 POC**: Build Settings Panel and Leaderboard
5. **Guildie testing** with 5-10 users

Estimated testing time: **30-60 minutes** for full suite, **5 minutes** for smoke test.
