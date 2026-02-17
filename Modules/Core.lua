local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local L = _G.TalentedLocale or {}
local internals = Talented._internals or {}

local DeepCopy = internals.DeepCopy
local SerializeLua = internals.SerializeLua
local RawSpellTextScore = internals.RawSpellTextScore
local ChooseBestSpellText = internals.ChooseBestSpellText
local ToNumber = internals.ToNumber
local GetSpellRecDescription = internals.GetSpellRecDescription
local ParseDurationHintSeconds = internals.ParseDurationHintSeconds
local SafeFormat = internals.SafeFormat
local GetUnspentTalentPoints = internals.GetUnspentTalentPoints or _G.GetUnspentTalentPoints
local TALENTED_WHISPER_PREFIX = internals.TALENTED_WHISPER_PREFIX or "\001TLDCOMM\001"
local TALENTED_LFT_COMM_TAG = internals.TALENTED_LFT_COMM_TAG or "TLDLFT:"
local ResetSpellRecDescCache = internals.ResetSpellRecDescCache

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

if type(SerializeLua) ~= "function" then
	SerializeLua = function(value)
		return tostring(value)
	end
end

if type(SafeFormat) ~= "function" then
	SafeFormat = function(fmt, a1, a2, a3, a4, a5, a6, a7, a8)
		if type(fmt) ~= "string" then
			return tostring(fmt or "")
		end
		local ok, out = pcall(string.format, fmt, a1, a2, a3, a4, a5, a6, a7, a8)
		if ok and type(out) == "string" then
			return out
		end
		return fmt
	end
end

if type(RawSpellTextScore) ~= "function" then
	RawSpellTextScore = function()
		return -1000
	end
end

if type(ChooseBestSpellText) ~= "function" then
	ChooseBestSpellText = function(primary, secondary)
		return secondary or primary
	end
end

if type(ToNumber) ~= "function" then
	ToNumber = function(value)
		if type(value) == "number" then
			return value
		end
		if type(value) == "string" then
			return tonumber(value)
		end
		return nil
	end
end

if type(GetSpellRecDescription) ~= "function" then
	GetSpellRecDescription = function()
		return nil
	end
end

if type(ParseDurationHintSeconds) ~= "function" then
	ParseDurationHintSeconds = function(text)
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
end

