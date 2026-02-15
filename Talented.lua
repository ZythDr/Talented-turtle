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
	-- Vanilla fallback: addon comm is not guaranteed, so only whisper when available.
	if type(SendAddonMessage) ~= "function" then
		return
	end
	if distribution == "WHISPER" and target and target ~= "" then
		SendAddonMessage(prefix or self.commPrefix or "Talented", tostring(message or ""), "WHISPER", target)
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
local TALENT_SPEC_PET_PRIMARY = _G.TALENT_SPEC_PET_PRIMARY or PET or "Pet"

local RawGetNumTalentTabs = _G.GetNumTalentTabs
local RawGetTalentTabInfo = _G.GetTalentTabInfo
local RawGetTalentInfo = _G.GetTalentInfo
local RawGetTalentPrereqs = _G.GetTalentPrereqs
local RawGetUnspentTalentPoints = _G.GetUnspentTalentPoints
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

local function CompatGetUnspentTalentPoints(_, pet, group)
	if pet then
		return 0
	end
	local ok, value = pcall(RawGetUnspentTalentPoints, nil, pet, group)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(RawGetUnspentTalentPoints)
	if ok and type(value) == "number" then
		return value
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
--

do
	Talented.prev_Print = Talented.Print
	local strformat = string.format
	local function fallback_message(fmt, a1, a2, a3, a4, a5, a6, a7, a8)
		if type(fmt) ~= "string" then
			return tostring(fmt)
		end
		local parts = {fmt}
		local args = {a1, a2, a3, a4, a5, a6, a7, a8}
		for i = 1, table.getn(args) do
			if args[i] ~= nil then
				parts[table.getn(parts) + 1] = tostring(args[i])
			end
		end
		return table.concat(parts, " ")
	end
	function Talented:Print(s, a1, a2, a3, a4, a5, a6, a7, a8)
		if type(s) == "string" and a1 ~= nil then
			local ok, msg = pcall(strformat, s, a1, a2, a3, a4, a5, a6, a7, a8)
			if ok then
				self:prev_Print(msg)
				return
			end
			self:prev_Print(fallback_message(s, a1, a2, a3, a4, a5, a6, a7, a8))
			return
		end
		self:prev_Print(tostring(s))
	end

	function Talented:Debug(a1, a2, a3, a4, a5, a6, a7, a8)
		if not self.db or self.db.profile.debug then
			self:Print(a1, a2, a3, a4, a5, a6, a7, a8)
		end
	end

	function Talented:MakeTarget(targetName)
		local name = self.db.char.targets[targetName]
		local src = name and self:GetTemplatesDB()[name]
		if not src then
			if name then
				self.db.char.targets[targetName] = nil
			end
			return
		end

		local target = self.target
		if not target then
			target = {}
			self.target = target
		end
		self:CopyPackedTemplate(src, target)

		local _, playerClass = UnitClass("player")
		if
			not self:ValidateTemplate(target) or
				(RAID_CLASS_COLORS[target.class] and target.class ~= playerClass) or
				(not RAID_CLASS_COLORS[target.class] and (not self.GetPetClass or target.class ~= self:GetPetClass()))
		 then
			self.db.char.targets[targetName] = nil
			return nil
		end
		target.name = name
		return target
	end

	function Talented:GetMode()
		return self.mode
	end

	function Talented:SetMode(mode)
		if self.mode ~= mode then
			self.mode = mode
			if mode == "apply" then
				self:ApplyCurrentTemplate()
			elseif self.base and self.base.view then
				self.base.view:SetViewMode(mode)
			end
		end
		local cb = self.base and self.base.checkbox
		if cb then
			cb:SetChecked(mode == "edit")
		end
	end

	function Talented:GetGlobalDB()
		local db = self.db
		if type(db) ~= "table" then
			return nil
		end
		local global = rawget(db, "global")
		if type(global) == "table" then
			return global
		end
		local ok, account = pcall(function()
			return db.account
		end)
		if ok and type(account) == "table" then
			return account
		end
		if type(db.raw) == "table" then
			if type(db.raw.account) ~= "table" then
				db.raw.account = {}
			end
			return db.raw.account
		end
		return nil
	end

	function Talented:GetTemplatesDB()
		local global = self:GetGlobalDB()
		if type(global) ~= "table" then
			global = {}
			if self.db and type(self.db.raw) == "table" then
				self.db.raw.account = global
			elseif self.db and type(self.db) == "table" then
				rawset(self.db, "global", global)
			end
		end
		if type(global.templates) ~= "table" then
			global.templates = {}
		end
		return global.templates
	end

	function Talented:ApplyDataOverrides(override, source)
		if type(override) ~= "table" then
			return false
		end
		local spelldata = override.spelldata or override.data
		local tabdata = override.tabdata
		local classCount = 0
		local changed = {}
		if type(spelldata) == "table" then
			for class, data in pairs(spelldata) do
				if type(class) == "string" and type(data) == "table" then
					local copy = DeepCopy(data)
					copy.__source = "override"
					self.spelldata[class] = copy
					changed[class] = true
					classCount = classCount + 1
				end
			end
		end
		if type(tabdata) == "table" then
			for class, tabs in pairs(tabdata) do
				if type(class) == "string" and type(tabs) == "table" then
					self.tabdata[class] = DeepCopy(tabs)
					changed[class] = true
				end
			end
		end
		if classCount > 0 then
			self._liveTalentDataBuilt = self._liveTalentDataBuilt or {}
			local global = self:GetGlobalDB()
			if type(global) == "table" then
				global.dataOverrides = global.dataOverrides or {spelldata = {}, tabdata = {}}
				for class in pairs(changed) do
					if type(self.spelldata[class]) == "table" then
						global.dataOverrides.spelldata[class] = DeepCopy(self.spelldata[class])
					end
					if type(self.tabdata[class]) == "table" then
						global.dataOverrides.tabdata[class] = DeepCopy(self.tabdata[class])
					end
				end
			end
			if type(self.IterateTalentViews) == "function" then
				for _, view in self:IterateTalentViews() do
					if view and changed[view.class] and type(view.SetClass) == "function" then
						view:SetClass(view.class, true)
						if type(view.Update) == "function" then
							view:Update()
						end
					end
				end
			end
			self:Print("Loaded talent data for %d class(es)%s.", classCount, source and (" from " .. tostring(source)) or "")
			return true
		end
		return false
	end

	function Talented:BuildCurrentClassDataOverride()
		local _, class = UnitClass("player")
		if not class then
			return nil
		end
		local data = self:UncompressSpellData(class)
		local tabs = self.tabdata and self.tabdata[class]
		if type(data) ~= "table" or type(tabs) ~= "table" then
			return nil
		end
		return {
			spelldata = {[class] = DeepCopy(data)},
			tabdata = {[class] = DeepCopy(tabs)}
		}, class, self._liveTalentDataBuilt and self._liveTalentDataBuilt[class]
	end

	function Talented:DumpCurrentClassData(filename)
		local override, class, isLive = self:BuildCurrentClassDataOverride()
		if not override then
			self:Print("Unable to build class data dump.")
			return
		end
		local payload = "return " .. SerializeLua(override, 0, {})
		local out = string.trim(filename or "")
		if out == "" then
			out = "Talented_" .. tostring(class) .. "_Data.lua"
		elseif not string.find(out, "%.[%w_%-]+$") then
			out = out .. ".lua"
		end
		if type(_G.ExportFile) == "function" then
			local ok, err = pcall(_G.ExportFile, out, payload)
			if ok then
				self:Print("Exported class data to imports/%s", out)
				if not isLive then
					self:Print("Note: dump used fallback embedded data for %s (live talent API data unavailable).", tostring(class))
				end
			else
				self:Print("Data export failed: %s", tostring(err))
			end
			return
		end
		self:ShowInDialog(payload)
		self:Print("SuperWoW ExportFile() missing; data opened in dialog instead.")
		if not isLive then
			self:Print("Note: dump used fallback embedded data for %s (live talent API data unavailable).", tostring(class))
		end
	end

	function Talented:LoadDataOverrideFromFile(filename)
		local src = string.trim(filename or "")
		if src == "" then
			self:Print("Usage: /talented loaddata <filename>")
			return
		end
		if type(_G.ImportFile) ~= "function" then
			self:Print("ImportFile() is unavailable on this client.")
			return
		end
		local candidates = {src}
		if not string.find(src, "%.[%w_%-]+$") then
			candidates[table.getn(candidates) + 1] = src .. ".lua"
			candidates[table.getn(candidates) + 1] = "Talented_" .. string.upper(src) .. "_Data.lua"
		end
		local text, loadedName
		for _, candidate in ipairs(candidates) do
			local okRead, data = pcall(_G.ImportFile, candidate)
			if okRead and type(data) == "string" and data ~= "" then
				text = data
				loadedName = candidate
				break
			end
		end
		if not text then
			self:Print("Could not read imports/%s", src)
			return
		end
		local loader, err = loadstring(text)
		if not loader then
			self:Print("Invalid data file %s: %s", loadedName or src, tostring(err))
			return
		end
		local okLoad, data = pcall(loader)
		if not okLoad or type(data) ~= "table" then
			self:Print("Data file %s did not return a table.", loadedName or src)
			return
		end
		if self:ApplyDataOverrides(data, loadedName or src) then
			self:UpdateView()
		else
			self:Print("No usable class data found in %s", loadedName or src)
		end
	end

	local STATUS_CLASS_ORDER

	local function ParseRankNumber(text)
		if type(text) ~= "string" then
			return nil
		end
		local value = string.match(text, "(%d+)")
		if not value then
			return nil
		end
		return tonumber(value)
	end

	local function NormalizeIconPath(path)
		if type(path) ~= "string" then
			return nil
		end
		local icon = string.lower(path)
		icon = string.gsub(icon, "/", "\\")
		if string.find(icon, "^interface\\icons\\") then
			icon = string.gsub(icon, "^interface\\icons\\", "")
		end
		return icon
	end

	ScoreSpellRecText = function(text)
		return RawSpellTextScore(text)
	end

	local function BuildSpellRecIndex(maxSpellId)
		local getField = _G.GetSpellRecField
		if type(getField) ~= "function" then
			return nil, 0
		end
		local getIcon = _G.GetSpellIconTexture
		local index = {}
		local scores = {}
		local durationVotes = {}
		local indexed = 0
		local function setBest(key, spellId, score)
			if type(key) ~= "string" or key == "" then
				return
			end
			local prev = scores[key]
			local prevId = index[key]
			if prev == nil or score > prev or (score == prev and (not prevId or spellId < prevId)) then
				index[key] = spellId
				scores[key] = score
			end
		end
			for spellId = 1, maxSpellId do
						local name = getField(spellId, "name")
							if type(name) == "string" and name ~= "" then
								local tipText = getField(spellId, "tooltip")
								local descText = getField(spellId, "description")
								local bestText = ChooseBestSpellText(tipText, descText)
								local durationIndex = ToNumber(getField(spellId, "durationIndex"))
								if durationIndex and durationIndex > 0 then
									local hint = ParseDurationHintSeconds(bestText)
									if type(hint) == "number" and hint > 0 then
										local bucket = durationVotes[durationIndex]
										if not bucket then
											bucket = {}
											durationVotes[durationIndex] = bucket
									end
										local key = tostring(hint)
										bucket[key] = (bucket[key] or 0) + 1
									end
								end
								local score = ScoreSpellRecText(bestText)
							local rank = ParseRankNumber(getField(spellId, "rank")) or 1
						local lowerName = string.lower(name)
						local baseKey = lowerName .. "\031" .. tostring(rank)
						local nameKey = "@n@\031" .. lowerName
						setBest(baseKey, spellId, score)
						setBest(nameKey, spellId, score - math.abs(rank - 1))
						if type(getIcon) == "function" then
							local iconId = getField(spellId, "spellIconID")
							local iconPath = iconId and getIcon(iconId)
							if type(iconPath) == "string" and iconPath ~= "" then
								local lowerIcon = string.lower(iconPath)
								local iconKey = baseKey .. "\031" .. lowerIcon
								setBest(iconKey, spellId, score + 5)
								local iconRankKey = "@ri@\031" .. tostring(rank) .. "\031" .. string.lower(iconPath)
								setBest(iconRankKey, spellId, score + 3)
								local nameIconKey = "@ni@\031" .. lowerName .. "\031" .. lowerIcon
								setBest(nameIconKey, spellId, score + 2 - math.abs(rank - 1))
								local normalized = NormalizeIconPath(iconPath)
								if normalized and normalized ~= "" then
									local normalizedKey = baseKey .. "\031" .. normalized
									setBest(normalizedKey, spellId, score + 5)
									local normalizedRankKey = "@ri@\031" .. tostring(rank) .. "\031" .. normalized
									setBest(normalizedRankKey, spellId, score + 3)
									local normalizedNameIconKey = "@ni@\031" .. lowerName .. "\031" .. normalized
									setBest(normalizedNameIconKey, spellId, score + 2 - math.abs(rank - 1))
								end
							end
						end
						indexed = indexed + 1
						end
				end
			local durationHints = {}
			for durationIndex, bucket in pairs(durationVotes) do
				local bestValue
				local bestCount = -1
				for secValue, count in pairs(bucket) do
					local n = tonumber(secValue)
					if n and (count > bestCount or (count == bestCount and (not bestValue or n < bestValue))) then
						bestValue = n
						bestCount = count
					end
				end
				if bestValue then
					durationHints[durationIndex] = bestValue
				end
			end
			return index, indexed, durationHints
		end

	function Talented:GetSpellRecIndex(maxSpellId)
		maxSpellId = tonumber(maxSpellId) or 80000
		if maxSpellId < 1 then
			maxSpellId = 80000
		end
		local cache = self._spellRecIndexCache
		if cache and cache.maxSpellId and cache.maxSpellId >= maxSpellId and type(cache.index) == "table" then
			return cache.index, cache.indexed or 0
		end
		local index, indexed, durationHints = BuildSpellRecIndex(maxSpellId)
		if type(index) ~= "table" then
			return nil, 0
		end
		self._spellRecIndexCache = {
			index = index,
			indexed = indexed,
			maxSpellId = maxSpellId,
			durationHints = durationHints or {}
		}
		SpellRecDescCache = {}
		return index, indexed
	end

	local function LookupResolvedSpellID(spellIndex, talentName, rank, iconKey)
		if type(spellIndex) ~= "table" or type(talentName) ~= "string" then
			return nil
		end
		local lowerName = string.lower(talentName)
		local baseKey = lowerName .. "\031" .. tostring(rank)
		local resolved
		if iconKey and iconKey ~= "" then
			resolved = spellIndex[baseKey .. "\031" .. iconKey]
			if not resolved then
				resolved = spellIndex["@ri@\031" .. tostring(rank) .. "\031" .. iconKey]
			end
			if not resolved then
				resolved = spellIndex["@ni@\031" .. lowerName .. "\031" .. iconKey]
			end
		end
		if not resolved then
			resolved = spellIndex[baseKey]
		end
		if not resolved then
			resolved = spellIndex["@n@\031" .. lowerName]
		end
		if type(resolved) == "number" then
			return resolved
		end
		return nil
	end

	function Talented:ResolveTalentRankSpellID(class, tab, index, rank, spellIndex)
		local data = self:UncompressSpellData(class)
		local talent = data and data[tab] and data[tab][index]
		if type(talent) ~= "table" or type(talent.name) ~= "string" or type(talent.ranks) ~= "table" then
			return nil
		end
		rank = tonumber(rank) or 1
		if rank < 1 then
			rank = 1
		end
		if rank > table.getn(talent.ranks) then
			return nil
		end
		if not spellIndex then
			spellIndex = self:GetSpellRecIndex()
		end
		if type(spellIndex) ~= "table" then
			return nil
		end
		local iconKey = NormalizeIconPath(talent.icon)
		local resolved = LookupResolvedSpellID(spellIndex, talent.name, rank, iconKey)
		if not resolved then
			local cache = self._spellRecIndexCache
			local currentMax = cache and cache.maxSpellId or 0
			if currentMax < 200000 then
				spellIndex = self:GetSpellRecIndex(200000)
				resolved = LookupResolvedSpellID(spellIndex, talent.name, rank, iconKey)
			end
		end
		if type(resolved) == "number" then
			talent.ranks[rank] = resolved
			return resolved
		end
		return nil
	end

	function Talented:ResolveTemplateSpellIDs(classFilter, maxSpellId)
		if type(_G.GetSpellRecField) ~= "function" then
			self:Print("nampower GetSpellRecField() is unavailable on this client.")
			return
		end
		if classFilter and classFilter ~= "" then
			classFilter = string.upper(classFilter)
		else
			classFilter = nil
		end
		if classFilter then
			local valid
			for _, class in ipairs(STATUS_CLASS_ORDER) do
				if class == classFilter then
					valid = true
					break
				end
			end
			if not valid then
				self:Print("Unknown class '%s'. Expected one of: %s", tostring(classFilter), table.concat(STATUS_CLASS_ORDER, ", "))
				return
			end
		end
		maxSpellId = tonumber(maxSpellId) or 80000
		if maxSpellId < 1 then
			maxSpellId = 80000
		end
		self:Print("Resolving template spell IDs using nampower spell records (scan 1..%d).", maxSpellId)
		local spellIndex, indexed = self:GetSpellRecIndex(maxSpellId)
		if type(spellIndex) ~= "table" then
			self:Print("Could not build spell index from nampower.")
			return
		end
		local changed = {spelldata = {}, tabdata = {}}
		local changedClasses = 0
		local changedTalents = 0
		local changedRanks = 0
		local _, playerClass = UnitClass("player")
		for _, class in ipairs(STATUS_CLASS_ORDER) do
			if (not classFilter or class == classFilter) and class ~= playerClass then
				local data = self:UncompressSpellData(class)
				if type(data) == "table" then
					local classChanged
					for tabIndex, tree in ipairs(data) do
						for talentIndex, talent in ipairs(tree) do
							if type(talent) == "table" and type(talent.name) == "string" and type(talent.ranks) == "table" then
									local talentChanged
									for rankIndex = 1, table.getn(talent.ranks) do
										local current = talent.ranks[rankIndex]
										if type(current) == "number" then
											local spellId = self:ResolveTalentRankSpellID(class, tabIndex, talentIndex, rankIndex, spellIndex)
											if type(spellId) == "number" and spellId ~= current then
												talentChanged = true
												classChanged = true
												changedRanks = changedRanks + 1
											end
										end
									end
								if talentChanged then
									changedTalents = changedTalents + 1
								end
							end
						end
					end
					if classChanged then
						changedClasses = changedClasses + 1
						changed.spelldata[class] = DeepCopy(data)
						if type(self.tabdata[class]) == "table" then
							changed.tabdata[class] = DeepCopy(self.tabdata[class])
						end
					end
				end
			end
		end
		self:Print("Spell index built from %d entries.", indexed)
		self:Print("Resolved %d rank IDs across %d talents in %d class(es).", changedRanks, changedTalents, changedClasses)
			if changedClasses > 0 then
				self:ApplyDataOverrides(changed, "nampower spell-id resolver")
				SpellRecDescCache = {}
				self:UpdateView()
			end
		if changedRanks == 0 then
			self:Print("No ranks were resolved. You may need a higher scan limit: /talented resolveids [CLASS] [MAX_ID]")
		end
	end

	STATUS_CLASS_ORDER = {
		"DRUID",
		"HUNTER",
		"MAGE",
		"PALADIN",
		"PRIEST",
		"ROGUE",
		"SHAMAN",
		"WARLOCK",
		"WARRIOR"
	}

	function Talented:PrintDataStatus()
		local global = self:GetGlobalDB()
		local saved = type(global) == "table" and global.dataOverrides and global.dataOverrides.spelldata
		local runtime = self.spelldata or {}
		local liveBuilt = self._liveTalentDataBuilt or {}
		local savedCount = 0
		for _, class in ipairs(STATUS_CLASS_ORDER) do
			if type(saved) == "table" and type(saved[class]) == "table" then
				savedCount = savedCount + 1
			end
		end
		self:Print("Data status: %d/%d classes have saved overrides.", savedCount, table.getn(STATUS_CLASS_ORDER))
		for _, class in ipairs(STATUS_CLASS_ORDER) do
			local source
			if type(saved) == "table" and type(saved[class]) == "table" then
				source = "override(saved)"
			elseif liveBuilt[class] then
				source = "live(api)"
			else
				local valueType = type(runtime[class])
				if valueType == "table" then
					source = "runtime(table)"
				elseif valueType == "string" then
					source = "embedded(string)"
				else
					source = "missing"
				end
			end
			self:Print("%s: %s", class, source)
		end
	end

	function Talented:DebugTalentSpell(class, tab, index, rank)
		class = type(class) == "string" and string.upper(class) or nil
		tab = tonumber(tab)
		index = tonumber(index)
		rank = tonumber(rank) or 1
		if not class or not tab or not index then
			self:Print("Usage: /talented debugtalent <CLASS> <TAB> <INDEX> [RANK]")
			return
		end
		local data = self:UncompressSpellData(class)
		local talent = data and data[tab] and data[tab][index]
		if type(talent) ~= "table" then
			self:Print("No talent data for %s tab %d index %d", tostring(class), tab, index)
			return
		end
		local maxRank = type(talent.ranks) == "table" and table.getn(talent.ranks) or 0
		if maxRank < 1 then
			self:Print("Talent has no rank data.")
			return
		end
		if rank < 1 then
			rank = 1
		elseif rank > maxRank then
			rank = maxRank
		end
		local raw = talent.ranks[rank]
		local resolved = self:GetTalentSpellID(class, tab, index, rank)
		self:Print("Talent %s [%s %s/%s rank %s/%s] raw=%s resolved=%s", tostring(talent.name or "?"), tostring(class), tostring(tab), tostring(index), tostring(rank), tostring(maxRank), tostring(raw), tostring(resolved))
		if type(_G.GetSpellRecField) == "function" and type(resolved) == "number" then
			local recName = _G.GetSpellRecField(resolved, "name")
			local recRank = _G.GetSpellRecField(resolved, "rank")
			self:Print("SpellRec %d: %s (%s)", resolved, tostring(recName), tostring(recRank))
			local t1 = GetSpellRecArrayNumber(resolved, "effectTriggerSpell", 1)
			local t2 = GetSpellRecArrayNumber(resolved, "effectTriggerSpell", 2)
			local t3 = GetSpellRecArrayNumber(resolved, "effectTriggerSpell", 3)
			self:Print("Triggers: %s, %s, %s", tostring(t1), tostring(t2), tostring(t3))
			local expanded = GetSpellRecDescription(resolved)
			if type(expanded) == "string" and expanded ~= "" then
				self:Print("Expanded: %s", string.sub(expanded, 1, 220))
			end
		end
	end

	function Talented:DebugTalentByName(class, query, rank)
		class = type(class) == "string" and string.upper(class) or nil
		query = string.trim(query or "")
		rank = tonumber(rank) or 1
		if not class or query == "" then
			self:Print("Usage: /talented debugname <CLASS> <TEXT>")
			return
		end
		local data = self:UncompressSpellData(class)
		if type(data) ~= "table" then
			self:Print("No class data for %s", tostring(class))
			return
		end
		local needle = string.lower(query)
		local found = 0
		for tab, tree in ipairs(data) do
			for index, talent in ipairs(tree) do
				local name = talent and talent.name
				if type(name) == "string" and string.find(string.lower(name), needle, 1, true) then
					found = found + 1
					self:DebugTalentSpell(class, tab, index, rank)
				end
			end
		end
		if found == 0 then
			self:Print("No talents matching '%s' in %s", query, class)
		end
	end

	function Talented:OnInitialize()
		self:RegisterDB("TalentedDB")
		self:RegisterDefaults("profile", self.defaults.profile)
		self:RegisterDefaults("account", self.defaults.global)
		self:RegisterDefaults("char", self.defaults.char)
		if self.db and self.db.profile and self.db.profile.hook_inspect_ui == nil then
			self.db.profile.hook_inspect_ui = true
		end
		self:GetTemplatesDB()

		self:UpgradeOptions()
		self:LoadTemplates()
		local global = self:GetGlobalDB()
		if type(global) == "table" and type(global.dataOverrides) == "table" then
			self:ApplyDataOverrides(global.dataOverrides, "saved overrides")
		end
		if type(_G.TalentedDataOverride) == "table" then
			self:ApplyDataOverrides(_G.TalentedDataOverride, "TalentedDataOverride")
		end

		self:RegisterChatCommand({"/talented", "/talentd"}, function(msg)
			self:OnChatCommand(msg)
		end)
		SlashCmdList = SlashCmdList or {}
		SlashCmdList.TALENTED = function(msg)
			self:OnChatCommand(msg)
		end
		SLASH_TALENTED1 = "/talented"
		SLASH_TALENTED2 = "/talentd"
		self:RegisterComm("Talented")
		self:Print("Ace2 vanilla build r20260215-23 loaded")
	end

	function Talented:OnChatCommand(input)
		if not input or string.trim(input) == "" then
			self:ToggleTalentFrame()
		else
			local cmd = string.lower(string.trim(input))
			if cmd == "options" or cmd == "config" then
				self:OpenOptionsFrame()
				return
			elseif cmd == "show" or cmd == "toggle" then
				self:ToggleTalentFrame()
				return
			elseif cmd == "resetpos" then
				if self.db and self.db.profile and self.db.profile.framepos then
					self.db.profile.framepos.TalentedFrame = nil
				end
				if self.base then
					self.base:ClearAllPoints()
					self.base:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
					self:SaveFramePosition(self.base)
				end
				self:Print("Frame position reset.")
				return
			end
				local a, b = string.match(input, "^(%S+)%s*(.*)$")
				a = a and string.lower(a) or ""
					if a == "dumpdata" or a == "dumpclass" then
						self:DumpCurrentClassData(b)
						return
					elseif a == "loaddata" then
						self:LoadDataOverrideFromFile(b)
						return
					elseif a == "datastatus" or a == "status" then
						self:PrintDataStatus()
						return
						elseif a == "resolveids" or a == "resolveid" then
							local arg1, arg2 = string.match(string.trim(b or ""), "^(%S*)%s*(%S*)$")
							local classFilter
							local maxSpellId
						if arg1 and arg1 ~= "" then
							local n = tonumber(arg1)
							if n then
								maxSpellId = n
							else
								classFilter = string.upper(arg1)
							end
						end
						if arg2 and arg2 ~= "" then
							local n = tonumber(arg2)
							if n then
								maxSpellId = n
							end
							end
							self:ResolveTemplateSpellIDs(classFilter, maxSpellId)
							return
						elseif a == "debugtalent" then
							local c, t, i, r = string.match(string.trim(b or ""), "^(%S+)%s+(%d+)%s+(%d+)%s*(%d*)$")
							self:DebugTalentSpell(c, t, i, r ~= "" and r or nil)
							return
						elseif a == "debugname" then
							local c, q = string.match(string.trim(b or ""), "^(%S+)%s+(.+)$")
							self:DebugTalentByName(c, q, 1)
							return
						elseif a == "tooltiplevel" or a == "tooltiplvl" then
							local level = tonumber(string.match(string.trim(b or ""), "^(%d+)$"))
							if not level then
								self:Print("Template tooltip baseline level: %d", GetTemplateTooltipBaselineLevel())
								self:Print("Usage: /talented tooltiplevel <1-60>")
								return
							end
							level = math.floor(level)
							if level < 1 then
								level = 1
							elseif level > 60 then
								level = 60
							end
							self.db.profile.template_tooltip_level = level
							SpellRecDescCache = {}
							self:Print("Template tooltip baseline level set to %d.", level)
							self:UpdateTooltip()
							return
						end
				if a == "apply" and b and b ~= "" then
					local template = self:GetTemplatesDB()[b]
				if template then
					self:SetTemplate(template)
					self:SetMode("apply")
				else
					self:Print(L['Can not apply, unknown template "%s"'], b)
				end
				return
			end
					self:Print("Commands: /talented, /talented show, /talented resetpos, /talented apply <name>, /talented dumpdata [file], /talented loaddata <file>, /talented datastatus, /talented resolveids [CLASS] [MAX_ID], /talented debugtalent <CLASS> <TAB> <INDEX> [RANK], /talented debugname <CLASS> <TEXT>, /talented tooltiplevel <1-60>")
				end
			end

	function Talented:DeleteCurrentTemplate()
		local template = self.template
		if template.talentGroup then return end
		local templates = self:GetTemplatesDB()
		templates[template.name] = nil
		self:SetTemplate()
	end

	function Talented:UpdateTemplateName(template, newname)
		if self:GetTemplatesDB()[newname] or template.talentGroup or type(newname) ~= "string" or newname == "" then return end

		local oldname = template.name
		template.name = newname
		local t = self:GetTemplatesDB()
		t[newname] = template
		t[oldname] = nil
	end

	do
		local function new(templates, name, class)
			local count = 0
			local template = {name = name, class = class}
			while templates[template.name] do
				count = count + 1
				template.name = format(L["%s (%d)"], name, count)
			end
			templates[template.name] = template
			return template
		end

		local function copy(dst, src)
			dst.class = src.class
			if src.code then
				dst.code = src.code
				return
			else
				for tab, tree in ipairs(Talented:UncompressSpellData(src.class)) do
					local s, d = src[tab], {}
					dst[tab] = d
					for index = 1, table.getn(tree) do
						d[index] = s[index]
					end
				end
			end
		end

		function Talented:ImportFromOther(name, src)
			if not self:UncompressSpellData(src.class) then
				return
			end

			local dst = new(self:GetTemplatesDB(), name, src.class)
			copy(dst, src)
			self:OpenTemplate(dst)
			return dst
		end

		function Talented:CopyTemplate(src)
			local dst = new(self:GetTemplatesDB(), format(L["Copy of %s"], src.name), src.class)
			copy(dst, src)
			return dst
		end

			function Talented:CreateEmptyTemplate(class)
				if type(class) == "string" then
					class = string.upper(class)
				end
				if not class then
					local _, playerClass = UnitClass("player")
					class = playerClass
				end
				if not self.spelldata[class] then
					local _, playerClass = UnitClass("player")
					class = playerClass
				end
				local template = new(self:GetTemplatesDB(), L["Empty"], class)

			local info = self:UncompressSpellData(class)

			for tab, tree in ipairs(info) do
				local t = {}
				template[tab] = t
				for index = 1, table.getn(tree) do
					t[index] = 0
				end
			end

			return template
		end

			Talented.importers = {}
			Talented.exporters = {}
			function Talented:ImportTemplate(url)
				local dst, result = new(self:GetTemplatesDB(), L["Imported"])
				for pattern, method in pairs(self.importers) do
					if string.find(url, pattern) then
						result = method(self, url, dst)
						if result then
							break
					end
				end
			end
			if result then
				if not self:ValidateTemplate(dst) then
					self:Print(L["The given template is not a valid one!"])
					self:GetTemplatesDB()[dst.name] = nil
				else
					return dst
				end
			else
				self:Print(L['"%s" does not appear to be a valid URL!'], url)
				self:GetTemplatesDB()[dst.name] = nil
			end
		end
	end

	function Talented:OpenTemplate(template)
		self:UnpackTemplate(template)
		if not self:ValidateTemplate(template, true) then
			local name = template.name
			self:GetTemplatesDB()[name] = nil
			self:Print(L["The template '%s' is no longer valid and has been removed."], name)
			return
		end
		local base = self:CreateBaseFrame()
		if not self.alternates then
			self:UpdatePlayerSpecs()
		end
		self:SetTemplate(template)
		if not base:IsVisible() then
			ShowUIPanel(base)
		end
	end

	function Talented:SetTemplate(template)
		if not template then
			template = assert(self:GetActiveSpec())
		end
		local view = self:CreateBaseFrame().view
		local old = view.template
		if template ~= old then
			if template.talentGroup then
				if not template.pet then
					view:SetTemplate(template, self:MakeTarget(template.talentGroup))
				else
					view:SetTemplate(template, self:MakeTarget(UnitName("PET")))
				end
			else
				view:SetTemplate(template)
			end
			self.template = template
		end
		if not template.talentGroup then
			self.db.profile.last_template = template.name
		end
		self:SetMode(self:GetDefaultMode())
		-- self:UpdateView()
	end

	function Talented:GetDefaultMode()
		return self.db.profile.always_edit and "edit" or "view"
	end

	function Talented:HookTalentFrameToggle()
		if type(IsAddOnLoaded) == "function" and type(LoadAddOn) == "function" and not IsAddOnLoaded("Blizzard_TalentUI") then
			pcall(LoadAddOn, "Blizzard_TalentUI")
		end

		if not self._talentedToggleProxy then
			self._talentedToggleProxy = function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
				return Talented:ToggleTalentFrame(a1, a2, a3, a4, a5, a6, a7, a8, a9)
			end
		end

		if type(_G.ToggleTalentFrame) == "function" and _G.ToggleTalentFrame ~= self._talentedToggleProxy then
			if not self.hooks then
				self.hooks = {}
			end
			if not self.hooks.ToggleTalentFrame then
				self.hooks.ToggleTalentFrame = _G.ToggleTalentFrame
			end
			_G.ToggleTalentFrame = self._talentedToggleProxy
		elseif type(_G.ToggleTalentFrame) ~= "function" then
			_G.ToggleTalentFrame = self._talentedToggleProxy
		end

		if type(_G.ShowUIPanel) == "function" then
			if not self._talentedShowUIPanelOriginal then
				self._talentedShowUIPanelOriginal = _G.ShowUIPanel
			end
			if not self._talentedShowUIPanelProxy then
				self._talentedShowUIPanelProxy = function(frame, a1, a2, a3, a4, a5, a6, a7, a8, a9)
					if frame and _G.TalentFrame and frame == _G.TalentFrame then
						return Talented:ToggleTalentFrame()
					end
					return Talented._talentedShowUIPanelOriginal(frame, a1, a2, a3, a4, a5, a6, a7, a8, a9)
				end
			end
			if _G.ShowUIPanel ~= self._talentedShowUIPanelProxy then
				_G.ShowUIPanel = self._talentedShowUIPanelProxy
			end
		end

		if TalentMicroButton and TalentMicroButton.SetScript then
			TalentMicroButton:SetScript("OnClick", _G.ToggleTalentFrame)
		end

		if TalentFrame and TalentFrame.GetScript and TalentFrame.SetScript and not self._talentFrameOnShowRedirect then
			local prevOnShow = TalentFrame:GetScript("OnShow")
			self._talentFrameOnShowRedirect = true
			TalentFrame:SetScript("OnShow", function()
				if prevOnShow then
					prevOnShow()
				end
				if Talented._openingTalentedFrame then
					return
				end
				if TalentFrame:IsShown() then
					HideUIPanel(TalentFrame)
				end
				Talented:OpenTalentedFrame()
			end)
		end
	end

	function Talented:OnEnable()
		self:HookTalentFrameToggle()
		self:SecureHook("UpdateMicroButtons")
		self:CheckHookInspectUI()

		self:RegisterEvent("ADDON_LOADED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("CHARACTER_POINTS_CHANGED")
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
	end

	function Talented:OnDisable()
		self:UnhookInspectUI()
	end

	function Talented:PLAYER_ENTERING_WORLD()
		self:HookTalentFrameToggle()
		local E = ElvUI and unpack(ElvUI)
		if E then
			-- spec tabs
			E.callbacks:Fire("Talented_SpecTabs")
		end
	end

	function Talented:PLAYER_TALENT_UPDATE()
		self:UpdatePlayerSpecs()
	end

	function Talented:CONFIRM_TALENT_WIPE(cost)
		local dialog = StaticPopup_Show("CONFIRM_TALENT_WIPE")
		if dialog then
			MoneyFrame_Update(dialog:GetName() .. "MoneyFrame", cost)
			self:SetTemplate()
			local frame = self.base
			if not frame or not frame:IsVisible() then
				self:Update()
				ShowUIPanel(self.base)
			end
			dialog:SetFrameLevel(frame:GetFrameLevel() + 5)
		end
	end

	function Talented:CHARACTER_POINTS_CHANGED()
		self:UpdatePlayerSpecs()
		self:UpdateView()
		if self.mode == "apply" then
			self:ApplyTalentPoints()
		end
	end

	function Talented:UpdateMicroButtons()
		local button = TalentMicroButton
		if not button or not button.SetButtonState then
			return
		end
		if self.db.profile.donthide and UnitLevel "player" < button.minLevel then
			button:Enable()
		end
		if self.base and self.base:IsShown() then
			button:SetButtonState("PUSHED", 1)
		else
			button:SetButtonState("NORMAL")
		end
	end

	function Talented:ToggleTalentFrame()
		local frame = self.base
		if TalentFrame and TalentFrame:IsVisible() then
			HideUIPanel(TalentFrame)
		end
		if not frame or not frame:IsVisible() then
			self:OpenTalentedFrame()
		else
			HideUIPanel(frame)
		end
	end

	function Talented:OpenTalentedFrame()
		local frame = self:CreateBaseFrame()
		if type(GetCurrentKeyBoardFocus) == "function" then
			local focus = GetCurrentKeyBoardFocus()
			if focus and focus.ClearFocus then
				focus:ClearFocus()
			end
		end
		local ok, err = pcall(function()
			self:Update()
		end)
		if not ok then
			self:Print("Update error: %s", tostring(err))
		end

		self._openingTalentedFrame = true
		local shown = false
		if type(ShowUIPanel) == "function" then
			local okShow = pcall(ShowUIPanel, frame)
			shown = okShow and frame:IsVisible()
		end
		if not shown then
			frame:Show()
		end
		if frame.SetAlpha then
			frame:SetAlpha(1)
		end
		if frame.SetScale then
			local s = tonumber(frame:GetScale()) or 1
			if s <= 0.01 then
				frame:SetScale(1)
			end
		end
		do
			local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
			local l, r, b, t = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
			if not l or not r or not b or not t or r < 0 or l > sw or t < 0 or b > sh then
				frame:ClearAllPoints()
				frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
				if self.db and self.db.profile and self.db.profile.framepos then
					self:SaveFramePosition(frame)
				end
			end
		end
		if frame.Raise then
			frame:Raise()
		end
		self._openingTalentedFrame = nil
	end

	function Talented:Update()
		self:CreateBaseFrame()
		self:UpdatePlayerSpecs()
		if not self.template then
			self:SetTemplate()
		end
		self:UpdateView()
	end

	function Talented:LoadTemplates()
		local db = self:GetTemplatesDB()
		local invalid = {}
		for name, code in pairs(db) do
			if type(code) == "string" then
				local class = self:GetTemplateStringClass(code)
				if class then
					db[name] = {
						name = name,
						code = code,
						class = class
					}
				else
					db[name] = nil
					invalid[table.getn(invalid) + 1] = name
				end
			elseif not self:ValidateTemplate(code) then
				db[name] = nil
				invalid[table.getn(invalid) + 1] = name
			end
		end
		if next(invalid) then
			table.sort(invalid)
			self:Print(L["The following templates are no longer valid and have been removed:"])
			self:Print(table.concat(invalid, ", "))
		end

			self.OnDatabaseShutdown = function(self)
				local _db = self:GetTemplatesDB()
				for name, template in pairs(_db) do
					template.talentGroup = nil
					Talented:PackTemplate(template)
					if template.code then
						_db[name] = template.code
					end
				end
			end
			self:RegisterEvent("PLAYER_LOGOUT", "OnDatabaseShutdown")
			self.LoadTemplates = nil
		end
	end

-------------------------------------------------------------------------------
-- spell.lua
--

do
	local function split_to_table(src, sep)
		local result = {}
		local start = 1
		local lensep = string.len(sep)
		while true do
			local pos = string.find(src, sep, start, true)
			if not pos then
				result[table.getn(result) + 1] = string.sub(src, start)
				break
			end
			result[table.getn(result) + 1] = string.sub(src, start, pos - 1)
			start = pos + lensep
		end
		return result
	end

	local function handle_ranks(parts)
		local result = {}
		local first = parts[1]
		local pos, row, column, req = 1
		local c = string.byte(first, pos)
		if c == 42 then
			row, column = nil, -1
			pos = pos + 1
			c = string.byte(first, pos)
		elseif c > 32 and c <= 40 then
			column = c - 32
			if column > 4 then
				row = true
				column = column - 4
			end
			pos = pos + 1
			c = string.byte(first, pos)
		end
		if c >= 65 and c <= 90 then
			req = c - 64
			pos = pos + 1
		elseif c >= 97 and c <= 122 then
			req = 96 - c
			pos = pos + 1
		end
		result[1] = tonumber(string.sub(first, pos))
		for i = 2, table.getn(parts) do
			result[i] = tonumber(parts[i])
		end
		local entry = {
			ranks = result,
			row = row,
			column = column,
			req = req
		}
		if not result[1] then
			entry.req = nil
			entry.ranks = nil
			entry.inactive = true
		end
		return entry
	end

	local function next_talent_pos(row, column)
		column = column + 1
		if column >= 5 then
			return row + 1, 1
		else
			return row, column
		end
	end

	local function handle_talents(src)
		local result = {}
		local talents = split_to_table(src, ",")
		for talent = 1, table.getn(talents) do
			result[talent] = handle_ranks(split_to_table(talents[talent], ";"))
		end
		local row, column = 1, 1
		for index, talent in ipairs(result) do
			local drow, dcolumn = talent.row, talent.column
			if dcolumn == -1 then
				talent.row, talent.column = result[index - 1].row, result[index - 1].column
				talent.inactive = true
			elseif dcolumn then
				if drow then
					row = row + 1
					column = dcolumn
				else
					column = column + dcolumn
				end
				talent.row, talent.column = row, column
			else
				talent.row, talent.column = row, column
			end
			if dcolumn ~= -1 or drow then
				row, column = next_talent_pos(row, column)
			end
			if talent.req then
				talent.req = talent.req + index
				assert(talent.req > 0 and talent.req <= table.getn(result))
			end
		end
		return result
	end

	local function handle_tabs(src)
		local result = {}
		local tabs = split_to_table(src, "|")
		for tab = 1, table.getn(tabs) do
			result[tab] = handle_talents(tabs[tab])
		end
		return result
	end

	local function ApplyRuntimeClassOverride(self, class)
		local overrideRoot = _G.TalentedDataOverride
		if type(overrideRoot) ~= "table" then
			return nil
		end
		local sdata = overrideRoot.spelldata and overrideRoot.spelldata[class]
		if type(sdata) ~= "table" then
			return nil
		end
		local copy = DeepCopy(sdata)
		copy.__source = "runtime_override"
		self.spelldata[class] = copy
		local tdata = overrideRoot.tabdata and overrideRoot.tabdata[class]
		if type(tdata) == "table" then
			self.tabdata[class] = DeepCopy(tdata)
		end
		return self.spelldata[class]
	end

	local function BuildLiveClassData(self, class)
		local _, playerClass = UnitClass("player")
		if class ~= playerClass then
			return nil
		end
		if self._liveTalentDataBuilt and self._liveTalentDataBuilt[class] and type(self.spelldata[class]) == "table" then
			return self.spelldata[class]
		end
		local tabs = GetNumTalentTabs()
		if type(tabs) ~= "number" or tabs <= 0 then
			return nil
		end
		local tabdata = self.tabdata[class]
		if type(tabdata) ~= "table" then
			tabdata = {}
			self.tabdata[class] = tabdata
		end
		local data = {}
		for tab = 1, tabs do
			local tabName, _, _, background = GetTalentTabInfo(tab)
			tabdata[tab] = tabdata[tab] or {}
			if tabName then
				tabdata[tab].name = tabName
			end
			if background then
				tabdata[tab].background = background
			end
			local tree = {}
			data[tab] = tree
			local numTalents = GetNumTalents(tab) or 0
			for index = 1, numTalents do
				local name, icon, row, column, _, maxRank = GetTalentInfo(tab, index)
				row = tonumber(row) or 1
				column = tonumber(column) or 1
				if row <= 0 then
					row = row + 1
				end
				if column <= 0 then
					column = column + 1
				end
				maxRank = tonumber(maxRank) or 1
				if maxRank < 1 then
					maxRank = 1
				end
				local ranks = {}
				for r = 1, maxRank do
					ranks[r] = r
				end
				local reqRow, reqColumn = GetTalentPrereqs(tab, index)
				if tonumber(reqRow) and reqRow <= 0 then
					reqRow = reqRow + 1
				end
				if tonumber(reqColumn) and reqColumn <= 0 then
					reqColumn = reqColumn + 1
				end
				tree[index] = {
					row = row,
					column = column,
					ranks = ranks,
					reqRow = tonumber(reqRow),
					reqColumn = tonumber(reqColumn),
					name = name,
					icon = icon
				}
			end
			for index, talent in ipairs(tree) do
				if talent.reqRow and talent.reqColumn then
					for reqIndex, reqTalent in ipairs(tree) do
						if reqTalent.row == talent.reqRow and reqTalent.column == talent.reqColumn then
							talent.req = reqIndex
							break
						end
					end
				end
				talent.reqRow = nil
				talent.reqColumn = nil
			end
		end
		data.__source = "live"
		self.spelldata[class] = data
		self._liveTalentDataBuilt = self._liveTalentDataBuilt or {}
		self._liveTalentDataBuilt[class] = true
		return data
	end

	local WEBDATA_CLASS_KEYS = {
		DRUID = "druid",
		HUNTER = "hunter",
		MAGE = "mage",
		PALADIN = "paladin",
		PRIEST = "priest",
		ROGUE = "rogue",
		SHAMAN = "shaman",
		WARLOCK = "warlock",
		WARRIOR = "warrior"
	}

	local function GetWebDataTalentDesc(class, tab, index, rank)
		local web = _G.tp_webdata
		if type(web) ~= "table" then
			return nil
		end
		local classKey = WEBDATA_CLASS_KEYS[class] or string.lower(tostring(class or ""))
		local classData = web[classKey]
		if type(classData) ~= "table" then
			return nil
		end
		local tree = classData[tab]
		if type(tree) ~= "table" then
			return nil
		end
		local talent = tree[index]
		if type(talent) ~= "table" then
			return nil
		end
		local text = talent[rank]
		if type(text) == "string" and text ~= "" then
			return text
		end
		return nil
	end

	function Talented:UncompressSpellData(class)
		local _, playerClass = UnitClass("player")
		local data = self.spelldata[class]
		if class ~= playerClass and type(data) == "table" and data.__source ~= "embedded" then
			return data
		end
		local live = BuildLiveClassData(self, class)
		if live then
			return live
		end
		data = self.spelldata[class]
		if class ~= playerClass and type(data) ~= "table" then
			local override = ApplyRuntimeClassOverride(self, class)
			if override then
				return override
			end
		end
		data = self.spelldata[class]
		if type(data) == "table" then
			return data
		end
		if type(data) ~= "string" then
			return nil
		end
		self:Debug("UNCOMPRESS CLASSDATA", class)
		data = handle_tabs(data)
		data.__source = "embedded"
		self.spelldata[class] = data
		if ENABLE_STRICT_SPELLDATA_CHECK and class == playerClass then
			self:CheckSpellData(class)
		end
		return data
	end

	local spellTooltip
	local spellLinkTooltip
	local function ParseSpellTooltip(tt)
		local lines = tt:NumLines()
		if not lines or lines < 2 then
			return ""
		end
		local value
		if lines == 2 and not tt.rights[2]:GetText() then
			value = tt.lefts[2]:GetText()
		else
			value = {}
			for i = 2, lines do
				value[i - 1] = {
					left = tt.lefts[i]:GetText(),
					right = tt.rights[i]:GetText()
				}
			end
		end
		return value
	end

	local function CreateSpellLinkTooltip()
		local tt = CreateFrame "GameTooltip"
		local lefts, rights = {}, {}
		for i = 1, 25 do
			local left, right = tt:CreateFontString(), tt:CreateFontString()
			left:SetFontObject(GameFontNormal)
			right:SetFontObject(GameFontNormal)
			tt:AddFontStrings(left, right)
			lefts[i], rights[i] = left, right
		end
		tt.lefts, tt.rights = lefts, rights
		function tt:SetEnchantSpell(spell)
			if type(self.SetHyperlink) ~= "function" then
				return nil
			end
			self:SetOwner(_G.TalentedFrame or UIParent, "ANCHOR_NONE")
			self:ClearLines()
			local ok = pcall(self.SetHyperlink, self, "enchant:" .. tostring(spell))
			if not ok then
				return nil
			end
			return self:NumLines()
		end
		local index
		if _G.CowTip then
			index = function(self, key)
				if not key then
					return ""
				end
				local lines = tt:SetEnchantSpell(key)
				if not lines then
					return ""
				end
				local value = ParseSpellTooltip(tt)
				tt:Hide()
				self[key] = value
				return value
			end
		else
			index = function(self, key)
				if not key then
					return ""
				end
				local lines = tt:SetEnchantSpell(key)
				if not lines then
					return ""
				end
				local value = ParseSpellTooltip(tt)
				self[key] = value
				return value
			end
		end
		Talented.spellLinkDescCache = setmetatable({}, {__index = index})
		CreateSpellLinkTooltip = nil
		return tt
	end

	local function CreateSpellTooltip()
		local tt = CreateFrame "GameTooltip"
		local nativeSetSpell = tt and tt.SetSpell
		local lefts, rights = {}, {}
		for i = 1, 5 do
			local left, right = tt:CreateFontString(), tt:CreateFontString()
			left:SetFontObject(GameFontNormal)
			right:SetFontObject(GameFontNormal)
			tt:AddFontStrings(left, right)
			lefts[i], rights[i] = left, right
		end
		tt.lefts, tt.rights = lefts, rights
		function tt:SetSpell(spell)
			if type(nativeSetSpell) ~= "function" then
				return nil
			end
			self:SetOwner(_G.TalentedFrame or UIParent, "ANCHOR_NONE")
			self:ClearLines()
			local ok = pcall(nativeSetSpell, self, spell)
			if not ok then
				return nil
			end
			return self:NumLines()
		end
		function tt:SetTalentData(tab, index)
			if type(self.SetTalent) ~= "function" then
				return nil
			end
			self:SetOwner(_G.TalentedFrame or UIParent, "ANCHOR_NONE")
			self:ClearLines()
			local ok = pcall(self.SetTalent, self, tab, index)
			if not ok then
				return nil
			end
			return self:NumLines()
		end
		local index
		if _G.CowTip then
			index = function(self, key)
				if not key then
					return ""
				end
				local lines = tt:SetSpell(key)
				if not lines then
					return ""
				end
				local value = ParseSpellTooltip(tt)
				tt:Hide() -- CowTip forces the Tooltip to Show, for some reason
				self[key] = value
				return value
			end
		else
			index = function(self, key)
				if not key then
					return ""
				end
				local lines = tt:SetSpell(key)
				if not lines then
					return ""
				end
				local value = ParseSpellTooltip(tt)
				self[key] = value
				return value
			end
		end
		Talented.spellDescCache = setmetatable({}, {__index = index})
		CreateSpellTooltip = nil
		return tt
	end

	function Talented:GetTalentName(class, tab, index)
		local tree = self:UncompressSpellData(class)
		local talent = tree and tree[tab] and tree[tab][index]
		local spell = talent and talent.ranks and talent.ranks[1]
		local _, playerClass = UnitClass("player")
		if class == playerClass then
			local name = GetTalentInfo(tab, index)
			if name then
				return name
			end
		end
		if talent and talent.name then
			return talent.name
		end
		local name = spell and CompatGetSpellInfo(spell)
		if name and name ~= "" then
			return name
		end
		return string.format("Talent %d/%d", tab or 0, index or 0)
	end

	function Talented:GetTalentIcon(class, tab, index)
		local tree = self:UncompressSpellData(class)
		local talent = tree and tree[tab] and tree[tab][index]
		local spell = talent and talent.ranks and talent.ranks[1]
		local _, playerClass = UnitClass("player")
		if class == playerClass then
			local _, icon = GetTalentInfo(tab, index)
			if icon then
				return icon
			end
		end
		if talent and talent.icon then
			return talent.icon
		end
		local _, _, icon = CompatGetSpellInfo(spell)
		return icon or SPELL_ICON_FALLBACK
	end

		function Talented:GetTalentDesc(class, tab, index, rank, useLiveTalentData)
			if not spellTooltip then
				spellTooltip = CreateSpellTooltip()
			end
			if not spellLinkTooltip then
				spellLinkTooltip = CreateSpellLinkTooltip()
			end
			local _, playerClass = UnitClass("player")
			if useLiveTalentData and class == playerClass then
				local lines = spellTooltip:SetTalentData(tab, index)
				if lines then
					return ParseSpellTooltip(spellTooltip)
				end
			end
			local talent = self:UncompressSpellData(class)[tab][index]
			local spell = self:GetTalentSpellID(class, tab, index, rank)
			if spell and self.spellLinkDescCache then
				local linkDesc = self.spellLinkDescCache[spell]
				if linkDesc and linkDesc ~= "" then
					return linkDesc
				end
			end
			local recDesc = GetSpellRecDescription(spell)
			if recDesc and recDesc ~= "" then
				return recDesc
			end
			local desc = spell and self.spellDescCache[spell]
			if desc and desc ~= "" then
				if not string.find(desc, "%$", 1, true) then
					return desc
				end
			end
			local webDesc = GetWebDataTalentDesc(class, tab, index, rank)
			if webDesc then
				return webDesc
			end
		local talentName = talent and talent.name
		if not talentName or talentName == "" then
			talentName = self:GetTalentName(class, tab, index)
		end
		return SafeFormat("%s (Rank %d)", talentName or "Talent", rank or 1)
	end

	function Talented:GetTalentPos(class, tab, index)
		local talent = self:UncompressSpellData(class)[tab][index]
		return talent.row, talent.column
	end

	function Talented:GetTalentPrereqs(class, tab, index)
		local talent = self:UncompressSpellData(class)[tab][index]
		return talent.req
	end

	function Talented:GetTalentRanks(class, tab, index)
		local talent = self:UncompressSpellData(class)[tab][index]
		return table.getn(talent.ranks)
	end

	local function IsPlaceholderRanks(ranks)
		if type(ranks) ~= "table" then
			return true
		end
		local n = table.getn(ranks)
		if n < 1 then
			return true
		end
		for i = 1, n do
			if ranks[i] ~= i then
				return false
			end
		end
		return true
	end

	function Talented:GetTalentSpellID(class, tab, index, rank)
		local tree = self:UncompressSpellData(class)
		local talent = tree and tree[tab] and tree[tab][index]
		local ranks = talent and talent.ranks
		if type(ranks) ~= "table" then
			return nil
		end
		local maxRank = table.getn(ranks)
		if maxRank < 1 then
			return nil
		end
		if type(rank) ~= "number" or rank < 1 or rank > maxRank then
			rank = 1
		end

		if IsPlaceholderRanks(ranks) then
			local resolved = self:ResolveTalentRankSpellID(class, tab, index, rank)
			if type(resolved) == "number" then
				return resolved
			end
			return nil
		end

		local spell = ranks[rank]
		if type(spell) ~= "number" then
			return nil
		end
		local _, playerClass = UnitClass("player")
		if class ~= playerClass then
			local remapped = self:ResolveTalentRankSpellID(class, tab, index, rank)
			if type(remapped) == "number" then
				spell = remapped
			end
		end
		if spell == rank then
			local resolved = self:ResolveTalentRankSpellID(class, tab, index, rank)
			if type(resolved) == "number" then
				return resolved
			end
			return nil
		end
		return spell
	end

	function Talented:GetTalentLink(template, tab, index, rank)
		rank = rank or (template[tab] and template[tab][index])
		if not rank or rank == 0 then
			rank = 1
		end
		local _, playerClass = UnitClass("player")
		local spell = self:GetTalentSpellID(template.class, tab, index, rank)
		if type(spell) == "number" and CompatGetSpellInfo(spell) then
			return SafeFormat("|cff71d5ff|Hspell:%d|h[%s]|h|r", spell, self:GetTalentName(template.class, tab, index))
		end
		if template.class == playerClass and self._liveTalentDataBuilt and self._liveTalentDataBuilt[playerClass] then
			return SafeFormat("|cff71d5ff[%s]|r", self:GetTalentName(template.class, tab, index))
		end
		return SafeFormat("|cff71d5ff[%s]|r", self:GetTalentName(template.class, tab, index))
	end
end

-------------------------------------------------------------------------------
-- check.lua
--

do
	local function DisableTalented(s, a1, a2, a3, a4, a5, a6, a7, a8)
		if _G.TalentedFrame then
			_G.TalentedFrame:Hide()
		end
		if type(s) == "string" and string.find(s, "%", 1, true) then
			s = SafeFormat(s, a1, a2, a3, a4, a5, a6, a7, a8)
		end
		if not ENABLE_STRICT_SPELLDATA_CHECK then
			if Talented then
				Talented._spellDataIncompatible = true
				Talented:Print("Compatibility warning: %s", tostring(s))
			end
			return
		end
		StaticPopupDialogs.TALENTED_DISABLE = {
			button1 = OKAY,
			text = L["Talented has detected an incompatible change in the talent information that requires an update to Talented. Talented will now Disable itself and reload the user interface so that you can use the default interface."] .. "|n" .. s,
			OnAccept = function()
				DisableAddOn("Talented")
				ReloadUI()
			end,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			interruptCinematic = 1
		}
		StaticPopup_Show("TALENTED_DISABLE")
	end

	function Talented:CheckSpellData(class)
		if self._spellDataIncompatible then
			self.CheckSpellData = nil
			return
		end
		if GetNumTalentTabs() < 1 then return end -- postpone checking without failing
		local spelldata, tabdata = self.spelldata[class], self.tabdata[class]
		local invalid
		if table.getn(spelldata) > GetNumTalentTabs() then
			print("too many tabs", table.getn(spelldata), GetNumTalentTabs())
			invalid = true
			for i = table.getn(spelldata), GetNumTalentTabs() + 1, -1 do
				spelldata[i] = nil
			end
		end
		for tab = 1, GetNumTalentTabs() do
			local talents = spelldata[tab]
			if not talents then
				print("missing talents for tab", tab)
				invalid = true
				talents = {}
				spelldata[tab] = talents
			end
			local tabname, _, _, background = GetTalentTabInfo(tab)
			tabdata[tab].name = tabname -- no need to mark invalid for these
			tabdata[tab].background = background
			if table.getn(talents) > GetNumTalents(tab) then
				print("too many talents for tab", tab)
				invalid = true
				for i = table.getn(talents), GetNumTalents(tab) + 1, -1 do
					talents[i] = nil
				end
			end
			for index = 1, GetNumTalents(tab) do
				local talent = talents[index]
				if not talent then
					return DisableTalented("%s:%d:%d MISSING TALENT", class, tab, index)
				end
				local name, icon, row, column, _, ranks = GetTalentInfo(tab, index)
				if not name then
					if not talent.inactive then
						print("inactive talent", class, tab, index)
						talent.inactive = true
						invalid = true
					end
				else
					if talent.inactive then
						return DisableTalented("%s:%d:%d NOT INACTIVE", class, tab, index)
					end
					local found
						for _, spell in ipairs(talent.ranks) do
							if CompatGetSpellInfo(spell) == name then
								found = true
								break
							end
						end
						if not found then
							local n = CompatGetSpellInfo(talent.ranks[1])
							return DisableTalented("%s:%d:%d MISMATCHED %s ~= %s", class, tab, index, n or "unknown talent-" .. talent.ranks[1], name)
						end
					if row ~= talent.row then
						print("invalid row for talent", tab, index, row, talent.row)
						invalid = true
						talent.row = row
					end
					if column ~= talent.column then
						print("invalid column for talent", tab, index, column, talent.column)
						invalid = true
						talent.column = column
					end
					if ranks > table.getn(talent.ranks) then
						return DisableTalented("%s:%d:%d MISSING RANKS %d ~= %d", class, tab, index, table.getn(talent.ranks), ranks)
					end
					if ranks < table.getn(talent.ranks) then
						invalid = true
						print("too many ranks for talent", tab, index, ranks, talent.ranks)
						for i = table.getn(talent.ranks), ranks + 1, -1 do
							talent.ranks[i] = nil
						end
					end
					local req_row, req_column, _, _, req2 = GetTalentPrereqs(tab, index)
					if req2 then
						print("too many reqs for talent", tab, index, req2)
						invalid = true
					end
					if not req_row then
						if talent.req then
							print("too many req for talent", tab, index)
							invalid = true
							talent.req = nil
						end
					else
						local req = talents[talent.req]
						if not req or req.row ~= req_row or req.column ~= req_column then
							print("invalid req for talent", tab, index, req and req.row, req_row, req and req.column, req_column)
							invalid = true
							-- it requires another pass to get the right talent.
							talent.req = 0
						end
					end
				end
			end
			for index = 1, GetNumTalents(tab) do
				local talent = talents[index]
				if talent.req == 0 then
					local row, column = GetTalentPrereqs(tab, index)
					for j = 1, GetNumTalents(tab) do
						if talents[j].row == row and talents[j].column == column then
							talent.req = j
							break
						end
					end
					assert(talent.req ~= 0)
				end
			end
		end
		if invalid then
			self:Print(L["WARNING: Talented has detected that its talent data is outdated. Talented will work fine for your class for this session but may have issue with other classes. You should update Talented if you can."])
		end
		self.CheckSpellData = nil
	end
end

-------------------------------------------------------------------------------
-- encode.lua
--

do
	local assert, ipairs = assert, ipairs
	local modf = math.modf or function(x)
		return math.floor(tonumber(x) or 0)
	end
	local fmod = math.fmod or math.mod or function(a, b)
		a = tonumber(a) or 0
		b = tonumber(b) or 1
		if b == 0 then
			return 0
		end
		return a - math.floor(a / b) * b
	end

	local stop = "Z"
	local talented_map = "012345abcdefABCDEFmnopqrMNOPQRtuvwxy*"
	local classmap = {
		"DRUID",
		"HUNTER",
		"MAGE",
		"PALADIN",
		"PRIEST",
		"ROGUE",
		"SHAMAN",
		"WARLOCK",
		"WARRIOR"
	}

	function Talented:GetTemplateStringClass(code, nmap)
		nmap = nmap or talented_map
		if string.len(code) <= 0 then return end
		local first = string.find(nmap, string.sub(code, 1, 1), 1, true)
		if not first then
			return
		end
		local index = modf((first - 1) / 3) + 1
		if not index or index > table.getn(classmap) then return end
		return classmap[index]
	end

	local function get_point_string(class, tabs, primary)
		if type(tabs) == "number" then
			return " - |cffffd200" .. tabs .. "|r"
		end
		local start = " - |cffffd200"
		if primary then
			start = start .. Talented.tabdata[class][primary].name .. " "
			tabs[primary] = "|cffffffff" .. tostring(tabs[primary]) .. "|cffffd200"
		end
		return start .. table.concat(tabs, "/", 1, 3) .. "|r"
	end

	local temp_tabcount = {}
		local function GetTemplateStringInfo(code)
		if string.len(code) <= 0 then return end

			local first = string.find(talented_map, string.sub(code, 1, 1), 1, true)
			if not first then
				return
			end
			local index = modf((first - 1) / 3) + 1
			if not index or index > table.getn(classmap) then return end
			local class = classmap[index]
			local talents = Talented:UncompressSpellData(class)
			if not talents then
				return
			end
		local tabs, count, t = 1, 0, 0
		for i = 2, string.len(code) do
			local char = string.sub(code, i, i)
			if char == stop then
				if t >= table.getn(talents[tabs]) then
					temp_tabcount[tabs] = count
					tabs = tabs + 1
					count, t = 0, 0
				end
				temp_tabcount[tabs] = count
				tabs = tabs + 1
				count, t = 0, 0
			else
				index = string.find(talented_map, char, 1, true) - 1
				if not index then
					return
				end
				local b = fmod(index, 6)
				local a = (index - b) / 6
				if t >= table.getn(talents[tabs]) then
					temp_tabcount[tabs] = count
					tabs = tabs + 1
					count, t = 0, 0
				end
				t = t + 2
				count = count + a + b
			end
		end
		if count > 0 then
			temp_tabcount[tabs] = count
		else
			tabs = tabs - 1
		end
		for i = tabs + 1, table.getn(talents) do
			temp_tabcount[i] = 0
		end
		tabs = table.getn(talents)
		if tabs == 1 then
			return get_point_string(class, temp_tabcount[1])
		else -- tab == 3
			local primary, min, max, total = 0, 0, 0, 0
			for i = 1, tabs do
				local points = temp_tabcount[i]
				if points < min then
					min = points
				end
				if points > max then
					primary, max = i, points
				end
				total = total + points
			end
			local middle = total - min - max
			if 3 * (middle - min) >= 2 * (max - min) then
				primary = nil
			end
			return get_point_string(class, temp_tabcount, primary)
		end
	end

	function Talented:GetTemplateInfo(template)
		self:Debug("GET TEMPLATE INFO", template.name)
		if template.code then
			return GetTemplateStringInfo(template.code)
		else
			local tabs = table.getn(template)
			if tabs == 1 then
				return get_point_string(template.class, self:GetPointCount(template))
			else
				local primary, min, max, total = 0, 0, 0, 0
				for i = 1, tabs do
					local points = 0
					for _, value in ipairs(template[i]) do
						points = points + value
					end
					temp_tabcount[i] = points
					if points < min then
						min = points
					end
					if points > max then
						primary, max = i, points
					end
					total = total + points
				end
				local middle = total - min - max
				if 3 * (middle - min) >= 2 * (max - min) then
					primary = nil
				end
				return get_point_string(template.class, temp_tabcount, primary)
			end
		end
	end

		function Talented:StringToTemplate(code, template, nmap)
			nmap = nmap or talented_map
			if type(code) ~= "string" or string.len(code) <= 0 then return end

			local first = string.find(nmap, string.sub(code, 1, 1), 1, true)
			if not first then
				return
			end
			local index = modf((first - 1) / 3) + 1
			if not index or index > table.getn(classmap) then
				return
			end

			local class = classmap[index]
			template = template or {}
			template.class = class
			for i = 1, table.getn(template) do
				template[i] = nil
			end

				local talents = self:UncompressSpellData(class)
				if type(talents) ~= "table" then
					return
				end

			local function tree_size(tree)
				if type(tree) ~= "table" then
					return nil
				end
				return table.getn(tree)
			end
			local function reset_tab(tabIndex)
				local tbl = template[tabIndex]
				if type(tbl) ~= "table" then
					tbl = {}
				else
					wipe(tbl)
				end
				template[tabIndex] = tbl
				return tbl
			end

			local tab = 1
			local t = reset_tab(tab)

			for i = 2, string.len(code) do
				local char = string.sub(code, i, i)
				if char == stop then
					local tree = talents[tab]
					local treeCount = tree_size(tree)
					if not treeCount then
						return
					end
					if table.getn(t) >= treeCount then
						tab = tab + 1
						tree = talents[tab]
						treeCount = tree_size(tree)
						if not treeCount then
							return
						end
						t = reset_tab(tab)
					end
					tab = tab + 1
					if not talents[tab] then
						return
					end
					t = reset_tab(tab)
				else
					local pos = string.find(nmap, char, 1, true)
					if not pos then
						return
					end
					index = pos - 1
					local b = fmod(index, 6)
					local a = (index - b) / 6

					local tree = talents[tab]
					local treeCount = tree_size(tree)
					if not treeCount then
						return
					end
					if table.getn(t) >= treeCount then
						tab = tab + 1
						tree = talents[tab]
						treeCount = tree_size(tree)
						if not treeCount then
							return
						end
						t = reset_tab(tab)
					end
					t[table.getn(t) + 1] = a

					if table.getn(t) < treeCount then
						t[table.getn(t) + 1] = b
					else
						if b ~= 0 then
							return
						end
					end
				end
			end

			if table.getn(template) > table.getn(talents) then
				return
			end
				do
					for tb, tree in ipairs(talents) do
						if type(tree) ~= "table" then
							return
						end
						local _t = template[tb] or {}
						template[tb] = _t
					for i = 1, table.getn(tree) do
					_t[i] = _t[i] or 0
				end
			end
		end

		return template, class
	end

	local function rtrim(s, c)
		local l = string.len(s)
		while l >= 1 and string.sub(s, l, l) == c do
			l = l - 1
		end
		return string.sub(s, 1, l)
	end

	local function get_next_valid_index(tmpl, index, talents)
		if not talents[index] then
			return 0, index
		else
			return tmpl[index], index + 1
		end
	end

	function Talented:TemplateToString(template, nmap)
		nmap = nmap or talented_map

		local class = template.class

		local code, ccode = ""
		do
				for index, c in ipairs(classmap) do
					if c == class then
						local i = (index - 1) * 3 + 1
						ccode = string.sub(nmap, i, i)
						break
					end
				end
			end
			assert(ccode, "invalid class")
			local s = string.sub(nmap, 1, 1)
		local info = self:UncompressSpellData(class)
		for tab, talents in ipairs(info) do
			local tmpl = template[tab]
			local index = 1
			while index <= table.getn(tmpl) do
				local r1, r2
				r1, index = get_next_valid_index(tmpl, index, talents)
				r2, index = get_next_valid_index(tmpl, index, talents)
				local v = r1 * 6 + r2 + 1
				local c = string.sub(nmap, v, v)
				assert(c)
				code = code .. c
			end
			local ncode = rtrim(code, s)
			if ncode ~= code then
				code = ncode .. stop
			end
		end
		local output = ccode .. rtrim(code, stop)

		return output
	end

	function Talented:PackTemplate(template)
		if not template or template.talentGroup or template.code then return end
		self:Debug("PACK TEMPLATE", template.name)
		template.code = self:TemplateToString(template)
		for tab in ipairs(template) do
			template[tab] = nil
		end
	end

	function Talented:UnpackTemplate(template)
		if not template.code then return end
		self:Debug("UNPACK TEMPLATE", template.name)
		local decoded = {}
		local parsed = self:StringToTemplate(template.code, decoded)
		if not parsed or type(decoded.class) ~= "string" then
			return
		end
		for i = 1, table.getn(template) do
			template[i] = nil
		end
		template.class = decoded.class
		for tab, tree in ipairs(decoded) do
			template[tab] = tree
		end
		template.code = nil
		if not RAID_CLASS_COLORS[template.class] then
			self:FixPetTemplate(template)
		end
	end

	function Talented:CopyPackedTemplate(src, dst)
		local packed = src.code
		if packed then
			self:UnpackTemplate(src)
		end
		dst.class = src.class
		for tab, talents in ipairs(src) do
			local d = dst[tab]
			if not d then
				d = {}
				dst[tab] = d
			end
			for index, value in ipairs(talents) do
				d[index] = value
			end
		end
		if packed then
			self:PackTemplate(src)
		end
	end
end

-------------------------------------------------------------------------------
-- viewmode.lua
--

do
	local ipairs = ipairs
	local GetTalentInfo = GetTalentInfo

	function Talented:UpdatePlayerSpecs()
		if GetNumTalentTabs() == 0 then return end
		local _, class = UnitClass("player")
		local info = self:UncompressSpellData(class)
		if not self.alternates then
			self.alternates = {}
		end
		for talentGroup = 1, GetNumTalentGroups() do
			local template = self.alternates[talentGroup]
			if not template then
				template = {
					talentGroup = talentGroup,
					name = talentGroup == 1 and TALENT_SPEC_PRIMARY or TALENT_SPEC_SECONDARY,
					class = class
				}
			else
				template.points = nil
			end
			for tab, tree in ipairs(info) do
				local ttab = template[tab]
				if not ttab then
					ttab = {}
					template[tab] = ttab
				end
				for index = 1, table.getn(tree) do
					local _, _, _, _, rank = GetTalentInfo(tab, index, nil, nil, talentGroup)
					ttab[index] = rank or 0
				end
			end
			self.alternates[talentGroup] = template
			if self.template == template then
				self:UpdateTooltip()
			end
			for _, view in self:IterateTalentViews(template) do
				view:Update()
			end
		end
	end

	function Talented:GetActiveSpec()
		if not self.alternates then
			self:UpdatePlayerSpecs()
		end
		return self.alternates[GetActiveTalentGroup()]
	end

	function Talented:UpdateView()
		if not self.base then return end
		self.base.view:Update()
	end
end

-------------------------------------------------------------------------------
-- view.lua
--

do
	local LAYOUT_BASE_X = 4
	local LAYOUT_BASE_Y = 24

	local LAYOUT_OFFSET_X, LAYOUT_OFFSET_Y, LAYOUT_DELTA_X, LAYOUT_DELTA_Y
	local LAYOUT_SIZE_X

	local function RecalcLayout(offset)
		if LAYOUT_OFFSET_X ~= offset then
			LAYOUT_OFFSET_X = offset
			LAYOUT_OFFSET_Y = LAYOUT_OFFSET_X

			LAYOUT_DELTA_X = LAYOUT_OFFSET_X / 2
			LAYOUT_DELTA_Y = LAYOUT_OFFSET_Y / 2

			LAYOUT_SIZE_X --[[LAYOUT_MAX_COLUMNS]] = 4 * LAYOUT_OFFSET_X + LAYOUT_DELTA_X

			return true
		end
	end

	local function offset(row, column)
		return (column - 1) * LAYOUT_OFFSET_X + LAYOUT_DELTA_X, -((row - 1) * LAYOUT_OFFSET_Y + LAYOUT_DELTA_Y)
	end

	local TalentView = {}
	function TalentView:init(frame, name)
		self.frame = frame
		self.name = name
		self.elements = {}
	end

	local function element_key(a, b, c)
		if c ~= nil then
			return tostring(a) .. "-" .. tostring(b) .. "-" .. tostring(c)
		elseif b ~= nil then
			return tostring(a) .. "-" .. tostring(b)
		end
		return tostring(a)
	end

	function TalentView:SetUIElement(element, a, b, c)
		self.elements[element_key(a, b, c)] = element
	end

	function TalentView:GetUIElement(a, b, c)
		return self.elements[element_key(a, b, c)]
	end

	function TalentView:SetViewMode(mode, force)
		if mode ~= self.mode or force then
			self.mode = mode
			self:Update()
		end
	end

	local function GetMaxPoints(inspect, pet, spec)
		local total = 0
		for i = 1, GetNumTalentTabs(inspect, pet, spec) do
			local _, _, points = GetTalentTabInfo(i, inspect, pet, spec)
			total = total + (points or 0)
		end
		return total + GetUnspentTalentPoints(inspect, pet, spec)
	end

	function TalentView:SetClass(class, force)
		if self.class == class and not force then return end
		local pet = not RAID_CLASS_COLORS[class]
		self.pet = pet

		Talented.Pool:changeSet(self.name)
		wipe(self.elements)
		local talents = Talented:UncompressSpellData(class)
		if not LAYOUT_OFFSET_X then
			RecalcLayout(Talented.db.profile.offset)
		end
		local top_offset, bottom_offset = LAYOUT_BASE_X, LAYOUT_BASE_X
		if self.frame.SetTabSize then
			local n = table.getn(talents)
			self.frame:SetTabSize(n)
			top_offset = top_offset + (4 - n) * LAYOUT_BASE_Y
			if Talented.db.profile.add_bottom_offset then
				bottom_offset = bottom_offset + LAYOUT_BASE_Y
			end
		end
		local first_tree = talents[1]
		local size_y = first_tree[table.getn(first_tree)].row * LAYOUT_OFFSET_Y + LAYOUT_DELTA_Y
		for tab, tree in ipairs(talents) do
			local frame = Talented:MakeTalentFrame(self.frame, LAYOUT_SIZE_X, size_y)
			frame.tab = tab
			frame.view = self
			frame.pet = self.pet

			local background = Talented.tabdata[class][tab].background
			frame.topleft:SetTexture("Interface\\TalentFrame\\" .. background .. "-TopLeft")
			frame.topright:SetTexture("Interface\\TalentFrame\\" .. background .. "-TopRight")
			frame.bottomleft:SetTexture("Interface\\TalentFrame\\" .. background .. "-BottomLeft")
			frame.bottomright:SetTexture("Interface\\TalentFrame\\" .. background .. "-BottomRight")

			self:SetUIElement(frame, tab)

			for index, talent in ipairs(tree) do
				if not talent.inactive then
					local button = Talented:MakeButton(frame)
					button.id = index

					self:SetUIElement(button, tab, index)

					button:SetPoint("TOPLEFT", offset(talent.row, talent.column))
					button.texture:SetTexture(Talented:GetTalentIcon(class, tab, index))
					button:Show()
				end
			end

			for index, talent in ipairs(tree) do
				local req = talent.req
				if req then
					local elements = {}
					Talented.DrawLine(elements, frame, offset, talent.row, talent.column, tree[req].row, tree[req].column)
					self:SetUIElement(elements, tab, index, req)
				end
			end

			frame:SetPoint("TOPLEFT", (tab - 1) * LAYOUT_SIZE_X + LAYOUT_BASE_X, -top_offset)
		end
		self.frame:SetSize(table.getn(talents) * LAYOUT_SIZE_X + LAYOUT_BASE_X * 2, size_y + top_offset + bottom_offset)
		self.frame:SetScale(Talented.db.profile.scale)

		self.class = class
		self:Update()
	end

	function TalentView:SetTemplate(template, target)
		if template then
			Talented:UnpackTemplate(template)
		end
		if target then
			Talented:UnpackTemplate(target)
		end

		local curr = self.target
		self.target = target
		if curr and curr ~= template and curr ~= target then
			Talented:PackTemplate(curr)
		end
		curr = self.template
		self.template = template
		if curr and curr ~= template and curr ~= target then
			Talented:PackTemplate(curr)
		end

		self.spec = template.talentGroup
		self:SetClass(template.class)

		return self:Update()
	end

	function TalentView:ClearTarget()
		if self.target then
			self.target = nil
			self:Update()
		end
	end

	function TalentView:GetReqLevel(total)
		if not self.pet then
			return total == 0 and 1 or total + 9
		else
			if total == 0 then
				return 10
			end
			if total > 16 then
				return 60 + (total - 15) * 4 -- this spec requires Beast Mastery
			else
				return 16 + total * 4
			end
		end
	end

	local GRAY_FONT_COLOR = GRAY_FONT_COLOR
	local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
	local GREEN_FONT_COLOR = GREEN_FONT_COLOR
	local RED_FONT_COLOR = RED_FONT_COLOR
	local LIGHTBLUE_FONT_COLOR = {r = 0.3, g = 0.9, b = 1}
	function TalentView:Update()
		local template, target = self.template, self.target
		local total = 0
		local info = Talented:UncompressSpellData(template.class)
		local at_cap = Talented:IsTemplateAtCap(template)
		for tab, tree in ipairs(info) do
			local count = 0
			local frame = self:GetUIElement(tab)
			for index, talent in ipairs(tree) do
				if not talent.inactive then
					local rank = template[tab][index] or 0
					count = count + rank
					local button = self:GetUIElement(tab, index)
					if button and (not button.texture or not button.slot or not button.rank) then
						self:SetUIElement(nil, tab, index)
						button = nil
					end
					if not button and frame then
						button = Talented:MakeButton(frame)
						if button then
							button.id = index
							self:SetUIElement(button, tab, index)
							button:SetPoint("TOPLEFT", offset(talent.row, talent.column))
							button.texture:SetTexture(Talented:GetTalentIcon(template.class, tab, index))
							button:Show()
						end
					end
						if not button then
							-- 1.12 safety: skip broken widget instead of aborting update.
							local req = talent.req
							if req then
								local reqElements = self:GetUIElement(tab, index, req)
								if reqElements then
									for _, element in ipairs(reqElements) do
										element:Hide()
									end
								end
							end
						else
							local color = GRAY_FONT_COLOR
							local state = Talented:GetTalentState(template, tab, index)
							if state == "empty" and (at_cap or self.mode == "view") then
								state = "unavailable"
							end
							if state == "unavailable" then
								button.texture:SetDesaturated(1)
								button.slot:SetVertexColor(0.65, 0.65, 0.65)
								button.rank:Hide()
								button.rank.texture:Hide()
							else
								button.rank:Show()
								button.rank.texture:Show()
								SetTextSafe(button.rank, rank)
								button.texture:SetDesaturated(0)
								if state == "full" then
									color = NORMAL_FONT_COLOR
								else
									color = GREEN_FONT_COLOR
								end
								button.slot:SetVertexColor(color.r, color.g, color.b)
								button.rank:SetVertexColor(color.r, color.g, color.b)
							end
							local req = talent.req
							if req then
								local ecolor = color
								if ecolor == GREEN_FONT_COLOR then
									if self.mode == "edit" then
										local s = Talented:GetTalentState(template, tab, req)
										if s ~= "full" then
											ecolor = RED_FONT_COLOR
										end
									else
										ecolor = NORMAL_FONT_COLOR
									end
								end
								local reqElements = self:GetUIElement(tab, index, req)
								if reqElements then
									for _, element in ipairs(reqElements) do
										element:SetVertexColor(ecolor.r, ecolor.g, ecolor.b)
									end
								end
							end
							local targetvalue = target and target[tab][index]
							if targetvalue and (targetvalue > 0 or rank > 0) then
								local btarget = Talented:GetButtonTarget(button)
								btarget:Show()
								btarget.texture:Show()
								SetTextSafe(btarget, targetvalue)
								local tcolor
								if rank < targetvalue then
									tcolor = LIGHTBLUE_FONT_COLOR
								elseif rank == targetvalue then
									tcolor = GRAY_FONT_COLOR
								else
									tcolor = RED_FONT_COLOR
								end
								btarget:SetVertexColor(tcolor.r, tcolor.g, tcolor.b)
							elseif button.target then
								button.target:Hide()
								button.target.texture:Hide()
							end
						end
					end
				end
			if frame then
				SetFormattedTextSafe(frame.name, L["%s (%d)"], Talented.tabdata[template.class][tab].name, count)
				total = total + count
				local clear = frame.clear
				if self.mode ~= "edit" or count <= 0 or self.spec then
					clear:Hide()
				else
					clear:Show()
				end
			end
		end
		local maxpoints = GetMaxPoints(nil, self.pet, self.spec)
		local points = self.frame.points
		if points then
			if Talented.db.profile.show_level_req then
				SetFormattedTextSafe(points, L["Level %d"], self:GetReqLevel(total))
			else
				SetFormattedTextSafe(points, L["%d/%d"], total, maxpoints)
			end
			local color
			if total < maxpoints then
				color = GREEN_FONT_COLOR
			elseif total > maxpoints then
				color = RED_FONT_COLOR
			else
				color = NORMAL_FONT_COLOR
			end
			points:SetTextColor(color.r, color.g, color.b)
		end
		local pointsleft = self.frame.pointsleft
		if pointsleft then
			if maxpoints ~= total and template.talentGroup then
				pointsleft:Show()
				SetFormattedTextSafe(pointsleft.text, L["You have %d talent |4point:points; left"], maxpoints - total)
			else
				pointsleft:Hide()
			end
		end
		local edit = self.frame.editname
		if edit then
			if template.talentGroup then
				edit:Hide()
			else
				edit:Show()
				SetTextSafe(edit, template and template.name)
			end
		end
		local cb, activate = self.frame.checkbox, self.frame.bactivate
		if cb then
			if template.talentGroup == GetActiveTalentGroup() or template.pet then
				if activate then
					activate:Hide()
				end
				cb:Show()
				SetTextSafe(cb.label, L["Edit talents"])
				cb.tooltip = L["Toggle editing of talents."]
			elseif template.talentGroup then
				cb:Hide()
				if activate then
					activate.talentGroup = template.talentGroup
					activate:Show()
				end
			else
				if activate then
					activate:Hide()
				end
				cb:Show()
				SetTextSafe(cb.label, L["Edit template"])
				cb.tooltip = L["Toggle edition of the template."]
			end
			cb:SetChecked(self.mode == "edit")
		end
		local targetname = self.frame.targetname
		if targetname then
			if template.pet then
				targetname:Show()
				SetTextSafe(targetname, TALENT_SPEC_PET_PRIMARY)
			elseif template.talentGroup then
				targetname:Show()
				if template.talentGroup == GetActiveTalentGroup() and target then
					SetTextSafe(targetname, string.format(L["Target: %s"], target and target.name or ""))
				elseif template.talentGroup == 1 then
					SetTextSafe(targetname, TALENT_SPEC_PRIMARY)
				else
					SetTextSafe(targetname, TALENT_SPEC_SECONDARY)
				end
			else
				targetname:Hide()
			end
		end
	end

	function TalentView:SetTooltipInfo(owner, tab, index)
		Talented:SetTooltipInfo(owner, self.class, tab, index)
	end

	local function IsChatLinkModifiedClick()
		if type(_G.IsModifiedClick) == "function" then
			return _G.IsModifiedClick("CHATLINK")
		end
		if type(_G.IsShiftKeyDown) == "function" then
			return _G.IsShiftKeyDown()
		end
		return false
	end

	local function GetOpenChatEditBox()
		local edit
		if type(_G.GetCurrentKeyBoardFocus) == "function" then
			edit = _G.GetCurrentKeyBoardFocus()
			if edit and type(edit.GetObjectType) == "function" and edit:GetObjectType() == "EditBox" then
				return edit
			end
		end
		if type(_G.ChatEdit_GetActiveWindow) == "function" then
			edit = _G.ChatEdit_GetActiveWindow()
			if edit and type(edit.IsVisible) == "function" and edit:IsVisible() then
				return edit
			end
		end
		edit = _G.ChatFrameEditBox
		if edit and type(edit.IsVisible) == "function" and edit:IsVisible() then
			return edit
		end
		if type(_G.ChatEdit_GetLastActiveWindow) == "function" then
			edit = _G.ChatEdit_GetLastActiveWindow()
			if edit and type(edit.IsVisible) == "function" and edit:IsVisible() then
				return edit
			end
		end
		return nil
	end

	local function TryInsertNativeTalentLink(tab, index)
		local edit = GetOpenChatEditBox()
		if not edit then
			return false
		end
		if not _G.TalentFrame and type(_G.TalentFrame_LoadUI) == "function" then
			pcall(_G.TalentFrame_LoadUI)
		end
		if not _G.TalentFrame then
			return false
		end
		if type(_G.PanelTemplates_SetTab) == "function" then
			pcall(_G.PanelTemplates_SetTab, _G.TalentFrame, tab)
		end
		if type(_G.TalentFrame_Update) == "function" then
			pcall(_G.TalentFrame_Update)
		end
		local nativeButton = _G["TalentFrameTalent" .. tostring(index)]
		if nativeButton and type(nativeButton.Click) == "function" then
			local ok = pcall(nativeButton.Click, nativeButton)
			if ok then
				return true
			end
		end
		return false
	end

	local function TryInsertLinkInChat(link)
		if type(link) ~= "string" or link == "" then
			return false
		end
		local edit = GetOpenChatEditBox()
		if not edit then
			return false
		end
		if type(_G.ChatEdit_InsertLink) == "function" then
			local ok, inserted = pcall(_G.ChatEdit_InsertLink, link)
			if ok and inserted ~= false then
				return true
			end
		end
		if type(edit.Insert) == "function" then
			local ok = pcall(edit.Insert, edit, link)
			if ok then
				if type(edit.SetFocus) == "function" then
					pcall(edit.SetFocus, edit)
				end
				return true
			end
		end
		if type(edit.GetText) == "function" and type(edit.SetText) == "function" then
			local okGet, current = pcall(edit.GetText, edit)
			if not okGet or type(current) ~= "string" then
				current = ""
			end
			local okSet = pcall(edit.SetText, edit, current .. link)
			if okSet then
				if type(edit.SetFocus) == "function" then
					pcall(edit.SetFocus, edit)
				end
				return true
			end
		end
		return false
	end

	function TalentView:OnTalentClick(button, tab, index)
		if IsChatLinkModifiedClick() then
			local _, playerClass = UnitClass("player")
			if self.template and self.template.class == playerClass and TryInsertNativeTalentLink(tab, index) then
				return
			end
			local link = Talented:GetTalentLink(self.template, tab, index)
			if link then
				if not TryInsertLinkInChat(link) then
					Talented:ShowInDialog(link)
				end
			end
		else
			self:UpdateTalent(tab, index, button == "LeftButton" and 1 or -1)
		end
	end

	function TalentView:UpdateTalent(tab, index, offset)
		if self.mode ~= "edit" then return end
		if self.spec then
			-- Applying talent
			if offset > 0 then
				Talented:LearnTalent(self.template, tab, index)
			end
			return
		end
		local template = self.template

		if offset > 0 and Talented:IsTemplateAtCap(template) then return end
		local s = Talented:GetTalentState(template, tab, index)

		local ranks = Talented:GetTalentRanks(template.class, tab, index)
		local original = template[tab][index]
		local value = original + offset
		if value < 0 or s == "unavailable" then
			value = 0
		elseif value > ranks then
			value = ranks
		end
		Talented:Debug("Updating %d-%d : %d -> %d (%d)", tab, index, original, value, offset)
		if value == original or not Talented:ValidateTalentBranch(template, tab, index, value) then return end
		template[tab][index] = value
		template.points = nil
		for _, view in Talented:IterateTalentViews(template) do
			view:Update()
		end
		local button = self:GetUIElement(tab, index)
		if button then
			Talented:SetTooltipInfo(button, self.class, tab, index)
		else
			Talented:UpdateTooltip()
		end
		return true
	end

	function TalentView:ClearTalentTab(t)
		local template = self.template
		if template and not template.talentGroup then
			local tab = template[t]
			for index, value in ipairs(tab) do
				tab[index] = 0
			end
		end
		for _, view in Talented:IterateTalentViews(template) do
			view:Update()
		end
	end

	Talented.views = {}
	Talented.TalentView = {
		__index = TalentView,
		new = function(self, frame, name)
			local view = setmetatable({}, self)
			view:init(frame, name)
			table.insert(Talented.views, view)
			return view
		end
	}

	local function next_TalentView(views, index)
		index = (index or 0) + 1
		local view = views[index]
		if not view then
			return nil
		else
			return index, view
		end
	end

	function Talented:IterateTalentViews(template)
		local next
		if template then
			next = function(views, index)
				while true do
					index = (index or 0) + 1
					local view = views[index]
					if not view then
						return nil
					elseif view.template == template then
						return index, view
					end
				end
			end
		else
			next = next_TalentView
		end
		return next, self.views
	end

	function Talented:ViewsReLayout(force)
		if RecalcLayout(self.db.profile.offset) or force then
			for _, view in self:IterateTalentViews() do
				view:SetClass(view.class, true)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- editmode.lua
--

do
	local ipairs = ipairs

	function Talented:IsTemplateAtCap(template)
		if not RAID_CLASS_COLORS[template.class] then
			return true
		end
		local max = self.max_talent_points or 51
		return self.db.profile.level_cap and self:GetPointCount(template) >= max
	end

	function Talented:GetPointCount(template)
		local total = 0
		local info = self:UncompressSpellData(template.class)
		if not info then
			return 0
		end
		for tab in ipairs(info) do
			total = total + self:GetTalentTabCount(template, tab)
		end
		return total
	end

	function Talented:GetTalentTabCount(template, tab)
		local total = 0
		for _, value in ipairs(template[tab]) do
			total = total + value
		end
		return total
	end

	function Talented:ClearTalentTab(t)
		local template = self.template
		if template and not template.talentGroup and self.mode == "edit" then
			local tab = template[t]
			for index, value in ipairs(tab) do
				tab[index] = 0
			end
		end
		self:UpdateView()
	end

	function Talented:GetSkillPointsPerTier(class)
		return 5
	end

	function Talented:GetTalentState(template, tab, index)
		local s
		local info = self:UncompressSpellData(template.class)[tab][index]
		local tier = (info.row - 1) * self:GetSkillPointsPerTier(template.class)
		local count = self:GetTalentTabCount(template, tab)

		if count < tier then
			s = false
		else
			s = true
			if info.req and self:GetTalentState(template, tab, info.req) ~= "full" then
				s = false
			end
		end

		if not s or info.inactive then
			s = "unavailable"
		else
			local value = template[tab][index]
			if value == table.getn(info.ranks) then
				s = "full"
			elseif value == 0 then
				s = "empty"
			else
				s = "available"
			end
		end
		return s
	end

	function Talented:ValidateTalentBranch(template, tab, index, newvalue)
		local count = 0
		local pointsPerTier = self:GetSkillPointsPerTier(template.class)
		local tree = self:UncompressSpellData(template.class)[tab]
		local ttab = template[tab]
		for i, talent in ipairs(tree) do
			local value = i == index and newvalue or ttab[i]
			if value > 0 then
				local tier = (talent.row - 1) * pointsPerTier
				if count < tier then
					self:Debug("Update refused because of tier")
					return false
				end
				local r = talent.req
				if r then
					local rvalue = r == index and newvalue or ttab[r]
					if rvalue < table.getn(tree[r].ranks) then
						self:Debug("Update refused because of prereq")
						return false
					end
				end
				count = count + value
			end
		end
		return true
	end

	function Talented:ValidateTemplate(template, fix)
		local class = template.class
		if not class then return end
		local pointsPerTier = self:GetSkillPointsPerTier(template.class)
		local info = self:UncompressSpellData(class)
		if not info then
			return
		end
		local fixed
		for tab, tree in ipairs(info) do
			local t = template[tab]
			if not t then
				return
			end
			local count = 0
			for i, talent in ipairs(tree) do
				local value = t[i]
				if not value then
					return
				end
				if value > 0 then
					if count < (talent.row - 1) * pointsPerTier or value > (talent.inactive and 0 or table.getn(talent.ranks)) then
						if fix then
							t[i], value, fixed = 0, 0, true
						else
							return
						end
					end
					local r = talent.req
					if r then
						if t[r] < table.getn(tree[r].ranks) then
							if fix then
								t[i], value, fixed = 0, 0, true
							else
								return
							end
						end
					end
					count = count + value
				end
			end
		end
		if fixed then
			self:Print(L["The template '%s' had inconsistencies and has been fixed. Please check it before applying."], template.name)
			template.points = nil
		end
		return true
	end
end

-------------------------------------------------------------------------------
-- learn.lua
--

do
	local StaticPopupDialogs = StaticPopupDialogs

	local function ShowDialog(text, tab, index, pet)
		StaticPopupDialogs.TALENTED_CONFIRM_LEARN = {
			button1 = YES,
			button2 = NO,
			OnAccept = function(self)
				LearnTalent(self.talent_tab, self.talent_index, self.is_pet)
			end,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			interruptCinematic = 1
		}
		ShowDialog = function(text, tab, index, pet)
			StaticPopupDialogs.TALENTED_CONFIRM_LEARN.text = text
			local dlg = StaticPopup_Show "TALENTED_CONFIRM_LEARN"
			dlg.talent_tab = tab
			dlg.talent_index = index
			dlg.is_pet = pet
			return dlg
		end
		return ShowDialog(text, tab, index, pet)
	end

	function Talented:LearnTalent(template, tab, index)
		local is_pet = not RAID_CLASS_COLORS[template.class]
		local p = self.db.profile

		if not p.confirmlearn then
			LearnTalent(tab, index, is_pet)
			return
		end

		if not p.always_call_learn_talents then
			local state = self:GetTalentState(template, tab, index)
			if
				state == "full" or -- talent maxed out
					state == "unavailable" or -- prereqs not fullfilled
					GetUnspentTalentPoints(nil, is_pet, GetActiveTalentGroup(nil, is_pet)) == 0
			 then -- no more points
				return
			end
		end

		ShowDialog(SafeFormat(L['Are you sure that you want to learn "%s (%d/%d)" ?'], self:GetTalentName(template.class, tab, index), template[tab][index] + 1, self:GetTalentRanks(template.class, tab, index)), tab, index, is_pet)
	end
end

-------------------------------------------------------------------------------
-- other.lua
--

do
	local function ShowDialog(sender, name, code)
		StaticPopupDialogs.TALENTED_CONFIRM_SHARE_TEMPLATE = {
			button1 = YES,
			button2 = NO,
			text = L['Do you want to add the template "%s" that %s sent you ?'],
			OnAccept = function(self)
				local res, value, class = pcall(Talented.StringToTemplate, Talented, self.code)
				if res then
					Talented:ImportFromOther(self.name, {
						code = self.code,
						class = class
					})
				else
					Talented:Print("Invalid template", value)
				end
			end,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			interruptCinematic = 1
		}
		ShowDialog = function(sender, name, code)
			local dlg = StaticPopup_Show("TALENTED_CONFIRM_SHARE_TEMPLATE", name, sender)
			dlg.name = name
			dlg.code = code
		end
		return ShowDialog(sender, name, code)
	end

	function Talented:OnCommReceived(prefix, message, distribution, sender)
		local status, name, code = self:Deserialize(message)
		if not status then return end

		ShowDialog(sender, name, code)
	end

	function Talented:ExportTemplateToUser(name)
		if not name or string.trim(name) == "" then return end
		local message = self:Serialize(self.template.name, self:TemplateToString(self.template))
		self:SendCommMessage("Talented", message, "WHISPER", name)
	end
end

-------------------------------------------------------------------------------
-- chat.lua
--

do
	local ipairs, format = ipairs, string.format

	function Talented:WriteToChat(text, a1, a2, a3, a4, a5, a6, a7, a8)
		if type(text) == "string" and string.find(text, "%", 1, true) then
			text = SafeFormat(text, a1, a2, a3, a4, a5, a6, a7, a8)
		end
		local edit = ChatEdit_GetLastActiveWindow and ChatEdit_GetLastActiveWindow() or DEFAULT_CHAT_FRAME.editBox
		local type = edit:GetAttribute("chatType")
		local lang = edit.language
		if type == "WHISPER" then
			local target = edit:GetAttribute("tellTarget")
			SendChatMessage(text, type, lang, target)
		elseif type == "CHANNEL" then
			local channel = edit:GetAttribute("channelTarget")
			SendChatMessage(text, type, lang, channel)
		else
			SendChatMessage(text, type, lang)
		end
	end

	local function EnsureUrlDialog()
		local function SetSizeCompat(obj, w, h)
			if not obj then
				return
			end
			if type(obj.SetSize) == "function" then
				obj:SetSize(w, h)
				return
			end
			if w ~= nil and type(obj.SetWidth) == "function" then
				obj:SetWidth(w)
			end
			if h ~= nil and type(obj.SetHeight) == "function" then
				obj:SetHeight(h)
			end
		end

		local frame = _G.TalentedURLDialog
		if frame and frame.editBox then
			return frame
		end

		frame = CreateFrame("Frame", "TalentedURLDialog", UIParent)
		frame:SetFrameStrata("DIALOG")
		frame:SetToplevel(true)
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		frame:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
		end)
		SetSizeCompat(frame, 420, 120)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		frame:SetBackdrop({
			bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			edgeSize = 16,
			tileSize = 32,
			insets = {left = 5, right = 5, top = 5, bottom = 5}
		})

		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", frame, "TOP", 0, -12)
		title:SetText(L["URL:"])

		local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		edit:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
		edit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -34)
		edit:SetHeight(20)
		edit:SetAutoFocus(false)
		edit:SetScript("OnEscapePressed", function(self)
			local widget = self or _G.this
			local parent = widget and widget.GetParent and widget:GetParent()
			if parent and parent.Hide then
				parent:Hide()
			end
		end)
		edit:SetScript("OnEnterPressed", function(self)
			local widget = self or _G.this
			if widget and widget.HighlightText then
				widget:HighlightText()
			end
		end)
		frame.editBox = edit

		local okay = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		SetSizeCompat(okay, 110, 22)
		okay:SetText(OKAY or "Okay")
		okay:SetPoint("TOP", edit, "BOTTOM", 0, -10)
		okay:SetScript("OnClick", function(self)
			local widget = self or _G.this
			local parent = widget and widget.GetParent and widget:GetParent()
			if parent and parent.Hide then
				parent:Hide()
			end
		end)

		UISpecialFrames[table.getn(UISpecialFrames) + 1] = "TalentedURLDialog"
		return frame
	end

	function Talented:ShowInDialog(text, a1, a2, a3, a4, a5, a6, a7, a8)
		if type(text) == "string" and string.find(text, "%", 1, true) then
			text = SafeFormat(text, a1, a2, a3, a4, a5, a6, a7, a8)
		end
		local dialog = EnsureUrlDialog()
		local edit = dialog and dialog.editBox
		if not edit then
			self:Print(text)
			return
		end
		dialog:Show()
		if type(dialog.Raise) == "function" then
			dialog:Raise()
		end
		SetTextSafe(edit, text)
		if type(edit.HighlightText) == "function" then
			edit:HighlightText()
		end
		if type(edit.SetFocus) == "function" then
			edit:SetFocus()
		end
	end
	end

