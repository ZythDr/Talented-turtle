-- Lua 5.0 compatibility: allow "text":format(...) style calls.
do
	local mt = getmetatable("")
	if mt and mt.__index ~= string then
		mt.__index = string
	end
end

-- Lua 5.0 / Vanilla compatibility: add :SetSize where only :SetWidth/:SetHeight
-- exist on widget prototypes.
do
	local function EnsureSetSize(obj)
		if not obj then
			return
		end
		local mt = getmetatable(obj)
		local idx = mt and mt.__index
		if type(idx) == "table" and type(idx.SetSize) ~= "function" then
			idx.SetSize = function(self, w, h)
				if w ~= nil then
					self:SetWidth(w)
				end
				if h ~= nil then
					self:SetHeight(h)
				end
			end
		end
	end

	if type(CreateFrame) == "function" then
		local frame = CreateFrame("Frame")
		EnsureSetSize(frame)
		if frame and frame.CreateTexture then
			EnsureSetSize(frame:CreateTexture())
		end
		if frame and frame.CreateFontString then
			EnsureSetSize(frame:CreateFontString())
		end
		EnsureSetSize(CreateFrame("Button", nil, frame))
		EnsureSetSize(CreateFrame("CheckButton", nil, frame))
	end
end

if not AceLibrary or not AceLibrary:HasInstance("AceAddon-2.0") then
	error("Talented requires Ace2 (AceAddon-2.0).")
end

local Talented = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceConsole-2.0", "AceHook-2.1", "AceDB-2.0")
_G.Talented = Talented

do
	local function DetectAddonFolder()
		if type(GetNumAddOns) == "function" and type(GetAddOnInfo) == "function" then
			local count = GetNumAddOns()
			for i = 1, count do
				local name = GetAddOnInfo(i)
				if name == "Talented-turtle" or name == "Talented" then
					return name
				end
			end
			for i = 1, count do
				local name, title = GetAddOnInfo(i)
				local t = string.lower(tostring(title or ""))
				if string.find(t, "talented", 1, true) then
					return name
				end
			end
		end
		return "Talented-turtle"
	end

	Talented.addonFolder = DetectAddonFolder()
	Talented.textureRoot = "Interface\\AddOns\\" .. Talented.addonFolder .. "\\Textures\\"
	_G.TALENTED_TEXTURE_ROOT = Talented.textureRoot
end

local function TalentedSlashDispatch(msg)
	local addon = _G.Talented
	if addon and type(addon.OnChatCommand) == "function" then
		addon:OnChatCommand(msg)
		return
	end
	if addon and type(addon.ToggleTalentFrame) == "function" then
		addon:ToggleTalentFrame()
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage("Talented: slash command is not ready yet.")
end

SlashCmdList = SlashCmdList or {}
SlashCmdList.TALENTED = TalentedSlashDispatch
SLASH_TALENTED1 = "/talented"
SLASH_TALENTED2 = "/talentd"

local L = setmetatable({}, {__index = function(t, k)
	t[k] = k
	return k
end})
_G.TalentedLocale = L
local TALENTED_WHISPER_PREFIX = "\001TLDCOMM\001"
local TALENTED_TURTLE_WHISPER_PREFIX = "TW_CHAT_MSG_WHISPER"
local TALENTED_TURTLE_COMM_TAG = "TALENTEDCOMM:"
local TALENTED_LFT_COMM_TAG = "TLDLFT:"

function Talented:Serialize(a, b)
	return tostring(a or "") .. "\031" .. tostring(b or "")
end

function Talented:Deserialize(msg)
	local a, b = string.match(msg or "", "^(.-)\031(.*)$")
	if not a then
		return false
	end
	return true, a, b
end

function Talented:RegisterComm(prefix)
	self.commPrefix = prefix or "Talented"
end