if type(ResetSpellRecDescCache) ~= "function" then
	ResetSpellRecDescCache = function()
	end
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
				(RAID_CLASS_COLORS[target.class] and target.class ~= playerClass)
		 then
			self.db.char.targets[targetName] = nil
			return nil
		end
		target.name = name
		return target
	end

	function Talented:RefreshTargetOverlays(targetName)
		local _, playerClass = UnitClass("player")
		for _, view in self:IterateTalentViews() do
			local template = view and view.template
			if type(template) == "table" then
				local key
				local shouldRefresh = false
				if template.talentGroup then
					key = template.talentGroup
					shouldRefresh = (targetName == nil or targetName == key)
					if shouldRefresh and template.class ~= playerClass then
						shouldRefresh = false
					end
				end
				if shouldRefresh then
					local target = self:MakeTarget(key)
					if type(view.SetTemplate) == "function" then
						view:SetTemplate(template, target)
					else
						view.target = target
						if type(view.Update) == "function" then
							view:Update()
						end
					end
				end
			end
		end
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

	function Talented:IsEditLockedForTemplate(template, pet)
		if type(template) ~= "table" then
			return false
		end
		if template.inspect_name then
			return true
		end
		if template.talentGroup then
			local group = template.talentGroup
			local unspent = GetUnspentTalentPoints(nil, pet, group)
			if type(unspent) ~= "number" then
				unspent = GetUnspentTalentPoints()
			end
			if type(unspent) ~= "number" or unspent <= 0 then
				return true
			end
		end
		return false
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

	function Talented:InvalidateSpellLookupCache()
		self._spellToTalentMap = nil
		self._spellToTalentMapBuilt = nil
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
			self:InvalidateSpellLookupCache()
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

	local function BuildDurationHints(durationVotes)
		local durationHints = {}
		for durationIndex, bucket in pairs(durationVotes or {}) do
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
		return durationHints
	end

	local function IndexSpellRecRecord(index, scores, durationVotes, spellId, getField, getIcon)
		local name = getField(spellId, "name")
		if type(name) ~= "string" or name == "" then
			return false
		end
		local function setBest(key, candidateId, score)
			if type(key) ~= "string" or key == "" then
				return
			end
			local prev = scores[key]
			local prevId = index[key]
			if prev == nil or score > prev or (score == prev and (not prevId or candidateId < prevId)) then
				index[key] = candidateId
				scores[key] = score
			end
		end

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
		return true
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
		for spellId = 1, maxSpellId do
			if IndexSpellRecRecord(index, scores, durationVotes, spellId, getField, getIcon) then
				indexed = indexed + 1
			end
		end
		return index, indexed, BuildDurationHints(durationVotes)
	end

	local RESOLVER_IDS_PER_TICK = 3000
	local RESOLVER_RANKS_PER_TICK = 320
	local RESOLVER_IDS_STEP = 120
	local RESOLVER_TIME_BUDGET = 0.006
	local RESOLVER_BOOST_TIME_BUDGET = 0.012
	local RESOLVER_BOOST_WINDOW = 1.5

	local function GetResolverFrameBudget(self)
		local now = type(GetTime) == "function" and GetTime() or 0
		if type(self._resolverBoostUntil) == "number" and now < self._resolverBoostUntil then
			return RESOLVER_BOOST_TIME_BUDGET
		end
		return RESOLVER_TIME_BUDGET
	end

	function Talented:BoostResolverWindow()
		if type(GetTime) ~= "function" then
			return
		end
		local untilTime = GetTime() + RESOLVER_BOOST_WINDOW
		if type(self._resolverBoostUntil) ~= "number" or untilTime > self._resolverBoostUntil then
			self._resolverBoostUntil = untilTime
		end
	end

	function Talented:EnsureResolverTicker()
		if self._resolverTicker or type(CreateFrame) ~= "function" then
			return
		end
		local addon = self
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:Hide()
		frame:SetScript("OnUpdate", function()
			addon:OnResolverTick()
		end)
		self._resolverTicker = frame
	end

	function Talented:HasResolverWork()
		local queue = self._spellResolveQueue
		return self._spellRecIndexBuild ~= nil or (type(queue) == "table" and type(queue.order) == "table" and table.getn(queue.order) > 0)
	end

	function Talented:UpdateResolverTickerState()
		local frame = self._resolverTicker
		if not frame then
			return
		end
		if self:HasResolverWork() then
			frame:Show()
		else
			frame:Hide()
		end
	end

	function Talented:StartAsyncSpellRecIndex(maxSpellId)
		local getField = _G.GetSpellRecField
		if type(getField) ~= "function" then
			return false
		end
		maxSpellId = tonumber(maxSpellId) or 80000
		if maxSpellId < 1 then
			maxSpellId = 80000
		end
		self:BoostResolverWindow()
		local cache = self._spellRecIndexCache
		if cache and cache.maxSpellId and cache.maxSpellId >= maxSpellId and type(cache.index) == "table" then
			return true
		end
		local build = self._spellRecIndexBuild
		if build and build.maxSpellId and build.maxSpellId >= maxSpellId then
			self:EnsureResolverTicker()
			self:UpdateResolverTickerState()
			return true
		end
		self._spellRecIndexBuild = {
			maxSpellId = maxSpellId,
			nextSpellId = 1,
			getField = getField,
			getIcon = _G.GetSpellIconTexture,
			index = {},
			scores = {},
			durationVotes = {},
			indexed = 0
		}
		self:EnsureResolverTicker()
		self:UpdateResolverTickerState()
		return true
	end

	function Talented:ProcessAsyncSpellRecIndex(maxPerTick, deadline)
		local build = self._spellRecIndexBuild
		if not build then
			return true
		end
		maxPerTick = tonumber(maxPerTick) or RESOLVER_IDS_PER_TICK
		if maxPerTick < 1 then
			maxPerTick = RESOLVER_IDS_PER_TICK
		end
		local count = 0
		while count < maxPerTick and build.nextSpellId <= build.maxSpellId do
			local n = 0
			while n < RESOLVER_IDS_STEP and count < maxPerTick and build.nextSpellId <= build.maxSpellId do
				if IndexSpellRecRecord(build.index, build.scores, build.durationVotes, build.nextSpellId, build.getField, build.getIcon) then
					build.indexed = build.indexed + 1
				end
				build.nextSpellId = build.nextSpellId + 1
				count = count + 1
				n = n + 1
			end
			if deadline and type(GetTime) == "function" and GetTime() >= deadline then
				break
			end
		end
		if build.nextSpellId > build.maxSpellId then
			self._spellRecIndexCache = {
				index = build.index,
				indexed = build.indexed,
				maxSpellId = build.maxSpellId,
				durationHints = BuildDurationHints(build.durationVotes)
			}
			self._spellRecIndexBuild = nil
			ResetSpellRecDescCache()
			return true
		end
		return false
	end

	function Talented:GetSpellRecIndex(maxSpellId, allowSyncBuild)
		maxSpellId = tonumber(maxSpellId) or 80000
		if maxSpellId < 1 then
			maxSpellId = 80000
		end
		if allowSyncBuild == nil then
			allowSyncBuild = true
		end
		local cache = self._spellRecIndexCache
		if cache and cache.maxSpellId and cache.maxSpellId >= maxSpellId and type(cache.index) == "table" then
			return cache.index, cache.indexed or 0
		end
		if not allowSyncBuild then
			self:StartAsyncSpellRecIndex(maxSpellId)
			return cache and cache.index or nil, cache and cache.indexed or 0
		end
		self._spellRecIndexBuild = nil
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
		ResetSpellRecDescCache()
		self:UpdateResolverTickerState()
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

	function Talented:QueueClassSpellResolution(class, maxSpellId)
		if type(_G.GetSpellRecField) ~= "function" then
			return false
		end
		class = type(class) == "string" and string.upper(class) or nil
		if not class then
			return false
		end
		local _, playerClass = UnitClass("player")
		if class == playerClass then
			return false
		end
		local data = self:UncompressSpellData(class)
		if type(data) ~= "table" then
			return false
		end
		maxSpellId = tonumber(maxSpellId) or 80000
		if maxSpellId < 1 then
			maxSpellId = 80000
		end

		local queue = self._spellResolveQueue
		if type(queue) ~= "table" then
			queue = {order = {}, byClass = {}}
			self._spellResolveQueue = queue
		end
		queue.order = queue.order or {}
		queue.byClass = queue.byClass or {}

		local entry = queue.byClass[class]
		if not entry then
			entry = {
				class = class,
				tab = 1,
				index = 1,
				rank = 1,
				maxSpellId = maxSpellId,
				retryAtMax = false
			}
			queue.byClass[class] = entry
			queue.order[table.getn(queue.order) + 1] = class
		elseif maxSpellId > (entry.maxSpellId or 0) then
			entry.maxSpellId = maxSpellId
		end

		self:BoostResolverWindow()
		self:StartAsyncSpellRecIndex(entry.maxSpellId)
		return true
	end

	function Talented:PrimeTemplateSpellResolution(template)
		if type(template) ~= "table" then
			return false
		end
		return self:QueueClassSpellResolution(template.class, 80000)
	end

	function Talented:ProcessClassResolveEntry(entry, budget, deadline)
		local data = self:UncompressSpellData(entry.class)
		if type(data) ~= "table" then
			return true, 0
		end
		local cache = self._spellRecIndexCache
		local spellIndex = cache and cache.index
		local cacheMax = cache and cache.maxSpellId or 0
		local used = 0

		while used < budget do
			local tree = data[entry.tab]
			if not tree then
				if entry.retryAtMax and cacheMax < 200000 then
					entry.retryAtMax = false
					entry.maxSpellId = 200000
					entry.tab = 1
					entry.index = 1
					entry.rank = 1
					self:StartAsyncSpellRecIndex(200000)
					return false, used
				end
				return true, used
			end

			local talent = tree[entry.index]
			if not talent then
				entry.tab = entry.tab + 1
				entry.index = 1
				entry.rank = 1
			else
				local ranks = talent.ranks
				if type(ranks) ~= "table" then
					entry.index = entry.index + 1
					entry.rank = 1
				else
					local maxRank = table.getn(ranks)
					if maxRank < 1 then
						entry.index = entry.index + 1
						entry.rank = 1
					elseif entry.rank > maxRank then
						entry.index = entry.index + 1
						entry.rank = 1
					else
						local current = ranks[entry.rank]
						if type(current) == "number" then
							local resolved = self:ResolveTalentRankSpellID(entry.class, entry.tab, entry.index, entry.rank, spellIndex, true)
							if type(resolved) ~= "number" and cacheMax < 200000 then
								entry.retryAtMax = true
							end
						end
						entry.rank = entry.rank + 1
						used = used + 1
						if deadline and type(GetTime) == "function" and GetTime() >= deadline then
							break
						end
					end
				end
			end
		end

		return false, used
	end

	function Talented:ProcessPendingClassResolves(maxRanks, deadline)
		local queue = self._spellResolveQueue
		if type(queue) ~= "table" or type(queue.order) ~= "table" or type(queue.byClass) ~= "table" then
			return false
		end
		if table.getn(queue.order) < 1 then
			return false
		end
		maxRanks = tonumber(maxRanks) or RESOLVER_RANKS_PER_TICK
		if maxRanks < 1 then
			maxRanks = RESOLVER_RANKS_PER_TICK
		end

		local processed = 0
		local active = false
		local maxSkips = table.getn(queue.order)
		local skips = 0

		while processed < maxRanks and table.getn(queue.order) > 0 do
			if deadline and type(GetTime) == "function" and GetTime() >= deadline then
				break
			end
			local class = table.remove(queue.order, 1)
			local entry = queue.byClass[class]
			if not entry then
				skips = 0
			else
				active = true
				local cache = self._spellRecIndexCache
				local cacheMax = cache and cache.maxSpellId or 0
				local requiredMax = tonumber(entry.maxSpellId) or 80000
				if cacheMax < requiredMax then
					self:StartAsyncSpellRecIndex(requiredMax)
					queue.order[table.getn(queue.order) + 1] = class
					skips = skips + 1
					if skips >= maxSkips then
						break
					end
				else
					local budget = maxRanks - processed
					local done, used = self:ProcessClassResolveEntry(entry, budget, deadline)
					if used > 0 then
						processed = processed + used
					end
					if done then
						queue.byClass[class] = nil
					else
						queue.order[table.getn(queue.order) + 1] = class
					end
					skips = 0
					maxSkips = table.getn(queue.order)
					if maxSkips < 1 then
						maxSkips = 1
					end
				end
			end
		end

		return active or table.getn(queue.order) > 0
	end

	function Talented:OnResolverTick()
		local deadline
		if type(GetTime) == "function" then
			deadline = GetTime() + GetResolverFrameBudget(self)
		end
		if self._spellRecIndexBuild then
			self:ProcessAsyncSpellRecIndex(RESOLVER_IDS_PER_TICK, deadline)
		end
		self:ProcessPendingClassResolves(RESOLVER_RANKS_PER_TICK, deadline)
		self:UpdateResolverTickerState()
	end

	function Talented:ResolveTalentRankSpellID(class, tab, index, rank, spellIndex, nonBlocking)
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
			if nonBlocking then
				spellIndex = self:GetSpellRecIndex(80000, false)
			else
				spellIndex = self:GetSpellRecIndex()
			end
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
				if nonBlocking then
					self:StartAsyncSpellRecIndex(200000)
				else
					spellIndex = self:GetSpellRecIndex(200000)
					resolved = LookupResolvedSpellID(spellIndex, talent.name, rank, iconKey)
				end
			end
		end
		if type(resolved) == "number" then
			if talent.ranks[rank] ~= resolved then
				talent.ranks[rank] = resolved
				self:InvalidateSpellLookupCache()
			end
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
				ResetSpellRecDescCache()
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
			if type(_G.GetSpellRecField) == "function" then
				self:StartAsyncSpellRecIndex(80000)
			end
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
							ResetSpellRecDescCache()
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
		if type(template) ~= "table" or template.talentGroup or type(newname) ~= "string" then
			return
		end
		newname = string.gsub(newname, "^%s+", "")
		newname = string.gsub(newname, "%s+$", "")
		if newname == "" then
			return
		end

		local t = self:GetTemplatesDB()
		local existing = t[newname]
		if existing and existing ~= template then
			return
		end

		local oldkey
		for key, value in pairs(t) do
			if value == template then
				oldkey = key
				break
			end
		end
		template.name = newname
		if oldkey and oldkey ~= newname then
			t[oldkey] = nil
		end
		t[newname] = template
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
				self:PrimeTemplateSpellResolution(template)
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
		self:PrimeTemplateSpellResolution(template)
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
		self:PrimeTemplateSpellResolution(template)
		local view = self:CreateBaseFrame().view
			local old = view.template
			if template ~= old then
				if template.talentGroup then
					view:SetTemplate(template, self:MakeTarget(template.talentGroup))
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

	function Talented:HookCloseSpecialWindows()
		if type(_G.CloseSpecialWindows) ~= "function" then
			return
		end
		if not self._talentedCloseSpecialWindowsOriginal then
			self._talentedCloseSpecialWindowsOriginal = _G.CloseSpecialWindows
		end
		if not self._talentedCloseSpecialWindowsProxy then
			self._talentedCloseSpecialWindowsProxy = function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
				local original = Talented and Talented._talentedCloseSpecialWindowsOriginal
				if type(original) == "function" then
					local ok, handled = pcall(original, a1, a2, a3, a4, a5, a6, a7, a8, a9)
					if ok and handled then
						return handled
					end
				end
				local urlDialog = _G.TalentedURLDialog
				if urlDialog and urlDialog.IsShown and urlDialog:IsShown() then
					urlDialog:Hide()
					return 1
				end
				local importDialog = _G.TalentedImportURLDialog
				if importDialog and importDialog.IsShown and importDialog:IsShown() then
					importDialog:Hide()
					return 1
				end
				if Talented and Talented.base and Talented.base.IsShown and Talented.base:IsShown() then
					local base = Talented.base
					if type(HideUIPanel) == "function" then
						pcall(HideUIPanel, base)
					end
					if base and base.IsShown and base:IsShown() and type(base.Hide) == "function" then
						base:Hide()
					end
					return 1
				end
			end
		end
		if _G.CloseSpecialWindows ~= self._talentedCloseSpecialWindowsProxy then
			_G.CloseSpecialWindows = self._talentedCloseSpecialWindowsProxy
		end
	end

	function Talented:HookCloseAllWindows()
		if type(_G.CloseAllWindows) ~= "function" then
			return
		end
		if not self._talentedCloseAllWindowsOriginal then
			self._talentedCloseAllWindowsOriginal = _G.CloseAllWindows
		end
		if not self._talentedCloseAllWindowsProxy then
			self._talentedCloseAllWindowsProxy = function(ignoreCenter, a1, a2, a3, a4, a5, a6, a7, a8)
				local handled
				local original = Talented and Talented._talentedCloseAllWindowsOriginal
				if type(original) == "function" then
					local ok, result = pcall(original, ignoreCenter, a1, a2, a3, a4, a5, a6, a7, a8)
					if ok then
						handled = result
					end
				end

				local closedTalented
				if Talented and Talented.base and Talented.base.IsShown and Talented.base:IsShown() then
					local base = Talented.base
					if type(HideUIPanel) == "function" then
						pcall(HideUIPanel, base)
					end
					if base and base.IsShown and base:IsShown() and type(base.Hide) == "function" then
						base:Hide()
					end
					closedTalented = 1
				end

				return handled or closedTalented
			end
		end
		if _G.CloseAllWindows ~= self._talentedCloseAllWindowsProxy then
			_G.CloseAllWindows = self._talentedCloseAllWindowsProxy
		end
	end

	function Talented:HookChatWhisperFilter()
		if type(_G.ChatFrame_OnEvent) ~= "function" then
			return
		end
		if not self._talentedChatFrameOnEventOriginal then
			self._talentedChatFrameOnEventOriginal = _G.ChatFrame_OnEvent
		end
		if not self._talentedChatFrameOnEventProxy then
			self._talentedChatFrameOnEventProxy = function(frame, event, a1, a2, a3, a4, a5, a6, a7, a8, a9)
				if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
					local message = a1
					if type(message) ~= "string" then
						message = _G.arg1
					end
					if type(message) == "string" and string.find(message, TALENTED_WHISPER_PREFIX, 1, true) == 1 then
						return
					end
				end
				if event == "CHAT_MSG_CHANNEL" then
					local message = a1
					if type(message) ~= "string" then
						message = _G.arg1
					end
					if type(message) == "string" and string.find(message, TALENTED_LFT_COMM_TAG, 1, true) == 1 then
						return
					end
				end
				return Talented._talentedChatFrameOnEventOriginal(frame, event, a1, a2, a3, a4, a5, a6, a7, a8, a9)
			end
		end
		if _G.ChatFrame_OnEvent ~= self._talentedChatFrameOnEventProxy then
			_G.ChatFrame_OnEvent = self._talentedChatFrameOnEventProxy
		end
	end

	function Talented:OnEnable()
		self:HookTalentFrameToggle()
		self:HookCloseSpecialWindows()
		self:HookCloseAllWindows()
		self:HookChatWhisperFilter()
		self:HookSetItemRef()
		self:HookChatHyperlinkShow()
		self:SecureHook("UpdateMicroButtons")
		self:HookInspectAPI()
		self:CheckHookInspectUI()
		if type(self.EnsureInspectButtons) == "function" then
			self:EnsureInspectButtons()
		end

		self:RegisterEvent("ADDON_LOADED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("CHARACTER_POINTS_CHANGED")
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterEvent("CHAT_MSG_WHISPER")
		self:RegisterEvent("CHAT_MSG_CHANNEL")
	end

	function Talented:OnDisable()
		self:UnhookInspectUI()
		self:UnregisterEvent("CHAT_MSG_WHISPER")
		self:UnregisterEvent("CHAT_MSG_CHANNEL")
		if _G.CloseSpecialWindows == self._talentedCloseSpecialWindowsProxy and type(self._talentedCloseSpecialWindowsOriginal) == "function" then
			_G.CloseSpecialWindows = self._talentedCloseSpecialWindowsOriginal
		end
		if _G.CloseAllWindows == self._talentedCloseAllWindowsProxy and type(self._talentedCloseAllWindowsOriginal) == "function" then
			_G.CloseAllWindows = self._talentedCloseAllWindowsOriginal
		end
		if _G.SetItemRef == self._talentedSetItemRefProxy and type(self._talentedSetItemRefOriginal) == "function" then
			_G.SetItemRef = self._talentedSetItemRefOriginal
		end
		if _G.ChatFrame_OnHyperlinkShow == self._talentedChatHyperlinkProxy and type(self._talentedChatHyperlinkOriginal) == "function" then
			_G.ChatFrame_OnHyperlinkShow = self._talentedChatHyperlinkOriginal
		end
		if _G.ChatFrame_OnEvent == self._talentedChatFrameOnEventProxy and type(self._talentedChatFrameOnEventOriginal) == "function" then
			_G.ChatFrame_OnEvent = self._talentedChatFrameOnEventOriginal
		end
	end

	function Talented:PLAYER_ENTERING_WORLD()
		self:HookTalentFrameToggle()
		self:HookCloseSpecialWindows()
		self:HookCloseAllWindows()
		self:HookInspectAPI()
		if type(self.EnsureInspectButtons) == "function" then
			self:EnsureInspectButtons()
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
		self:HookCloseSpecialWindows()
		self:HookCloseAllWindows()
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
		local function NormalizeTemplateColor(color)
			if type(color) ~= "table" then
				return nil
			end
			local r = tonumber(color.r)
			local g = tonumber(color.g)
			local b = tonumber(color.b)
			if not r or not g or not b then
				return nil
			end
			if r < 0 then r = 0 elseif r > 1 then r = 1 end
			if g < 0 then g = 0 elseif g > 1 then g = 1 end
			if b < 0 then b = 0 elseif b > 1 then b = 1 end
			return {r = r, g = g, b = b}
		end
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
				elseif type(code) == "table" and type(code.code) == "string" then
					local class = code.class or self:GetTemplateStringClass(code.code)
					if class then
						code.class = class
						code.name = name
						code.menuColor = NormalizeTemplateColor(code.menuColor)
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
						if type(template.menuColor) == "table" then
							_db[name] = {
								name = template.name or name,
								class = template.class,
								code = template.code,
								menuColor = {
									r = template.menuColor.r,
									g = template.menuColor.g,
									b = template.menuColor.b
								}
							}
						else
							_db[name] = template.code
						end
					end
				end
			end
			self:RegisterEvent("PLAYER_LOGOUT", "OnDatabaseShutdown")
			self.LoadTemplates = nil
		end
	end