-------------------------------------------------------------------------------
-- tips.lua
--

do
	local type = type
	local ipairs = ipairs
	local GameTooltip = GameTooltip
	local IsAltKeyDown = IsAltKeyDown
	local GREEN_FONT_COLOR = GREEN_FONT_COLOR
	local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
	local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
	local RED_FONT_COLOR = RED_FONT_COLOR

	local function addline(line, color, split)
		GameTooltip:AddLine(line, color.r, color.g, color.b, split)
	end

	local function TrySetNativeSpellTooltip(tooltip, spell)
		if type(spell) ~= "number" then
			return false
		end
		if type(tooltip.SetSpell) ~= "function" then
			if type(tooltip.SetHyperlink) == "function" and _G.SUPERWOW_VERSION then
				tooltip:ClearLines()
				local okEnchant = pcall(tooltip.SetHyperlink, tooltip, "enchant:" .. tostring(spell))
				return okEnchant and (tooltip:NumLines() or 0) > 0 or false
			end
			return false
		end
		tooltip:ClearLines()
		local ok = pcall(tooltip.SetSpell, tooltip, spell)
		if ok and (tooltip:NumLines() or 0) > 0 then
			return true
		end
		if type(tooltip.SetHyperlink) == "function" and _G.SUPERWOW_VERSION then
			tooltip:ClearLines()
			local okEnchant = pcall(tooltip.SetHyperlink, tooltip, "enchant:" .. tostring(spell))
			if okEnchant and (tooltip:NumLines() or 0) > 0 then
				return true
			end
		end
		return false
	end

		local function addtipline(tip)
			local color = HIGHLIGHT_FONT_COLOR
			tip = tip or ""
			if type(tip) == "string" then
				addline(tip, NORMAL_FONT_COLOR, true)
			else
				for _, i in ipairs(tip) do
					if (_ == table.getn(tip)) then
						color = NORMAL_FONT_COLOR
					end
					local left = i and i.left or ""
					local right = i and i.right or ""
					if right and right ~= "" then
						if left and left ~= "" then
							addline(left .. " " .. right, color, true)
						else
							addline(right, color, true)
						end
					else
						addline(left, color, true)
					end
				end
			end
		end

	local lastTooltipInfo = {}
	local function TooltipIsOwnedByFrame(frame)
		if not frame or type(GameTooltip.IsOwned) ~= "function" then
			return false
		end
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, frame)
		return ok and owned
	end

	local function IsValidTooltipFrame(frame)
		if not frame then
			return false
		end
		if type(frame.GetParent) ~= "function" then
			return false
		end
		local parent = frame:GetParent()
		if not parent or type(parent.view) ~= "table" then
			return false
		end
		return true
	end

		function Talented:SetTooltipInfo(frame, class, tab, index)
		if not IsValidTooltipFrame(frame) then
			wipe(lastTooltipInfo)
			if GameTooltip:IsShown() then
				GameTooltip:Hide()
			end
			return
		end
			lastTooltipInfo[1] = frame
			lastTooltipInfo[2] = class
			lastTooltipInfo[3] = tab
			lastTooltipInfo[4] = index
				if not TooltipIsOwnedByFrame(frame) then
					local ok = pcall(GameTooltip.SetOwner, GameTooltip, frame, "ANCHOR_RIGHT")
					if not ok then
						wipe(lastTooltipInfo)
						return
					end
				end

			GameTooltip:ClearLines()
				local template = frame:GetParent().view.template
				self:UnpackTemplate(template)
				local rank = template[tab][index]
				local _, playerClass = UnitClass("player")
				local usingDefaultTooltip = false
				local allowNativeTooltip = (class == playerClass and template and template.talentGroup and not IsAltKeyDown())
				if allowNativeTooltip and type(GameTooltip.SetTalent) == "function" then
					local ok = pcall(GameTooltip.SetTalent, GameTooltip, tab, index)
					if ok and (GameTooltip:NumLines() or 0) > 0 then
						usingDefaultTooltip = true
					else
						GameTooltip:ClearLines()
					end
				end

				if not usingDefaultTooltip and allowNativeTooltip then
					local spell = self:GetTalentSpellID(class, tab, index, rank > 0 and rank or 1)
					if TrySetNativeSpellTooltip(GameTooltip, spell) then
						usingDefaultTooltip = true
					end
				end

			if not usingDefaultTooltip then
				local tree = self.spelldata[class][tab]
				local info = tree[index]
				local tier = (info.row - 1) * self:GetSkillPointsPerTier(class)
				local ranks, req = table.getn(info.ranks), info.req
				addline(self:GetTalentName(class, tab, index), HIGHLIGHT_FONT_COLOR)
				addline(SafeFormat(TOOLTIP_TALENT_RANK or "Rank %d/%d", rank, ranks), HIGHLIGHT_FONT_COLOR)
				if req then
					local oranks = table.getn(tree[req].ranks)
					if template[tab][req] < oranks then
						addline(SafeFormat(TOOLTIP_TALENT_PREREQ or "", oranks, self:GetTalentName(class, tab, req)), RED_FONT_COLOR)
					end
				end
				if tier >= 1 and self:GetTalentTabCount(template, tab) < tier then
					addline(SafeFormat(TOOLTIP_TALENT_TIER_POINTS or "", tier, self.tabdata[class][tab].name), RED_FONT_COLOR)
				end
				if IsAltKeyDown() then
					for i = 1, ranks do
							local tip = self:GetTalentDesc(class, tab, index, i, allowNativeTooltip)
						if type(tip) == "table" then
							tip = tip[table.getn(tip)].left
						end
						addline(tip, i == rank and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR, true)
					end
				else
						if rank > 0 then
								addtipline(self:GetTalentDesc(class, tab, index, rank, allowNativeTooltip))
							end
							if rank < ranks then
								addline("|n" .. (TOOLTIP_TALENT_NEXT_RANK or "Next rank:"), HIGHLIGHT_FONT_COLOR)
								addtipline(self:GetTalentDesc(class, tab, index, rank + 1, allowNativeTooltip))
							end
						end
					end
			local s = self:GetTalentState(template, tab, index)
		if self.mode == "edit" then
			if template.talentGroup then
				if s == "available" or s == "empty" then
					addline(TOOLTIP_TALENT_LEARN, GREEN_FONT_COLOR)
				end
			elseif s == "full" then
				addline(TALENT_TOOLTIP_REMOVEPREVIEWPOINT, GREEN_FONT_COLOR)
			elseif s == "available" then
				GameTooltip:AddDoubleLine(
					TALENT_TOOLTIP_ADDPREVIEWPOINT,
					TALENT_TOOLTIP_REMOVEPREVIEWPOINT,
					GREEN_FONT_COLOR.r,
					GREEN_FONT_COLOR.g,
					GREEN_FONT_COLOR.b,
					GREEN_FONT_COLOR.r,
					GREEN_FONT_COLOR.g,
					GREEN_FONT_COLOR.b
				)
			elseif s == "empty" then
				addline(TALENT_TOOLTIP_ADDPREVIEWPOINT, GREEN_FONT_COLOR)
			end
		end
		GameTooltip:Show()
	end

	function Talented:HideTooltipInfo()
		GameTooltip:Hide()
		wipe(lastTooltipInfo)
	end

		function Talented:UpdateTooltip()
			local frame = lastTooltipInfo[1]
			if next(lastTooltipInfo) and IsValidTooltipFrame(frame) then
				self:SetTooltipInfo(unpack(lastTooltipInfo))
			elseif next(lastTooltipInfo) then
				self:HideTooltipInfo()
			end
		end

	function Talented:MODIFIER_STATE_CHANGED(mod)
		if string.sub(mod or "", -3) == "ALT" then
			self:UpdateTooltip()
		end
	end
