-------------------------------------------------------------------------------
-- other.lua
--

local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local L = _G.TalentedLocale or {}
local TALENTED_WHISPER_PREFIX = "\001TLDCOMM\001"
local TALENTED_LFT_COMM_TAG = "TLDLFT:"

do
	local recentComm = {}
	local function IsDuplicateComm(sender, message)
		if type(sender) ~= "string" then
			sender = ""
		end
		local key = tostring(sender) .. "\031" .. tostring(message or "")
		local now = type(GetTime) == "function" and GetTime() or 0
		local last = recentComm[key]
		if type(last) == "number" and (now - last) <= 2 then
			return true
		end
		recentComm[key] = now
		return false
	end

	local function ResolvePopupFrameFromContext(data)
		if type(data) == "table" and data.which then
			return data
		end
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

	local function ShowDialog(sender, name, code)
		StaticPopupDialogs.TALENTED_CONFIRM_SHARE_TEMPLATE = {
			button1 = YES,
			button2 = NO,
			text = L['Do you want to add the template "%s" that %s sent you ?'],
			OnAccept = function(data)
				local popup = ResolvePopupFrameFromContext(data)
				local codeValue = type(data) == "table" and data.code or nil
				local nameValue = type(data) == "table" and data.name or nil
				if (not codeValue or codeValue == "") and popup then
					codeValue = popup.code
				end
				if (not nameValue or nameValue == "") and popup then
					nameValue = popup.name
				end
				if not codeValue or codeValue == "" then
					return
				end
				local res, value, class = pcall(Talented.StringToTemplate, Talented, codeValue)
				if res then
					Talented:ImportFromOther(nameValue, {
						code = codeValue,
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
			local dlg = StaticPopup_Show("TALENTED_CONFIRM_SHARE_TEMPLATE", name, sender, {
				name = name,
				code = code
			})
			if dlg then
				dlg.name = name
				dlg.code = code
			end
		end
		return ShowDialog(sender, name, code)
	end

	function Talented:OnCommReceived(prefix, message, distribution, sender)
		if IsDuplicateComm(sender, message) then
			return
		end
		local status, name, code = self:Deserialize(message)
		if not status then return end

		ShowDialog(sender, name, code)
	end

	function Talented:CHAT_MSG_WHISPER(message, sender)
		if type(message) ~= "string" or type(sender) ~= "string" then
			return
		end
		if not string.find(message, TALENTED_WHISPER_PREFIX, 1, true) then
			return
		end
		local payload = string.sub(message, string.len(TALENTED_WHISPER_PREFIX) + 1)
		local prefix, body = string.match(payload or "", "^(.-)\031(.*)$")
		if not prefix or not body or prefix == "" then
			return
		end
		self:OnCommReceived(prefix, body, "WHISPER", sender)
	end

	function Talented:CHAT_MSG_CHANNEL(message, sender)
		if type(message) ~= "string" then
			return
		end
		if not string.find(message, TALENTED_LFT_COMM_TAG, 1, true) then
			return
		end
		local payload = string.sub(message, string.len(TALENTED_LFT_COMM_TAG) + 1)
		local recipient, prefix, body = string.match(payload or "", "^(.-)\031(.-)\031(.*)$")
		if not recipient or recipient == "" or not prefix or prefix == "" or not body then
			return
		end
		local selfName = type(UnitName) == "function" and UnitName("player") or nil
		if type(selfName) ~= "string" or selfName == "" then
			return
		end
		if string.lower(selfName) ~= string.lower(recipient) then
			return
		end
		self:OnCommReceived(prefix, body, "WHISPER", sender)
	end

	function Talented:ExportTemplateToUser(name)
		if not name or string.trim(name) == "" then return end
		local message = self:Serialize(self.template.name, self:TemplateToString(self.template))
		self:SendCommMessage("Talented", message, "WHISPER", name)
	end
end
