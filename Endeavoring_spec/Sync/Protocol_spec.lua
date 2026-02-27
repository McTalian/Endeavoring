--- Tests for Sync/Protocol.lua
---
--- Covers:
--- - NormalizeKeys forward compatibility (short keys → verbose keys)
--- - Verbose keys pass through unchanged
--- - Mixed/unknown keys are preserved
--- - Integration with OnAddonMessage for each message type

local nsMocks = require("Endeavoring_spec._mocks.nsMocks")

-- Helpers ----------------------------------------------------------------

--- Load Protocol.lua into a fresh namespace and return both
local function SetupProtocol()
	local ns = nsMocks.CreateNS()

	-- Make sender different from "our" BattleTag so messages aren't ignored
	ns.DB.GetMyBattleTag = function() return "TestPlayer#1234" end

	nsMocks.LoadAddonFile("Endeavoring/Sync/Protocol.lua", ns)
	return ns, ns.Protocol
end

--- Simulate receiving an addon message.
--- Stubs MessageCodec.Decode to return the given decoded payload, then
--- calls Protocol.OnAddonMessage with the correct prefix.
--- @param ns table The addon namespace
--- @param decodedPayload table What Decode should return
--- @param sender string|nil Sender name (default "OtherPlayer")
local function SimulateMessage(ns, decodedPayload, sender)
	sender = sender or "OtherPlayer"
	-- Stub Decode to return our crafted payload
	ns.MessageCodec.Decode = function()
		return decodedPayload, nil
	end
	ns.Protocol.OnAddonMessage("Ndvrng", "fake_encoded_data", "GUILD", sender)
end

-- Tests ------------------------------------------------------------------

