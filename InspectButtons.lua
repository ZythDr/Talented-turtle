local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local L = _G.TalentedLocale or setmetatable({}, {__index = function(t, k) t[k] = k return k end})

local function GetSafeActiveTalentGroup()
	if type(_G.GetActiveTalentGroup) == "function" then
		local ok, group = pcall(_G.GetActiveTalentGroup, true)
		if ok and type(group) == "number" and group > 0 then
			return group
		end
		ok, group = pcall(_G.GetActiveTalentGroup)
		if ok and type(group) == "number" and group > 0 then
			return group
		end
	end
	return 1
end

local function CreateOpenButton(name, parent, x, y, point, relativePoint)
	if type(parent) ~= "table" then
		return nil
	end
	local button = _G[name]
	if not button then
		button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
	end
	button:SetWidth(74)
	button:SetHeight(20)
	button:SetText(L["Talented"])
	button:ClearAllPoints()
	button:SetPoint(point or "TOPRIGHT", parent, relativePoint or point or "TOPRIGHT", x or -40, y or -40)
	button:SetScript("OnClick", function()
		Talented:OpenInspectedTemplateFromButton()
	end)
	return button
end

local function AnchorOpenTab(tab)
	if type(tab) ~= "table" then
		return
	end
	tab:ClearAllPoints()
	if type(_G.InspectFrameTab3) == "table" then
		tab:SetPoint("TOPLEFT", _G.InspectFrameTab3, "TOPRIGHT", -16, 0)
	elseif type(_G.InspectFrameTab2) == "table" then
		tab:SetPoint("TOPLEFT", _G.InspectFrameTab2, "TOPRIGHT", -16, 0)
	else
		tab:SetPoint("TOPLEFT", _G.InspectFrame, "BOTTOMLEFT", 100, 2)
	end
end

local function CreateOpenTab(name, parent)
	if type(parent) ~= "table" or type(_G.InspectFrameTab3) ~= "table" then
		return nil
	end
	local tab = _G[name]
	if not tab then
		tab = CreateFrame("Button", name, parent, "CharacterFrameTabButtonTemplate")
	end
	tab:SetText(L["Talented"])
	tab:SetID(4)
	if type(PanelTemplates_TabResize) == "function" then
		PanelTemplates_TabResize(0, tab)
	end
	AnchorOpenTab(tab)
	tab:SetScript("OnClick", function(self)
		local tabButton = self or _G.this
		if type(PlaySound) == "function" then
			PlaySound("igCharacterInfoTab")
		end
		Talented:OpenInspectedTemplateFromButton()
		if tabButton and type(PanelTemplates_DeselectTab) == "function" then
			PanelTemplates_DeselectTab(tabButton)
		end
		if tabButton and type(tabButton.SetChecked) == "function" then
			tabButton:SetChecked(nil)
		end
		if tabButton and type(tabButton.UnlockHighlight) == "function" then
			tabButton:UnlockHighlight()
		end
	end)
	return tab
end

function Talented:OpenInspectedTemplateFromButton()
	local unit = self:GetInspectUnit()
	local level = unit and tonumber(UnitLevel(unit)) or 0
	if level > 0 and level < 10 then
		self:Print(L["Target must be at least level 10 to have talents."])
		return
	end

	local template = self:UpdateInspectTemplate()
	if not template and type(self.inspections) == "table" then
		local name = unit and UnitName(unit)
		if type(name) == "string" and name ~= "" then
			local preferred = name .. " - " .. tostring(GetSafeActiveTalentGroup())
			template = self.inspections[preferred]
			if not template then
				for _, value in pairs(self.inspections) do
					if type(value) == "table" and value.inspect_name == name then
						template = value
						break
					end
				end
			end
		end
	end
	if not template then
		self:Print(L["No inspected talent data is available yet."])
		return
	end
	self:OpenTemplate(template)
end

function Talented:EnsureInspectButtons()
	if _G.InspectFrame then
		self.inspectOpenInTalentedButton = self.inspectOpenInTalentedButton or CreateOpenButton("TalentedInspectOpenButton", _G.InspectFrame, -42, 82, "BOTTOMRIGHT", "BOTTOMRIGHT")
		-- Create once as soon as inspect talent tab exists, so skin addons can catch it.
		if not self.inspectOpenInTalentedTab and _G.InspectFrameTab3 then
			self.inspectOpenInTalentedTab = CreateOpenTab("InspectFrameTab4", _G.InspectFrame)
		end
	end
	if _G.SuperInspectFrame then
		self.superInspectOpenInTalentedButton = self.superInspectOpenInTalentedButton or CreateOpenButton("TalentedSuperInspectOpenButton", _G.SuperInspectFrame, -10, -50)
	end
	if not self._inspectButtonUpdateFrame then
		local watcher = CreateFrame("Frame")
		local elapsed = 0
		watcher:SetScript("OnUpdate", function()
			elapsed = elapsed + (arg1 or 0)
			if elapsed < 0.25 then
				return
			end
			elapsed = 0
			Talented:UpdateInspectButtons()
		end)
		self._inspectButtonUpdateFrame = watcher
	end
	self:UpdateInspectButtons()
end

function Talented:UpdateInspectButtons()
	local enabled = self.db and self.db.profile and self.db.profile.hook_inspect_ui
	local useTab = self.db and self.db.profile and self.db.profile.inspect_open_as_tab
	local b = self.inspectOpenInTalentedButton
	local t = self.inspectOpenInTalentedTab

	if enabled and _G.InspectFrame and _G.InspectFrameTab3 and (not t) then
		t = CreateOpenTab("InspectFrameTab4", _G.InspectFrame)
		self.inspectOpenInTalentedTab = t
	end
	if b then
		local show = false
		if enabled and not useTab and _G.InspectFrame and _G.InspectFrame:IsShown() and _G.InspectFrameTab3 then
			if type(_G.InspectFrameTab3.GetChecked) == "function" then
				show = _G.InspectFrameTab3:GetChecked() and true or false
			else
				show = true
			end
		end
		if show then
			b:Show()
		else
			b:Hide()
		end
	end
	if t then
		local show = enabled and useTab and _G.InspectFrame and _G.InspectFrame:IsShown()
		if show then
			if type(_G.PanelTemplates_SetNumTabs) == "function" and _G.InspectFrame then
				PanelTemplates_SetNumTabs(_G.InspectFrame, 4)
			end
			AnchorOpenTab(t)
			t:Show()
			if type(PanelTemplates_TabResize) == "function" then
				PanelTemplates_TabResize(0, t)
			end
			if type(PanelTemplates_DeselectTab) == "function" then
				PanelTemplates_DeselectTab(t)
			end
			if type(t.SetChecked) == "function" then
				t:SetChecked(nil)
			end
			if type(t.UnlockHighlight) == "function" then
				t:UnlockHighlight()
			end
		else
			t:Hide()
			if type(_G.PanelTemplates_SetNumTabs) == "function" and _G.InspectFrame then
				PanelTemplates_SetNumTabs(_G.InspectFrame, 3)
			end
		end
	end

	local s = self.superInspectOpenInTalentedButton
	if s then
		local show = enabled and _G.SuperInspectFrame and _G.SuperInspectFrame:IsShown()
		if show then
			s:Show()
		else
			s:Hide()
		end
	end
end
