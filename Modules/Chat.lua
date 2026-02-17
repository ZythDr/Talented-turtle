-------------------------------------------------------------------------------
-- chat.lua
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

local function SetTextSafe(widget, text)
	if not widget or type(widget.SetText) ~= "function" then
		return
	end
	local ok = pcall(widget.SetText, widget, tostring(text or ""))
	if not ok then
		pcall(widget.SetText, widget, "")
	end
end

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
		frame:SetScript("OnHide", function(self)
			local editBox = self and self.editBox
			if editBox and type(editBox.ClearFocus) == "function" then
				editBox:ClearFocus()
			end
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
			if widget and widget.ClearFocus then
				widget:ClearFocus()
			end
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
			local editBox = parent and parent.editBox
			if editBox and type(editBox.ClearFocus) == "function" then
				editBox:ClearFocus()
			end
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
		if type(self.ShowURLDialog) == "function" then
			local ok, shown = pcall(self.ShowURLDialog, self, text)
			if ok and shown then
				return
			end
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