end

-------------------------------------------------------------------------------
-- apply.lua
--

do
	function Talented:ApplyCurrentTemplate()
		local template = self.template
		local pet = not RAID_CLASS_COLORS[template.class]
		if pet then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your pet's class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local _, playerClass = UnitClass("player")
		if playerClass ~= template.class then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local count = 0
		local current = self:GetActiveSpec()
		-- check if enough talent points are available
		local available = GetUnspentTalentPoints()
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			for index = 1, table.getn(tree) do
				local delta = template[tab][index] - current[tab][index]
				if delta > 0 then
					count = count + delta
				end
			end
		end
		if count == 0 then
			self:Print(L["Nothing to do"])
			self.mode = "view"
			self:UpdateView()
		elseif count > available then
			self:Print(L["Sorry, I can't apply this template because you don't have enough talent points available (need %d)!"], count)
			self.mode = "view"
			self:UpdateView()
		else
			self:EnableUI(false)
			self:ApplyTalentPoints()
		end
	end

	function Talented:ApplyTalentPoints()
		local template = self.template
		local current = self:GetActiveSpec()
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			for index = 1, table.getn(tree) do
				local target = template[tab][index]
				local rank = current[tab][index]
				if rank < target then
					local state = self:GetTalentState(current, tab, index)
					if state == "available" or state == "empty" then
						LearnTalent(tab, index, false)
						local _, _, _, _, newrank = GetTalentInfo(tab, index)
						if type(newrank) == "number" and newrank > rank then
							return true
						end
					end
				end
			end
		end
		return self:CheckTalentPointsApplied()
	end

	function Talented:CheckTalentPointsApplied()
		local template = self.template
		local failed
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			local ttab = template[tab]
			for index = 1, table.getn(tree) do
				local _, _, _, _, currentRank = GetTalentInfo(tab, index)
				local delta = ttab[index] - (currentRank or 0)
				if delta > 0 then
					failed = true
					break
				end
			end
		end
		if failed then
			Talented:Print(L["Error while applying talents! some of the request talents were not set!"])
		else
				local cp = GetUnspentTalentPoints()
				Talented:Print(L["Template applied successfully, %d talent points remaining."], cp)

				if self.db.profile.restore_bars then
					local set = string.lower(string.trim(string.match(template.name or "", "[^-]*") or ""))
					if set and ABS then
						ABS:RestoreProfile(set)
					elseif set and _G.KPack and _G.KPack.ActionBarSaver then
					_G.KPack.ActionBarSaver:RestoreProfile(set)
				end
			end
		end
		Talented:OpenTemplate(self:GetActiveSpec())
		Talented:EnableUI(true)

		return not failed
	end
