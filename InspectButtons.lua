local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local L = _G.TalentedLocale or setmetatable({}, {__index = function(t, k) t[k] = k return k end})

local function CreateOpenButton(name, parent, x, y)
	if type(parent) ~= "table" then
		return nil
	end
	local button = _G[name]
	if not button then
		button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
	end
	button:SetWidth(90)
	button:SetHeight(20)
	button:SetText(L["Talented"])
	button:ClearAllPoints()
	button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x or -40, y or -40)
	button:SetScript("OnClick", function()
		Talented:OpenInspectedTemplateFromButton()
	end)
	return button
end

function Talented:OpenInspectedTemplateFromButton()
	local template = self:UpdateInspectTemplate()
	if not template and type(self.inspections) == "table" then
		local unit = self:GetInspectUnit()
		local name = unit and UnitName(unit)
		if type(name) == "string" and name ~= "" then
			local preferred = name .. " - " .. tostring(GetActiveTalentGroup(true))
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
	if not (self.db and self.db.profile and self.db.profile.hook_inspect_ui) then
		return
	end
	if _G.InspectFrame then
		self.inspectOpenInTalentedButton = self.inspectOpenInTalentedButton or CreateOpenButton("TalentedInspectOpenButton", _G.InspectFrame, -38, -34)
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
	local b = self.inspectOpenInTalentedButton
	if b then
		local show = false
		if enabled and _G.InspectFrame and _G.InspectFrame:IsShown() and _G.InspectFrameTab3 then
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
