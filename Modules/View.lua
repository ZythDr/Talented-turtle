local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local L = _G.TalentedLocale or {}
local RawUnitCharacterPoints = _G.UnitCharacterPoints

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

local function SetTextSafe(widget, text)
	if widget and type(widget.SetText) == "function" then
		widget:SetText(tostring(text or ""))
	end
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

local function CompatGetNumTalentTabs(inspect, pet, talentGroup)
	if pet then
		return 0
	end
	if type(_G.GetNumTalentTabs) ~= "function" then
		return 0
	end
	local ok, value = pcall(_G.GetNumTalentTabs, inspect, pet, talentGroup)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(_G.GetNumTalentTabs, inspect)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(_G.GetNumTalentTabs)
	if ok and type(value) == "number" then
		return value
	end
	return 0
end

local function CompatGetTalentTabInfo(tab, inspect, pet, talentGroup)
	if pet then
		return nil
	end
	if type(_G.GetTalentTabInfo) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e, f, g, h = pcall(_G.GetTalentTabInfo, tab, inspect, pet, talentGroup)
	if ok and a ~= nil then
		return a, b, c, d, e, f, g, h
	end
	ok, a, b, c, d, e, f, g, h = pcall(_G.GetTalentTabInfo, tab, inspect)
	if ok and a ~= nil then
		return a, b, c, d, e, f, g, h
	end
	ok, a, b, c, d, e, f, g, h = pcall(_G.GetTalentTabInfo, tab)
	if ok then
		return a, b, c, d, e, f, g, h
	end
	return nil
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
	if type(_G.GetUnspentTalentPoints) ~= "function" then
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

local function CompatGetActiveTalentGroup()
	if type(_G.GetActiveTalentGroup) == "function" then
		local ok, value = pcall(_G.GetActiveTalentGroup)
		if ok and type(value) == "number" and value > 0 then
			return value
		end
	end
	return 1
end

local GetNumTalentTabs = CompatGetNumTalentTabs
local GetTalentTabInfo = CompatGetTalentTabInfo

function Talented:GetTreeBackgroundDimAlpha()
	local p = self.db and self.db.profile
	if p and p.dim_tree_background then
		return 0.3
	end
	return 0
end

function Talented:ApplyTreeBackgroundDim(frame)
	if not frame then
		return
	end
	local dim = self:GetTreeBackgroundDimAlpha()
	local function ApplyShade(tex)
		if not tex then
			return
		end
		if type(tex.SetVertexColor) == "function" then
			tex:SetVertexColor(1, 1, 1, 1)
		end
		if type(tex.SetAlpha) == "function" then
			tex:SetAlpha(1)
		end
	end
	ApplyShade(frame.topleft)
	ApplyShade(frame.topright)
	ApplyShade(frame.bottomleft)
	ApplyShade(frame.bottomright)

	-- Disable old per-tree overlay path.
	if frame._talentedDimOverlay and type(frame._talentedDimOverlay.Hide) == "function" then
		frame._talentedDimOverlay:Hide()
	end

	-- One shared overlay across all visible trees for this view.
	local view = frame.view
	local root = view and view.frame
	local overlay = root and root._talentedTreeDimOverlay
	if root and not overlay and type(root.CreateTexture) == "function" then
		overlay = root:CreateTexture(nil, "ARTWORK")
		root._talentedTreeDimOverlay = overlay
		overlay:SetTexture(0, 0, 0, 1)
		overlay:SetDrawLayer("ARTWORK", 0)
		if type(overlay.SetBlendMode) == "function" then
			overlay:SetBlendMode("BLEND")
		end
	end
	if overlay and view then
		local left = tonumber(view._treeDimLeft) or 4
		local top = tonumber(view._treeDimTop) or 24
		local width = tonumber(view._treeDimWidth) or 0
		local height = tonumber(view._treeDimHeight) or 0
		if width > 0 and height > 0 and type(overlay.ClearAllPoints) == "function" and type(overlay.SetPoint) == "function" then
			overlay:ClearAllPoints()
			overlay:SetPoint("TOPLEFT", root, "TOPLEFT", left, -top)
			overlay:SetPoint("BOTTOMRIGHT", root, "TOPLEFT", left + width, -(top + height))
		end
		if dim > 0 and width > 0 and height > 0 then
			if type(overlay.SetAlpha) == "function" then
				overlay:SetAlpha(dim)
			end
			if type(overlay.Show) == "function" then
				overlay:Show()
			end
		else
			if type(overlay.Hide) == "function" then
				overlay:Hide()
			end
		end
	end