function Talented:SendCommMessage(prefix, message, distribution, target)
	-- Vanilla/Turtle: addon whispers are not supported reliably.
	if distribution ~= "WHISPER" or not target or target == "" then
		return
	end

	local commPrefix = prefix or self.commPrefix or "Talented"
	local payload = tostring(message or "")
	local addonSent = nil

	-- Preferred Turtle transport: targeted addon whisper emulation.
	if type(SendAddonMessage) == "function" then
		local addonPrefix = TALENTED_TURTLE_WHISPER_PREFIX .. "<" .. tostring(target) .. ">"
		local addonMessage = TALENTED_TURTLE_COMM_TAG .. tostring(commPrefix) .. "\031" .. payload
		local ok, sent = pcall(SendAddonMessage, addonPrefix, addonMessage, "GUILD")
		if ok and (sent == 1 or sent == true) then
			addonSent = true
		end
	end

	-- Turtle LFT broadcast-style fallback with explicit recipient in payload.
	-- Commonly hidden by users, and already used by many addons on Turtle.
	if addonSent ~= true and type(SendChatMessage) == "function" and type(GetChannelName) == "function" then
		local channelId = GetChannelName("LookingForGroup")
		if not channelId or channelId == 0 then
			channelId = GetChannelName("LFT")
		end
		if channelId and channelId ~= 0 then
			local lftPayload = TALENTED_LFT_COMM_TAG .. string.lower(tostring(target)) .. "\031" .. tostring(commPrefix) .. "\031" .. payload
			local ok = pcall(SendChatMessage, lftPayload, "CHANNEL", nil, channelId)
			if ok then
				addonSent = true
			end
		end
	end

	-- Turtle/Vanilla fallback: emulate direct comm via tagged whisper.
	-- Keep this for robustness when addon channel delivery is unavailable.
	if type(SendChatMessage) == "function" and (addonSent ~= 1 and addonSent ~= true) then
		local whisper = TALENTED_WHISPER_PREFIX .. tostring(commPrefix) .. "\031" .. payload
		pcall(SendChatMessage, whisper, "WHISPER", nil, target)
	end
end

if not string.trim then
	function string.trim(s)
		return string.gsub(string.gsub(s or "", "^%s+", ""), "%s+$", "")
	end
end

if not string.match then
	function string.match(s, pattern, init)
		local _, _, a, b, c, d, e, f, g, h = string.find(s or "", pattern, init)
		return a, b, c, d, e, f, g, h
	end
end

if not wipe then
	function wipe(t)
		for k in pairs(t) do
			t[k] = nil
		end
		return t
	end
end

if not strsplit then
	function strsplit(sep, text)
		local fields = {}
		local start = 1
		local src = tostring(text or "")
		local lensep = string.len(sep or "")
		if lensep == 0 then
			return src
		end
		while true do
			local pos = string.find(src, sep, start, true)
			if not pos then
				fields[table.getn(fields) + 1] = string.sub(src, start)
				break
			end
			fields[table.getn(fields) + 1] = string.sub(src, start, pos - 1)
			start = pos + lensep
		end
		return unpack(fields)
	end
end
local TALENT_SPEC_PRIMARY = _G.TALENT_SPEC_PRIMARY or TALENTS or "Primary"
local TALENT_SPEC_SECONDARY = _G.TALENT_SPEC_SECONDARY or "Secondary"

local RawGetNumTalentTabs = _G.GetNumTalentTabs
local RawGetTalentTabInfo = _G.GetTalentTabInfo
local RawGetTalentInfo = _G.GetTalentInfo
local RawGetTalentPrereqs = _G.GetTalentPrereqs
local RawGetUnspentTalentPoints = _G.GetUnspentTalentPoints
local RawUnitCharacterPoints = _G.UnitCharacterPoints
local RawLearnTalent = _G.LearnTalent
local RawGetSpellInfo = _G.GetSpellInfo
local RawSpellInfo = _G.SpellInfo
local ENABLE_STRICT_SPELLDATA_CHECK = false

local function CompatGetNumTalentTabs(inspect, pet, talentGroup)
	if pet then
		return 0
	end
	local ok, value = pcall(RawGetNumTalentTabs, inspect, pet, talentGroup)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(RawGetNumTalentTabs, inspect)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(RawGetNumTalentTabs)
	if ok and type(value) == "number" then
		return value
	end
	return 0