end

-------------------------------------------------------------------------------
-- inspectui.lua
--

do
	local prev_script
	local TURTLE_INSPECT_PREFIX = "TW_CHAT_MSG_WHISPER"
	local TURTLE_INSPECT_DONE = "INSTalentEND;"

	local function GetTurtleInspectSpec()
		local com = _G.inspectCom or _G.InspectTalentsComFrame
		if type(com) == "table" and type(com.SPEC) == "table" then
			return com.SPEC
		end
	end

	local function HasTurtleInspectAPI()
		return _G.InspectTalentsComFrame ~= nil or _G.InspectFrameTalentsTab_OnClick ~= nil
	end

	local function GetTurtleInspectRank(class, tab, index)
		local spec = GetTurtleInspectSpec()
		if type(spec) ~= "table" then
			return nil
		end
		if class and type(spec.class) == "string" and spec.class ~= class then
			return nil
		end
		local tree = spec[tab]
		if type(tree) ~= "table" then
			return nil
		end
		local talent = tree[index]
		if type(talent) ~= "table" then
			return nil
		end
		if type(talent.rank) == "number" then
			return talent.rank
		end
		return nil
	end

	local function GetInspectTalentRank(class, tab, index, talentGroup, turtleOnly)
		if turtleOnly then
			local rank = GetTurtleInspectRank(class, tab, index)
			if type(rank) == "number" then
				return rank, true
			end
			return 0, false
		end
		local _, _, _, _, rank = GetTalentInfo(tab, index, true, nil, talentGroup)
		if type(rank) == "number" then
			return rank, true
		end
		rank = GetTurtleInspectRank(class, tab, index)
		if type(rank) == "number" then
			return rank, true
		end
		return 0, false
	end

	local new_script = function(self)
		if prev_script and prev_script ~= new_script then
			pcall(prev_script, self or _G.this)
		end
		local unit = Talented:GetInspectUnit()
		if unit and type(_G.NotifyInspect) == "function" then
			pcall(_G.NotifyInspect, unit)
		end
		Talented:UpdateInspectTemplate()
	end

	function Talented:HookInspectUI()
		if not InspectFrameTab3 then
			return
		end
		if not prev_script then
			prev_script = InspectFrameTab3:GetScript("OnClick")
			InspectFrameTab3:SetScript("OnClick", new_script)
		end
	end

	function Talented:UnhookInspectUI()
		if not InspectFrameTab3 then
			prev_script = nil
			return
		end
		if prev_script then
			InspectFrameTab3:SetScript("OnClick", prev_script)
			prev_script = nil
		end
	end

	function Talented:CheckHookInspectUI()
		if not InspectFrameTab3 and not IsAddOnLoaded("Blizzard_InspectUI") then
			return
		end
		self:RegisterEvent("INSPECT_TALENT_READY")
		self:RegisterEvent("CHAT_MSG_ADDON")
		if self.db.profile.hook_inspect_ui then
			if IsAddOnLoaded("Blizzard_InspectUI") then
				self:HookInspectUI()
			end
		else
			if IsAddOnLoaded("Blizzard_InspectUI") then
				self:UnhookInspectUI()
			end
			self:UnregisterEvent("CHAT_MSG_ADDON")
		end
	end

	function Talented:ADDON_LOADED(addon)
		if addon == "Blizzard_TalentUI" then
			self:HookTalentFrameToggle()
			return
		end
		if addon == "Blizzard_InspectUI" and self.db and self.db.profile and self.db.profile.hook_inspect_ui then
			self:HookInspectUI()
		end
	end

	function Talented:GetInspectUnit()
		if InspectFrame and InspectFrame.unit then
			return InspectFrame.unit
		end
		if type(UnitExists) == "function" and UnitExists("target") and type(CanInspect) == "function" and CanInspect("target") then
			return "target"
		end
		return nil
	end

	function Talented:INSPECT_TALENT_READY()
		self:UpdateInspectTemplate()
	end

	function Talented:CHAT_MSG_ADDON(prefix, message, channel, sender)
		if type(prefix) ~= "string" or type(message) ~= "string" then
			return
		end
		if not string.find(prefix, TURTLE_INSPECT_PREFIX, 1, true) then
			return
		end
		if not string.find(message, TURTLE_INSPECT_DONE, 1, true) then
			return
		end
		local unit = self:GetInspectUnit()
		if unit and type(UnitName) == "function" and type(sender) == "string" and sender ~= "" then
			local targetName = UnitName(unit)
			if type(targetName) == "string" and targetName ~= "" then
				if string.lower(targetName) ~= string.lower(sender) then
					return
				end
			end
		end
		self:UpdateInspectTemplate()
	end

	function Talented:UpdateInspectTemplate()
		local unit = self:GetInspectUnit()
		if not unit then return end
		local name = UnitName(unit)
		if not name then return end
		local level = tonumber(UnitLevel(unit)) or 0
		if level < 10 then
			return nil
		end
		local inspections = self.inspections or {}
		self.inspections = inspections
		local _, class = UnitClass(unit)
		local info = self:UncompressSpellData(class)
		if not info then
			return
		end
		local turtleSpec = GetTurtleInspectSpec()
		local useTurtleInspect = HasTurtleInspectAPI()
		if useTurtleInspect and type(turtleSpec) == "table" and type(turtleSpec.class) == "string" and turtleSpec.class ~= class then
			return nil
		end
		local retval
		for talentGroup = 1, GetNumTalentGroups(true) do
			local hasInspectData
			local ranksByTab = {}
			local template_name = name .. " - " .. tostring(talentGroup)
			for tab, tree in ipairs(info) do
				ranksByTab[tab] = {}
				for index = 1, table.getn(tree) do
					local rank, fromInspect = GetInspectTalentRank(class, tab, index, talentGroup, useTurtleInspect)
					if fromInspect then
						hasInspectData = true
					end
					ranksByTab[tab][index] = rank or 0
				end
			end
			if not hasInspectData then
				return nil
			end
			local template = inspections[template_name]
			if not template then
				template = {
					name = SafeFormat(L["Inspection of %s"], name) .. (talentGroup == GetActiveTalentGroup(true) and "" or L[" (alt)"]),
					class = class
				}
				for tab, tree in ipairs(info) do
					template[tab] = {}
				end
				inspections[template_name] = template
			else
				self:UnpackTemplate(template)
			end
			template.inspect_name = name
			template.inspect_level = level
			template.menu_name = string.format("%s - %d", tostring(name), level) .. (talentGroup == GetActiveTalentGroup(true) and "" or L[" (alt)"])
			template.name = SafeFormat(L["Inspection of %s"], name) .. string.format(" (Level %d)", level) .. (talentGroup == GetActiveTalentGroup(true) and "" or L[" (alt)"])
			for tab, tree in ipairs(info) do
				for index = 1, table.getn(tree) do
					template[tab][index] = ranksByTab[tab][index]
				end
			end
			if not self:ValidateTemplate(template) then
				inspections[template_name] = nil
			else
				local found
				for _, view in self:IterateTalentViews(template) do
					view:Update()
					found = true
				end
				if not found then
					self:PackTemplate(template)
				end
				if talentGroup == GetActiveTalentGroup(true) then
					retval = template
				end
			end
		end
		return retval
	end
