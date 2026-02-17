-------------------------------------------------------------------------------
-- learn.lua
--

local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local L = _G.TalentedLocale or {}

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

local function SafeGetActiveTalentGroup(inspect, pet)
	if type(_G.GetActiveTalentGroup) ~= "function" then
		return 1
	end
	local ok, value = pcall(_G.GetActiveTalentGroup, inspect, pet)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(_G.GetActiveTalentGroup)
	if ok and type(value) == "number" then
		return value
	end
	return 1
end

local function SafeGetUnspentTalentPoints(inspect, pet, group)
	if pet then
		return 0
	end
	if type(_G.GetUnspentTalentPoints) ~= "function" then
		if type(_G.UnitCharacterPoints) == "function" then
			local ok, cp = pcall(_G.UnitCharacterPoints, "player")
			if ok and type(cp) == "number" then
				return cp
			end
		end
		return 0
	end
	local ok, value = pcall(_G.GetUnspentTalentPoints)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(_G.GetUnspentTalentPoints, inspect, pet, group)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(_G.GetUnspentTalentPoints, group)
	if ok and type(value) == "number" then
		return value
	end
	return 0
end

local function SafeLearnTalent(tab, index, pet)
	if pet or type(_G.LearnTalent) ~= "function" then
		return
	end
	local ok = pcall(_G.LearnTalent, tab, index, pet)
	if not ok then
		pcall(_G.LearnTalent, tab, index)
	end
end

do
	local StaticPopupDialogs = StaticPopupDialogs
	local function ResolvePopupFrameFromThis()
		local widget = _G.this
		if type(widget) ~= "table" then
			return nil
		end
		if widget.which then
			return widget
		end
		if type(widget.GetParent) == "function" then
			local parent = widget:GetParent()
			if type(parent) == "table" and parent.which then
				return parent
			end
		end
		return nil
	end

	local function ShowDialog(text, tab, index, pet)
		StaticPopupDialogs.TALENTED_CONFIRM_LEARN = {
			button1 = YES,
			button2 = NO,
			OnAccept = function(data)
				local tabIndex, talentIndex, isPet
				if type(data) == "table" then
					tabIndex = data.talent_tab
					talentIndex = data.talent_index
					isPet = data.is_pet
				end
				if tabIndex == nil or talentIndex == nil then
					local popup = ResolvePopupFrameFromThis()
					if popup then
						tabIndex = popup.talent_tab
						talentIndex = popup.talent_index
						isPet = popup.is_pet
					end
				end
				if tabIndex == nil or talentIndex == nil then
					return
				end
				SafeLearnTalent(tabIndex, talentIndex, isPet)
			end,
			timeout = 0,
			exclusive = 1,
			whileDead = 1,
			interruptCinematic = 1
		}
		ShowDialog = function(text, tab, index, pet)
			StaticPopupDialogs.TALENTED_CONFIRM_LEARN.text = text
			local dlg = StaticPopup_Show("TALENTED_CONFIRM_LEARN", nil, nil, {
				talent_tab = tab,
				talent_index = index,
				is_pet = pet
			})
			if dlg then
				dlg.talent_tab = tab
				dlg.talent_index = index
				dlg.is_pet = pet
			end
			return dlg
		end
		return ShowDialog(text, tab, index, pet)
	end

	function Talented:LearnTalent(template, tab, index, bypassConfirm)
		local is_pet = not RAID_CLASS_COLORS[template.class]
		local p = self.db.profile

		if not p.always_call_learn_talents then
			local state = self:GetTalentState(template, tab, index)
			if
				state == "full" or -- talent maxed out
					state == "unavailable" or -- prereqs not fullfilled
					SafeGetUnspentTalentPoints(nil, is_pet, SafeGetActiveTalentGroup(nil, is_pet)) == 0
			 then -- no more points
					return
				end
			end

		if bypassConfirm or not p.confirmlearn then
			SafeLearnTalent(tab, index, is_pet)
			return
		end

		ShowDialog(SafeFormat(L['Are you sure that you want to learn "%s (%d/%d)" ?'], self:GetTalentName(template.class, tab, index), template[tab][index] + 1, self:GetTalentRanks(template.class, tab, index)), tab, index, is_pet)
	end
end
