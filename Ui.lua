local Talented = _G.Talented
local L = _G.TalentedLocale or setmetatable({}, {__index = function(t, k)
	t[k] = k
	return k
end})

-- globals
local RawCreateFrame = CreateFrame
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local min, max = math.min, math.max
local GameTooltip = GameTooltip
local TALENT_SPEC_PRIMARY = _G.TALENT_SPEC_PRIMARY or TALENTS or "Primary"
local TALENT_SPEC_SECONDARY = _G.TALENT_SPEC_SECONDARY or "Secondary"
local TALENT_SPEC_ACTIVATE = _G.TALENT_SPEC_ACTIVATE or ACTIVATE or "Activate"
local GetNumTalentGroups = function()
	return 1
end
local GetActiveTalentGroup = function()
	return 1
end
local SetActiveTalentGroup = function()
end

local function EnsureSetSize(obj)
	if obj and type(obj.SetSize) ~= "function" then
		obj.SetSize = function(self, w, h)
			if w ~= nil then
				self:SetWidth(w)
			end
			if h ~= nil then
				self:SetHeight(h)
			end
		end
	end
	return obj
end

local function SetTextSafe(widget, text)
	if not widget or type(widget.SetText) ~= "function" then
		return
	end
	widget:SetText(tostring(text or ""))
end

local function TalentedTexture(file)
	local root = Talented and Talented.textureRoot
	if type(root) ~= "string" or root == "" then
		root = _G.TALENTED_TEXTURE_ROOT
	end
	if type(root) ~= "string" or root == "" then
		root = "Interface\\AddOns\\Talented-turtle\\Textures\\"
	end
	return root .. file
end

local function CreateTexture(base, layer, path, blend)
	local t = base:CreateTexture(nil, layer)
	if path then
		t:SetTexture(path)
	end
	if blend then
		t:SetBlendMode(blend)
	end
	return t
end

local function CreateAllPointsTexture(base, layer, path, blend)
	local t = CreateTexture(base, layer, path, blend)
	t:SetAllPoints(base)
	return t
end

local function WrapWidgetFactories(frame)
	if not frame or frame._talentedSetSizeWrapped then
		return frame
	end
	frame._talentedSetSizeWrapped = true
	if frame.SetScript then
		local oldSetScript = frame.SetScript
		frame.SetScript = function(self, scriptType, handler)
			if type(handler) ~= "function" then
				return oldSetScript(self, scriptType, handler)
			end
			if scriptType == "OnEvent" then
				return oldSetScript(self, scriptType, function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
					local owner = this or self
					return handler(owner, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, a1, a2, a3, a4, a5, a6, a7, a8, a9)
				end)
			end
			return oldSetScript(self, scriptType, function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
				local owner = this or self
				if a1 == nil then a1 = _G.arg1 end
				if a2 == nil then a2 = _G.arg2 end
				if a3 == nil then a3 = _G.arg3 end
				if a4 == nil then a4 = _G.arg4 end
				if a5 == nil then a5 = _G.arg5 end
				if a6 == nil then a6 = _G.arg6 end
				if a7 == nil then a7 = _G.arg7 end
				if a8 == nil then a8 = _G.arg8 end
				if a9 == nil then a9 = _G.arg9 end
				return handler(owner, a1, a2, a3, a4, a5, a6, a7, a8, a9)
			end)
		end
	end
	if frame.CreateTexture then
		local oldCreateTexture = frame.CreateTexture
		frame.CreateTexture = function(self, a1, a2, a3, a4, a5, a6, a7, a8, a9)
			return EnsureSetSize(oldCreateTexture(self, a1, a2, a3, a4, a5, a6, a7, a8, a9))
		end
	end
	if frame.CreateFontString then
		local oldCreateFontString = frame.CreateFontString
		frame.CreateFontString = function(self, a1, a2, a3, a4, a5, a6, a7, a8, a9)
			return EnsureSetSize(oldCreateFontString(self, a1, a2, a3, a4, a5, a6, a7, a8, a9))
		end
	end
	return frame
end

local function CreateFrame(frameType, name, parent, inherits)
	return EnsureSetSize(WrapWidgetFactories(RawCreateFrame(frameType, name, parent, inherits)))
end

-------------------------------------------------------------------------------
-- ui\pool.lua - Talented.Pool
--

do
	local rawget, rawset = rawget, rawset
	local setmetatable = setmetatable
	local pairs, ipairs = pairs, ipairs

	local Pool = {pools = {}, sets = {}}

	function Pool:new()
		local pool = setmetatable({used = {}, available = {}}, self)
		self.pools[pool] = true
		return pool
	end

	function Pool:changeSet(name)
		if not self.sets[name] then
			self.sets[name] = {}
		end
		assert(self.sets[name])
		self.set = name
		self:clearSet(name)
	end

	function Pool:clearSet(name)
		local set = self.sets[name]
		assert(set)
		for widget, pool in pairs(set) do
			assert(pool.used[widget])
			widget:Hide()
			pool.used[widget] = nil
			pool.available[widget] = true
			set[widget] = nil
		end
	end

	function Pool:AddToSet(widget, pool)
		self.sets[self.set][widget] = pool
	end

	Pool.__index = {
		next = function(self)
			local widget = next(self.available)
			if not widget then return end
			self.available[widget] = nil
			self.used[widget] = true
			widget:Show()
			Pool:AddToSet(widget, self)
			return widget
		end,
		push = function(self, widget)
			self.used[widget] = true
			Pool:AddToSet(widget, self)
		end
	}

	Talented.Pool = Pool
end

-------------------------------------------------------------------------------
-- ui\base.lua
--