end

local function CompatGetTalentTabInfo(tab, inspect, pet, talentGroup)
	if pet then
		return nil
	end
	local ok, a, b, c, d, e, f, g, h = pcall(RawGetTalentTabInfo, tab, inspect, pet, talentGroup)
	if ok and a ~= nil then
		return a, b, c, d, e, f, g, h
	end
	ok, a, b, c, d, e, f, g, h = pcall(RawGetTalentTabInfo, tab, inspect)
	if ok and a ~= nil then
		return a, b, c, d, e, f, g, h
	end
	ok, a, b, c, d, e, f, g, h = pcall(RawGetTalentTabInfo, tab)
	if ok then
		return a, b, c, d, e, f, g, h
	end
end

local function CompatGetTalentInfo(tab, index, inspect, pet, talentGroup)
	if pet then
		return nil
	end
	local ok, a, b, c, d, e, f, g, h, i = pcall(RawGetTalentInfo, tab, index, inspect, pet, talentGroup)
	if ok and a ~= nil then
		return a, b, c, d, e, f, g, h, i
	end
	ok, a, b, c, d, e, f, g, h, i = pcall(RawGetTalentInfo, tab, index, inspect)
	if ok and a ~= nil then
		return a, b, c, d, e, f, g, h, i
	end
	ok, a, b, c, d, e, f, g, h, i = pcall(RawGetTalentInfo, tab, index)
	if ok then
		return a, b, c, d, e, f, g, h, i
	end
end

local function CompatGetTalentPrereqs(tab, index)
	if type(RawGetTalentPrereqs) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e = pcall(RawGetTalentPrereqs, tab, index)
	if ok then
		return a, b, c, d, e
	end
end

local function CompatGetNumTalentGroups(inspect)
	return 1
end

local function CompatGetActiveTalentGroup(inspect)
	return 1
end

local function CompatSetActiveTalentGroup(group)
	return
end

local function CompatGetUnspentTalentPoints(inspect, pet, group)
	if pet then
		return 0
	end
	if not inspect and type(RawUnitCharacterPoints) == "function" then
		local ok, value = pcall(RawUnitCharacterPoints, "player")
		if ok and type(value) == "number" then
			return value
		end
	end
	if type(RawGetUnspentTalentPoints) ~= "function" then
		return 0
	end

	-- Prefer native Vanilla-style call first. Some clients accept extended
	-- signatures but return 0 even when unspent points exist.
	local ok, value = pcall(RawGetUnspentTalentPoints)
	if ok and type(value) == "number" then
		return value
	end

	ok, value = pcall(RawGetUnspentTalentPoints, nil, pet, group)
	if ok and type(value) == "number" then
		return value
	end

	if group ~= nil then
		ok, value = pcall(RawGetUnspentTalentPoints, group)
		if ok and type(value) == "number" then
			return value
		end
	end

	return 0
end

local function CompatLearnTalent(tab, index, pet)
	if pet or type(RawLearnTalent) ~= "function" then
		return
	end
	local ok = pcall(RawLearnTalent, tab, index, pet)
	if not ok then
		pcall(RawLearnTalent, tab, index)
	end
end

local SPELL_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
local CompatSpellNameCache = {}
local SpellRecDescCache = {}
local SpellRecDescInProgress = {}
local SpellRecDataCache = {}
local ScoreSpellRecText

local function ToNumber(value)
	if type(value) == "number" then
		return value
	elseif type(value) == "string" then
		return tonumber(value)
	end
	return nil
end

local function GetIndexedValue(value, index)
	if type(value) ~= "table" then
		return nil
	end
	local v = value[index]
	if v == nil then
		v = value[index - 1]
	end
	if v == nil and index == 1 then
		v = value[0]
	end
	return ToNumber(v)
end

