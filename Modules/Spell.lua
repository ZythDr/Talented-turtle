local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local internals = Talented._internals or {}
local DeepCopy = internals.DeepCopy
local SafeFormat = internals.SafeFormat
local CompatGetSpellInfo = internals.CompatGetSpellInfo
local GetNumTalentTabs = internals.GetNumTalentTabs or _G.GetNumTalentTabs
local GetTalentTabInfo = internals.GetTalentTabInfo or _G.GetTalentTabInfo
local GetTalentInfo = internals.GetTalentInfo or _G.GetTalentInfo
local GetTalentPrereqs = internals.GetTalentPrereqs or _G.GetTalentPrereqs
local GetUnspentTalentPoints = internals.GetUnspentTalentPoints or _G.GetUnspentTalentPoints
local ENABLE_STRICT_SPELLDATA_CHECK = internals.ENABLE_STRICT_SPELLDATA_CHECK
local GetSpellRecDescription = internals.GetSpellRecDescription
local SPELL_ICON_FALLBACK = internals.SPELL_ICON_FALLBACK

if type(DeepCopy) ~= "function" then
	local function _copy(value, seen)
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
			out[_copy(k, seen)] = _copy(v, seen)
		end
		return out
	end
	DeepCopy = _copy
end

if type(SafeFormat) ~= "function" then
	SafeFormat = function(fmt, a1, a2, a3, a4, a5, a6, a7, a8)
		if type(fmt) ~= "string" then
			return tostring(fmt or "")
		end
		local ok, msg = pcall(string.format, fmt, a1, a2, a3, a4, a5, a6, a7, a8)
		if ok and type(msg) == "string" then
			return msg
		end
		return fmt
	end
end

if type(CompatGetSpellInfo) ~= "function" then
	CompatGetSpellInfo = function(spell)
		if type(_G.GetSpellInfo) == "function" then
			local ok, n, r, icon = pcall(_G.GetSpellInfo, spell)
			if ok and n then
				return n, r, icon
			end
		end
		if type(_G.SpellInfo) == "function" then
			local ok, n, r, icon = pcall(_G.SpellInfo, spell)
			if ok and n then
				return n, r, icon
			end
		end
		return nil
	end
end

if type(GetSpellRecDescription) ~= "function" then
	GetSpellRecDescription = function()
		return nil
	end
end

if type(ENABLE_STRICT_SPELLDATA_CHECK) ~= "boolean" then
	ENABLE_STRICT_SPELLDATA_CHECK = false
end