describe("Protocol", function()

	describe("NormalizeKeys", function()

		describe("MANIFEST with verbose keys", function()
			it("should process a manifest with standard verbose keys", function()
				local ns, Protocol = SetupProtocol()

				-- Manifest from a different player
				local senderBTag = "Neighbor#5678"
				local payload = {
					type = "M",
					battleTag = senderBTag,
					alias = "NeighborAlias",
					charsUpdatedAt = 1700000000,
					aliasUpdatedAt = 1700000000,
				}

				-- The sender is new, so we expect:
				-- 1. UpdateProfileAlias to be called
				-- 2. A REQUEST_CHARS message to be built and sent
				local aliasUpdated = false
				ns.DB.UpdateProfileAlias = function(bt, alias, ts)
					aliasUpdated = true
					assert.are.equal(senderBTag, bt)
					assert.are.equal("NeighborAlias", alias)
					assert.are.equal(1700000000, ts)
					return true
				end

				local requestSent = false
				ns.AddonMessages.BuildMessage = function(msgType, data)
					if msgType == "R" then
						assert.are.equal(senderBTag, data.b)
						requestSent = true
						return "encoded_request"
					end
					return "encoded_message"
				end
				ns.AddonMessages.SendMessage = function() return true end

				SimulateMessage(ns, payload)

				assert.is_true(aliasUpdated, "UpdateProfileAlias should have been called")
				assert.is_true(requestSent, "REQUEST_CHARS should have been sent")
			end)
		end)

		describe("MANIFEST with short keys", function()
			it("should normalize short keys and process a manifest correctly", function()
				local ns, Protocol = SetupProtocol()

				local senderBTag = "Neighbor#5678"
				-- Same manifest but with future short keys
				local payload = {
					t = "M",
					b = senderBTag,
					a = "NeighborAlias",
					cu = 1700000000,
					au = 1700000000,
				}

				local aliasUpdated = false
				ns.DB.UpdateProfileAlias = function(bt, alias, ts)
					aliasUpdated = true
					assert.are.equal(senderBTag, bt)
					assert.are.equal("NeighborAlias", alias)
					assert.are.equal(1700000000, ts)
					return true
				end

				local requestSent = false
				ns.AddonMessages.BuildMessage = function(msgType, data)
					if msgType == "R" then
						assert.are.equal(senderBTag, data.b)
						requestSent = true
						return "encoded_request"
					end
					return "encoded_message"
				end
				ns.AddonMessages.SendMessage = function() return true end

				SimulateMessage(ns, payload)

				assert.is_true(aliasUpdated, "UpdateProfileAlias should have been called with short keys")
				assert.is_true(requestSent, "REQUEST_CHARS should have been sent with short keys")
			end)
		end)

		describe("CHARS_UPDATE with verbose keys", function()
			it("should add characters from verbose-key payload", function()
				local ns, Protocol = SetupProtocol()

				local senderBTag = "Neighbor#5678"
				local payload = {
					type = "C",
					battleTag = senderBTag,
					charsUpdatedAt = 1700000000,
					characters = {
						{ name = "Char1", realm = "Stormrage", addedAt = 1700000000 },
						{ name = "Char2", realm = "Proudmoore", addedAt = 1700000001 },
					},
				}

				local addedChars = nil
				ns.DB.AddCharactersToProfile = function(bt, chars)
					assert.are.equal(senderBTag, bt)
					addedChars = chars
					return true
				end

				local cacheInvalidated = false
				ns.CharacterCache.Invalidate = function(bt)
					assert.are.equal(senderBTag, bt)
					cacheInvalidated = true
				end

				SimulateMessage(ns, payload)

				assert.is_not_nil(addedChars, "AddCharactersToProfile should have been called")
				assert.are.equal(2, #addedChars)
				assert.are.equal("Char1", addedChars[1].name)
				assert.are.equal("Stormrage", addedChars[1].realm)
				assert.are.equal(1700000000, addedChars[1].addedAt)
				assert.are.equal("Char2", addedChars[2].name)
				assert.is_true(cacheInvalidated)
			end)
		end)

		describe("CHARS_UPDATE with short keys", function()
			it("should normalize short keys in both envelope and nested character objects", function()
				local ns, Protocol = SetupProtocol()

				local senderBTag = "Neighbor#5678"
				-- Short keys at every level
				local payload = {
					t = "C",
					b = senderBTag,
					cu = 1700000000,
					c = {
						{ n = "Char1", r = "Stormrage", d = 1700000000 },
						{ n = "Char2", r = "Proudmoore", d = 1700000001 },
					},
				}

				local addedChars = nil
				ns.DB.AddCharactersToProfile = function(bt, chars)
					assert.are.equal(senderBTag, bt)
					addedChars = chars
					return true
				end

				local cacheInvalidated = false
				ns.CharacterCache.Invalidate = function(bt)
					cacheInvalidated = true
				end

				SimulateMessage(ns, payload)

				assert.is_not_nil(addedChars, "AddCharactersToProfile should have been called with short keys")
				assert.are.equal(2, #addedChars)
				assert.are.equal("Char1", addedChars[1].name)
				assert.are.equal("Stormrage", addedChars[1].realm)
				assert.are.equal(1700000000, addedChars[1].addedAt)
				assert.are.equal("Char2", addedChars[2].name)
				assert.are.equal("Proudmoore", addedChars[2].realm)
				assert.is_true(cacheInvalidated)
			end)
		end)

		describe("ALIAS_UPDATE with verbose keys", function()
			it("should update alias from verbose-key payload", function()
				local ns, Protocol = SetupProtocol()

				local senderBTag = "Neighbor#5678"
				local payload = {
					type = "A",
					battleTag = senderBTag,
					alias = "NewAlias",
					aliasUpdatedAt = 1700000100,
				}

				local aliasUpdated = false
				ns.DB.UpdateProfileAlias = function(bt, alias, ts)
					aliasUpdated = true
					assert.are.equal(senderBTag, bt)
					assert.are.equal("NewAlias", alias)
					assert.are.equal(1700000100, ts)
					return true
				end

				SimulateMessage(ns, payload)

				assert.is_true(aliasUpdated, "UpdateProfileAlias should have been called")
			end)
		end)

		describe("ALIAS_UPDATE with short keys", function()
			it("should normalize short keys and update alias", function()
				local ns, Protocol = SetupProtocol()

				local senderBTag = "Neighbor#5678"
				local payload = {
					t = "A",
					b = senderBTag,
					a = "NewAlias",
					au = 1700000100,
				}

				local aliasUpdated = false
				ns.DB.UpdateProfileAlias = function(bt, alias, ts)
					aliasUpdated = true
					assert.are.equal(senderBTag, bt)
					assert.are.equal("NewAlias", alias)
					assert.are.equal(1700000100, ts)
					return true
				end

				SimulateMessage(ns, payload)

				assert.is_true(aliasUpdated, "UpdateProfileAlias should have been called with short keys")
			end)
		end)

		describe("REQUEST_CHARS with verbose keys", function()
			it("should respond with CHARS_UPDATE when requested about us", function()
				local ns, Protocol = SetupProtocol()

				local myBTag = "TestPlayer#1234"
				local payload = {
					type = "R",
					battleTag = myBTag,
					afterTimestamp = 0,
				}

				-- Set up our profile to have characters to send
				ns.DB.GetCharactersAddedAfter = function(afterTs)
					assert.are.equal(0, afterTs)
					return {
						{ name = "MyChar", realm = "Stormrage", addedAt = 1700000000 },
					}
				end

				local charsUpdateSent = false
				ns.Coordinator.SendCharsUpdate = function(bt, chars, ts, channel, target)
					charsUpdateSent = true
					assert.are.equal(myBTag, bt)
					assert.are.equal(1, #chars)
					assert.are.equal("MyChar", chars[1].n)
					return true
				end

				SimulateMessage(ns, payload)

				assert.is_true(charsUpdateSent, "SendCharsUpdate should have been called")
			end)
		end)

		describe("REQUEST_CHARS with short keys", function()
			it("should normalize short keys and respond correctly", function()
				local ns, Protocol = SetupProtocol()

				local myBTag = "TestPlayer#1234"
				local payload = {
					t = "R",
					b = myBTag,
					af = 0,
				}

				ns.DB.GetCharactersAddedAfter = function(afterTs)
					assert.are.equal(0, afterTs)
					return {
						{ name = "MyChar", realm = "Stormrage", addedAt = 1700000000 },
					}
				end

				local charsUpdateSent = false
				ns.Coordinator.SendCharsUpdate = function(bt, chars, ts, channel, target)
					charsUpdateSent = true
					assert.are.equal(myBTag, bt)
					assert.are.equal(1, #chars)
					return true
				end

				SimulateMessage(ns, payload)

				assert.is_true(charsUpdateSent, "SendCharsUpdate should have been called with short keys")
			end)
		end)

		describe("edge cases", function()
			it("should preserve unknown keys that aren't in the short key map", function()
				local ns, Protocol = SetupProtocol()

				-- A MANIFEST with an extra unknown field
				local senderBTag = "Neighbor#5678"
				local payload = {
					type = "M",
					battleTag = senderBTag,
					alias = "Alias",
					charsUpdatedAt = 1700000000,
					aliasUpdatedAt = 1700000000,
					unknownField = "should survive",
				}

				-- We just need it to not error; the unknown field is ignored by handlers
				-- but shouldn't cause a crash
				SimulateMessage(ns, payload)
			end)

			it("should handle numeric table keys (arrays) without mangling them", function()
				local ns, Protocol = SetupProtocol()

				local senderBTag = "Neighbor#5678"
				-- characters is a numerically-indexed array - indices must survive
				local payload = {
					t = "C",
					b = senderBTag,
					cu = 1700000000,
					c = {
						[1] = { n = "Char1", r = "Stormrage", d = 1700000000 },
						[2] = { n = "Char2", r = "Proudmoore", d = 1700000001 },
					},
				}

				local addedChars = nil
				ns.DB.AddCharactersToProfile = function(bt, chars)
					addedChars = chars
					return true
				end

				SimulateMessage(ns, payload)

				assert.is_not_nil(addedChars)
				assert.are.equal(2, #addedChars)
			end)

			it("should handle mixed verbose and short keys in the same message", function()
				local ns, Protocol = SetupProtocol()

				local senderBTag = "Neighbor#5678"
				-- Mix: short 't' for type, verbose 'battleTag', short 'cu'
				local payload = {
					t = "C",
					battleTag = senderBTag,
					cu = 1700000000,
					characters = {
						-- Mix: short 'n' but verbose 'realm'
						{ n = "Char1", realm = "Stormrage", d = 1700000000 },
					},
				}

				local addedChars = nil
				ns.DB.AddCharactersToProfile = function(bt, chars)
					assert.are.equal(senderBTag, bt)
					addedChars = chars
					return true
				end

				SimulateMessage(ns, payload)

				assert.is_not_nil(addedChars, "Mixed keys should work")
				assert.are.equal(1, #addedChars)
				assert.are.equal("Char1", addedChars[1].name)
				assert.are.equal("Stormrage", addedChars[1].realm)
			end)

			it("should reject messages with wrong prefix", function()
				local ns, Protocol = SetupProtocol()

				local called = false
				ns.MessageCodec.Decode = function()
					called = true
					return { type = "M" }, nil
				end

				ns.Protocol.OnAddonMessage("WrongPrefix", "data", "GUILD", "OtherPlayer")

				assert.is_false(called, "Decode should not be called for wrong prefix")
			end)

			it("should reject empty/nil messages", function()
				local ns, Protocol = SetupProtocol()

				-- These should not error
				ns.Protocol.OnAddonMessage("Ndvrng", "", "GUILD", "OtherPlayer")
				ns.Protocol.OnAddonMessage("Ndvrng", nil, "GUILD", "OtherPlayer")
			end)
		end)
	end)
end)