do
	local PlaySound = PlaySound

	Talented.uielements = {}

	-- All this exists so that a UIPanelButtonTemplate2 like button correctly works
	-- with :SetButtonState(). This is because the state is only updated after
	-- :OnMouse{Up|Down}().

	local BUTTON_TEXTURES = {
		NORMAL = "Interface\\Buttons\\UI-Panel-Button-Up",
		PUSHED = "Interface\\Buttons\\UI-Panel-Button-Down",
		DISABLED = "Interface\\Buttons\\UI-Panel-Button-Disabled",
		PUSHED_DISABLED = "Interface\\Buttons\\UI-Panel-Button-Disabled-Down"
	}
	local DefaultButton_Enable = GameMenuButtonOptions.Enable
	local DefaultButton_Disable = GameMenuButtonOptions.Disable
	local DefaultButton_SetButtonState = GameMenuButtonOptions.SetButtonState
	local function Button_SetState(self, state)
		if not state then
			if self:IsEnabled() == 0 then
				state = "DISABLED"
			else
				state = self:GetButtonState()
			end
		end
		if state == "DISABLED" and self.locked_state == "PUSHED" then
			state = "PUSHED_DISABLED"
		end
		local texture = BUTTON_TEXTURES[state]
		self.left:SetTexture(texture)
		self.middle:SetTexture(texture)
		self.right:SetTexture(texture)
		if self._talentedText then
			self._talentedText:SetFontObject((state == "DISABLED" or state == "PUSHED_DISABLED") and GameFontDisable or GameFontNormal)
		end
	end

	local function Button_SetButtonState(self, state, locked)
		self.locked_state = locked and state
		if self:IsEnabled() ~= 0 then
			DefaultButton_SetButtonState(self, state, locked)
		end
		Button_SetState(self)
	end

	local function Button_OnMouseDown(self)
		Button_SetState(self, self:IsEnabled() == 0 and "DISABLED" or "PUSHED")
	end

	local function Button_OnMouseUp(self)
		Button_SetState(self, self:IsEnabled() == 0 and "DISABLED" or "NORMAL")
	end

	local function Button_Enable(self)
		DefaultButton_Enable(self)
		if self.locked_state then
			Button_SetButtonState(self, self.locked_state, true)
		else
			Button_SetState(self)
		end
	end

	local function Button_Disable(self)
		DefaultButton_Disable(self)
		Button_SetState(self)
	end

	local function MakeButton(parent)
		local button = CreateFrame("Button", nil, parent)
		-- Keep a dedicated label for consistent text rendering in Vanilla.
		local nativeSetText = button.SetText
		local nativeGetTextWidth = button.GetTextWidth
		local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("CENTER", button, "CENTER", 0, 0)
		button._talentedText = text
		function button:SetText(value)
			value = tostring(value or "")
			self._talentedText:SetText(value)
		end
		function button:GetTextWidth()
			local w = self._talentedText:GetStringWidth()
			if type(w) == "number" and w > 0 then
				return w
			end
			if type(nativeGetTextWidth) == "function" then
				local ok, nativeWidth = pcall(nativeGetTextWidth, self)
				if ok and type(nativeWidth) == "number" then
					return nativeWidth
				end
			end
			return 0
		end
		local setNormalFontObject = button.SetNormalFontObject
		if type(setNormalFontObject) == "function" then
			setNormalFontObject(button, GameFontNormal)
		end
		if button._talentedText then
			button._talentedText:SetFontObject(GameFontNormal)
		end
		local setHighlightFontObject = button.SetHighlightFontObject
		if type(setHighlightFontObject) == "function" then
			setHighlightFontObject(button, GameFontHighlight)
		end
		local setDisabledFontObject = button.SetDisabledFontObject
		if type(setDisabledFontObject) == "function" then
			setDisabledFontObject(button, GameFontDisable)
		end

		local texture = button:CreateTexture()
		texture:SetTexCoord(0, 0.09375, 0, 0.6875)
		texture:SetPoint("LEFT", button, "LEFT", 0, 0)
		texture:SetSize(12, 22)
		button.left = texture

		texture = button:CreateTexture()
		texture:SetTexCoord(0.53125, 0.625, 0, 0.6875)
		texture:SetPoint("RIGHT", button, "RIGHT", 0, 0)
		texture:SetSize(12, 22)
		button.right = texture

		texture = button:CreateTexture()
		texture:SetTexCoord(0.09375, 0.53125, 0, 0.6875)
		texture:SetPoint("LEFT", button.left, "RIGHT")
		texture:SetPoint("RIGHT", button.right, "LEFT")
		texture:SetHeight(22)
		button.middle = texture

		texture = button:CreateTexture()
		texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
		texture:SetBlendMode("ADD")
		texture:SetTexCoord(0, 0.625, 0, 0.6875)
		texture:SetAllPoints(button)
		button:SetHighlightTexture(texture)

		button:SetScript("OnMouseDown", Button_OnMouseDown)
		button:SetScript("OnMouseUp", Button_OnMouseUp)
		button:SetScript("OnShow", Button_SetState)
		button.Enable = Button_Enable
		button.Disable = Button_Disable
		button.SetButtonState = Button_SetButtonState
		Button_SetState(button, "NORMAL")

		table.insert(Talented.uielements, button)
		return button
	end

	local function CreateBaseButtons(parent)
		local TEMPLATE_NAME_WIDTH = 248 -- 50% wider than previous 165

		local function Frame_OnEnter(self)
			self = self or this
			if not self then
				return
			end
			if self.tooltip then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
				GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, 1)
			end
		end

		local function Frame_OnLeave(self)
			self = self or this
			if not self then
				return
			end
			if GameTooltip:IsOwned(self) then
				GameTooltip:Hide()
			end
		end

		local b = MakeButton(parent)
		SetTextSafe(b, L["Actions"])
		b:SetSize(max(100, b:GetTextWidth() + 22), 22)
		b:SetScript("OnClick", function(self) Talented:OpenActionMenu(self) end)
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -4)
		parent.bactions = b

		b = MakeButton(parent)
		SetTextSafe(b, L["Templates"])
		b:SetSize(max(100, b:GetTextWidth() + 22), 22)
		b:SetScript("OnClick", function(self) Talented:OpenTemplateMenu(self) end)
		b:SetPoint("LEFT", parent.bactions, "RIGHT", 14, 0)
		parent.bmode = b

		local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
		e:SetFontObject(ChatFontNormal)
		e:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
		e:SetSize(TEMPLATE_NAME_WIDTH, 13)
		e:SetAutoFocus(false)
		e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		e:SetScript("OnEditFocusLost", function(self)
			SetTextSafe(self, Talented.template and Talented.template.name)
		end)
		e:SetScript("OnEnterPressed", function(self)
			Talented:UpdateTemplateName(Talented.template, self:GetText())
			Talented:UpdateView()
			self:ClearFocus()
		end)
		e:SetScript("OnEnter", Frame_OnEnter)
		e:SetScript("OnLeave", Frame_OnLeave)
		e:SetPoint("LEFT", parent.bmode, "RIGHT", 14, 1)
		e.tooltip = L["You can edit the name of the template here. You must press the Enter key to save your changes."]
		parent.editname = e

		local color = CreateFrame("Button", nil, parent)
		color:SetSize(14, 14)
		color:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		color:SetPoint("LEFT", e, "RIGHT", 4, 0)
		color:SetScript("OnClick", function(self, button)
			button = button or _G.arg1 or "LeftButton"
			local template = Talented.template
			if not Talented:IsTemplateMenuColorEditable(template) then
				return
			end
			if button == "RightButton" then
				Talented:ClearTemplateMenuColor(template)
				Talented:UpdateView()
				return
			end
			Talented:OpenTemplateColorPicker(template, self)
		end)
		color:SetScript("OnEnter", Frame_OnEnter)
		color:SetScript("OnLeave", Frame_OnLeave)
		color.tooltip = "Left-click: choose a template color. Right-click: clear custom color."
		local swatch = color:CreateTexture(nil, "ARTWORK")
		swatch:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
		swatch:SetAllPoints(color)
		color.swatch = swatch
		parent.templatecolor = color
		table.insert(Talented.uielements, color)

		local targetname = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		targetname:SetJustifyH("LEFT")
		targetname:SetSize(TEMPLATE_NAME_WIDTH, 13)
		targetname:SetPoint("LEFT", parent.bmode, "RIGHT", 14, 0)
		parent.targetname = targetname

		do
			local f = CreateFrame("Frame", nil, parent)
			f:SetSize(20, 20)
			f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 8)
			f:SetFrameLevel(parent:GetFrameLevel() + 2)

			local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			text:SetJustifyH("RIGHT")
			text:SetSize(400, 20)
			text:SetPoint("RIGHT", f, "RIGHT", 1, 1)
			f.text = text
			parent.pointsleft = f
		end

		local cb = CreateFrame("Checkbutton", nil, parent)
		parent.checkbox = cb

		cb:SetSize(20, 20)

		local label = cb:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		label:SetJustifyH("LEFT")
		label:SetSize(400, 20)
		label:SetPoint("LEFT", cb, "RIGHT", 1, 1)
		cb.label = label

		cb:SetNormalTexture(CreateAllPointsTexture(cb, nil, "Interface\\Buttons\\UI-CheckBox-Up"))
		cb:SetPushedTexture(CreateAllPointsTexture(cb, nil, "Interface\\Buttons\\UI-CheckBox-Down"))
		cb:SetDisabledTexture(CreateAllPointsTexture(cb, nil, "Interface\\Buttons\\UI-CheckBox-Check-Disabled"))
		cb:SetCheckedTexture(CreateAllPointsTexture(cb, nil, "Interface\\Buttons\\UI-CheckBox-Check"))
		cb:SetHighlightTexture(CreateAllPointsTexture(cb, nil, "Interface\\Buttons\\UI-CheckBox-Highlight", "ADD"))
		cb:SetScript("OnClick", function() Talented:SetMode(Talented.mode == "edit" and "view" or "edit") end)
		cb:SetScript("OnEnter", Frame_OnEnter)
		cb:SetScript("OnLeave", Frame_OnLeave)
		cb:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 8)
		cb:SetFrameLevel(parent:GetFrameLevel() + 2)

		local points = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		points:SetJustifyH("RIGHT")
		points:SetSize(80, 14)
		points:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -6)
		parent.points = points

		b = MakeButton(parent)
		SetTextSafe(b, TALENT_SPEC_ACTIVATE)
		b:SetSize(b:GetTextWidth() + 40, 22)
		b:SetScript("OnClick", function(self)
			if self.talentGroup then
				SetActiveTalentGroup(self.talentGroup)
			end
		end)
		b:SetPoint("BOTTOM", parent, "BOTTOM", 0, 6)
		b:SetFrameLevel(parent:GetFrameLevel() + 2)
		parent.bactivate = b
	end

	local function BaseFrame_SetTabSize(self, tabs)
		tabs = tabs or 3
		local editname, targetname, points = self.editname, self.targetname, self.points
		editname:ClearAllPoints()
		targetname:ClearAllPoints()
		points:ClearAllPoints()
		if tabs == 1 then
			editname:SetPoint("TOPLEFT", self.bactions, "BOTTOMLEFT", 0, -31)
			targetname:SetPoint("TOPLEFT", self.bactions, "BOTTOMLEFT", 0, -32)
			points:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -56)
		elseif tabs == 2 then
			editname:SetPoint("TOPLEFT", self.bmode, "BOTTOMLEFT", 0, -31)
			targetname:SetPoint("TOPLEFT", self.bmode, "BOTTOMLEFT", 0, -32)
			points:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -31)
		elseif tabs == 3 then
			editname:SetPoint("LEFT", self.bmode, "RIGHT", 14, 1)
			targetname:SetPoint("LEFT", self.bmode, "RIGHT", 14, 0)
			points:SetPoint("TOPRIGHT", self, "TOPRIGHT", -40, -6)
		end
	end

	local function CloseButton_OnClick(self, button)
		if button == "LeftButton" then
			if self.OnClick then
				self:OnClick(button)
			else
				self:GetParent():Hide()
			end
		else
			Talented:OpenLockMenu(self, self:GetParent())
		end
	end

	function Talented:CreateCloseButton(parent, OnClickHandler)
		local close = CreateFrame("Button", nil, parent)
		close:SetNormalTexture(CreateAllPointsTexture(close, nil, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"))
		close:SetPushedTexture(CreateAllPointsTexture(close, nil, "Interface\\Buttons\\UI-Panel-MinimizeButton-Down"))
		close:SetHighlightTexture(CreateAllPointsTexture(close, nil, "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD"))
		close:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		close:SetScript("OnClick", CloseButton_OnClick)
		close.OnClick = OnClickHandler

		close:SetSize(32, 32)
		close:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 1, 0)

		return close
	end

	function Talented:SyncTalentViewFrameLevels(view)
		if type(view) ~= "table" or type(view.GetUIElement) ~= "function" then
			return
		end
		local holder = view.frame
		if type(holder) ~= "table" or type(holder.GetFrameLevel) ~= "function" then
			return
		end
		local template = view.template
		if type(template) ~= "table" or type(template.class) ~= "string" then
			return
		end
		local trees = self:UncompressSpellData(template.class)
		if type(trees) ~= "table" then
			return
		end

		local baseLevel = holder:GetFrameLevel() or 0
		-- Keep tree art/lines at holder level and icon buttons one level above.
		-- This preserves intra-tree ordering without sinking elements behind backdrop.
		local treeLevel = baseLevel
		local buttonLevel = baseLevel + 1
		-- Keep arrow overlay on the same frame level as buttons.
		-- Arrow textures already use draw layer "OVERLAY", so tips render above icons
		-- without escaping above unrelated addon windows.
		local overlayLevel = buttonLevel
		local clearLevel = baseLevel + 2

		for tab, tree in ipairs(trees) do
			local frame = view:GetUIElement(tab)
			if frame and type(frame.SetFrameLevel) == "function" then
				frame:SetFrameLevel(treeLevel)
				if frame.overlay and type(frame.overlay.SetFrameLevel) == "function" then
					frame.overlay:SetFrameLevel(overlayLevel)
				end
				if frame.clear and type(frame.clear.SetFrameLevel) == "function" then
					frame.clear:SetFrameLevel(clearLevel)
				end
			end
			if type(tree) == "table" then
				for index, talent in ipairs(tree) do
					if not talent.inactive then
						local button = view:GetUIElement(tab, index)
						if button and type(button.SetFrameLevel) == "function" then
							button:SetFrameLevel(buttonLevel)
						end
					end
				end
			end
		end
	end

	function Talented:SyncAllTalentFrameLevels()
		if type(self.IterateTalentViews) ~= "function" then
			return
		end
		for _, view in self:IterateTalentViews() do
			self:SyncTalentViewFrameLevels(view)
		end
	end

	function Talented:CreateBaseFrame()
		local frame = _G.TalentedFrame or CreateFrame("Frame", "TalentedFrame", UIParent)
		frame:Hide()

		frame:SetFrameStrata("DIALOG")
		frame:EnableMouse(true)
		frame:SetToplevel(true)
		frame:SetSize(50, 50)
		frame:SetBackdrop({
			bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			edgeSize = 16,
			tileSize = 32,
			insets = {left = 5, right = 5, top = 5, bottom = 5}
		})

		local close = self:CreateCloseButton(frame, function(self) HideUIPanel(self:GetParent()) end)
		frame.close = close
		table.insert(Talented.uielements, close)

		CreateBaseButtons(frame)

		UISpecialFrames[table.getn(UISpecialFrames) + 1] = "TalentedFrame"

		frame:SetScript("OnShow", function()
			Talented:RegisterEvent("MODIFIER_STATE_CHANGED")
			if frame.bactions and type(frame.bactions.SetButtonState) == "function" then
				frame.bactions:SetButtonState("NORMAL")
			end
			if frame.bmode and type(frame.bmode.SetButtonState) == "function" then
				frame.bmode:SetButtonState("NORMAL")
			end
			if type(SetButtonPulse) == "function" and TalentMicroButton then
				SetButtonPulse(TalentMicroButton, 0, 1)
			end
			if type(PlaySound) == "function" then
				PlaySound("TalentScreenOpen")
			end
			frame._talentedLastFrameLevel = nil
			Talented:SyncAllTalentFrameLevels()
			Talented:UpdateMicroButtons()
		end)
		frame:SetScript("OnUpdate", function(self)
			local level = self:GetFrameLevel()
			if level ~= self._talentedLastFrameLevel then
				self._talentedLastFrameLevel = level
				Talented:SyncAllTalentFrameLevels()
			end
		end)
		frame:SetScript("OnHide", function()
			if type(PlaySound) == "function" then
				PlaySound("TalentScreenClose")
			end
			if Talented.mode == "apply" then
				Talented:SetMode(Talented:GetDefaultMode())
				Talented:Print(L["Error! Talented window has been closed during template application. Please reapply later."])
				Talented:EnableUI(true)
			end
			Talented:CloseMenu()
			Talented:UpdateMicroButtons()
			Talented:UnregisterEvent("MODIFIER_STATE_CHANGED")
		end)
		frame.SetTabSize = BaseFrame_SetTabSize
		frame.view = self.TalentView:new(frame, "base")
		self:LoadFramePosition(frame)
		self:SetFrameLock(frame)

			self.base = frame
			if type(self.RunSkinCallbacks) == "function" then
				self:RunSkinCallbacks("base-created")
			end
			self.CreateBaseFrame = function(self)
				return self.base
			end
		return frame
	end

	function Talented:EnableUI(enable)
		if enable then
			for _, element in ipairs(self.uielements) do
				element:Enable()
			end
		else
			for _, element in ipairs(self.uielements) do
				element:Disable()
			end
		end
	end

	function Talented:MakeAlternateView()
		local frame = CreateFrame("Frame", "TalentedAltFrame", UIParent)

		frame:SetFrameStrata("DIALOG")
		if _G.TalentedFrame then
			frame:SetFrameLevel(_G.TalentedFrame:GetFrameLevel() + 5)
		end
		frame:EnableMouse(true)
		frame:SetToplevel(true)
		frame:SetSize(50, 50)
		frame:SetBackdrop({
			bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			edgeSize = 16,
			tileSize = 32,
			insets = {left = 5, right = 5, top = 5, bottom = 5}
		})

		frame.close = self:CreateCloseButton(frame)
		frame.view = self.TalentView:new(frame, "alt")
		frame:SetScript("OnShow", function(self)
			self._talentedLastFrameLevel = nil
			Talented:SyncAllTalentFrameLevels()
		end)
		frame:SetScript("OnUpdate", function(self)
			local level = self:GetFrameLevel()
			if level ~= self._talentedLastFrameLevel then
				self._talentedLastFrameLevel = level
				Talented:SyncAllTalentFrameLevels()
			end
		end)
		self:LoadFramePosition(frame)
		self:SetFrameLock(frame)

		self.altView = frame
		self.MakeAlternateView = function(self)
			return self.altView
		end
		return frame
	end
end

-------------------------------------------------------------------------------
-- ui\trees.lua
--

do
	local trees = Talented.Pool:new()

	local function Layout(frame, width, height)
		local texture_height = height / (256 + 75)
		local texture_width = width / (256 + 44)

		frame:SetSize(width, height)

		local wl, wr, ht, hb = texture_width * 256, texture_width * 64, texture_height * 256, texture_height * 128

		frame.topleft:SetSize(wl, ht)
		frame.topright:SetSize(wr, ht)
		frame.bottomleft:SetSize(wl, hb)
		frame.bottomright:SetSize(wr, hb)

		frame.name:SetWidth(width)
	end

	local function ClearBranchButton_OnClick(self)
		local parent = self:GetParent()
		if parent.view then
			parent.view:ClearTalentTab(parent.tab)
		else
			Talented:ClearTalentTab(self:GetParent().tab)
		end
	end

	local function NewTalentFrame(parent)
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

		local t = CreateTexture(frame, "BACKGROUND")
		t:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		frame.topleft = t

		t = CreateTexture(frame, "BACKGROUND")
		t:SetPoint("TOPLEFT", frame.topleft, "TOPRIGHT")
		frame.topright = t

		t = CreateTexture(frame, "BACKGROUND")
		t:SetPoint("TOPLEFT", frame.topleft, "BOTTOMLEFT")
		frame.bottomleft = t

		t = CreateTexture(frame, "BACKGROUND")
		t:SetPoint("TOPLEFT", frame.topleft, "BOTTOMRIGHT")
		frame.bottomright = t

		-- Optional dim layer over the tree artwork (kept below branch/icon layers).
		local dim = CreateTexture(frame, "BACKGROUND")
		dim:SetTexture(0, 0, 0, 0)
		dim:SetAllPoints(frame)
		frame.dim = dim

		local fs = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		fs:SetPoint("TOP", frame, "TOP", 0, -4)
		fs:SetJustifyH("CENTER")
		frame.name = fs

		local overlay = CreateFrame("Frame", nil, frame)
		overlay:SetAllPoints(frame)

		frame.overlay = overlay

		local clear = CreateFrame("Button", nil, frame)
		frame.clear = clear

		clear:SetNormalTexture(CreateAllPointsTexture(clear, nil, "Interface\\Buttons\\CancelButton-Up"))
		clear:SetPushedTexture(CreateAllPointsTexture(clear, nil, "Interface\\Buttons\\CancelButton-Down"))
		clear:SetHighlightTexture(CreateAllPointsTexture(clear, nil, "Interface\\Buttons\\CancelButton-Highlight", "ADD"))

		clear:SetScript("OnClick", ClearBranchButton_OnClick)
		clear:SetScript("OnEnter", Talented.base.editname:GetScript("OnEnter"))
		clear:SetScript("OnLeave", Talented.base.editname:GetScript("OnLeave"))
		clear.tooltip = L["Remove all talent points from this tree."]
		clear:SetSize(32, 32)
		clear:ClearAllPoints()
		clear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

		trees:push(frame)

		return frame
	end

	function Talented:MakeTalentFrame(parent, width, height)
		local tree = trees:next()
		if tree then
			tree:SetParent(parent)
		else
			tree = NewTalentFrame(parent)
		end
		Layout(tree, width, height)
		if self.ApplyTreeBackgroundDim then
			self:ApplyTreeBackgroundDim(tree)
		end
		return tree
	end
end

-------------------------------------------------------------------------------
-- ui\buttons.lua
--

do
	local buttons = Talented.Pool:new()

	local function Button_OnEnter(self)
		local parent = self:GetParent()
		parent.view:SetTooltipInfo(self, parent.tab, self.id)
	end

	local function Button_OnLeave(self)
		Talented:HideTooltipInfo()
	end

	local function Button_OnClick(self, button, down)
		local parent = self:GetParent()
		button = button or _G.arg1 or "LeftButton"
		parent.view:OnTalentClick(button, parent.tab, self.id)
	end

	local function MakeRankFrame(button, anchor)
		local t = CreateTexture(button, "OVERLAY", TalentedTexture("border"))
		t:SetSize(32, 32)
		t:SetPoint("CENTER", button, anchor)
		local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs.texture = t
		fs:SetPoint("CENTER", t)
		return fs
	end

	local function NewButton(parent)
		local button = CreateFrame("Button", nil, parent)
		-- ItemButtonTemplate (minus Count and Slot)
		button:SetSize(37, 37)
		local t = CreateTexture(button, "BORDER")
		t:SetSize(64, 64)
		t:SetAllPoints(button)
		button.texture = t
		t = CreateTexture(button, nil, "Interface\\Buttons\\UI-Quickslot2")
		t:SetSize(64, 64)
		t:SetPoint("CENTER", button, "CENTER", 0, -1)
		button:SetNormalTexture(t)
		t = CreateTexture(button, nil, "Interface\\Buttons\\UI-Quickslot-Depress")
		t:SetSize(36, 36)
		t:SetPoint("CENTER", button, "CENTER", 0, 0)
		button:SetPushedTexture(t)
		t = CreateTexture(button, nil, "Interface\\Buttons\\ButtonHilight-Square", "ADD")
		t:SetSize(36, 36)
		t:SetPoint("CENTER", button, "CENTER", 0, 0)
		button:SetHighlightTexture(t)
		-- TalentButtonTemplate
		local texture = CreateTexture(button, "BACKGROUND", "Interface\\Buttons\\UI-EmptySlot-White")
		texture:SetSize(64, 64)
		texture:SetPoint("CENTER", button, "CENTER", 0, -1)
		button.slot = texture

		button.rank = MakeRankFrame(button, "BOTTOMRIGHT")

		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		button:SetScript("OnEnter", Button_OnEnter)
		button:SetScript("OnLeave", Button_OnLeave)
		button:SetScript("OnClick", Button_OnClick)

		buttons:push(button)
		return button
	end

	function Talented:MakeButton(parent)
		local button = buttons:next()
		local p = parent
		if button then
			button:SetParent(p)
		else
			button = NewButton(p)
		end
		return button
	end

	function Talented:GetButtonTarget(button)
		local target = button.target
		if not target then
			target = MakeRankFrame(button, "TOPRIGHT")
			button.target = target
		end
		return target
	end
end

-------------------------------------------------------------------------------
-- ui\branches.lua
--

do
	local branches = Talented.Pool:new()

	local function NewBranch(parent)
		local t = parent:CreateTexture(nil, "BORDER")
		t:SetTexture(TalentedTexture("branches-normal"))
		t:SetSize(32, 32)
		t:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

		branches:push(t)

		return t
	end

	function Talented:MakeBranch(parent)
		local branch = branches:next()
		if branch then
			branch:SetParent(parent)
		else
			branch = NewBranch(parent)
		end
		return branch
	end
end

-------------------------------------------------------------------------------
-- ui\arrows.lua
--

do
	local arrows = Talented.Pool:new()

	local function NewArrow(parent)
		local t = parent:CreateTexture(nil, "OVERLAY")
		t:SetTexture(TalentedTexture("arrows-normal"))
		t:SetSize(32, 32)
		t:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

		arrows:push(t)

		return t
	end

	function Talented:MakeArrow(parent)
		local arrow = arrows:next()
		if arrow then
			arrow:SetParent(parent.overlay)
		else
			arrow = NewArrow(parent.overlay)
		end
		return arrow
	end
end

-------------------------------------------------------------------------------
-- ui\lines.lua
--

do
	local COORDS = {
		branch = {
			top = {left = 0.12890625, width = 0.125, height = 0.96875},
			left = {left = 0.2578125, width = 0.125},
			topright = {left = 0.515625, width = 0.125},
			topleft = {left = 0.640625, width = -0.125}
		},
		arrow = {
			top = {left = 0, width = 0.5},
			left = {left = 0.5, width = 0.5},
			right = {left = 1.0, width = -0.5}
		}
	}

	local function SetTextureCoords(object, type, subtype)
		local coords = COORDS[type] and COORDS[type][subtype]
		if not coords then return end

		local left = coords.left
		local right = left + coords.width
		local bottom = coords.height or 1

		object:SetTexCoord(left, right, 0, bottom)
	end

	local function DrawVerticalLine(list, parent, offset, base_row, base_column, row, column)
		if column ~= base_column then
			return false
		end
		for i = row + 1, base_row - 1 do
			local x, y = offset(i, column)
			local branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x + 2, y + 32)
			list[table.getn(list) + 1] = branch
			SetTextureCoords(branch, "branch", "top")
			branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x + 2, y)
			list[table.getn(list) + 1] = branch
			SetTextureCoords(branch, "branch", "top")
		end
		local x, y = offset(base_row, base_column)
		local branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x + 2, y + 32)
		list[table.getn(list) + 1] = branch
		SetTextureCoords(branch, "branch", "top")
		local arrow = Talented:MakeArrow(parent)
		SetTextureCoords(arrow, "arrow", "top")
		arrow:SetPoint("TOPLEFT", x + 2, y + 16)
		list[table.getn(list) + 1] = arrow

		return true
	end

	local function DrawHorizontalLine(list, parent, offset, base_row, base_column, row, column)
		if row ~= base_row then
			return false
		end
		for i = min(base_column, column) + 1, max(base_column, column) - 1 do
			local x, y = offset(row, i)
			local branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x - 32, y - 2)
			list[table.getn(list) + 1] = branch
			SetTextureCoords(branch, "branch", "left")
			branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x, y - 2)
			list[table.getn(list) + 1] = branch
			SetTextureCoords(branch, "branch", "left")
		end
		local x, y = offset(base_row, base_column)
		local branch = Talented:MakeBranch(parent)
		list[table.getn(list) + 1] = branch
		SetTextureCoords(branch, "branch", "left")
		local arrow = Talented:MakeArrow(parent)
		if base_column < column then
			SetTextureCoords(arrow, "arrow", "right")
			arrow:SetPoint("TOPLEFT", x + 20, y - 2)
			branch:SetPoint("TOPLEFT", x + 32, y - 2)
		else
			SetTextureCoords(arrow, "arrow", "left")
			arrow:SetPoint("TOPLEFT", x - 15, y - 2)
			branch:SetPoint("TOPLEFT", x - 32, y - 2)
		end
		list[table.getn(list) + 1] = arrow
		return true
	end

	local function DrawHorizontalVerticalLine(list, parent, offset, base_row, base_column, row, column)
		local min_row, max_row, min_column, max_column
		--[[
			FIXME : I need to check if this line is possible and return false if not.
			Note that for the current trees, it's never impossible.
		]]
		if base_column < column then
			min_column = base_column + 1
			max_column = column - 1
		else
			min_column = column + 1
			max_column = base_column - 1
		end

		for i = min_column, max_column do
			local x, y = offset(row, i)
			local branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x - 32, y - 2)
			list[table.getn(list) + 1] = branch
			SetTextureCoords(branch, "branch", "left")
			branch = Talented:MakeBranch(parent)
			branch:SetPoint("TOPLEFT", x, y - 2)
			list[table.getn(list) + 1] = branch
			SetTextureCoords(branch, "branch", "left")
		end

		local x, y = offset(row, base_column)
		local branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x + 2, y - 2)
		list[table.getn(list) + 1] = branch
		local branch2 = Talented:MakeBranch(parent)
		SetTextureCoords(branch2, "branch", "left")
		list[table.getn(list) + 1] = branch2
		if base_column < column then
			branch2:SetPoint("TOPLEFT", x + 35, y - 2)
			SetTextureCoords(branch, "branch", "topleft")
		else
			branch2:SetPoint("TOPLEFT", x - 29, y - 2)
			SetTextureCoords(branch, "branch", "topright")
		end

		for i = row + 1, base_row - 1 do
			local xofs, yofs = offset(i, base_column)
			local b = Talented:MakeBranch(parent)
			b:SetPoint("TOPLEFT", xofs + 2, yofs + 32)
			list[table.getn(list) + 1] = b
			SetTextureCoords(b, "branch", "top")
			b = Talented:MakeBranch(parent)
			b:SetPoint("TOPLEFT", xofs + 2, yofs)
			list[table.getn(list) + 1] = b
			SetTextureCoords(b, "branch", "top")
		end

		x, y = offset(base_row, base_column)
		branch = Talented:MakeBranch(parent)
		branch:SetPoint("TOPLEFT", x + 2, y + 32)
		list[table.getn(list) + 1] = branch
		SetTextureCoords(branch, "branch", "top")
		local arrow = Talented:MakeArrow(parent)
		SetTextureCoords(arrow, "arrow", "top")
		arrow:SetPoint("TOPLEFT", x + 2, y + 16)
		list[table.getn(list) + 1] = arrow

		return true
	end

	local function DrawVerticalHorizontalLine(list, parent, offset, base_row, base_column, row, column)
		--[[
			FIXME : I need to check if this line is possible and return false if not.
			Note that it should never be impossible.
			Also, I need to really implement it.
		]]
		return true
	end

	function Talented.DrawLine(list, parent, offset, base_row, base_column, row, column)
		return DrawVerticalLine(list, parent, offset, base_row, base_column, row, column)
			or DrawHorizontalLine(list, parent, offset, base_row, base_column, row, column)
			or DrawHorizontalVerticalLine(list, parent, offset, base_row, base_column, row, column)
			or DrawVerticalHorizontalLine(list, parent, offset, base_row, base_column, row, column)
	end