if type(SPELL_ICON_FALLBACK) ~= "string" or SPELL_ICON_FALLBACK == "" then
	SPELL_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
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
		if type(self.InvalidateSpellLookupCache) == "function" then
			self:InvalidateSpellLookupCache()
		end
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
		if type(self.InvalidateSpellLookupCache) == "function" then
			self:InvalidateSpellLookupCache()
		end
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
		self:InvalidateSpellLookupCache()
		if ENABLE_STRICT_SPELLDATA_CHECK and class == playerClass then
			self:CheckSpellData(class)
		end
		return data
	end

	local spellTooltip
	local spellLinkTooltip
	local function GetTooltipLineText(fs)
		if not fs then
			return nil
		end
		if type(fs.IsVisible) == "function" and not fs:IsVisible() then
			return nil
		end
		if type(fs.GetText) ~= "function" then
			return nil
		end
		local text = fs:GetText()
		if type(text) ~= "string" or text == "" then
			return nil
		end
		return text
	end

	local function TooltipDataHasPlaceholders(data)
		if type(data) == "string" then
			return string.find(data, "%$", 1, true) ~= nil
		end
		if type(data) ~= "table" then
			return false
		end
		for i = 1, table.getn(data) do
			local line = data[i]
			if type(line) == "string" then
				if string.find(line, "%$", 1, true) then
					return true
				end
			elseif type(line) == "table" then
				local left = line.left
				local right = line.right
				if type(left) == "string" and string.find(left, "%$", 1, true) then
					return true
				end
				if type(right) == "string" and string.find(right, "%$", 1, true) then
					return true
				end
			end
		end
		return false
	end

	local function ParseSpellTooltip(tt)
		local lines = tt:NumLines()
		if not lines or lines < 2 then
			return ""
		end
		local value
		local right2 = GetTooltipLineText(tt.rights and tt.rights[2])
		local left2 = GetTooltipLineText(tt.lefts and tt.lefts[2])
		if lines == 2 and not right2 then
			value = left2 or ""
		else
			value = {}
			for i = 2, lines do
				local left = GetTooltipLineText(tt.lefts and tt.lefts[i])
				local right = GetTooltipLineText(tt.rights and tt.rights[i])
				value[i - 1] = {
					left = left,
					right = right
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
			local linkDesc
			if spell and self.spellLinkDescCache then
				linkDesc = self.spellLinkDescCache[spell]
				if linkDesc and linkDesc ~= "" and not TooltipDataHasPlaceholders(linkDesc) then
					return linkDesc
				end
			end
			local desc = spell and self.spellDescCache[spell]
			if desc and desc ~= "" and not TooltipDataHasPlaceholders(desc) then
				return desc
			end
			local recDesc = GetSpellRecDescription(spell)
			if recDesc and recDesc ~= "" then
				return recDesc
			end
			if desc and desc ~= "" then
				return desc
			end
			if linkDesc and linkDesc ~= "" then
				return linkDesc
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

	local function IsSuspiciousTalentSpellText(text)
		if type(text) ~= "string" or text == "" then
			return false
		end
		local lower = string.lower(text)
		return string.find(lower, "designer note", 1, true) ~= nil
			or string.find(lower, "design note", 1, true) ~= nil
			or string.find(lower, "only purpose of this aura", 1, true) ~= nil
			or string.find(lower, "mark a player", 1, true) ~= nil
	end

	local function IsSuspiciousTalentSpellID(spell)
		if type(spell) ~= "number" or spell <= 0 then
			return false
		end
		local recDesc = GetSpellRecDescription(spell)
		if IsSuspiciousTalentSpellText(recDesc) then
			return true
		end
		local getField = _G.GetSpellRecField
		if type(getField) == "function" then
			local tooltip = getField(spell, "tooltip")
			local description = getField(spell, "description")
			if IsSuspiciousTalentSpellText(tooltip) or IsSuspiciousTalentSpellText(description) then
				return true
			end
		end
		return false
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
			local resolved = self:ResolveTalentRankSpellID(class, tab, index, rank, nil, true)
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
			local remapped = self:ResolveTalentRankSpellID(class, tab, index, rank, nil, true)
			if type(remapped) == "number" then
				spell = remapped
			end
		elseif IsSuspiciousTalentSpellID(spell) then
			-- Player-class dumps can occasionally contain helper/aura marker IDs.
			-- Re-run resolver and prefer a non-note spell where possible.
			local remapped = self:ResolveTalentRankSpellID(class, tab, index, rank, nil, true)
			if type(remapped) == "number" then
				spell = remapped
			end
		end
		if spell == rank then
			local resolved = self:ResolveTalentRankSpellID(class, tab, index, rank, nil, true)
			if type(resolved) == "number" then
				return resolved
			end
			return nil
		end
		return spell
	end

		local CUSTOM_TALENT_LINK_TREE_BASE = 900
		local CUSTOM_TALENT_LINK_TAB_SCALE = 10000
		local CUSTOM_TALENT_LINK_INDEX_SCALE = 100

		function Talented:EnsureCustomTalentLinkMaps()
			if type(self._customTalentClassToId) == "table" and type(self._customTalentIdToClass) == "table" then
				return
			end
			local classToId = {}
			local idToClass = {}
			local order = STATUS_CLASS_ORDER or {}
			for i, class in ipairs(order) do
				if type(class) == "string" then
					classToId[class] = i
					idToClass[i] = class
				end
			end
			self._customTalentClassToId = classToId
			self._customTalentIdToClass = idToClass
		end

		function Talented:EncodeCustomTalentLink(class, tab, index, rank)
			self:EnsureCustomTalentLinkMaps()
			local classId = self._customTalentClassToId and self._customTalentClassToId[class]
			tab = tonumber(tab)
			index = tonumber(index)
			rank = tonumber(rank) or 1
			if not classId or not tab or not index then
				return nil
			end
			if tab < 1 or index < 1 then
				return nil
			end
			if rank < 1 then
				rank = 1
			end
			local tree = CUSTOM_TALENT_LINK_TREE_BASE + classId
			local packedIndex = tab * CUSTOM_TALENT_LINK_TAB_SCALE + index * CUSTOM_TALENT_LINK_INDEX_SCALE + rank
			return tree, packedIndex
		end

		function Talented:DecodeCustomTalentLink(tree, packedIndex)
			self:EnsureCustomTalentLinkMaps()
			tree = tonumber(tree)
			packedIndex = tonumber(packedIndex)
			if not tree or not packedIndex then
				return nil
			end
			local classId = tree - CUSTOM_TALENT_LINK_TREE_BASE
			if classId < 1 then
				return nil
			end
			local class = self._customTalentIdToClass and self._customTalentIdToClass[classId]
			if not class then
				return nil
			end
			local tab = math.floor(packedIndex / CUSTOM_TALENT_LINK_TAB_SCALE)
			local remainder = packedIndex - (tab * CUSTOM_TALENT_LINK_TAB_SCALE)
			local index = math.floor(remainder / CUSTOM_TALENT_LINK_INDEX_SCALE)
			local rank = remainder - (index * CUSTOM_TALENT_LINK_INDEX_SCALE)
			if tab < 1 or index < 1 then
				return nil
			end
			if rank < 1 then
				rank = 1
			end
			return class, tab, index, rank
		end

		local function ParseNativeTalentHyperlink(link)
			if type(link) ~= "string" then
				return nil
			end
			local tree, index = string.match(link, "^talent:(%d+):(%d+):")
			if not tree then
				tree, index = string.match(link, "^talent:(%d+):(%d+)$")
			end
			tree = tonumber(tree)
			index = tonumber(index)
			if not tree or not index then
				return nil
			end
			return tree, index
		end

		function Talented:BuildTalentLinkSlots()
			local slots = self._talentLinkSlots
			if type(slots) == "table" and table.getn(slots) > 0 then
				return slots
			end
			slots = {}
			local numTabs = tonumber(type(_G.GetNumTalentTabs) == "function" and _G.GetNumTalentTabs() or 0) or 0
			if numTabs < 1 then
				numTabs = 3
			end
			for tab = 1, numTabs do
				local numTalents = tonumber(type(_G.GetNumTalents) == "function" and _G.GetNumTalents(tab) or 0) or 0
				if numTalents < 1 then
					numTalents = 1
				end
				for index = 1, numTalents do
					slots[table.getn(slots) + 1] = {tab = tab, index = index}
				end
			end
			self._talentLinkSlots = slots
			self._talentLinkSlotByPayload = self._talentLinkSlotByPayload or {}
			self._talentLinkPayloadBySlot = self._talentLinkPayloadBySlot or {}
			self._talentLinkNextSlot = self._talentLinkNextSlot or 1
			return slots
		end

		function Talented:AllocateTalentLinkSlot(class, tab, index, rank)
			class = type(class) == "string" and string.upper(class) or nil
			tab = tonumber(tab)
			index = tonumber(index)
			rank = tonumber(rank) or 1
			if not class or not tab or not index then
				return nil
			end
			if rank < 1 then
				rank = 1
			end
			local slots = self:BuildTalentLinkSlots()
			local slotCount = table.getn(slots)
			if slotCount < 1 then
				return nil
			end
			local payloadKey = SafeFormat("%s:%d:%d:%d", class, tab, index, rank)
			local slotByPayload = self._talentLinkSlotByPayload or {}
			local payloadBySlot = self._talentLinkPayloadBySlot or {}
			local slotId = slotByPayload[payloadKey]
			if not slotId or not slots[slotId] then
				slotId = tonumber(self._talentLinkNextSlot) or 1
				if slotId < 1 or slotId > slotCount then
					slotId = 1
				end
				local previous = payloadBySlot[slotId]
				if type(previous) == "table" and previous.key then
					slotByPayload[previous.key] = nil
				end
				slotByPayload[payloadKey] = slotId
				payloadBySlot[slotId] = {key = payloadKey, class = class, tab = tab, index = index, rank = rank}
				slotId = slotId + 1
				if slotId > slotCount then
					slotId = 1
				end
				self._talentLinkNextSlot = slotId
			end
			self._talentLinkSlotByPayload = slotByPayload
			self._talentLinkPayloadBySlot = payloadBySlot
			local slot = slots[slotByPayload[payloadKey]]
			if not slot then
				return nil
			end
			return slot.tab, slot.index
		end

		function Talented:ResolveTalentLinkSlot(tree, index)
			tree = tonumber(tree)
			index = tonumber(index)
			if not tree or not index then
				return nil
			end
			local slots = self:BuildTalentLinkSlots()
			local payloadBySlot = self._talentLinkPayloadBySlot
			if type(slots) ~= "table" or type(payloadBySlot) ~= "table" then
				return nil
			end
			for slotId = 1, table.getn(slots) do
				local slot = slots[slotId]
				if slot and slot.tab == tree and slot.index == index then
					local payload = payloadBySlot[slotId]
					if type(payload) == "table" then
						return payload.class, payload.tab, payload.index, payload.rank
					end
					return nil
				end
			end
			return nil
		end

		function Talented:GetTalentLink(template, tab, index, rank)
			if type(template) ~= "table" or type(template.class) ~= "string" then
				return nil
			end
			tab = tonumber(tab)
			index = tonumber(index)
			if not tab or not index then
				return nil
			end
			rank = tonumber(rank or (template[tab] and template[tab][index])) or 1
			if rank < 1 then
				rank = 1
			end
			local name = self:GetTalentName(template.class, tab, index)
			local sender = UnitName("player")
			local linkTab, linkIndex = self:AllocateTalentLinkSlot(template.class, tab, index, rank)
			if linkTab and linkIndex and sender and sender ~= "" then
				return SafeFormat("|cFF71D5FF|Htalent:%d:%d:%s:|h[%s]|h|r", linkTab, linkIndex, sender, name)
			end

			local spell = self:GetTalentSpellID(template.class, tab, index, rank)
			if type(spell) == "number" and spell > 0 then
				return SafeFormat("|cFF71D5FF|Henchant:%d|h[%s]|h|r", spell, name)
			end
			return SafeFormat("|cFF71D5FF|Htalented:%s:%d:%d:%d|h[%s]|h|r", string.upper(template.class), tab, index, rank, name)
		end

		function Talented:BuildSpellToTalentMap()
			if self._spellToTalentMapBuilt and type(self._spellToTalentMap) == "table" then
				return self._spellToTalentMap
			end
			local map = {}
			local classOrder = STATUS_CLASS_ORDER
			local function ScanClass(class)
				if type(class) == "string" and type((self.spelldata or {})[class]) ~= "nil" then
					local trees = self:UncompressSpellData(class)
					if type(trees) == "table" then
						for tab, tree in ipairs(trees) do
							for index, talent in ipairs(tree) do
								local ranks = talent and talent.ranks
								local maxRank = type(ranks) == "table" and table.getn(ranks) or 0
								for rank = 1, maxRank do
									local spell = self:GetTalentSpellID(class, tab, index, rank)
									if type(spell) == "number" and spell > 0 and not map[spell] then
										map[spell] = {class = class, tab = tab, index = index, rank = rank}
									end
								end
							end
						end
					end
				end
			end
			if type(classOrder) == "table" then
				for _, class in ipairs(classOrder) do
					ScanClass(class)
				end
			else
				for class, _ in pairs(self.spelldata or {}) do
					ScanClass(class)
				end
			end
			self._spellToTalentMap = map
			self._spellToTalentMapBuilt = true
			return map
		end

		function Talented:GetTalentBySpellID(spellId)
			spellId = tonumber(spellId)
			if not spellId or spellId <= 0 then
				return nil
			end
			local map = self:BuildSpellToTalentMap()
			local talent = map and map[spellId]
			if talent then
				return talent
			end
			self:InvalidateSpellLookupCache()
			map = self:BuildSpellToTalentMap()
			return map and map[spellId]
		end

		function Talented:ShowTalentTooltip(class, tab, index, rank)
			if type(class) ~= "string" then
				return false
			end
			tab = tonumber(tab)
			index = tonumber(index)
			rank = tonumber(rank) or 1
			if not tab or not index then
				return false
			end
			local data = self:UncompressSpellData(class)
			if type(data) ~= "table" or type(data[tab]) ~= "table" or type(data[tab][index]) ~= "table" then
				return false
			end
			if rank < 1 then
				rank = 1
			end
			local maxRank = self:GetTalentRanks(class, tab, index) or 1
			if rank > maxRank then
				rank = maxRank
			end

			local tooltip = _G.ItemRefTooltip or _G.GameTooltip
			if not tooltip then
				return false
			end
			if tooltip.SetOwner then
				pcall(tooltip.SetOwner, tooltip, UIParent, "ANCHOR_PRESERVE")
			end
			if tooltip.ClearLines then
				tooltip:ClearLines()
			end

			local function AddTipText(desc)
				if type(desc) == "string" then
					if desc ~= "" then
						tooltip:AddLine(desc, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
					end
					return
				end
				if type(desc) ~= "table" then
					return
				end
					local n = table.getn(desc)
					for i = 1, n do
						local line = desc[i]
						local color = (i == n) and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR
						if type(line) == "table" then
							local left, right = line.left, line.right
							if type(left) == "string" and left == "" then
								left = nil
							end
							if type(right) == "string" and right == "" then
								right = nil
							end
							if left and right then
								tooltip:AddDoubleLine(left, right, color.r, color.g, color.b, color.r, color.g, color.b)
							elseif left then
								tooltip:AddLine(left, color.r, color.g, color.b, true)
							elseif right then
								tooltip:AddLine(right, color.r, color.g, color.b, true)
							end
						elseif type(line) == "string" then
						tooltip:AddLine(line, color.r, color.g, color.b, true)
					end
				end
			end

			tooltip:AddLine(self:GetTalentName(class, tab, index), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			tooltip:AddLine(SafeFormat(TOOLTIP_TALENT_RANK or "Rank %d/%d", rank, maxRank), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			AddTipText(self:GetTalentDesc(class, tab, index, rank, false))

			if tooltip.Show then
				tooltip:Show()
			end
			return true
		end

		function Talented:BuildTalentTooltipLines(class, tab, index, rank)
			if type(class) ~= "string" then
				return nil
			end
			tab = tonumber(tab)
			index = tonumber(index)
			rank = tonumber(rank) or 1
			if not tab or not index then
				return nil
			end
			local data = self:UncompressSpellData(class)
			if type(data) ~= "table" or type(data[tab]) ~= "table" or type(data[tab][index]) ~= "table" then
				return nil
			end
			if rank < 1 then
				rank = 1
			end
			local maxRank = self:GetTalentRanks(class, tab, index) or 1
			if maxRank < 1 then
				return nil
			end
			if rank > maxRank then
				rank = maxRank
			end

			local lines = {}
			local function AddLine(left, right)
				lines[table.getn(lines) + 1] = {left = left, right = right}
			end
			local function AddDesc(desc)
				if type(desc) == "string" then
					if desc ~= "" then
						AddLine(desc)
					end
					return
				end
				if type(desc) ~= "table" then
					return
				end
				for i = 1, table.getn(desc) do
					local line = desc[i]
					if type(line) == "table" then
						local left, right = line.left, line.right
						if (left and left ~= "") or (right and right ~= "") then
							AddLine(left, right)
						end
					elseif type(line) == "string" and line ~= "" then
						AddLine(line)
					end
				end
			end

			AddLine(self:GetTalentName(class, tab, index))
			AddLine(SafeFormat(TOOLTIP_TALENT_RANK or "Rank %d/%d", rank, maxRank))
			AddDesc(self:GetTalentDesc(class, tab, index, rank, false))
			return lines
		end

		local function ParseTalentedHyperlink(link)
			if type(link) ~= "string" then
				return nil
			end
			local class, tab, index, rank = string.match(link, "^talented:([^:]+):(%d+):(%d+):(%d+)$")
			if not class then
				class, tab, index = string.match(link, "^talented:([^:]+):(%d+):(%d+)$")
			end
			class = class and string.upper(class)
			tab = tonumber(tab)
			index = tonumber(index)
			rank = tonumber(rank) or 1
			if not class or not tab or not index then
				return nil
			end
			if rank < 1 then
				rank = 1
			end
			return class, tab, index, rank
		end

		function Talented:ShowCustomTalentHyperlink(link)
			local tree, packedIndex = ParseNativeTalentHyperlink(link)
			if not tree then
				return false
			end
			local class, tab, index, rank = self:DecodeCustomTalentLink(tree, packedIndex)
			if not class then
				class, tab, index, rank = self:ResolveTalentLinkSlot(tree, packedIndex)
			end
			if not class then
				return false
			end
			return self:ShowTalentTooltip(class, tab, index, rank)
		end

		function Talented:ShowTalentedHyperlink(link)
			local class, tab, index, rank = ParseTalentedHyperlink(link)
			if not class then
				return false
			end
			return self:ShowTalentTooltip(class, tab, index, rank)
		end

		function Talented:HandleSetItemRef(link, text, button)
			if type(link) ~= "string" then
				return false
			end
			if string.sub(link, 1, 7) == "talent:" then
				return self:ShowCustomTalentHyperlink(link)
			end
			if string.sub(link, 1, 9) == "talented:" then
				return self:ShowTalentedHyperlink(link)
			end
			local spellId = tonumber(string.match(link, "^enchant:(%d+)"))
			if spellId then
				local talent = self:GetTalentBySpellID(spellId)
				if talent then
					return self:ShowTalentTooltip(talent.class, talent.tab, talent.index, talent.rank)
				end
			end
			return false
		end

		function Talented:HookSetItemRef()
			if self._talentedSetItemRefProxy then
				return
			end
			self._talentedSetItemRefOriginal = _G.SetItemRef
			self._talentedSetItemRefProxy = function(link, text, button, a4, a5, a6, a7, a8)
				local handled
				if Talented then
					local ok, result = pcall(Talented.HandleSetItemRef, Talented, link, text, button)
					handled = ok and result
				end
				if handled then
					return
				end
				local original = Talented and Talented._talentedSetItemRefOriginal
				if type(original) == "function" then
					return original(link, text, button, a4, a5, a6, a7, a8)
				end
			end
			_G.SetItemRef = self._talentedSetItemRefProxy
		end

		function Talented:HandleChatHyperlink(link, text, button)
			if type(link) ~= "string" then
				return false
			end
			if string.sub(link, 1, 7) == "talent:" then
				if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
					ChatFrameEditBox:Insert(text or "")
					return true
				end
				return self:ShowCustomTalentHyperlink(link)
			end
			if string.sub(link, 1, 9) == "talented:" then
				if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
					ChatFrameEditBox:Insert(text or "")
					return true
				end
				return self:ShowTalentedHyperlink(link)
			end
			local spellId = tonumber(string.match(link, "^enchant:(%d+)"))
			if spellId then
				local talent = self:GetTalentBySpellID(spellId)
				if talent then
					if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
						ChatFrameEditBox:Insert(text or "")
						return true
					end
					return self:ShowTalentTooltip(talent.class, talent.tab, talent.index, talent.rank)
				end
			end
			return false
		end

		function Talented:HookChatHyperlinkShow()
			local current = _G.ChatFrame_OnHyperlinkShow
			if current == self._talentedChatHyperlinkProxy then
				return
			end
			self._talentedChatHyperlinkOriginal = current
			self._talentedChatHyperlinkProxy = function(link, text, button, a4, a5, a6, a7, a8)
				local handled = false
				if Talented and type(Talented.HandleChatHyperlink) == "function" then
					local ok, result = pcall(Talented.HandleChatHyperlink, Talented, link, text, button)
					handled = ok and result
				end
				if handled then
					return
				end
				local original = Talented and Talented._talentedChatHyperlinkOriginal
				if type(original) == "function" then
					return original(link, text, button, a4, a5, a6, a7, a8)
				end
			end
			_G.ChatFrame_OnHyperlinkShow = self._talentedChatHyperlinkProxy
		end
	end
