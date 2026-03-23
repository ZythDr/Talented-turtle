-------------------------------------------------------------------------------
-- inspectui.lua
--

local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local L = _G.TalentedLocale or {}
local TALENTED_TURTLE_WHISPER_PREFIX = "TW_CHAT_MSG_WHISPER"
local TALENTED_TURTLE_COMM_TAG = "TALENTEDCOMM:"

local function CompatGetNumTalentGroups(inspect)
	if type(_G.GetNumTalentGroups) == "function" then
		local ok, value = pcall(_G.GetNumTalentGroups, inspect)
		if ok and type(value) == "number" and value > 0 then
			return value
		end
		ok, value = pcall(_G.GetNumTalentGroups)
		if ok and type(value) == "number" and value > 0 then
			return value
		end
	end
	return 1
end

local function CompatGetActiveTalentGroup(inspect)
	if type(_G.GetActiveTalentGroup) == "function" then
		local ok, value = pcall(_G.GetActiveTalentGroup, inspect)
		if ok and type(value) == "number" and value > 0 then
			return value
		end
		ok, value = pcall(_G.GetActiveTalentGroup)
		if ok and type(value) == "number" and value > 0 then
			return value
		end
	end
	return 1
end

local function SafeFormat(fmt, a1, a2, a3, a4, a5, a6, a7, a8)
	if type(fmt) ~= "string" then
		return tostring(fmt or "")
	end
	local ok, out = pcall(string.format, fmt, a1, a2, a3, a4, a5, a6, a7, a8)
	if ok and type(out) == "string" then
		return out
	end
	return fmt
end