end
local GetUnspentTalentPoints = CompatGetUnspentTalentPoints
local GetActiveTalentGroup = CompatGetActiveTalentGroup

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
		self.externalTreeTitles = {}
	end

	local function EnsureExternalTreeTitle(self, tab, treeFrame)
		if type(self.externalTreeTitles) ~= "table" then
			self.externalTreeTitles = {}
		end
		local fs = self.externalTreeTitles[tab]
		if not fs and self.frame and type(self.frame.CreateFontString) == "function" then
			fs = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			self.externalTreeTitles[tab] = fs
		end
		if fs and treeFrame then
			fs:ClearAllPoints()
			fs:SetPoint("TOP", treeFrame, "TOP", 0, -4)
			fs:SetJustifyH("CENTER")
			fs:SetWidth(treeFrame:GetWidth() or 0)
			fs:Show()
		end
		return fs
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
		if not inspect and not pet and type(RawUnitCharacterPoints) == "function" then
			local spent = 0
			for i = 1, GetNumTalentTabs() do
				local _, _, points = GetTalentTabInfo(i)
				spent = spent + (points or 0)
			end
			local ok, unspent = pcall(RawUnitCharacterPoints, "player")
			if ok and type(unspent) == "number" then
				return spent + unspent
			end
		end
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
			if frame.name and type(frame.name.Hide) == "function" then
				frame.name:Hide()
			end

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
			EnsureExternalTreeTitle(self, tab, frame)
		end
		if type(self.externalTreeTitles) == "table" then
			for i = table.getn(talents) + 1, table.getn(self.externalTreeTitles) do
				local fs = self.externalTreeTitles[i]
				if fs and type(fs.Hide) == "function" then
					fs:Hide()
				end
			end
		end
		self._treeDimLeft = LAYOUT_BASE_X
		self._treeDimTop = top_offset
		self._treeDimWidth = table.getn(talents) * LAYOUT_SIZE_X
		self._treeDimHeight = size_y
		self.frame:SetSize(table.getn(talents) * LAYOUT_SIZE_X + LAYOUT_BASE_X * 2, size_y + top_offset + bottom_offset)
		self.frame:SetScale(Talented.db.profile.scale)

			self.class = class
			self:Update()
			if type(Talented.RunSkinCallbacks) == "function" then
				Talented:RunSkinCallbacks("view-set-class")
			end
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
			if type(Talented.RunSkinCallbacks) == "function" then
				Talented:RunSkinCallbacks("view-set-template")
			end

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
		local editLocked = Talented:IsEditLockedForTemplate(template, self.pet)
		local editing = (self.mode == "edit" and not editLocked)
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
								if state == "empty" and (at_cap or not editing) then
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
										if editing then
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
					Talented:ApplyTreeBackgroundDim(frame)
					local fs = EnsureExternalTreeTitle(self, tab, frame)
					if fs then
						SetFormattedTextSafe(fs, L["%s (%d)"], Talented.tabdata[template.class][tab].name, count)
					else
						SetFormattedTextSafe(frame.name, L["%s (%d)"], Talented.tabdata[template.class][tab].name, count)
					end
					total = total + count
					local clear = frame.clear
					if not editing or count <= 0 or self.spec then
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
			local remaining
			if template and template.talentGroup and not self.pet and type(RawUnitCharacterPoints) == "function" then
				local ok, value = pcall(RawUnitCharacterPoints, "player")
				if ok and type(value) == "number" then
					remaining = value
				end
			end
			if type(remaining) ~= "number" then
				remaining = maxpoints - total
			end
			local color = NORMAL_FONT_COLOR
			if remaining > 0 then
				color = GREEN_FONT_COLOR
			elseif remaining < 0 then
				color = RED_FONT_COLOR
			end
			pointsleft:Show()
			SetFormattedTextSafe(pointsleft.text, L["Remaining points: %d"], remaining)
			pointsleft.text:SetTextColor(color.r, color.g, color.b)
		end
		local edit = self.frame.editname
		local colorbutton = self.frame.templatecolor
		if edit then
			if template.talentGroup then
				edit:Hide()
				if colorbutton then
					colorbutton:Hide()
				end
			else
				edit:Show()
				SetTextSafe(edit, template and template.name)
				if Talented.GetTemplateMenuColor then
					local r, g, b = Talented:GetTemplateMenuColor(template)
					if r then
						edit:SetTextColor(r, g, b)
					else
						edit:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
					end
				end
				if colorbutton then
					local canColor = Talented.IsTemplateMenuColorEditable and Talented:IsTemplateMenuColorEditable(template)
					if canColor then
						colorbutton:Show()
						if Talented.RefreshTemplateColorButton then
							Talented:RefreshTemplateColorButton(colorbutton, template)
						end
					else
						colorbutton:Hide()
					end
				end
			end
		elseif colorbutton then
			colorbutton:Hide()
		end
			local cb, activate = self.frame.checkbox, self.frame.bactivate
				if cb then
					if template.talentGroup == GetActiveTalentGroup() then
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
				cb:SetChecked(editing and true or false)
				if editLocked then
					cb:Disable()
					if cb.label and type(cb.label.SetTextColor) == "function" then
						cb.label:SetTextColor(0.5, 0.5, 0.5)
					end
				else
					cb:Enable()
					if cb.label and type(cb.label.SetTextColor) == "function" then
						cb.label:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
					end
				end
			end
			local targetname = self.frame.targetname
			if targetname then
				if template.talentGroup then
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
		if type(edit.Insert) == "function" then
			local ok = pcall(edit.Insert, edit, link)
			if ok then
				if type(edit.SetFocus) == "function" then
					pcall(edit.SetFocus, edit)
				end
				return true
			end
		end
		if type(_G.ChatEdit_InsertLink) == "function" then
			local ok, inserted = pcall(_G.ChatEdit_InsertLink, link)
			if ok and inserted ~= false then
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
			local rank = self.template and self.template[tab] and self.template[tab][index]
			local link = Talented:GetTalentLink(self.template, tab, index, rank)
			local inserted
			if link then
				-- Vanilla behavior: modified-click inserts into an active chat
				-- edit box only. If chat is not active, do nothing.
				inserted = TryInsertLinkInChat(link)
			end
			-- Shift-click QoL: if chat is not active and this is a live talent view,
			-- treat it as a quick-learn action (bypass confirm popup).
			if not inserted and button == "LeftButton" and self.mode == "edit" and self.spec and self.template and self.template.talentGroup and type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown() and not GetOpenChatEditBox() then
				self:UpdateTalent(tab, index, 1, true)
			end
			return
		else
			self:UpdateTalent(tab, index, button == "LeftButton" and 1 or -1)
		end
	end

	function TalentView:UpdateTalent(tab, index, offset, bypassConfirm)
		if self.mode ~= "edit" then return end
		if Talented:IsEditLockedForTemplate(self.template, self.pet) then return end
		if self.spec then
			-- Applying talent
			if offset > 0 then
				Talented:LearnTalent(self.template, tab, index, bypassConfirm)
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
		if template and not template.talentGroup and not template.inspect_name then
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