end

-------------------------------------------------------------------------------
-- ui\menu.lua
--

do
	local classNames = {}
	local CLASS_SORT_ORDER = _G.CLASS_SORT_ORDER or {
		"WARRIOR",
		"ROGUE",
		"MAGE",
		"PRIEST",
		"WARLOCK",
		"HUNTER",
		"DRUID",
		"SHAMAN",
		"PALADIN"
	}
	if type(FillLocalizedClassList) == "function" then
		FillLocalizedClassList(classNames, false)
	else
		local src = LOCALIZED_CLASS_NAMES_MALE or LOCALIZED_CLASS_NAMES_FEMALE
		if type(src) == "table" then
			for token, localized in pairs(src) do
				classNames[token] = localized
			end
		end
		classNames.WARRIOR = classNames.WARRIOR or "Warrior"
		classNames.ROGUE = classNames.ROGUE or "Rogue"
		classNames.MAGE = classNames.MAGE or "Mage"
		classNames.PRIEST = classNames.PRIEST or "Priest"
		classNames.WARLOCK = classNames.WARLOCK or "Warlock"
		classNames.HUNTER = classNames.HUNTER or "Hunter"
		classNames.DRUID = classNames.DRUID or "Druid"
		classNames.SHAMAN = classNames.SHAMAN or "Shaman"
		classNames.PALADIN = classNames.PALADIN or "Paladin"
	end

	local menuColorCodes = {}
	local SHAMAN_COLOR_OVERRIDE = {r = 0.0, g = 0.44, b = 0.87}
	local function fill_menuColorCodes()
		for name, default in pairs(RAID_CLASS_COLORS) do
			local color = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[name] or default
			if name == "SHAMAN" then
				color = SHAMAN_COLOR_OVERRIDE
			end
			menuColorCodes[name] = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
		end
	end
	fill_menuColorCodes()

	if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS.RegisterCallback then
		CUSTOM_CLASS_COLORS:RegisterCallback(fill_menuColorCodes)
	end

	local function ColorizeByClass(class, text)
		local s = tostring(text or "")
		local code = menuColorCodes[class]
		if type(code) ~= "string" or code == "" then
			return s
		end
		return code .. s .. "|r"
	end

	function Talented:GetClassMenuColor(class)
		if type(class) ~= "string" then
			return nil
		end
		local default = RAID_CLASS_COLORS[class]
		if type(default) ~= "table" then
			return nil
		end
		local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or default
		if class == "SHAMAN" then
			color = SHAMAN_COLOR_OVERRIDE
		end
		return color.r, color.g, color.b
	end

	local function ClampColorValue(v)
		v = tonumber(v)
		if not v then
			return nil
		end
		if v < 0 then
			return 0
		end
		if v > 1 then
			return 1
		end
		return v
	end

	function Talented:GetTemplateMenuColor(template)
		local c = type(template) == "table" and template.menuColor or nil
		if type(c) ~= "table" then
			return nil
		end
		local r = ClampColorValue(c.r)
		local g = ClampColorValue(c.g)
		local b = ClampColorValue(c.b)
		if not r or not g or not b then
			return nil
		end
		return r, g, b
	end

	function Talented:IsTemplateMenuColorEditable(template)
		if type(template) ~= "table" then
			return false
		end
		if template.talentGroup or template.inspect_name then
			return false
		end
		return true
	end

	function Talented:SetTemplateMenuColor(template, r, g, b)
		if not self:IsTemplateMenuColorEditable(template) then
			return false
		end
		r = ClampColorValue(r)
		g = ClampColorValue(g)
		b = ClampColorValue(b)
		if not r or not g or not b then
			return false
		end
		template.menuColor = {r = r, g = g, b = b}
		return true
	end

	function Talented:ClearTemplateMenuColor(template)
		if not self:IsTemplateMenuColorEditable(template) then
			return
		end
		template.menuColor = nil
	end

	local function TemplateColorCode(template)
		local r, g, b = Talented:GetTemplateMenuColor(template)
		if not r then
			return nil
		end
		return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
	end

	function Talented:ColorizeTemplateName(template, class, text)
		local s = tostring(text or "")
		local code = TemplateColorCode(template)
		if type(code) ~= "string" or code == "" then
			return s
		end
		return code .. s .. "|r"
	end

	function Talented:RefreshTemplateColorButton(button, template)
		if not button or not button.swatch then
			return
		end
		local r, g, b = self:GetTemplateMenuColor(template)
		if not r then
			r, g, b = 1, 1, 1
			button:SetAlpha(0.7)
		else
			button:SetAlpha(1)
		end
		button.swatch:SetVertexColor(r, g, b)
	end

	function Talented:OpenTemplateColorPicker(template, button)
		if not self:IsTemplateMenuColorEditable(template) then
			return
		end
		local picker = _G.ColorPickerFrame
		if not picker or type(picker.SetColorRGB) ~= "function" then
			return
		end
		local r, g, b = self:GetTemplateMenuColor(template)
		local hadColor = r and g and b
		if not r then
			r, g, b = 1, 1, 1
		end
		local function apply()
			local pr, pg, pb = picker:GetColorRGB()
			if not hadColor and math.abs(pr - 1) < 0.001 and math.abs(pg - 1) < 0.001 and math.abs(pb - 1) < 0.001 then
				Talented:ClearTemplateMenuColor(template)
			elseif Talented:SetTemplateMenuColor(template, pr, pg, pb) then
				-- set successfully
			end
			Talented:UpdateView()
		end
		local restore = {r = r, g = g, b = b}
		local cancel = function()
			if hadColor then
				Talented:SetTemplateMenuColor(template, restore.r, restore.g, restore.b)
			else
				Talented:ClearTemplateMenuColor(template)
			end
			Talented:UpdateView()
		end
		-- Avoid any existing callback receiving this initialization color.
		picker.func = nil
		picker.cancelFunc = nil
		picker.opacityFunc = nil
		picker.hasOpacity = nil
		picker.opacity = 0
		picker:SetColorRGB(r, g, b)
		picker.func = apply
		picker.cancelFunc = cancel
		if picker.Hide then
			picker:Hide()
		end
		if type(_G.ShowUIPanel) == "function" then
			_G.ShowUIPanel(picker)
		elseif picker.Show then
			picker:Show()
		end
		-- Keep native picker internals intact, but force a higher strata than Talented.
		if type(picker.SetFrameStrata) == "function" then
			picker:SetFrameStrata("DIALOG")
		end
		if type(picker.Raise) == "function" then
			picker:Raise()
		end
	end

	local function SortEntryText(entry)
		local s = entry and (entry.sortKey or entry.text) or ""
		s = tostring(s or "")
		s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
		s = string.gsub(s, "|r", "")
		return s
	end

	local function BuildOrderedOptions()
		local args = Talented.options and Talented.options.args and Talented.options.args.options and Talented.options.args.options.args
		if type(args) ~= "table" then
			return {}
		end
		local ordered = {}
		for key, opt in pairs(args) do
			if type(opt) == "table" and (opt.type == "header" or opt.type == "toggle" or opt.type == "range") then
				ordered[table.getn(ordered) + 1] = {key = key, opt = opt, order = opt.order or 999}
			end
		end
		table.sort(ordered, function(a, b)
			if a.order == b.order then
				return tostring(a.key) < tostring(b.key)
			end
			return a.order < b.order
		end)
		return ordered
	end

	local function IsOptionDisabled(opt)
		if not opt then
			return false
		end
		local disabled = opt.disabled
		if type(disabled) == "string" and type(Talented[disabled]) == "function" then
			local ok, value = pcall(Talented[disabled], Talented)
			return ok and value and true or false
		elseif type(disabled) == "function" then
			local ok, value = pcall(disabled, Talented)
			return ok and value and true or false
		end
		return disabled and true or false
	end

	local function ClampRange(value, minValue, maxValue)
		if value < minValue then
			return minValue
		end
		if value > maxValue then
			return maxValue
		end
		return value
	end

	local function RoundToStep(value, step, minValue)
		if not step or step <= 0 then
			return value
		end
		minValue = minValue or 0
		local scaled = (value - minValue) / step
		local rounded = math.floor(scaled + 0.5)
		return minValue + rounded * step
	end

	local function FormatRangeValue(value, step)
		if not value then
			return ""
		end
		if step and step < 1 then
			return string.format("%.2f", value)
		end
		return tostring(math.floor(value + 0.5))
	end

	local function OnOptionEnter(self)
		if not self.tooltip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, 1)
	end

	local function OnOptionLeave(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end

	function Talented:RefreshOptionsFrame()
		local frame = self.optionsFrame
		if not frame or not frame._rows then
			return
		end
		if not self.db or not self.db.profile then
			return
		end
		for _, row in ipairs(frame._rows) do
			local opt = row.opt
			local key = row.key
			local value = self.db and self.db.profile and self.db.profile[key]
			local disabled = IsOptionDisabled(opt)
			if row.kind == "toggle" then
				row._updating = true
				row.widget:SetChecked(value and true or false)
				row._updating = false
				if disabled then
					if row.widget.Disable then row.widget:Disable() end
					row.label:SetTextColor(0.5, 0.5, 0.5)
				else
					if row.widget.Enable then row.widget:Enable() end
					row.label:SetTextColor(1, 0.82, 0)
				end
			elseif row.kind == "range" then
				local minValue = tonumber(opt.min) or 0
				local maxValue = tonumber(opt.max) or minValue
				local step = tonumber(opt.step) or 1
				if type(value) ~= "number" then
					value = minValue
				end
				value = ClampRange(RoundToStep(value, step, minValue), minValue, maxValue)
				self.db.profile[key] = value
				row.value:SetText(FormatRangeValue(value, step))
				if disabled then
					if row.minus.Disable then row.minus:Disable() end
					if row.plus.Disable then row.plus:Disable() end
					row.label:SetTextColor(0.5, 0.5, 0.5)
					row.value:SetTextColor(0.5, 0.5, 0.5)
				else
					if row.minus.Enable then row.minus:Enable() end
					if row.plus.Enable then row.plus:Enable() end
					row.label:SetTextColor(1, 0.82, 0)
					row.value:SetTextColor(1, 1, 1)
				end
			end
		end
	end

	function Talented:CreateOptionsFrame()
		if self.optionsFrame then
			return self.optionsFrame
		end

		local strataOrder = {
			"BACKGROUND",
			"LOW",
			"MEDIUM",
			"HIGH",
			"DIALOG",
			"FULLSCREEN",
			"FULLSCREEN_DIALOG",
			"TOOLTIP"
		}
		local function NextStrata(strata)
			local current = tostring(strata or "DIALOG")
			for i, value in ipairs(strataOrder) do
				if value == current then
					return strataOrder[min(i + 1, table.getn(strataOrder))]
				end
			end
			return "FULLSCREEN"
		end

		local frame = CreateFrame("Frame", "TalentedOptionsFrame", UIParent)
		frame:SetFrameStrata("FULLSCREEN")
		frame:SetToplevel(true)
		local function RaiseOptionsFrame(self)
			local base = _G.TalentedFrame or Talented.base
			if base and type(base.GetFrameStrata) == "function" then
				self:SetFrameStrata(NextStrata(base:GetFrameStrata()))
			else
				self:SetFrameStrata("FULLSCREEN")
			end
			if type(self.Raise) == "function" then
				self:Raise()
			end
		end
		frame:SetScript("OnShow", RaiseOptionsFrame)
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		frame:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			Talented:SaveFramePosition(self)
		end)
		frame:SetSize(420, 430)
		frame:SetBackdrop({
			bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			edgeSize = 16,
			tileSize = 32,
			insets = {left = 5, right = 5, top = 5, bottom = 5}
		})

		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		title:SetPoint("TOP", frame, "TOP", 0, -12)
		title:SetText(L["Talented Options"])

		local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
		subtitle:SetText(L["Vanilla-compatible options"])

		local close = self:CreateCloseButton(frame, function(button)
			button:GetParent():Hide()
		end)
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)

		UISpecialFrames[table.getn(UISpecialFrames) + 1] = "TalentedOptionsFrame"

		frame._rows = {}
		local entries = BuildOrderedOptions()
		local y = -44

		local function ApplyOptionChange(opt, key, value)
			if not Talented.db or not Talented.db.profile then
				return
			end
			Talented.db.profile[key] = value
			local arg = opt and opt.arg
			if type(arg) == "string" and type(Talented[arg]) == "function" then
				Talented[arg](Talented)
			end
			Talented:RefreshOptionsFrame()
		end

		for _, entry in ipairs(entries) do
			local key, opt = entry.key, entry.opt
			if opt.type == "header" then
				local header = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
				header:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
				header:SetText(opt.name or key)
				y = y - 20
			elseif opt.type == "toggle" then
				local cb = CreateFrame("CheckButton", nil, frame)
				cb:SetSize(20, 20)
				local function makeTexture(path, blend)
					local t = cb:CreateTexture()
					t:SetTexture(path)
					t:SetAllPoints(cb)
					if blend then
						t:SetBlendMode(blend)
					end
					return t
				end
				cb:SetNormalTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Up"))
				cb:SetPushedTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Down"))
				cb:SetDisabledTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled"))
				cb:SetCheckedTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Check"))
				cb:SetHighlightTexture(makeTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD"))
				cb:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
				cb.tooltip = opt.desc
				cb:SetScript("OnEnter", OnOptionEnter)
				cb:SetScript("OnLeave", OnOptionLeave)

				local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
				label:SetWidth(360)
				label:SetJustifyH("LEFT")
				label:SetText(opt.name or key)
				cb:SetScript("OnClick", function(self)
					if self._updating then
						return
					end
					ApplyOptionChange(opt, key, self:GetChecked() and true or false)
				end)

				frame._rows[table.getn(frame._rows) + 1] = {
					kind = "toggle",
					key = key,
					opt = opt,
					widget = cb,
					label = label
				}
				y = y - 24
			elseif opt.type == "range" then
				local row = CreateFrame("Frame", nil, frame)
				row:SetSize(390, 22)
				row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
				row.tooltip = opt.desc
				row:SetScript("OnEnter", OnOptionEnter)
				row:SetScript("OnLeave", OnOptionLeave)

				local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				label:SetPoint("LEFT", row, "LEFT", 0, 0)
				label:SetWidth(210)
				label:SetJustifyH("LEFT")
				label:SetText(opt.name or key)

				local minus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
				minus:SetPoint("LEFT", label, "RIGHT", 8, 0)
				minus:SetSize(24, 20)
				minus:SetText("-")
				minus.tooltip = opt.desc
				minus:SetScript("OnEnter", OnOptionEnter)
				minus:SetScript("OnLeave", OnOptionLeave)

				local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
				value:SetPoint("LEFT", minus, "RIGHT", 8, 0)
				value:SetWidth(60)
				value:SetJustifyH("CENTER")

				local plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
				plus:SetPoint("LEFT", value, "RIGHT", 8, 0)
				plus:SetSize(24, 20)
				plus:SetText("+")
				plus.tooltip = opt.desc
				plus:SetScript("OnEnter", OnOptionEnter)
				plus:SetScript("OnLeave", OnOptionLeave)

				local function shiftRange(delta)
					if not Talented.db or not Talented.db.profile then
						return
					end
					local minValue = tonumber(opt.min) or 0
					local maxValue = tonumber(opt.max) or minValue
					local step = tonumber(opt.step) or 1
					local current = tonumber(Talented.db.profile[key]) or minValue
					local updated = ClampRange(RoundToStep(current + (step * delta), step, minValue), minValue, maxValue)
					ApplyOptionChange(opt, key, updated)
				end

				minus:SetScript("OnClick", function() shiftRange(-1) end)
				plus:SetScript("OnClick", function() shiftRange(1) end)

				frame._rows[table.getn(frame._rows) + 1] = {
					kind = "range",
					key = key,
					opt = opt,
					label = label,
					value = value,
					minus = minus,
					plus = plus
				}
				y = y - 26
			end
		end

		local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		reset:SetSize(140, 22)
		reset:SetText(L["Reset Position"])
		reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
		reset:SetScript("OnClick", function()
			frame:ClearAllPoints()
			frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			Talented:SaveFramePosition(frame)
		end)

		local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		closeButton:SetSize(100, 22)
		closeButton:SetText(CLOSE or "Close")
		closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
		closeButton:SetScript("OnClick", function()
			frame:Hide()
		end)

		self.optionsFrame = frame
		self:LoadFramePosition(frame)
		RaiseOptionsFrame(frame)
		return frame
	end

	function Talented:OpenOptionsFrame()
		local frame = self:CreateOptionsFrame()
		local base = _G.TalentedFrame or self.base
		if base and type(base.GetFrameStrata) == "function" then
			local strata = base:GetFrameStrata()
			local next = "FULLSCREEN"
			if strata == "BACKGROUND" then next = "LOW"
			elseif strata == "LOW" then next = "MEDIUM"
			elseif strata == "MEDIUM" then next = "HIGH"
			elseif strata == "HIGH" then next = "DIALOG"
			elseif strata == "DIALOG" then next = "FULLSCREEN"
			elseif strata == "FULLSCREEN" then next = "FULLSCREEN_DIALOG"
			elseif strata == "FULLSCREEN_DIALOG" then next = "TOOLTIP"
			elseif strata == "TOOLTIP" then next = "TOOLTIP"
			end
			frame:SetFrameStrata(next)
		else
			frame:SetFrameStrata("FULLSCREEN")
		end
		if type(frame.Raise) == "function" then
			frame:Raise()
		end
		self:RefreshOptionsFrame()
		if not frame:IsVisible() then
			frame:Show()
		end
	end

	function Talented:GetNamedMenu(name)
		local menus = self.menus
		if not menus then
			menus = {}
			self.menus = menus
		end
		local menu = menus[name]
		if not menu then
			menu = {}
			menus[name] = menu
		end
		return menu
	end

	local function Menu_SetTemplate(entry, template)
		if template == nil and type(entry) == "table" and entry.class then
			template = entry
		end
		if type(template) ~= "table" then
			return
		end
		local button = _G.this
		if type(button) == "table" then
			button.keepShownOnClick = nil
		end
		if IsShiftKeyDown() then
			local frame = Talented:MakeAlternateView()
			frame.view:SetTemplate(template)
			frame.view:SetViewMode("view")
			frame:Show()
		else
			Talented:OpenTemplate(template)
		end
		Talented:CloseMenu()
	end

	function Talented:DeleteTemplateByReference(template)
		if type(template) ~= "table" or template.talentGroup or template.inspect_name then
			return false
		end
		local db = self:GetTemplatesDB()
		local key = nil
		local name = template.name
		if type(name) == "string" and db[name] == template then
			key = name
		else
			for candidate, entry in pairs(db) do
				if entry == template then
					key = candidate
					break
				end
			end
		end
		if not key then
			return false
		end
		db[key] = nil
		if self.template == template then
			self:SetTemplate()
		end
		self:UpdateView()
		self:QueueTemplateMenuRefresh()
		return true
	end

	function Talented:SaveInspectedTemplate(template)
		if type(template) ~= "table" or not template.inspect_name then
			return nil
		end
		local baseName = template.menu_name or template.name or template.inspect_name
		local saved = self:ImportFromOther(baseName, template)
		if saved and not self:GetTemplateMenuColor(saved) then
			local r, g, b = self:GetClassMenuColor(saved.class)
			if r and g and b then
				self:SetTemplateMenuColor(saved, r, g, b)
			end
		end
		self:QueueTemplateMenuRefresh()
		return saved
	end

	local contextMenuTicker
	function Talented:QueueTemplateContextMenu(template, anchor)
		if type(template) ~= "table" then
			return
		end
		self._pendingTemplateContext = {template = template, anchor = anchor}
		if not contextMenuTicker then
			contextMenuTicker = CreateFrame("Frame")
			contextMenuTicker:Hide()
			contextMenuTicker:SetScript("OnUpdate", function(self)
				self:Hide()
				local pending = Talented and Talented._pendingTemplateContext
				if not pending then
					return
				end
				Talented._pendingTemplateContext = nil
				Talented:OpenTemplateContextMenu(pending.anchor, pending.template)
			end)
		end
		contextMenuTicker:Show()
	end

	local function Menu_NewTemplate(entry, class)
		if class == nil then
			if type(entry) == "string" then
				class = entry
			elseif type(entry) == "table" then
				class = entry.arg1
			end
			if class == nil and type(_G.this) == "table" then
				class = _G.this.arg1
			end
		end
		Talented:OpenTemplate(Talented:CreateEmptyTemplate(class))
		Talented:CloseMenu()
	end

	local function EnsureImportDialog()
		local frame = _G.TalentedImportURLDialog
		if frame and frame.editBox then
			return frame
		end

		frame = CreateFrame("Frame", "TalentedImportURLDialog", UIParent)
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
			frame:SetScript("OnHide", function(self)
				local editBox = self and self.editBox
				if editBox and type(editBox.ClearFocus) == "function" then
					editBox:ClearFocus()
				end
			end)
		frame:SetSize(540, 140)
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
		title:SetWidth(500)
		title:SetJustifyH("CENTER")
		title:SetText(L["Enter a Turtlecraft Talents URL (https://talents.turtlecraft.gg/...)."])

		local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		edit:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -44)
		edit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -44)
		edit:SetHeight(20)
		edit:SetAutoFocus(false)
		frame.editBox = edit

			local function accept()
				local url = edit:GetText() or ""
				url = string.gsub(url, "^%s+", "")
				url = string.gsub(url, "%s+$", "")
				if type(edit.ClearFocus) == "function" then
					edit:ClearFocus()
				end
				frame:Hide()
				local template = Talented:ImportTemplate(url)
				if template then
					Talented:OpenTemplate(template)
				end
		end

		edit:SetScript("OnEnterPressed", function()
			accept()
		end)
			edit:SetScript("OnEscapePressed", function()
				if type(edit.ClearFocus) == "function" then
					edit:ClearFocus()
				end
				frame:Hide()
			end)

		local import = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		import:SetSize(110, 22)
		import:SetText(ACCEPT or "Accept")
		import:SetPoint("TOP", edit, "BOTTOM", -70, -10)
		import:SetScript("OnClick", accept)

		local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		cancel:SetSize(110, 22)
		cancel:SetText(CANCEL or "Cancel")
		cancel:SetPoint("LEFT", import, "RIGHT", 20, 0)
			cancel:SetScript("OnClick", function()
				if type(edit.ClearFocus) == "function" then
					edit:ClearFocus()
				end
				frame:Hide()
			end)

		UISpecialFrames[table.getn(UISpecialFrames) + 1] = "TalentedImportURLDialog"
		return frame
	end

	function Talented:ShowImportDialog()
		local popup = StaticPopup_Show("TALENTED_IMPORT_URL")
		if popup then
			return
		end

		local frame = EnsureImportDialog()
		frame:Show()
		frame:Raise()
		if frame.editBox then
			frame.editBox:SetText("")
			frame.editBox:SetFocus()
		end
	end

	function Talented:CreateTemplateMenu()
		local menu = self:GetNamedMenu("Template")

		local entry = self:GetNamedMenu("primary")
		entry.text = TALENT_SPEC_PRIMARY
		entry.func = Menu_SetTemplate
		menu[table.getn(menu) + 1] = entry

		if GetNumTalentGroups() > 1 then
			entry = self:GetNamedMenu("secondary")
			entry.text = TALENT_SPEC_SECONDARY
			entry.disabled = true
			entry.func = Menu_SetTemplate
			menu[table.getn(menu) + 1] = entry
		end

		entry = self:GetNamedMenu("separator")
		if not entry.text then
			entry.text = ""
			entry.disabled = true
			entry.separator = true
		end
		menu[table.getn(menu) + 1] = entry

		local list = {}
		for _, name in ipairs(CLASS_SORT_ORDER) do
			if Talented.spelldata[name] and RAID_CLASS_COLORS[name] then
				list[table.getn(list) + 1] = name
			end
		end

		for _, name in ipairs(list) do
			entry = self:GetNamedMenu(name)
			entry.text = ColorizeByClass(name, classNames[name])
			entry.colorCode = nil
			entry.hasArrow = true
			entry.menuList = self:GetNamedMenu(name .. "List")
			menu[table.getn(menu) + 1] = entry
		end

		menu[table.getn(menu) + 1] = self:GetNamedMenu("separator")

		entry = self:GetNamedMenu("Inspected")
		entry.text = L["Inspected Characters"]
		entry.hasArrow = true
		entry.menuList = self:GetNamedMenu("InspectedList")
		menu[table.getn(menu) + 1] = entry

		self.CreateTemplateMenu = function(self)
			return self:GetNamedMenu("Template")
		end
		return menu
	end

	local function Sort_Template_Menu_Entry(a, b)
		a, b = SortEntryText(a), SortEntryText(b)
		if not a then
			return false
		end
		if not b then
			return true
		end
		return a < b
	end

	local function ResetMenuEntry(entry)
		if type(entry) ~= "table" then
			return
		end
		entry.disabled = nil
		entry.separator = nil
		entry.notCheckable = nil
		entry.hasArrow = nil
		entry.menuList = nil
		entry.value = nil
		entry.keepShownOnClick = nil
		entry.checked = nil
		entry.func = nil
		entry.arg1 = nil
		entry.arg2 = nil
		entry.sortKey = nil
		entry.isTitle = nil
	end

		local function update_template_entry(entry, name, template, class, forceClassColor)
			local points = template.points
			if not points then
				points = Talented:GetTemplateInfo(template)
				template.points = points
			end
			entry.sortKey = tostring(name or "")
			if forceClassColor then
				entry.text = ColorizeByClass(class, name) .. points
			else
				entry.text = Talented:ColorizeTemplateName(template, class, name) .. points
			end
		end

	function Talented:MakeTemplateMenu()
		local menu = self:CreateTemplateMenu()

		local templates = self:GetTemplatesDB()
		for class, color in pairs(menuColorCodes) do
			local menuList = self:GetNamedMenu(class .. "List")
			local index = 1
			for name, template in pairs(templates) do
				if template.class == class then
					local entry = menuList[index]
					if not entry then
						entry = {}
						menuList[index] = entry
					end
					ResetMenuEntry(entry)
					index = index + 1
					update_template_entry(entry, name, template, class)
					entry.func = Menu_SetTemplate
					entry.checked = (self.template == template)
					entry.arg1 = template
					entry.colorCode = nil
					entry.notCheckable = nil
					entry.hasArrow = nil
					entry.menuList = nil
				end
			end
			for i = index, table.getn(menuList) do
				ResetMenuEntry(menuList[i])
				menuList[i].text = nil
			end
			table.sort(menuList, Sort_Template_Menu_Entry)
			local mnu = self:GetNamedMenu(class)
			if index == 1 then
				mnu.text = classNames[class]
				mnu.disabled = true
				mnu.colorCode = nil
			else
				mnu.text = ColorizeByClass(class, classNames[class])
				mnu.disabled = nil
				mnu.colorCode = nil
			end
		end

		if not self.inspections then
			self:GetNamedMenu("Inspected").disabled = true
		else
			self:GetNamedMenu("Inspected").disabled = nil
			local menuList = self:GetNamedMenu("InspectedList")
			local index = 1
			for name, template in pairs(self.inspections) do
				local entry = menuList[index]
				if not entry then
					entry = {}
					menuList[index] = entry
				end
				ResetMenuEntry(entry)
				index = index + 1
				update_template_entry(entry, template.menu_name or template.name or name, template, template.class, true)
				entry.func = Menu_SetTemplate
				entry.checked = (self.template == template)
				entry.arg1 = template
				entry.colorCode = nil
			end
			for i = index, table.getn(menuList) do
				ResetMenuEntry(menuList[i])
				menuList[i].text = nil
			end
			table.sort(menuList, Sort_Template_Menu_Entry)
		end
		local talentGroup = GetActiveTalentGroup()
		local entry = self:GetNamedMenu("primary")
		local current = self.alternates[1]
		update_template_entry(entry, TALENT_SPEC_PRIMARY, current)
		entry.arg1 = current
		entry.checked = (self.template == current)
		if table.getn(self.alternates) > 1 and GetNumTalentGroups() > 1 then
			local alt = self.alternates[2]
			local e = self:GetNamedMenu("secondary")
			e.disabled = false
			update_template_entry(e, TALENT_SPEC_SECONDARY, alt)
			e.arg1 = alt
			e.checked = (self.template == alt)
		end

		return menu
	end

		local function NormalizeText(text)
			if type(text) ~= "string" then
				return ""
			end
			local out = string.gsub(text, "^%s+", "")
			out = string.gsub(out, "%s+$", "")
			return out
		end

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
				if type(parent) == "table" and type(parent.GetParent) == "function" then
					local grand = parent:GetParent()
					if type(grand) == "table" and grand.which then
						return grand
					end
				end
			end
			return nil
		end

		local function GetPopupEditBoxes(popup)
			if type(popup) ~= "table" or type(popup.GetName) ~= "function" then
				return nil, nil
			end
			local name = popup:GetName()
			return getglobal(name .. "WideEditBox"), getglobal(name .. "EditBox")
		end

		local function ReadPopupText(popup)
			if type(popup) ~= "table" then
				return ""
			end
			local wide, edit = GetPopupEditBoxes(popup)
			local wideText = (wide and type(wide.GetText) == "function") and wide:GetText() or ""
			local editText = (edit and type(edit.GetText) == "function") and edit:GetText() or ""
			wideText = NormalizeText(wideText)
			editText = NormalizeText(editText)
			if wideText ~= "" then
				return wideText
			end
			return editText
		end

		local function ClearPopupEditBoxes(popup)
			if type(popup) ~= "table" then
				return
			end
			local wide, edit = GetPopupEditBoxes(popup)
			if wide and type(wide.SetText) == "function" then
				wide:SetText("")
			end
			if edit and edit ~= wide and type(edit.SetText) == "function" then
				edit:SetText("")
			end
		end

		local function ClearPopupFocus(popup)
			if type(popup) ~= "table" then
				return
			end
			local wide, edit = GetPopupEditBoxes(popup)
			if wide and type(wide.ClearFocus) == "function" then
				wide:ClearFocus()
			end
			if edit and edit ~= wide and type(edit.ClearFocus) == "function" then
				edit:ClearFocus()
			end
		end

		local function FocusPopupEditBox(popup, highlight)
			if type(popup) ~= "table" then
				return
			end
			local wide, edit = GetPopupEditBoxes(popup)
			local target = (wide and type(wide.IsShown) == "function" and wide:IsShown()) and wide or edit
			if target and type(target.SetFocus) == "function" then
				target:SetFocus()
			end
			if highlight and target and type(target.HighlightText) == "function" then
				target:HighlightText()
			end
		end

		local function AnchorWidePopupControls(popup)
			if type(popup) ~= "table" or type(popup.GetName) ~= "function" then
				return
			end
			local name = popup:GetName()
			local wide, edit = GetPopupEditBoxes(popup)
			if wide and type(wide.IsShown) == "function" and wide:IsShown() and type(wide.ClearAllPoints) == "function" then
				wide:ClearAllPoints()
				wide:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -44)
				wide:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -16, -44)
			end
			local button1 = getglobal(name .. "Button1")
			local button2 = getglobal(name .. "Button2")
			local anchor = (wide and type(wide.IsShown) == "function" and wide:IsShown()) and wide or edit
			if not button1 or not anchor then
				return
			end
			button1:ClearAllPoints()
			if button2 and type(button2.IsShown) == "function" and button2:IsShown() then
				button2:ClearAllPoints()
				button1:SetPoint("TOPRIGHT", anchor, "BOTTOM", -6, -8)
				button2:SetPoint("LEFT", button1, "RIGHT", 13, 0)
			else
				button1:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
			end
		end

		StaticPopupDialogs["TALENTED_IMPORT_URL"] = {
		text = L["Enter a Turtlecraft Talents URL (https://talents.turtlecraft.gg/...)."],
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		hasWideEditBox = 1,
		maxLetters = 256,
		whileDead = 1,
			OnShow = function()
				local popup = ResolvePopupFrameFromThis()
				if not popup then
					return
				end
				if type(popup.SetWidth) == "function" then
					popup:SetWidth(520)
				end
				ClearPopupEditBoxes(popup)
				AnchorWidePopupControls(popup)
				FocusPopupEditBox(popup, false)
			end,
			OnAccept = function()
				local popup = ResolvePopupFrameFromThis()
				if not popup then
					return
				end
				local url = ReadPopupText(popup)
				ClearPopupFocus(popup)
				local template = Talented:ImportTemplate(url)
				if template then
					Talented:OpenTemplate(template)
				end
			end,
			OnHide = function()
				local popup = ResolvePopupFrameFromThis()
				if not popup then
					return
				end
				ClearPopupFocus(popup)
				ClearPopupEditBoxes(popup)
			end,
		timeout = 0,
		EditBoxOnEnterPressed = function()
			StaticPopup_OnClick(this:GetParent(), 1)
		end,
			EditBoxOnEscapePressed = function()
				this:GetParent():Hide()
			end,
		hideOnEscape = 1
	}

		StaticPopupDialogs["TALENTED_EXPORT_TO"] = {
			text = L["Enter the name of the character you want to send the template to."],
			button1 = ACCEPT,
			button2 = CANCEL,
			hasEditBox = 1,
			maxLetters = 256,
			whileDead = 1,
				autoCompleteParams = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.WHISPER,
					OnAccept = function()
						local popup = ResolvePopupFrameFromThis()
						if not popup then
							return
						end
						local name = ReadPopupText(popup)
						ClearPopupFocus(popup)
						Talented:ExportTemplateToUser(name)
					end,
				OnShow = function()
					local popup = ResolvePopupFrameFromThis()
					if not popup then
						return
					end
					ClearPopupEditBoxes(popup)
					FocusPopupEditBox(popup, false)
				end,
				OnHide = function()
					local popup = ResolvePopupFrameFromThis()
					if not popup then
						return
					end
					ClearPopupFocus(popup)
					ClearPopupEditBoxes(popup)
				end,
		timeout = 0,
		EditBoxOnEnterPressed = function()
			StaticPopup_OnClick(this:GetParent(), 1)
		end,
		EditBoxOnEscapePressed = function()
			this:GetParent():Hide()
		end,
		hideOnEscape = 1
	}

		StaticPopupDialogs["TALENTED_SHOW_URL"] = {
			text = L["URL:"],
			button1 = OKAY,
			hasEditBox = 1,
			hasWideEditBox = 1,
			maxLetters = 2048,
			whileDead = 1,
			OnShow = function(data)
				local popup = ResolvePopupFrameFromThis()
				if not popup then
					return
				end
				if type(popup.SetWidth) == "function" then
					popup:SetWidth(620)
				end
				local text = type(data) == "string" and data or type(Talented._showUrlDialogText) == "string" and Talented._showUrlDialogText or ""
				local wide, edit = GetPopupEditBoxes(popup)
				local target = (wide and type(wide.IsShown) == "function" and wide:IsShown()) and wide or edit
				if target and type(target.SetText) == "function" then
					target:SetText(text)
				end
				AnchorWidePopupControls(popup)
				FocusPopupEditBox(popup, true)
			end,
			OnAccept = function()
				local popup = ResolvePopupFrameFromThis()
				if not popup then
					return
				end
				ClearPopupFocus(popup)
			end,
			OnHide = function()
				local popup = ResolvePopupFrameFromThis()
				if not popup then
					return
				end
				Talented._showUrlDialogText = nil
				ClearPopupFocus(popup)
				local wide, edit = GetPopupEditBoxes(popup)
				if wide and type(wide.SetText) == "function" then
					wide:SetText("")
				end
				if edit and edit ~= wide and type(edit.SetText) == "function" then
					edit:SetText("")
				end
			end,
			timeout = 0,
			EditBoxOnEnterPressed = function()
				StaticPopup_OnClick(this:GetParent(), 1)
			end,
			EditBoxOnEscapePressed = function()
				this:GetParent():Hide()
			end,
			hideOnEscape = 1
		}

		function Talented:ShowURLDialog(text)
			local value = type(text) == "string" and text or ""
			Talented._showUrlDialogText = value
			local popup = StaticPopup_Show("TALENTED_SHOW_URL", nil, nil, value)
			return popup and true or false
		end

	function Talented:CreateActionMenu()
		if not self.template then
			local active = type(self.GetActiveSpec) == "function" and self:GetActiveSpec() or nil
			if active then
				self.template = active
			end
		end
		local menu = self:GetNamedMenu("Action")

		local menuList = self:GetNamedMenu("NewTemplates")
		wipe(menuList)

		local list = {}
		for _, name in ipairs(CLASS_SORT_ORDER) do
			if Talented.spelldata[name] and RAID_CLASS_COLORS[name] then
				list[table.getn(list) + 1] = name
			end
		end

		for _, name in ipairs(list) do
			local s = {
				text = ColorizeByClass(name, classNames[name]),
				colorCode = nil,
				sortKey = classNames[name],
				func = Menu_NewTemplate,
				arg1 = name
			}
			menuList[table.getn(menuList) + 1] = s
		end

		menu[table.getn(menu) + 1] = {
			text = L["New Template"],
			hasArrow = true,
			menuList = menuList
		}
		local entry = self:GetNamedMenu("separator")
		if not entry.text then
			entry.text = ""
			entry.disabled = true
			entry.separator = true
		end
		menu[table.getn(menu) + 1] = entry

		entry = self:GetNamedMenu("Apply")
		entry.text = L["Apply template"]
		entry.func = function()
			Talented:SetMode("apply")
		end
		menu[table.getn(menu) + 1] = entry

		if GetNumTalentGroups() > 1 and type(_G.SetActiveTalentGroup) == "function" then
			entry = self:GetNamedMenu("SwitchTalentGroup")
			entry.text = L["Switch to this Spec"]
			entry.func = function(entry, talentGroup)
				SetActiveTalentGroup(talentGroup)
			end
			menu[table.getn(menu) + 1] = entry
		end

		entry = self:GetNamedMenu("Delete")
		entry.text = L["Delete template"]
		entry.func = function()
			Talented:DeleteCurrentTemplate()
		end
		menu[table.getn(menu) + 1] = entry

		entry = self:GetNamedMenu("Copy")
		entry.text = L["Copy template"]
		entry.func = function()
			Talented:OpenTemplate(Talented:CopyTemplate(Talented.template))
		end
		menu[table.getn(menu) + 1] = entry

		entry = self:GetNamedMenu("Target")
		entry.text = L["Set as target"]
		entry.func = function(a1, a2, a3)
			local targetName, name, checked
			if type(a1) == "table" then
				targetName = a2
				name = a3
				checked = a1.checked
			else
				targetName = a1
				name = a2
				checked = a3
			end
			local button = _G.this
			if type(button) == "table" then
				if targetName == nil then
					targetName = button.arg1
				end
				if name == nil then
					name = button.arg2
				end
				if checked == nil then
					checked = button.checked
				end
			end
				if targetName == nil then
					return
				end
				if checked then
					Talented.db.char.targets[targetName] = nil
				else
					Talented.db.char.targets[targetName] = name
				end
				if type(Talented.RefreshTargetOverlays) == "function" then
					Talented:RefreshTargetOverlays(targetName)
				elseif Talented.base and Talented.base.view and type(Talented.base.view.Update) == "function" then
					Talented.base.view:Update()
				end
			end
		entry.arg2 = self.template and self.template.name or nil
		menu[table.getn(menu) + 1] = entry

		menu[table.getn(menu) + 1] = self:GetNamedMenu("separator")
			menu[table.getn(menu) + 1] = {
				text = L["Import template ..."],
				func = function()
					Talented:ShowImportDialog()
				end
			}

		entry = self:GetNamedMenu("Export")
		entry.text = L["Export template ..."]
		entry.func = nil
		entry.hasArrow = true
		entry.menuList = self:GetNamedMenu("exporters")
		entry.arg1 = nil
		menu[table.getn(menu) + 1] = entry

		menu[table.getn(menu) + 1] = {
			text = L["Send to ..."],
			func = function()
				StaticPopup_Show "TALENTED_EXPORT_TO"
			end
		}

		menu[table.getn(menu) + 1] = {
			text = L["Options ..."],
			func = function()
				Talented:OpenOptionsFrame()
			end
		}

		self.CreateActionMenu = function(self)
			return self:GetNamedMenu("Action")
		end
		return menu
	end

	local function Export_Template(entry, handler)
		local exporter = handler
		if type(exporter) ~= "function" then
			if type(entry) == "function" then
				exporter = entry
			elseif type(entry) == "table" then
				exporter = entry.arg1
			end
		end
		if type(exporter) ~= "function" and type(_G.this) == "table" then
			exporter = _G.this.arg1
		end
		if type(exporter) ~= "function" and type(Talented.exporters) == "table" then
			exporter = Talented.exporters["Turtlecraft Talents"]
			if type(exporter) ~= "function" then
				for _, fn in pairs(Talented.exporters) do
					if type(fn) == "function" then
						exporter = fn
						break
					end
				end
			end
		end
		if type(exporter) ~= "function" then
			Talented:Print(L["No export handler is available."])
			return
		end

		local url = exporter(Talented, Talented.template)
		if url then
			if not (type(Talented.ShowURLDialog) == "function" and Talented:ShowURLDialog(url)) then
				Talented:ShowInDialog(url)
			end
		end
	end

	function Talented:MakeActionMenu()
		local menu = self:CreateActionMenu()
		if not self.template then
			return menu
		end
		local templateTalentGroup, activeTalentGroup = self.template.talentGroup, GetActiveTalentGroup()
		local _, playerClass = UnitClass("player")
		local restricted = (self.template.class ~= playerClass)
		local targetName
		if not restricted then
			targetName = templateTalentGroup or activeTalentGroup
		end

		self:GetNamedMenu("Apply").disabled = templateTalentGroup or restricted
		self:GetNamedMenu("Delete").disabled = templateTalentGroup or not self:GetTemplatesDB()[self.template.name]
		local switch = self:GetNamedMenu("SwitchTalentGroup")
		switch.disabled = (restricted or not templateTalentGroup or templateTalentGroup == activeTalentGroup)
		switch.arg1 = templateTalentGroup

		local target = self:GetNamedMenu("Target")
		if templateTalentGroup then
			target.text = L["Clear target"]
			target.arg1 = targetName
			target.arg2 = nil
			target.disabled = not self.db.char.targets[targetName]
			target.checked = nil
		else
			target.text = L["Set as target"]
			target.arg1 = targetName
			target.arg2 = self.template.name
			target.disabled = not targetName

			target.checked = (self.db.char.targets[targetName] == self.template.name)
		end

		for _, entry in ipairs(self:GetNamedMenu("NewTemplates")) do
			local class = entry.arg1
			entry.text = ColorizeByClass(class, classNames[class])
			entry.colorCode = nil
		end

		local exporters = self:GetNamedMenu("exporters")
		local index = 1
		for name, handler in pairs(self.exporters) do
			exporters[index] = exporters[index] or {}
			exporters[index].text = name
			exporters[index].func = Export_Template
			exporters[index].arg1 = handler
			index = index + 1
		end
		for i = index, table.getn(exporters) do
			exporters[i].text = nil
		end

			local exporterCount = index - 1
			local exportEntry = self:GetNamedMenu("Export")
			if exporterCount <= 0 then
				exportEntry.text = L["Export template ..."]
				exportEntry.func = nil
				exportEntry.hasArrow = nil
				exportEntry.menuList = nil
				exportEntry.arg1 = nil
				exportEntry.disabled = true
			elseif exporterCount == 1 then
				local single = exporters[1]
				exportEntry.text = L["Export template ..."]
				exportEntry.func = Export_Template
				exportEntry.hasArrow = nil
				exportEntry.menuList = nil
				exportEntry.arg1 = single.arg1
				exportEntry.disabled = nil
			else
				exportEntry.text = L["Export template ..."]
				exportEntry.func = nil
				exportEntry.hasArrow = true
				exportEntry.menuList = exporters
				exportEntry.arg1 = nil
			exportEntry.disabled = nil
		end

		return menu
	end

	function Talented:CloseMenu()
		if type(CloseDropDownMenus) == "function" then
			CloseDropDownMenus()
		elseif type(HideDropDownMenu) == "function" then
			HideDropDownMenu(1)
		end
		self._openDropdownMenu = nil
	end

	function Talented:GetDropdownFrame(frame)
		local dropdown = CreateFrame("Frame", "TalentedDropDown", nil, "UIDropDownMenuTemplate")
		dropdown.point = "TOPLEFT"
		dropdown.relativePoint = "BOTTOMLEFT"
		dropdown.displayMode = "MENU"
		dropdown.xOffset = 2
		dropdown.yOffset = 2
		dropdown.relativeTo = frame
		self.dropdown = dropdown
		self.GetDropdownFrame = function(self, frame)
			local dropdown = self.dropdown
			dropdown.relativeTo = frame
			return dropdown
		end
		return dropdown
	end

	local function ShowMenu(menu, dropdown, anchorName, xOffset, yOffset)
		if type(EasyMenu) == "function" then
			if anchorName then
				EasyMenu(menu, dropdown, anchorName, xOffset or 0, yOffset or 0, "MENU")
			else
				EasyMenu(menu, dropdown)
			end
			return true
		end
		if type(UIDropDownMenu_Initialize) == "function" and type(ToggleDropDownMenu) == "function" and type(UIDropDownMenu_AddButton) == "function" then
			UIDropDownMenu_Initialize(dropdown, function(_, level, menuList)
				level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
				local entries
				if level > 1 then
					entries = menuList or UIDROPDOWNMENU_MENU_VALUE
				else
					entries = menu
				end
				if type(entries) ~= "table" then
					return
				end
				for _, entry in ipairs(entries) do
					if entry and entry.text ~= nil then
						local info = {}
						for k, v in pairs(entry) do
							info[k] = v
						end
						if info.hasArrow and info.menuList and info.value == nil then
							info.value = info.menuList
						end
						UIDropDownMenu_AddButton(info, level)
					end
				end
			end, "MENU")
			if type(CloseDropDownMenus) == "function" then
				CloseDropDownMenus()
			elseif type(HideDropDownMenu) == "function" then
				HideDropDownMenu(1)
			end
			local anchor = anchorName
			local ox, oy = xOffset, yOffset
			if not anchor then
				anchor = dropdown.relativeTo
				ox = dropdown.xOffset or 0
				oy = dropdown.yOffset or 0
			end
			ToggleDropDownMenu(1, nil, dropdown, anchor, ox or 0, oy or 0)
			local maxLevels = UIDROPDOWNMENU_MAXLEVELS or 2
			local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
			for level = 1, maxLevels do
				for i = 1, maxButtons do
					local button = _G["DropDownList" .. tostring(level) .. "Button" .. tostring(i)]
					if button and type(button.RegisterForClicks) == "function" then
						button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
					end
				end
			end
			return true
		end
		if Talented and Talented.Print then
			Talented:Print("Dropdown menu API is unavailable on this client build.")
		end
		return nil
	end

	function Talented:BuildTemplateContextMenu(template)
		if type(template) ~= "table" then
			return nil
		end
		local function ResolveContextTemplate(a1, a2)
			if type(a2) == "table" then
				return a2
			end
			if type(a1) == "table" then
				return a1
			end
			if type(_G.this) == "table" and type(_G.this.arg1) == "table" then
				return _G.this.arg1
			end
			return nil
		end
		local menu = self:GetNamedMenu("TemplateContext")
		wipe(menu)

		if template.inspect_name then
			menu[1] = {
				text = "Save template",
				func = function(a1, a2)
					local inspectedTemplate = ResolveContextTemplate(a1, a2)
					if inspectedTemplate then
						Talented:SaveInspectedTemplate(inspectedTemplate)
					end
				end,
				arg1 = template
			}
			else
				local deleteText = L["Delete template"] or "Delete template"
				menu[1] = {
					text = "|cffff4040" .. deleteText .. "|r",
					func = function(a1, a2)
						local savedTemplate = ResolveContextTemplate(a1, a2)
						if savedTemplate then
							Talented:DeleteTemplateByReference(savedTemplate)
						end
				end,
				arg1 = template
			}
		end

		if not menu[1] then
			return nil
		end
		return menu
	end

	function Talented:OpenTemplateContextSubmenu(template)
		local menu = self:BuildTemplateContextMenu(template)
		if not menu then
			return nil
		end
		if type(ToggleDropDownMenu) ~= "function" then
			return nil
		end
		local level = tonumber(UIDROPDOWNMENU_MENU_LEVEL) or 1
		if level < 1 then
			level = 1
		end
		local submenuLevel = level + 1
		local maxLevels = tonumber(UIDROPDOWNMENU_MAXLEVELS) or 2
		if submenuLevel > maxLevels then
			-- Vanilla dropdown depth is often limited to 2. Reuse current level
			-- so template context actions can still open without closing parent.
			submenuLevel = level
		end
		local button = _G.this
		if type(button) ~= "table" then
			return nil
		end
		if type(_G["DropDownList" .. tostring(submenuLevel)]) ~= "table" then
			if submenuLevel ~= level and type(_G["DropDownList" .. tostring(level)]) == "table" then
				submenuLevel = level
			else
				return nil
			end
		end
		local openMenu = _G.UIDROPDOWNMENU_OPEN_MENU
		if not openMenu then
			return nil
		end
		button.value = menu
		local ok = pcall(ToggleDropDownMenu, submenuLevel, menu, openMenu, button, 0, 0)
		if not ok then
			return nil
		end
		return true
	end

	function Talented:OpenTemplateContextMenu(anchor, template)
		local menu = self:BuildTemplateContextMenu(template)
		if not menu then
			return
		end

		if type(anchor) == "table" then
			local n = type(anchor.GetName) == "function" and anchor:GetName() or nil
			if type(n) == "string" and string.find(n, "^DropDownList%d+", 1, false) then
				anchor = nil
			elseif type(anchor.IsShown) == "function" and not anchor:IsShown() then
				anchor = nil
			end
		end
		local fallbackAnchor = (self.base and self.base.bmode) or self.base or UIParent
		local dropdown = self:GetDropdownFrame(anchor or fallbackAnchor)
		ShowMenu(menu, dropdown, "cursor", -8, 8)
	end

	local templateMenuRefreshFrame
	function Talented:IsTemplateMenuOpen()
		local list = _G.DropDownList1
		if not list or not list.IsShown or not list:IsShown() then
			return false
		end
		if UIDROPDOWNMENU_OPEN_MENU ~= "TalentedDropDown" then
			return false
		end
		return self._openDropdownMenu == "template"
	end

	function Talented:RefreshOpenTemplateMenu()
		if not self:IsTemplateMenuOpen() then
			return false
		end
		local anchor = self._lastTemplateMenuAnchor
		if type(anchor) ~= "table" or (type(anchor.IsShown) == "function" and not anchor:IsShown()) then
			anchor = (self.base and self.base.bmode) or self.base or UIParent
		end
		ShowMenu(self:MakeTemplateMenu(), self:GetDropdownFrame(anchor))
		return true
	end

	function Talented:QueueTemplateMenuRefresh()
		self._templateMenuRefreshQueued = true
		if not templateMenuRefreshFrame then
			templateMenuRefreshFrame = CreateFrame("Frame")
			templateMenuRefreshFrame:Hide()
			templateMenuRefreshFrame:SetScript("OnUpdate", function(self)
				self:Hide()
				if not Talented then
					return
				end
				Talented._templateMenuRefreshQueued = nil
				Talented:RefreshOpenTemplateMenu()
			end)
		end
		templateMenuRefreshFrame:Show()
	end

	function Talented:OpenTemplateMenu(frame)
		self._openDropdownMenu = "template"
		self._lastTemplateMenuAnchor = frame
		ShowMenu(self:MakeTemplateMenu(), self:GetDropdownFrame(frame))
	end

	function Talented:OpenActionMenu(frame)
		self._openDropdownMenu = "action"
		ShowMenu(self:MakeActionMenu(), self:GetDropdownFrame(frame))
	end

	function Talented:OpenLockMenu(frame, parent)
		local menu = self:GetNamedMenu("LockFrame")
		local entry = menu[1]
		if not entry then
			entry = {
				text = L["Lock frame"],
				func = function(entry, frame)
					local target = frame
					if not target and type(entry) == "table" then
						target = entry.arg1
					end
					if not target and type(_G.this) == "table" then
						target = _G.this.arg1
					end
					if not target then
						target = Talented.base or _G.TalentedFrame
					end
					if target then
						local locked = Talented:GetFrameLock(target) and true or false
						Talented:SetFrameLock(target, not locked)
					end
				end
			}
			menu[1] = entry
		end
		entry.arg1 = parent
		entry.checked = self:GetFrameLock(parent)
		ShowMenu(menu, self:GetDropdownFrame(frame))
	end
end

-------------------------------------------------------------------------------
-- ui\spectabs.lua
--

do
	-- Intentionally disabled in this Vanilla/Turtle fork for now.
	-- Keep this section reserved for a future Turtle loadout tab implementation.
end