do
	local prev_script
	local prev_inspect_show
	local prev_twinspect_show



	local TURTLE_INSPECT_PREFIX = "TW_CHAT_MSG_WHISPER"
	local TURTLE_INSPECT_DONE = "INSTalentEND;"
	local TURTLE_INSPECT_TALENT_INFO = "INSTalentInfo;"

	-- Talented's own spec store, populated from incoming INSTalentInfo whisper
	-- packets. Used when InspectTalentsComFrame no longer exists as a Lua
	-- global (Turtle WoW 1.18.1+).
	local turtleInspectSpec = {class = ""}
	for _i = 1, 3 do turtleInspectSpec[_i] = {} end
	Talented._turtleInspectSpec = turtleInspectSpec  -- exposed for Debug.lua
	local TURTLE_TALENT_REQUEST = "TalentInfoRequest_"
	local TURTLE_TALENT_ANSWER = ":TalentInfoAnswer_"
	local INSPECT_REQUEST_THROTTLE = 0.75
	local INSPECT_UI_SUPPRESS_WINDOW = 1.25

	local function EncodeTurtleTooltipText(text)
		text = tostring(text or "")
		if text == "" then
			return ""
		end
		return string.gsub(text, ":", "*dd*")
	end

	local function BuildTurtleTooltipPayload(lines)
		if type(lines) ~= "table" then
			return ""
		end
		local out = ""
		for i = 1, table.getn(lines) do
			local line = lines[i]
			local left, right
			if type(line) == "table" then
				left, right = line.left, line.right
			elseif type(line) == "string" then
				left = line
			end
			if type(left) ~= "string" or left == "" then
				left = " "
			end
			if type(right) ~= "string" or right == "" then
				right = " "
			end
			-- Turtle's chat-link tooltip renderer does not clear per-line left/right
			-- text before applying payload. Emit both sides for every line so stale
			-- right-column values (cooldowns/range) cannot bleed across lines.
			out = out .. "L" .. tostring(i) .. ";" .. EncodeTurtleTooltipText(left) .. "@"
			out = out .. "R" .. tostring(i) .. ";" .. EncodeTurtleTooltipText(right) .. "@"
		end
		if type(TOOLTIP_TALENT_LEARN) == "string" and TOOLTIP_TALENT_LEARN ~= "" then
			out = string.gsub(out, TOOLTIP_TALENT_LEARN, "")
		end
		return out
	end

	local function GetTurtleInspectSpec()
		local com = _G.inspectCom or _G.InspectTalentsComFrame
		if type(com) == "table" and type(com.SPEC) == "table" then
			return com.SPEC
		end
		-- 1.18.1: InspectTalentsComFrame no longer exists as a Lua global.
		-- Fall back to Talented's own store populated from INSTalentInfo packets.
		return turtleInspectSpec
	end

	local function HasTurtleInspectAPI()
		-- Returns true when the Turtle WoW turtleSpec path should be used for inspect.
		-- InspectTalentsComFrame / InspectFrameTalentsTab_OnClick: old pre-1.18.1 protocol.
		-- TWTalentFrame: present in 1.18.1+ where INSTalentInfo packets still arrive via
		-- CHAT_MSG_ADDON after Tab4 click, populating turtleInspectSpec.
		-- NOTE: GetTalentInfo(tab, index, true) returns the PLAYER'S OWN talents in Turtle
		-- WoW, not the inspected target's — the turtleSpec path must be used for inspect.
		return _G.InspectTalentsComFrame ~= nil
			or _G.InspectFrameTalentsTab_OnClick ~= nil
			or _G.TWTalentFrame ~= nil
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

	local function GetInspectTalentRank(class, tab, index, talentGroup, preferTurtle)
		local rank
		-- In Turtle WoW 1.18.1, GetTalentInfo(tab, index, true, ...) returns the
		-- player's OWN talents rather than the inspected target's. When the Turtle
		-- whisper-protocol inspect API is present we must rely solely on
		-- inspectCom.SPEC and never fall back to GetTalentInfo(true, ...).
		local hasTurtleAPI = HasTurtleInspectAPI()
		if not preferTurtle and not hasTurtleAPI then
			local _, _, _, _, inspectRank = _G.GetTalentInfo(tab, index, true, nil, talentGroup)
			if type(inspectRank) == "number" then
				return inspectRank, true
			end
		end
		rank = GetTurtleInspectRank(class, tab, index)
		if type(rank) == "number" then
			return rank, true
		end
		if preferTurtle and not hasTurtleAPI then
			local _, _, _, _, inspectRank = _G.GetTalentInfo(tab, index, true, nil, talentGroup)
			if type(inspectRank) == "number" then
				return inspectRank, true
			end
		end
		return 0, false
	end

	local new_script = function(self)
		if prev_script and prev_script ~= new_script then
			pcall(prev_script, self or _G.this)
		end
		Talented:RequestInspectData(Talented:GetInspectUnit(), "inspect-tab")
		Talented:UpdateInspectTemplate()
	end

	local twinspect_show_proxy = function(a1, a2, a3, a4, a5, a6, a7, a8)
		local addon = Talented
		local suppress = addon and addon._suppressInspectTalentsUI
		local untilTime = addon and addon._suppressInspectTalentsUIUntil
		if suppress and type(untilTime) == "number" and type(GetTime) == "function" then
			if GetTime() <= untilTime then
				return
			end
		end
		if prev_twinspect_show and prev_twinspect_show ~= twinspect_show_proxy then
			return prev_twinspect_show(a1, a2, a3, a4, a5, a6, a7, a8)
		end
	end

	local _switchToTab1Frame = CreateFrame("Frame")
	_switchToTab1Frame:Hide()
	_switchToTab1Frame:SetScript("OnUpdate", function()
		_switchToTab1Frame:Hide()
		local tab1 = _G.InspectFrameTab1
		if tab1 then
			-- Use :Click() rather than GetScript("OnClick") because tab OnClick
			-- handlers are defined in XML and not accessible via GetScript in vanilla.
			pcall(function() tab1:Click() end)
		end
	end)

	local function SwitchToTab1()
		-- Defer by one frame so the C-side talent request initiated by Tab4:Click()
		-- has already been dispatched before we switch the panel away.
		_switchToTab1Frame:Show()
	end

	local function TriggerInspectTab4Preload()
		-- 1.18.1: talent data is loaded by Tab4's native C-side handler.
		-- Only trigger when TWTalentFrame exists (1.18.1) but the old Lua whisper
		-- protocol is absent (HasTurtleInspectAPI() = false).
		if _G.InspectTalentsComFrame ~= nil or _G.InspectFrameTalentsTab_OnClick ~= nil then
			return  -- old protocol present: RequestInspectData whisper handles it
		end
		if not (_G.TWTalentFrame and _G.InspectFrameTab4) then
			return
		end
		if not (_G.InspectFrame and _G.InspectFrame:IsShown()) then
			return
		end
		_G.InspectFrameTab4:SetScript("OnClick", prev_script)
		pcall(function() _G.InspectFrameTab4:Click() end)
		_G.InspectFrameTab4:SetScript("OnClick", new_script)
		-- Switch back to Tab1 on the very next frame. The C-side request is already
		-- dispatched by Click(); deferred by one frame so the panel fully registers.
		SwitchToTab1()
	end

	local inspect_show_proxy = function(unit, a1, a2, a3, a4, a5, a6, a7, a8)
		local r1, r2, r3, r4
		if prev_inspect_show and prev_inspect_show ~= inspect_show_proxy then
			r1, r2, r3, r4 = prev_inspect_show(unit, a1, a2, a3, a4, a5, a6, a7, a8)
		end
		Talented:RequestInspectData(unit or Talented:GetInspectUnit(), "inspect-show")
		TriggerInspectTab4Preload()
		Talented:UpdateInspectTemplate()
		return r1, r2, r3, r4
	end

	-- Expose as a method so InspectButtons.lua can call it as a fallback.
	function Talented:TriggerInspectTab4Preload()
		TriggerInspectTab4Preload()
	end

	function Talented:HandleTurtleTalentTooltipRequest(prefix, message, channel, sender)
		if type(prefix) ~= "string" or type(message) ~= "string" then
			return false
		end
		if not string.find(prefix, TURTLE_INSPECT_PREFIX, 1, true) then
			return false
		end
		local tree, packedIndex = string.match(message, TURTLE_TALENT_REQUEST .. "(%d+)_(%d+)")
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
		local lines = self:BuildTalentTooltipLines(class, tab, index, rank)
		local payload = BuildTurtleTooltipPayload(lines)
		if payload ~= "" and type(_G.SendAddonMessage) == "function" and type(sender) == "string" and sender ~= "" then
			local outPrefix = TURTLE_INSPECT_PREFIX .. "<" .. tostring(sender) .. ">"
			pcall(_G.SendAddonMessage, outPrefix, TURTLE_TALENT_ANSWER .. payload, "GUILD")
		end
		return true
	end

	function Talented:RequestInspectData(unit, reason)
		if not unit then
			unit = self:GetInspectUnit()
		end
		if not unit then
			return false
		end
		if type(UnitExists) == "function" and not UnitExists(unit) then
			return false
		end
		if type(CanInspect) == "function" and not CanInspect(unit) then
			return false
		end
		local name = UnitName(unit)
		if not name or name == "" then
			return false
		end
		self._inspectUnitHint = unit
		local level = tonumber(UnitLevel(unit)) or 0
		if level > 0 and level < 10 then
			return false
		end
		if type(GetTime) == "function" then
			local now = GetTime()
			if self._inspectLastRequestName == name and type(self._inspectLastRequestAt) == "number" and (now - self._inspectLastRequestAt) < INSPECT_REQUEST_THROTTLE then
				return false
			end
			self._inspectLastRequestName = name
			self._inspectLastRequestAt = now
			self._inspectOpenPending = nil
			if reason == "inspect-tab" then
				self._suppressInspectTalentsUI = nil
				self._suppressInspectTalentsUIUntil = nil
			else
				self._suppressInspectTalentsUI = true
				self._suppressInspectTalentsUIUntil = now + INSPECT_UI_SUPPRESS_WINDOW
			end
		end
		if type(_G.TWInspectTalents_Show) == "function" and _G.TWInspectTalents_Show ~= twinspect_show_proxy then
			prev_twinspect_show = _G.TWInspectTalents_Show
			_G.TWInspectTalents_Show = twinspect_show_proxy
		end
		if type(_G.NotifyInspect) == "function" then
			self._suppressInspectAPISecureHook = true
			pcall(_G.NotifyInspect, unit)
			self._suppressInspectAPISecureHook = nil
		end
		local requested = false
		-- Always reset turtleInspectSpec for the new inspect target so stale data
		-- from a previous inspect cannot bleed through, and so that the class guard
		-- in GetTurtleInspectRank passes correctly. Must run outside the
		-- HasTurtleInspectAPI() guard, which may vary by client configuration.
		do
			local _, cls = UnitClass(unit)
			if type(cls) == "string" then
				turtleInspectSpec.class = cls
				for i = 1, 3 do turtleInspectSpec[i] = {} end
			end
		end
		if type(_G.SendAddonMessage) == "function" and HasTurtleInspectAPI() then
			local _, class = UnitClass(unit)
			local com = _G.inspectCom or _G.InspectTalentsComFrame
			if type(com) == "table" and type(com.SPEC) == "table" and type(class) == "string" then
				com.SPEC.class = class
				-- Wipe per-talent rank entries left over from the previous inspect.
				-- Ins_Init() only resets tree-level metadata; spec[tab][index] tables
				-- persist and would cause UpdateInspectTemplate to read stale ranks
				-- (which appear to be the viewer's own talents) before the whisper
				-- response arrives. After this clear, GetTurtleInspectRank returns nil
				-- for every slot, so hasInspectData stays false until INSTalentEND.
				for i = 1, 3 do
					if type(com.SPEC[i]) == "table" then
						local j = 1
						while com.SPEC[i][j] ~= nil do
							com.SPEC[i][j] = nil
							j = j + 1
						end
					end
				end
			end
			if unit == "target" and type(_G.Ins_Init) == "function" then
				pcall(_G.Ins_Init)
			end
			local prefix = "TW_CHAT_MSG_WHISPER<" .. tostring(name) .. ">"
			pcall(_G.SendAddonMessage, prefix, "INSShowTalents", "GUILD")
			requested = true
			self:DebugInspect("RequestInspectData: whisper sent  target=" .. tostring(name) .. "  reason=" .. tostring(reason))
		end
		return requested
	end

	function Talented:HookInspectAPI()
		if self._inspectAPIHooked then
			return
		end
		self._inspectAPIHooked = true
		self:SecureHook("NotifyInspect")
		self:SecureHook("InspectUnit")
	end

	function Talented:NotifyInspect(unit)
		if self._suppressInspectAPISecureHook then
			return
		end
		if type(unit) == "string" and unit ~= "" then
			self._inspectUnitHint = unit
		end
		self:RequestInspectData(unit or self:GetInspectUnit(), "notify-hook")
	end

	function Talented:InspectUnit(unit)
		if self._suppressInspectAPISecureHook then
			return
		end
		if type(unit) == "string" and unit ~= "" then
			self._inspectUnitHint = unit
		end
		self:RequestInspectData(unit or self:GetInspectUnit(), "inspect-hook")
	end

	function Talented:HookInspectUI()
		if _G.InspectFrameTab4 and not prev_script then
			prev_script = _G.InspectFrameTab4:GetScript("OnClick")
			_G.InspectFrameTab4:SetScript("OnClick", new_script)
		end
		if type(_G.InspectFrame_Show) == "function" and _G.InspectFrame_Show ~= inspect_show_proxy then
			prev_inspect_show = _G.InspectFrame_Show
			_G.InspectFrame_Show = inspect_show_proxy
		end
		if type(_G.TWInspectTalents_Show) == "function" and _G.TWInspectTalents_Show ~= twinspect_show_proxy then
			prev_twinspect_show = _G.TWInspectTalents_Show
			_G.TWInspectTalents_Show = twinspect_show_proxy
		end
		self:RequestInspectData(self:GetInspectUnit(), "hook-inspect")
	end

	function Talented:UnhookInspectUI()
		if not _G.InspectFrameTab4 then
			prev_script = nil
			if _G.InspectFrame_Show == inspect_show_proxy and prev_inspect_show then
				_G.InspectFrame_Show = prev_inspect_show
			end
			prev_inspect_show = nil
			if _G.TWInspectTalents_Show == twinspect_show_proxy and prev_twinspect_show then
				_G.TWInspectTalents_Show = prev_twinspect_show
			end
			prev_twinspect_show = nil
			self._suppressInspectTalentsUI = nil
			self._suppressInspectTalentsUIUntil = nil
			return
		end
		if prev_script then
			_G.InspectFrameTab4:SetScript("OnClick", prev_script)
			prev_script = nil
		end
		if _G.InspectFrame_Show == inspect_show_proxy and prev_inspect_show then
			_G.InspectFrame_Show = prev_inspect_show
		end
		prev_inspect_show = nil
		if _G.TWInspectTalents_Show == twinspect_show_proxy and prev_twinspect_show then
			_G.TWInspectTalents_Show = prev_twinspect_show
		end
		prev_twinspect_show = nil
		self._suppressInspectTalentsUI = nil
		self._suppressInspectTalentsUIUntil = nil
	end

	function Talented:CheckHookInspectUI()
		self:RegisterEvent("CHAT_MSG_ADDON")
		if self.db.profile.hook_inspect_ui then
			self:RegisterEvent("INSPECT_TALENT_READY")
			self:RegisterEvent("PLAYER_TARGET_CHANGED")
			if _G.InspectFrameTab4 or IsAddOnLoaded("Blizzard_InspectUI") then
				self:HookInspectUI()
			end
		else
			self:UnregisterEvent("INSPECT_TALENT_READY")
			self:UnregisterEvent("PLAYER_TARGET_CHANGED")
			if _G.InspectFrameTab4 or IsAddOnLoaded("Blizzard_InspectUI") then
				self:UnhookInspectUI()
			end
		end
	end

	function Talented:ADDON_LOADED(addon)
		self:HookSetItemRef()
		self:HookChatHyperlinkShow()
		if addon == "Blizzard_InspectUI" or addon == "SuperInspect" then
			if type(self.EnsureInspectButtons) == "function" then
				self:EnsureInspectButtons()
			end
		end
		if addon == "Blizzard_TalentUI" then
			self:HookTalentFrameToggle()
			return
		end
		if addon == "Blizzard_InspectUI" and self.db and self.db.profile and self.db.profile.hook_inspect_ui then
			self:CheckHookInspectUI()
			self:RequestInspectData(self:GetInspectUnit(), "addon-loaded")
		end
	end

	function Talented:GetInspectUnit()
		if InspectFrame and InspectFrame.unit then
			return InspectFrame.unit
		end
		if self._inspectUnitHint and type(UnitExists) == "function" and UnitExists(self._inspectUnitHint) and type(CanInspect) == "function" and CanInspect(self._inspectUnitHint) then
			return self._inspectUnitHint
		end
		if type(UnitExists) == "function" and UnitExists("target") and type(CanInspect) == "function" and CanInspect("target") then
			return "target"
		end
		return nil
	end

	function Talented:INSPECT_TALENT_READY()
		local template = self:UpdateInspectTemplate()
		-- In 1.18.1, INSPECT_TALENT_READY fires after Tab4 preload loads talent data.
		-- Auto-open Talented if the user already clicked the button.
		if template and self._inspectOpenPending and type(self.OpenTemplate) == "function" then
			self._inspectOpenPending = nil
			self:OpenTemplate(template)
		end
		if type(self.UpdateInspectButtons) == "function" then
			self:UpdateInspectButtons()
		end
	end

	function Talented:PLAYER_TARGET_CHANGED()
		if self.db and self.db.profile and not self.db.profile.hook_inspect_ui then
			return
		end
		if not InspectFrame or not InspectFrame:IsShown() then
			if type(self.UpdateInspectButtons) == "function" then
				self:UpdateInspectButtons()
			end
			return
		end
		self:RequestInspectData(self:GetInspectUnit(), "target-changed")
		if type(self.UpdateInspectButtons) == "function" then
			self:UpdateInspectButtons()
		end
	end

	function Talented:CHAT_MSG_ADDON(prefix, message, channel, sender)
		if type(prefix) ~= "string" or type(message) ~= "string" then
			return
		end
		if string.find(prefix, TALENTED_TURTLE_WHISPER_PREFIX, 1, true) and string.find(message, TALENTED_TURTLE_COMM_TAG, 1, true) == 1 then
			local payload = string.sub(message, string.len(TALENTED_TURTLE_COMM_TAG) + 1)
			local commPrefix, body = string.match(payload or "", "^(.-)\031(.*)$")
			if commPrefix and commPrefix ~= "" and body then
				self:OnCommReceived(commPrefix, body, "WHISPER", sender)
			end
			return
		end
		if self:HandleTurtleTalentTooltipRequest(prefix, message, channel, sender) then
			return
		end
		if not string.find(prefix, TURTLE_INSPECT_PREFIX, 1, true) then
			return
		end
		-- Parse INSTalentInfo packets into Talented's own spec store.
		-- In Turtle WoW 1.18.1, InspectTalentsComFrame no longer exists as a
		-- Lua global, so nobody else processes these packets.
		if string.find(message, TURTLE_INSPECT_TALENT_INFO, 1, true) then
			local parts = {}
			for part in string.gfind(message, "[^;]+") do
				parts[table.getn(parts) + 1] = part
			end
			local treeIdx  = tonumber(parts[2])
			local talentIdx = tonumber(parts[3])
			local currRank  = tonumber(parts[7])
			if treeIdx and talentIdx and currRank then
				if not turtleInspectSpec[treeIdx] then
					turtleInspectSpec[treeIdx] = {}
				end
				turtleInspectSpec[treeIdx][talentIdx] = {rank = currRank}
			end
			return
		end
		if not string.find(message, TURTLE_INSPECT_DONE, 1, true) then
			return
		end
		self:DebugInspect("CHAT_MSG_ADDON: INSTalentEND received  sender=" .. tostring(sender))
		local template = self:UpdateInspectTemplate()
		if template and self._inspectOpenPending and type(self.OpenTemplate) == "function" then
			self._inspectOpenPending = nil
			self:OpenTemplate(template)
		end
		if type(self.UpdateInspectButtons) == "function" then
			self:UpdateInspectButtons()
		end
	end

	function Talented:UpdateInspectTemplate()
		local unit = self:GetInspectUnit()
		if not unit then return end
		local name = UnitName(unit)
		if not name then return end
		local rawLevel = tonumber(UnitLevel(unit)) or 0
		if rawLevel > 0 and rawLevel < 10 then
			return nil
		end
		local level = rawLevel > 0 and rawLevel or nil
		local inspections = self.inspections or {}
		self.inspections = inspections
		local _, class = UnitClass(unit)
		local info = self:UncompressSpellData(class)
		if not info then
			return
		end
		self:QueueClassSpellResolution(class, 80000)
		local turtleSpec = GetTurtleInspectSpec()
		local useTurtleInspect = HasTurtleInspectAPI()
		if useTurtleInspect and type(turtleSpec) == "table" and type(turtleSpec.class) == "string" and turtleSpec.class ~= class then
			useTurtleInspect = false
		end
		self:DebugInspect("UpdateInspectTemplate: reading SPEC  unit=" .. tostring(unit) .. "  class=" .. tostring(class) .. "  useTurtleInspect=" .. tostring(useTurtleInspect))
		local retval
		for talentGroup = 1, CompatGetNumTalentGroups(true) do
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
					name = SafeFormat(L["Inspection of %s"], name) .. (talentGroup == CompatGetActiveTalentGroup(true) and "" or L[" (alt)"]),
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
			local levelText = level and tostring(level) or "?"
			template.menu_name = string.format("%s - %s", tostring(name), levelText) .. (talentGroup == CompatGetActiveTalentGroup(true) and "" or L[" (alt)"])
			template.name = SafeFormat(L["Inspection of %s"], name) .. string.format(" (Level %s)", levelText) .. (talentGroup == CompatGetActiveTalentGroup(true) and "" or L[" (alt)"])
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
				if talentGroup == CompatGetActiveTalentGroup(true) then
					retval = template
				end
			end
		end
		return retval
	end
end