local function GetSpellRecData(spell)
	if type(spell) ~= "number" then
		return nil
	end
	local cached = SpellRecDataCache[spell]
	if cached ~= nil then
		return cached or nil
	end
	local getter = _G.GetSpellRec
	if type(getter) ~= "function" then
		SpellRecDataCache[spell] = false
		return nil
	end
	local ok, data = pcall(getter, spell)
	if ok and type(data) == "table" then
		SpellRecDataCache[spell] = data
		return data
	end
	SpellRecDataCache[spell] = false
	return nil
end

local function GetSpellRecScalarNumber(spell, field)
	local getField = _G.GetSpellRecField
	if type(getField) == "function" then
		local ok, value = pcall(getField, spell, field)
		if ok then
			local n = ToNumber(value)
			if n ~= nil then
				return n
			end
			n = GetIndexedValue(value, 1)
			if n ~= nil then
				return n
			end
		end
	end
	local rec = GetSpellRecData(spell)
	if type(rec) == "table" then
		local n = ToNumber(rec[field])
		if n ~= nil then
			return n
		end
		n = GetIndexedValue(rec[field], 1)
		if n ~= nil then
			return n
		end
	end
	return nil
end

local function GetSpellRecArrayNumber(spell, field, index)
	index = tonumber(index) or 1
	if index < 1 then
		index = 1
	end
	local getField = _G.GetSpellRecField
	if type(getField) == "function" then
		local ok, value = pcall(getField, spell, field, index)
		if ok then
			local n = ToNumber(value)
			if n ~= nil then
				return n
			end
			n = GetIndexedValue(value, index)
			if n ~= nil then
				return n
			end
		end
		ok, value = pcall(getField, spell, field)
		if ok then
			local n = GetIndexedValue(value, index)
			if n ~= nil then
				return n
			end
		end
	end
	local rec = GetSpellRecData(spell)
	if type(rec) == "table" then
		return GetIndexedValue(rec[field], index)
	end
	return nil
end

local function GetTemplateTooltipBaselineLevel()
	local level
	local addon = _G.Talented
	if addon and addon.db and addon.db.profile then
		level = tonumber(addon.db.profile.template_tooltip_level)
	end
	if not level and type(UnitLevel) == "function" then
		local playerLevel = UnitLevel("player")
		if type(playerLevel) == "number" and playerLevel > 0 then
			level = playerLevel
		end
	end
	level = tonumber(level) or 60
	if level < 1 then
		level = 1
	elseif level > 60 then
		level = 60
	end
	return level
end

local function RoundNumber(value, digits)
	local mult = math.pow(10, digits or 0)
	if value >= 0 then
		return math.floor(value * mult + 0.5) / mult
	end
	return math.ceil(value * mult - 0.5) / mult
end

local function FormatTokenNumber(value)
	if type(value) ~= "number" then
		return nil
	end
	local rounded = RoundNumber(value, 2)
	local asInt = RoundNumber(rounded, 0)
	if math.abs(rounded - asInt) < 0.0001 then
		return tostring(asInt)
	end
	local oneDecimal = RoundNumber(rounded, 1)
	if math.abs(rounded - oneDecimal) < 0.0001 then
		return tostring(oneDecimal)
	end
	return tostring(rounded)
end

local function RawSpellTextScore(text)
	if type(text) ~= "string" then
		return -1000
	end
	local compact = string.gsub(string.gsub(text, "\r", " "), "%s+", " ")
	compact = string.gsub(compact, "^%s+", "")
	compact = string.gsub(compact, "%s+$", "")
	if compact == "" then
		return -1000
	end
	local score = math.min(string.len(compact), 200)
	local words = 0
	for _ in string.gfind(compact, "%S+") do
		words = words + 1
	end
	if words <= 1 then
		score = score - 120
	elseif words <= 3 then
		score = score - 40
	else
		score = score + 20
	end
	if string.find(compact, "%$") then
		score = score - 5
	end
	local lower = string.lower(compact)
	-- Strongly de-prioritize non-player-facing helper/aura notes that sometimes
	-- collide with real talent spell names/ranks in spell records.
	if string.find(lower, "designer note", 1, true)
		or string.find(lower, "design note", 1, true)
		or string.find(lower, "only purpose of this aura", 1, true)
		or string.find(lower, "mark a player", 1, true) then
		score = score - 800
	end
	return score
