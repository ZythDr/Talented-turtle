-- Talented Vanilla compatibility layer.
-- Provides a tiny subset of Ace3/LibStub APIs used by Talented.

if not table.getn then
	table.getn = function(t)
		if type(t) ~= "table" then
			return 0
		end
		local n = 0
		while t[n + 1] ~= nil do
			n = n + 1
		end
		return n
	end
end

if not string.trim then
	function string.trim(s)
		return string.gsub(string.gsub(s or "", "^%s+", ""), "%s+$", "")
	end
end

if not wipe then
	function wipe(t)
		for k in pairs(t) do
			t[k] = nil
		end
		return t
	end
end

if not strsplit then
	function strsplit(sep, text)
		local fields = {}
		local start = 1
		local lensep = string.len(sep or "")
		local src = tostring(text or "")
		if lensep == 0 then
			return src
		end
		while true do
			local pos = string.find(src, sep, start, true)
			if not pos then
				fields[table.getn(fields) + 1] = string.sub(src, start)
				break
			end
			fields[table.getn(fields) + 1] = string.sub(src, start, pos - 1)
			start = pos + lensep
		end
		return unpack(fields)
	end
end

local _libs = {}

local LibStub = {}
function LibStub:NewLibrary(name, minor)
	local lib = _libs[name]
	if not lib then
		lib = {}
		_libs[name] = lib
		return lib
	end
	return nil
end

function LibStub:GetLibrary(name, silent)
	local lib = _libs[name]
	if lib then
		return lib
	end
	if silent then
		return nil
	end
	error("Cannot find a library instance of " .. tostring(name))
end

setmetatable(LibStub, {
	__call = function(self, name, silent)
		return self:GetLibrary(name, silent)
	end
})

_G.LibStub = LibStub

do
	local aceLocale = {}
	local apps = {}

	function aceLocale:NewLocale(app, locale, isDefault)
		local appLocales = apps[app]
		if not appLocales then
			appLocales = {default = nil, data = {}}
			apps[app] = appLocales
		end

		local current = GetLocale and GetLocale() or "enUS"
		local shouldLoad = isDefault or (locale == current)
		if not shouldLoad then
			return nil
		end

		local tbl = appLocales.data[locale]
		if not tbl then
			tbl = {}
			appLocales.data[locale] = tbl
		end
		if isDefault then
			appLocales.default = tbl
		end
		return tbl
	end

	function aceLocale:GetLocale(app)
		local appLocales = apps[app]
		if not appLocales then
			error("Unknown locale app: " .. tostring(app))
		end
		local current = GetLocale and GetLocale() or "enUS"
		local tbl = appLocales.data[current] or appLocales.default
		if not tbl then
			error("No locale table for app: " .. tostring(app))
		end
		return setmetatable(tbl, {
			__index = appLocales.default or tbl
		})
	end

	_libs["AceLocale-3.0"] = aceLocale
end

do
	local aceDB = {}

	local function copyDefaults(src, dst)
		for k, v in pairs(src) do
			if type(v) == "table" then
				if type(dst[k]) ~= "table" then
					dst[k] = {}
				end
				copyDefaults(v, dst[k])
			elseif dst[k] == nil then
				dst[k] = v
			end
		end
	end

	function aceDB:New(name, defaults)
		if type(_G[name]) ~= "table" then
			_G[name] = {}
		end
		local root = _G[name]
		if type(root.profile) ~= "table" then
			root.profile = {}
		end
		if type(root.global) ~= "table" then
			root.global = {}
		end
		if type(root.char) ~= "table" then
			root.char = {}
		end
		if defaults then
			copyDefaults(defaults, root)
		end

		local db = root
		function db:RegisterCallback()
		end
		function db:UnregisterCallback()
		end
		return db
	end

	_libs["AceDB-3.0"] = aceDB
end

do
	local aceConfig = {}
	function aceConfig:RegisterOptionsTable()
	end
	_libs["AceConfig-3.0"] = aceConfig

	local aceConfigDialog = {}
	function aceConfigDialog:AddToBlizOptions()
		return nil
	end
	function aceConfigDialog:Open()
	end
	_libs["AceConfigDialog-3.0"] = aceConfigDialog

	local aceConfigCmd = {}
	function aceConfigCmd:HandleCommand()
	end
	_libs["AceConfigCmd-3.0"] = aceConfigCmd
end