end

-------------------------------------------------------------------------------
-- pet.lua
--

do
	function Talented:FixPetTemplate(template)
		local data = self:UncompressSpellData(template.class)[1]
		for index = 1, table.getn(data) - 1 do
			local info = data[index]
			local ninfo = data[index + 1]
			if info.row == ninfo.row and info.column == ninfo.column then
				local talent = not info.inactive
				local value = template[1][index] + template[1][index + 1]
				if talent then
					template[1][index] = value
					template[1][index + 1] = 0
				else
					template[1][index] = 0
					template[1][index + 1] = value
				end
			end
		end
	end

	function Talented:GetPetClass()
		local _, _, _, texture = GetTalentTabInfo(1, nil, true)
		return texture and string.sub(texture, 10)
	end

	local function PetTalentsAvailable()
		local talentGroup = GetActiveTalentGroup(nil, true)
		if not talentGroup then return end
		local has_talent = GetTalentInfo(1, 1, nil, true, talentGroup) or GetTalentInfo(1, 2, nil, true, talentGroup)
		return has_talent
	end

	function Talented:PET_TALENT_UPDATE()
		local class = self:GetPetClass()
		if not class or not PetTalentsAvailable() then return end
		self:FixAlternatesTalents(class)
		local template = self.pet_current
		if not template then
			template = {pet = true, name = TALENT_SPEC_PET_PRIMARY}
			self.pet_current = template
		end
		local talentGroup = GetActiveTalentGroup(nil, true)
		template.talentGroup = talentGroup
		template.class = class
		local info = self:UncompressSpellData(class)
		for tab, tree in ipairs(info) do
			local ttab = template[tab]
			if not ttab then
				ttab = {}
				template[tab] = ttab
			end
			for index in ipairs(tree) do
				local _, _, _, _, rank = GetTalentInfo(tab, index, nil, true, talentGroup)
				ttab[index] = rank or 0
			end
		end
		for _, view in self:IterateTalentViews(template) do
			view:SetClass(class)
			view:Update()
		end
		if self.mode == "apply" then
			self:CheckTalentPointsApplied()
		end
	end

	function Talented:UNIT_PET(unit)
		if unit == "player" then
			self:PET_TALENT_UPDATE()
		end
	end

	function Talented:InitializePet()
		self:RegisterEvent("UNIT_PET")
		self:RegisterEvent("PET_TALENT_UPDATE")
		self:PET_TALENT_UPDATE()
	end

	function Talented:FixAlternatesTalents(class)
		local talentGroup = GetActiveTalentGroup(nil, true)
		local data = self:UncompressSpellData(class)[1]
		for index = 1, table.getn(data) - 1 do
			local info = data[index]
			local ninfo = data[index + 1]
			if info.row == ninfo.row and info.column == ninfo.column then
				local talent = GetTalentInfo(1, index, nil, true, talentGroup)
				local ntalent = GetTalentInfo(1, index + 1, nil, true, talentGroup)
				if talent then
					assert(not ntalent)
					info.inactive = nil
					ninfo.inactive = true
				else
					assert(ntalent)
					info.inactive = true
					ninfo.inactive = nil
				end
				for _, template in pairs(self:GetTemplatesDB()) do
					if template.class == class and not template.code then
						local value = template[1][index] + template[1][index + 1]
						if talent then
							template[1][index] = value
							template[1][index + 1] = 0
						else
							template[1][index] = 0
							template[1][index + 1] = value
						end
					end
				end
			end
		end
		for _, view in self:IterateTalentViews() do
			if view.class == class then
				view:SetClass(view.class, true)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- whpet.lua
