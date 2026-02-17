local Talented = _G.Talented
local L = _G.TalentedLocale or setmetatable({}, {__index = function(t, k)
	t[k] = k
	return k
end})

Talented.max_talent_points = 51

Talented.defaults = {
		profile = {
			confirmlearn = true,
			level_cap = true,
			show_level_req = true,
			offset = 60,
			scale = 1,
				add_bottom_offset = true,
				dim_tree_background = false,
				framepos = {},
				hook_inspect_ui = true,
				template_tooltip_level = 60
			},
	global = {templates = {}},
	char = {targets = {}}
}

function Talented:SetOption(info, value)
	local name = info[table.getn(info)]
	self.db.profile[name] = value
	local arg = info.arg
	if arg then
		self[arg](self)
	end
end

function Talented:GetOption(info)
	local name = info[table.getn(info)]
	return self.db.profile[name]
end

function Talented:MustNotConfirmLearn()
	return not self.db.profile.confirmlearn
end

Talented.options = {
	desc = L["Talented - Talent Editor"],
	type = "group",
	childGroups = "tab",
	handler = Talented,
	get = "GetOption",
	set = "SetOption",
	args = {
		options = {
			name = L["Options"],
			desc = L["General Options for Talented."],
			type = "group",
			order = 1,
			args = {
				header1 = {
					type = "header",
					name = L["General options"],
					order = 1
				},
				always_edit = {
					type = "toggle",
					name = L["Always edit"],
					desc = L["Always allow templates and the current build to be modified, instead of having to Unlock them first."],
					arg = "UpdateView",
					order = 2
				},
				confirmlearn = {
					type = "toggle",
					name = L["Confirm Learning"],
					desc = L["Ask for user confirmation before learning any talent."],
					order = 3
				},
				always_call_learn_talents = {
					type = "toggle",
					name = L["Always try to learn talent"],
					desc = L["Always call the underlying API when a user input is made, even when no talent should be learned from it."],
					disabled = "MustNotConfirmLearn",
					order = 4
				},
				level_cap = {
					type = "toggle",
					name = L["Talent cap"],
					desc = string.format(L["Restrict templates to a maximum of %d points."], Talented.max_talent_points),
					arg = "UpdateView",
					order = 5
				},
				show_level_req = {
					type = "toggle",
					name = L["Level restriction"],
					desc = L["Show the required level for the template, instead of the number of points."],
					arg = "UpdateView",
					order = 6
				},
				hook_inspect_ui = {
					type = "toggle",
					name = L["Hook Inspect UI"],
					desc = L["Hook the Talent Inspection UI."],
					arg = "CheckHookInspectUI",
					order = 7
				},
				show_url_in_chat = {
					type = "toggle",
					name = L["Output URL in Chat"],
					desc = L["Disabled on this Vanilla build. Export uses the selectable URL dialog."],
					disabled = true,
					order = 8
				},
				header3 = {
					type = "header",
					name = L["Display options"],
					order = 9
				},
				offset = {
					type = "range",
					name = L["Icon offset"],
					desc = L["Distance between icons."],
					arg = "ReLayout",
					order = 10,
					min = 48,
					max = 64,
					step = 2
				},
				scale = {
					type = "range",
					name = L["Frame scale"],
					desc = L["Overall scale of the Talented frame."],
					arg = "ReLayout",
					order = 11,
					min = 0.5,
					max = 1.5,
					step = 0.01
				},
				add_bottom_offset = {
					type = "toggle",
					name = L["Add bottom offset"],
					desc = L["Add some space below the talents to show the bottom information."],
					arg = "ReLayout",
					order = 12
				},
				dim_tree_background = {
					type = "toggle",
					name = L["Dim tree backgrounds"],
					desc = L["Add a dark overlay over talent tree artwork to improve icon readability."],
					arg = "UpdateView",
					order = 13
				}
			}
		},
		apply = {
			name = "Apply",
			desc = "Apply the specified template",
			type = "input",
			dialogHidden = true,
			order = 99,
			set = function(_, name)
				local template = Talented.db.global.templates[name]
				if not template then
					Talented:Print(L['Can not apply, unknown template "%s"'], name)
					return
				end
				Talented:SetTemplate(template)
				Talented:SetMode "apply"
			end
		}
	}
}

function Talented:ReLayout()
	self:ViewsReLayout(true)
end

function Talented:UpgradeOptions()
	local p = self.db.profile
	if p.point or p.offsetx or p.offsety then
		local opts = {
			anchor = p.point or "CENTER",
			anchorTo = p.point or "CENTER",
			x = p.offsetx or 0,
			y = p.offsety or 0
		}
		p.framepos.TalentedFrame = opts
		p.point, p.offsetx, p.offsety = nil, nil, nil
	end
	local c = self.db.char
	if c.target then
		c.targets[1] = c.target
		c.target = nil
	end
	self.UpgradeOptions = nil
end

function Talented:SaveFramePosition(frame)
	local db = self.db.profile.framepos
	local name = frame:GetName()

	local data, _ = db[name]
	if not data then
		data = {}
		db[name] = data
	end
	data.anchor, _, data.anchorTo, data.x, data.y = frame:GetPoint(1)
end

function Talented:LoadFramePosition(frame)
	if not self.db then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		return
	end
	local data = self.db.profile.framepos[frame:GetName()]
	if data and data.anchor then
		frame:ClearAllPoints()
		frame:SetPoint(data.anchor, UIParent, data.anchorTo or data.anchor, data.x or 0, data.y or 0)
	else
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		self:SaveFramePosition(frame)
	end
end

local function BaseFrame_OnMouseDown(self)
	if self.OnMouseDown then
		self:OnMouseDown()
	end
	self:StartMoving()
end

local function BaseFrame_OnMouseUp(self)
	self:StopMovingOrSizing()
	Talented:SaveFramePosition(self)
	if self.OnMouseUp then
		self:OnMouseUp()
	end
end

function Talented:SetFrameLock(frame, locked)
	if not frame then
		frame = self.base or _G.TalentedFrame
		if not frame then
			return
		end
	end
	local db = self.db.profile.framepos
	local name = frame:GetName()
	if not name then
		return
	end
	local data = db[name]
	if not data then
		data = {}
		db[name] = data
	end
	if locked == nil then
		locked = data.locked
	elseif locked == false then
		locked = nil
	end
	data.locked = locked
	if locked then
		frame:SetMovable(false)
		frame:SetScript("OnMouseDown", nil)
		frame:SetScript("OnMouseUp", nil)
	else
		frame:SetMovable(true)
		frame:SetScript("OnMouseDown", BaseFrame_OnMouseDown)
		frame:SetScript("OnMouseUp", BaseFrame_OnMouseUp)
	end
	frame:SetClampedToScreen(true)
end

function Talented:GetFrameLock(frame)
	if not frame then
		frame = self.base or _G.TalentedFrame
		if not frame then
			return nil
		end
	end
	local data = self.db.profile.framepos[frame:GetName()]
	return data and data.locked
end