end

local function ChooseBestSpellText(primary, secondary)
	local pscore = RawSpellTextScore(primary)
	local sscore = RawSpellTextScore(secondary)
	if sscore > pscore then
		return secondary
	end
	return primary
end

local STANDARD_DURATION_BY_INDEX = {
	[1] = 10,
	[3] = 30,
	[6] = 60,
	[8] = 120,
	[9] = 180,
	[10] = 300,
	[11] = 600,
	[21] = 3,
	[23] = 5,
	[27] = 15
}

local CROSSREF_DURATION_BY_INDEX = {
	[1] = 10,
	[3] = 30,
	[7] = 5,
	[8] = 15,
	[9] = 2,
	[21] = 6,
	[23] = 20,
	[28] = 3,
	[29] = 12,
	[35] = 8,
	[39] = 120
}

local function ParseDurationHintSeconds(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local lower = string.lower(text)
	local value = string.match(lower, "for%s+([%d%.]+)%s+sec")
	if not value then
		value = string.match(lower, "lasts%s+([%d%.]+)%s+sec")
	end
	if not value then
		value = string.match(lower, "duration%s*:?%s*([%d%.]+)%s+sec")
	end
	if not value then
		return nil
	end
	return tonumber(value)
end

local function ResolveSpellDurationSeconds(spell, isCrossRef)
	local duration = GetSpellRecScalarNumber(spell, "duration")
	if type(duration) == "number" then
		if duration > 1000 then
			return duration / 1000
		end
		return duration
	end
	local index = GetSpellRecScalarNumber(spell, "durationIndex")
	if type(index) ~= "number" then
		return nil
	end
	local map = isCrossRef and CROSSREF_DURATION_BY_INDEX or STANDARD_DURATION_BY_INDEX
	local value = map[index] or STANDARD_DURATION_BY_INDEX[index] or CROSSREF_DURATION_BY_INDEX[index]
	if type(value) == "number" then
		return value
	end
	local addon = _G.Talented
	local cache = addon and addon._spellRecIndexCache
	local inferred = cache and cache.durationHints and cache.durationHints[index]
	if type(inferred) == "number" then
		return inferred
	end
	local amp = GetSpellRecArrayNumber(spell, "effectAmplitude", 1)
	if type(amp) == "number" and amp > 0 then
		return amp / 1000
	end
	return nil
end

local function ComputeSpellEffectValue(spell, effectIndex, applyLevelScaling)
	local base = GetSpellRecArrayNumber(spell, "effectBasePoints", effectIndex)
	if base == nil then
		return nil
	end
	local baseValue = base + 1
	if not applyLevelScaling then
		return baseValue
	end
	local perLevel = GetSpellRecArrayNumber(spell, "effectRealPointsPerLevel", effectIndex) or 0
	if perLevel == 0 then
		return baseValue
	end
	local level = GetTemplateTooltipBaselineLevel()
	local spellLevel = GetSpellRecScalarNumber(spell, "spellLevel") or 1
	local baseLevel = GetSpellRecScalarNumber(spell, "baseLevel") or spellLevel
	local maxLevel = GetSpellRecScalarNumber(spell, "maxLevel") or 0
	if level < baseLevel then
		level = baseLevel
	elseif maxLevel > 0 and level > maxLevel then
		level = maxLevel
	end
	local delta = level - baseLevel
	if delta < 0 then
		delta = 0
	end
	return baseValue + perLevel * delta
end

local function ResolveSpellTooltipTokenValue(spell, token, index, isCrossRef)
	local kind = string.lower(token or "")
	local idx = tonumber(index)
	if idx == nil then
		idx = 1
	end
	if idx < 1 then
		idx = 1
	end
	if kind == "s" or kind == "m" or kind == "o" then
		return ComputeSpellEffectValue(spell, idx, not isCrossRef)
	elseif kind == "h" then
		local proc = GetSpellRecScalarNumber(spell, "procChance")
		if type(proc) == "number" and proc > 0 then
			return proc
		end
		return ComputeSpellEffectValue(spell, idx, not isCrossRef)
	elseif kind == "d" then
		return ResolveSpellDurationSeconds(spell, isCrossRef)
	elseif kind == "n" then
		local charges = GetSpellRecScalarNumber(spell, "stackAmount")
		if type(charges) == "number" and charges > 0 then
			return charges
		end
		charges = GetSpellRecScalarNumber(spell, "procCharges")
		if type(charges) == "number" and charges > 0 then
			return charges
		end
		return nil
	elseif kind == "t" then
		local amp = GetSpellRecArrayNumber(spell, "effectAmplitude", idx)
		if type(amp) == "number" and amp > 0 then
			return amp / 1000
		end
	end
	return nil
end

local function ExpandSpellRecTokens(spell, text)
	if type(text) ~= "string" or text == "" then
		return text
	end
	if not string.find(text, "$", 1, true) then
		return text
	end
	text = string.gsub(text, "%$/(%-?%d+);(%d+)([%a])(%d*)", function(divisor, refSpellId, token, index)
		local refId = tonumber(refSpellId)
		if type(refId) ~= "number" then
			return "$/" .. divisor .. ";" .. refSpellId .. token .. index
		end
		local value = ResolveSpellTooltipTokenValue(refId, token, index ~= "" and index or nil, true)
		local div = tonumber(divisor)
		if type(value) == "number" and type(div) == "number" and div ~= 0 then
			return FormatTokenNumber(value / div) or ("$/" .. divisor .. ";" .. refSpellId .. token .. index)
		end
		return "$/" .. divisor .. ";" .. refSpellId .. token .. index
	end)

	text = string.gsub(text, "%$(%d+)([%a])(%d*)", function(refSpellId, token, index)
		local refId = tonumber(refSpellId)
		if type(refId) ~= "number" then
			return "$" .. refSpellId .. token .. index
		end
		local value = ResolveSpellTooltipTokenValue(refId, token, index ~= "" and index or nil, true)
		if type(value) == "number" then
			return FormatTokenNumber(value) or ("$" .. refSpellId .. token .. index)
		end
		return "$" .. refSpellId .. token .. index
	end)

	text = string.gsub(text, "%$/(%-?%d+);([%a])(%d*)", function(divisor, token, index)
		local value = ResolveSpellTooltipTokenValue(spell, token, index ~= "" and index or nil, false)
		local div = tonumber(divisor)
		if type(value) == "number" and type(div) == "number" and div ~= 0 then
			return FormatTokenNumber(value / div) or ("$/" .. divisor .. ";" .. token .. index)
		end
		return "$/" .. divisor .. ";" .. token .. index
	end)

	text = string.gsub(text, "%$([%a])(%d*)", function(token, index)
		local value = ResolveSpellTooltipTokenValue(spell, token, index ~= "" and index or nil, false)
		if type(value) == "number" then
			return FormatTokenNumber(value) or ("$" .. token .. index)
		end
		return "$" .. token .. index
	end)

	return text
end

local function CompatGetSpellNameByID(spell)
	if type(spell) ~= "number" then
		return nil
	end
	local cached = CompatSpellNameCache[spell]
	if cached ~= nil then
		return cached
	end
	local name
	if type(RawSpellInfo) == "function" then
		name = RawSpellInfo(spell)
	end
	CompatSpellNameCache[spell] = name or false
	return name
end

local function CompatGetSpellInfo(spell)
	if type(RawGetSpellInfo) == "function" then
		return RawGetSpellInfo(spell)
	end
	if type(RawSpellInfo) == "function" then
		local name, rank, icon = RawSpellInfo(spell)
		if name then
			return name, rank, icon
		end
	end
	local name = CompatGetSpellNameByID(spell)
	if not name then
		name = "spell-" .. tostring(spell)
	end
	return name, nil, SPELL_ICON_FALLBACK
end

local function GetSpellRecDescription(spell)
	if type(spell) ~= "number" then
		return nil
	end
	local cached = SpellRecDescCache[spell]
	if cached ~= nil then
		return cached or nil
	end
	if SpellRecDescInProgress[spell] then
		return nil
	end
	SpellRecDescInProgress[spell] = true

	local text
	local getField = _G.GetSpellRecField
	if type(getField) ~= "function" then
		SpellRecDescInProgress[spell] = nil
		SpellRecDescCache[spell] = false
		return nil
	end
	local rawTooltip = getField(spell, "tooltip")
	local rawDescription = getField(spell, "description")
	text = ChooseBestSpellText(rawTooltip, rawDescription)
	if type(text) == "string" then
		text = string.gsub(text, "\r", "")
		text = string.gsub(text, "%s+$", "")
		text = ExpandSpellRecTokens(spell, text)
		if text == "" then
			text = nil
		end
	else
		text = nil
	end
	if text then
		local bestText = text
		local bestSpell = spell
		local bestScore = ScoreSpellRecText(bestText)
		if bestScore < 40 then
			local function considerSpell(otherSpell)
				if type(otherSpell) ~= "number" or otherSpell <= 0 or otherSpell == spell then
					return
				end
				local otherText = GetSpellRecDescription(otherSpell)
				local otherScore = ScoreSpellRecText(otherText)
				if otherScore > bestScore + 10 then
					bestText = otherText
					bestSpell = otherSpell
					bestScore = otherScore
				end
			end
			for i = 1, 3 do
				considerSpell(GetSpellRecArrayNumber(spell, "effectTriggerSpell", i))
			end
			considerSpell(GetSpellRecScalarNumber(spell, "modalNextSpell"))
		end
		text = bestText
	end

	SpellRecDescInProgress[spell] = nil
	SpellRecDescCache[spell] = text or false
	return text
end

local GetNumTalentTabs = CompatGetNumTalentTabs
local GetTalentTabInfo = CompatGetTalentTabInfo
local GetTalentInfo = CompatGetTalentInfo
local GetTalentPrereqs = CompatGetTalentPrereqs
local GetNumTalentGroups = CompatGetNumTalentGroups
local GetActiveTalentGroup = CompatGetActiveTalentGroup
local SetActiveTalentGroup = CompatSetActiveTalentGroup
local GetUnspentTalentPoints = CompatGetUnspentTalentPoints
local LearnTalent = CompatLearnTalent

local function SetTextSafe(widget, text)
	if widget and type(widget.SetText) == "function" then
		widget:SetText(tostring(text or ""))
	end
end

local function SafeFormat(fmt, a1, a2, a3, a4, a5, a6, a7, a8)
	if type(fmt) ~= "string" then
		return tostring(fmt or "")
	end
	local ok, msg = pcall(string.format, fmt, a1, a2, a3, a4, a5, a6, a7, a8)
	if ok and type(msg) == "string" then
		return msg
	end
	return fmt
end

local function SetFormattedTextSafe(widget, fmt, a1, a2, a3, a4, a5, a6, a7, a8)
	if not widget then
		return
	end
	if type(widget.SetFormattedText) == "function" then
		widget:SetFormattedText(fmt, a1, a2, a3, a4, a5, a6, a7, a8)
	elseif type(widget.SetText) == "function" then
		widget:SetText(SafeFormat(fmt, a1, a2, a3, a4, a5, a6, a7, a8))
	end
end

local function DeepCopy(value, seen)
	local t = type(value)
	if t ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local out = {}
	seen[value] = out
	for k, v in pairs(value) do
		out[DeepCopy(k, seen)] = DeepCopy(v, seen)
	end
	return out
end

local function SerializeLua(value, indent, seen)
	indent = indent or 0
	seen = seen or {}
	local vtype = type(value)
	if vtype == "number" then
		return tostring(value)
	elseif vtype == "boolean" then
		return value and "true" or "false"
	elseif vtype == "string" then
		return string.format("%q", value)
	elseif vtype ~= "table" then
		return "nil"
	end
	if seen[value] then
		return "nil"
	end
	seen[value] = true
	local nextIndent = indent + 2
	local parts = {"{"}
	local isArray = true
	local maxIndex = 0
	for k in pairs(value) do
		if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
			isArray = false
			break
		end
		if k > maxIndex then
			maxIndex = k
		end
	end
	if isArray then
		for i = 1, maxIndex do
			parts[table.getn(parts) + 1] = string.rep(" ", nextIndent) .. SerializeLua(value[i], nextIndent, seen) .. ","
		end
	else
		for k, v in pairs(value) do
			local key
			if type(k) == "string" and string.find(k, "^[%a_][%w_]*$") then
				key = k
			else
				key = "[" .. SerializeLua(k, nextIndent, seen) .. "]"
			end
			parts[table.getn(parts) + 1] = string.rep(" ", nextIndent) .. key .. " = " .. SerializeLua(v, nextIndent, seen) .. ","
		end
	end
	parts[table.getn(parts) + 1] = string.rep(" ", indent) .. "}"
	seen[value] = nil
	return table.concat(parts, "\n")
end

-------------------------------------------------------------------------------
-- core.lua
-- moved to Modules/Core.lua

local function ResetSpellRecDescCache()
	if type(wipe) == "function" then
		wipe(SpellRecDescCache)
	else
		for k in pairs(SpellRecDescCache) do
			SpellRecDescCache[k] = nil
		end
	end
end

Talented._internals = Talented._internals or {}
Talented._internals.DeepCopy = DeepCopy
Talented._internals.SerializeLua = SerializeLua
Talented._internals.SafeFormat = SafeFormat
Talented._internals.GetUnspentTalentPoints = GetUnspentTalentPoints
Talented._internals.RawSpellTextScore = RawSpellTextScore
Talented._internals.ChooseBestSpellText = ChooseBestSpellText
Talented._internals.ToNumber = ToNumber
Talented._internals.GetSpellRecDescription = GetSpellRecDescription
Talented._internals.TALENTED_WHISPER_PREFIX = TALENTED_WHISPER_PREFIX
Talented._internals.TALENTED_LFT_COMM_TAG = TALENTED_LFT_COMM_TAG
Talented._internals.ResetSpellRecDescCache = ResetSpellRecDescCache

-------------------------------------------------------------------------------
-- spell.lua
-- moved to Modules/Spell.lua

Talented._internals = Talented._internals or {}
Talented._internals.DeepCopy = DeepCopy
Talented._internals.SafeFormat = SafeFormat
Talented._internals.CompatGetSpellInfo = CompatGetSpellInfo
Talented._internals.GetNumTalentTabs = GetNumTalentTabs
Talented._internals.GetTalentTabInfo = GetTalentTabInfo
Talented._internals.GetTalentInfo = GetTalentInfo
Talented._internals.GetTalentPrereqs = GetTalentPrereqs
Talented._internals.GetUnspentTalentPoints = GetUnspentTalentPoints
Talented._internals.ENABLE_STRICT_SPELLDATA_CHECK = ENABLE_STRICT_SPELLDATA_CHECK
Talented._internals.GetSpellRecDescription = GetSpellRecDescription
Talented._internals.SPELL_ICON_FALLBACK = SPELL_ICON_FALLBACK

-------------------------------------------------------------------------------
-- check.lua
-- moved to Modules/Check.lua

-------------------------------------------------------------------------------
-- encode.lua
-- moved to Modules/Encode.lua

-------------------------------------------------------------------------------
-- viewmode.lua
-- moved to Modules/ViewMode.lua


-------------------------------------------------------------------------------
-- view.lua
-- moved to Modules/View.lua

-------------------------------------------------------------------------------
-- editmode.lua
-- moved to Modules/EditMode.lua


-------------------------------------------------------------------------------
-- learn.lua
-- moved to Modules/Learn.lua


-------------------------------------------------------------------------------
-- tips.lua
-- moved to Modules/Tips.lua


-------------------------------------------------------------------------------
-- apply.lua
-- moved to Modules/Apply.lua


-------------------------------------------------------------------------------
-- inspectui.lua
-- moved to Modules/InspectUI.lua