--

do
	local WH_MAP = "0zMcmVokRsaqbdrfwihuGINALpTjnyxtgevE"
	local WH_PET_INFO_CLASS = "FFCTTTFTT FF       TT  CFCC  CCTCCC FCF CTTFFF"

	local TALENTED_MAP = "012345abcdefABCDEFmnopqrMNOPQRtuvwxy*"
	local TALENTED_CLASS_CODE = {
		F = "Ferocity",
		C = "Cunning",
		T = "Tenacity",
		Ferocity = "t",
		Cunning = "w",
		Tenacity = "*",
		["t"] = "Ferocity",
		["w"] = "Cunning",
		["*"] = "Tenacity"
	}

	function Talented:GetPetClassByFamily(index)
		return TALENTED_CLASS_CODE[string.sub(WH_PET_INFO_CLASS, index, index)]
	end

	local function GetPetFamilyForClass(class)
		return string.find(WH_PET_INFO_CLASS, string.sub(class, 1, 1), 1, true)
	end

	local function map(code, src, dst)
		local temp = {}
		for i = 1, string.len(code) do
			local index = assert(string.find(src, string.sub(code, i, i), 1, true))
			temp[i] = string.sub(dst, index, index)
		end
		return table.concat(temp)
	end

	local function ImportCode(code)
		local a = (string.find(WH_MAP, string.sub(code, 1, 1), 1, true) - 1) * 10
		local b = (string.find(WH_MAP, string.sub(code, 2, 2), 1, true) - 1) / 2
		local family = a + math.floor(b)
		local class = Talented:GetPetClassByFamily(family)

		return TALENTED_CLASS_CODE[class] .. map(string.sub(code, 3), WH_MAP, TALENTED_MAP)
	end

	local function ExportCode(code)
		local class = TALENTED_CLASS_CODE[string.sub(code, 1, 1)]
		local family = GetPetFamilyForClass(class)

		local a = math.floor(family / 10)
		local b = (family - (a * 10)) * 2 + 1
		return string.sub(WH_MAP, a + 1, a + 1) .. string.sub(WH_MAP, b, b) .. map(string.sub(code, 2), TALENTED_MAP, WH_MAP)
	end

	local function FixImportTemplate(self, template)
		local data = self:UncompressSpellData(template.class)[1]
		template = template[1]
		for index, info in ipairs(data) do
			if info.inactive then
				if index > 1 and info.row == data[index - 1].row and info.column == data[index - 1].column then
					template[index - 1] = template[index] + template[index - 1]
				elseif index < table.getn(data) and info.row == data[index + 1].row and info.column == data[index + 1].column then
					template[index + 1] = template[index] + template[index + 1]
				end
			end
		end
	end

	local function FixExportTemplate(self, template)
		local data = self:UncompressSpellData(template.class)[1]
		template = template[1]
		for index, info in ipairs(data) do
			if info.inactive then
				if index > 1 and info.row == data[index - 1].row and info.column == data[index - 1].column then
					template[index - 1] = template[index] + template[index - 1]
				end
			end
		end
	end

	Talented.importers["/%??petcalc#"] = function(self, url, dst)
		return
	end

	function Talented:ExportWhpetTemplate(template, url)
		return
	end
end
