-- Talented inspect debug module.
-- Enable via /talented -> Options -> "Debug Inspect" toggle.
-- When enabled, prints a chat-frame report at each key stage of the inspect
-- pipeline so you can see exactly what data is flowing through.

local Talented = _G.Talented
local L = _G.TalentedLocale or setmetatable({}, {__index = function(t, k) t[k] = k return k end})

local function globalsSummary()
	local checks = {
		"InspectTalentsComFrame",
		"InspectFrameTalentsTab_OnClick",
		"TWInspectTalents_Show",
		"Ins_Init",
		"TWTalentFrame",
		"InspectFrameTab4",
		"InspectFrameTab5",
	}
	local found, missing = {}, {}
	for i = 1, table.getn(checks) do
		local k = checks[i]
		if _G[k] ~= nil then
			found[table.getn(found) + 1] = k
		else
			missing[table.getn(missing) + 1] = k
		end
	end
	return "present=[" .. table.concat(found, ",") .. "]  nil=[" .. table.concat(missing, ",") .. "]"
end

local function specSummary()
	local spec
	local com = _G.inspectCom or _G.InspectTalentsComFrame
	if type(com) == "table" and type(com.SPEC) == "table" then
		spec = com.SPEC
	elseif type(Talented._turtleInspectSpec) == "table" then
		spec = Talented._turtleInspectSpec
	else
		return "(no spec store found)"
	end
	local class = tostring(spec.class or "?")
	local parts = {"class=" .. class}
	for t = 1, 3 do
		local tree = spec[t]
		if type(tree) == "table" then
			local spent = 0
			local slots = 0
			for i = 1, 30 do
				if tree[i] ~= nil then
					slots = i
					local r = type(tree[i]) == "table" and tree[i].rank or nil
					if type(r) == "number" and r > 0 then
						spent = spent + r
					end
				end
			end
			parts[t + 1] = "tab" .. t .. ":[" .. slots .. " slots, " .. spent .. " pts]"
		else
			parts[t + 1] = "tab" .. t .. ":nil"
		end
	end
	return table.concat(parts, "  ")
end

function Talented:DebugInspect(msg)
	if not (self.db and self.db.profile and self.db.profile.debug_inspect) then
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[TalentedDebug]|r " .. tostring(msg) .. "\n  SPEC: " .. specSummary() .. "\n  GLOBALS: " .. globalsSummary())
end