do
	local aceAddon = {}

	local function addonPrint(self, msg)
		if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00" .. tostring(self.name or "Talented") .. ":|r " .. tostring(msg))
		elseif print then
			print(tostring(self.name or "Talented") .. ": " .. tostring(msg))
		end
	end

	local function dispatchEvent(self, ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
		if ev == "ADDON_LOADED" and not self._initialized and a1 == self.name then
			self._initialized = true
			if self.OnInitialize then
				self:OnInitialize()
			end
		elseif ev == "PLAYER_LOGIN" and not self._enabled then
			if not self._initialized and self.OnInitialize then
				self._initialized = true
				self:OnInitialize()
			end
			self._enabled = true
			if self.OnEnable then
				self:OnEnable()
			end
		end

		local method = self._eventHandlers and self._eventHandlers[ev]
		if not method then
			method = self[ev]
		elseif type(method) == "string" then
			method = self[method]
		end
		if method then
			method(self, ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
		end
	end

	local function ensureFrame(self)
		if self._eventFrame then
			return
		end
		local frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
			dispatchEvent(self, ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
		end)
		self._eventFrame = frame
	end

	function aceAddon:NewAddon(name)
		local addon = {
			name = name,
			_eventHandlers = {},
			hooks = {},
			securehooks = {},
			_initialized = false,
			_enabled = false
		}

		function addon:Print(msg, a1, a2, a3, a4, a5)
			if type(msg) == "string" and string.find(msg, "%%", 1, true) and a1 ~= nil then
				addonPrint(self, string.format(msg, a1, a2, a3, a4, a5))
			else
				addonPrint(self, msg)
			end
		end

		function addon:RegisterEvent(ev, method)
			ensureFrame(self)
			self._eventHandlers[ev] = method or ev
			self._eventFrame:RegisterEvent(ev)
		end

		function addon:UnregisterEvent(ev)
			if self._eventFrame then
				self._eventFrame:UnregisterEvent(ev)
			end
			self._eventHandlers[ev] = nil
		end

		function addon:RegisterChatCommand(cmd, method)
			local key = string.upper((cmd or "talented"):gsub("^/", ""))
			SlashCmdList = SlashCmdList or {}
			SlashCmdList[key] = function(msg)
				local m = method
				if type(m) == "string" then
					m = addon[m]
				end
				if m then
					m(addon, msg)
				end
			end
			_G["SLASH_" .. key .. "1"] = "/" .. (cmd or "talented")
		end

		function addon:RawHook(funcName)
			local original = _G[funcName]
			if type(original) ~= "function" then
				return
			end
			self.hooks[funcName] = original
			_G[funcName] = function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
				local m = addon[funcName]
				if m then
					return m(addon, a1, a2, a3, a4, a5, a6, a7, a8, a9)
				end
				return original(a1, a2, a3, a4, a5, a6, a7, a8, a9)
			end
		end

		function addon:SecureHook(funcName)
			local original = _G[funcName]
			if type(original) ~= "function" then
				return
			end
			self.securehooks[funcName] = original
			_G[funcName] = function(a1, a2, a3, a4, a5, a6, a7, a8, a9)
				local r1, r2, r3, r4, r5, r6, r7, r8, r9 = original(a1, a2, a3, a4, a5, a6, a7, a8, a9)
				local m = addon[funcName]
				if m then
					m(addon, a1, a2, a3, a4, a5, a6, a7, a8, a9)
				end
				return r1, r2, r3, r4, r5, r6, r7, r8, r9
			end
		end

		function addon:RegisterComm()
		end
		function addon:SendCommMessage()
		end
		function addon:Serialize(a, b)
			return tostring(a or "") .. "\031" .. tostring(b or "")
		end
		function addon:Deserialize(msg)
			local a, b = string.match(msg or "", "^(.-)\031(.*)$")
			if not a then
				return false
			end
			return true, a, b
		end

		ensureFrame(addon)
		addon._eventFrame:RegisterEvent("ADDON_LOADED")
		addon._eventFrame:RegisterEvent("PLAYER_LOGIN")

		return addon
	end

	_libs["AceAddon-3.0"] = aceAddon
	_libs["AceEvent-3.0"] = {}
	_libs["AceHook-3.0"] = {}
	_libs["AceConsole-3.0"] = {}
	_libs["AceComm-3.0"] = {}
	_libs["AceSerializer-3.0"] = {}
	_libs["AceDBOptions-3.0"] = nil
end
