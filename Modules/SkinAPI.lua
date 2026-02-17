local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

-- Stable helper API for external skinners (e.g. pfUI-addonskinner).
-- It intentionally returns raw widget references and avoids any styling itself.

local function add_unique(out, seen, key, obj)
	if type(obj) ~= "table" then
		return
	end
	if seen[obj] then
		return
	end
	seen[obj] = true
	out[key][table.getn(out[key]) + 1] = obj
end

function Talented:RegisterSkinCallback(id, fn)
	if type(id) ~= "string" or id == "" or type(fn) ~= "function" then
		return false
	end
	self._skinCallbacks = self._skinCallbacks or {}
	self._skinCallbacks[id] = fn
	return true
end

function Talented:UnregisterSkinCallback(id)
	if type(id) ~= "string" or id == "" then
		return false
	end
	if type(self._skinCallbacks) ~= "table" then
		return false
	end
	self._skinCallbacks[id] = nil
	return true
end

function Talented:RunSkinCallbacks(reason)
	local callbacks = self._skinCallbacks
	if type(callbacks) ~= "table" then
		return
	end
	for id, fn in pairs(callbacks) do
		if type(fn) == "function" then
			pcall(fn, self, reason)
		end
	end
end

function Talented:GetSkinTargets()
	local out = {
		frames = {},
		buttons = {},
		edits = {},
		fontStrings = {},
		textures = {},
		treeFrames = {},
		talentButtons = {}
	}
	local seen = {}

	local base = self.base
	if type(base) == "table" then
		add_unique(out, seen, "frames", base)
		add_unique(out, seen, "buttons", base.bactions)
		add_unique(out, seen, "buttons", base.bmode)
		add_unique(out, seen, "buttons", base.close)
		add_unique(out, seen, "buttons", base.checkbox)
		add_unique(out, seen, "buttons", base.bactivate)
		add_unique(out, seen, "buttons", base.templatecolor)

		add_unique(out, seen, "edits", base.editname)

		add_unique(out, seen, "fontStrings", base.targetname)
		add_unique(out, seen, "fontStrings", base.points)
		if type(base.pointsleft) == "table" then
			add_unique(out, seen, "frames", base.pointsleft)
			add_unique(out, seen, "fontStrings", base.pointsleft.text)
		end
		if type(base.checkbox) == "table" then
			add_unique(out, seen, "fontStrings", base.checkbox.label)
		end
		if type(base.templatecolor) == "table" then
			add_unique(out, seen, "textures", base.templatecolor.swatch)
		end
	end

	if type(self.IterateTalentViews) == "function" then
		for _, view in self:IterateTalentViews() do
			if type(view) == "table" and type(view.GetUIElement) == "function" and type(view.template) == "table" then
				local template = view.template
				local trees = self:UncompressSpellData(template.class)
				if type(trees) == "table" then
					for tab, tree in ipairs(trees) do
						local treeFrame = view:GetUIElement(tab)
						add_unique(out, seen, "treeFrames", treeFrame)
						add_unique(out, seen, "frames", treeFrame)
						if type(treeFrame) == "table" then
							add_unique(out, seen, "textures", treeFrame.topleft)
							add_unique(out, seen, "textures", treeFrame.topright)
							add_unique(out, seen, "textures", treeFrame.bottomleft)
							add_unique(out, seen, "textures", treeFrame.bottomright)
							add_unique(out, seen, "fontStrings", treeFrame.name)
							add_unique(out, seen, "buttons", treeFrame.clear)
							add_unique(out, seen, "frames", treeFrame.overlay)
						end

						for index, talent in ipairs(tree) do
							if not talent.inactive then
								local button = view:GetUIElement(tab, index)
								add_unique(out, seen, "talentButtons", button)
								add_unique(out, seen, "buttons", button)
								if type(button) == "table" then
									add_unique(out, seen, "textures", button.texture)
									add_unique(out, seen, "textures", button.slot)
									add_unique(out, seen, "fontStrings", button.rank)
									if type(button.rank) == "table" then
										add_unique(out, seen, "textures", button.rank.texture)
									end
									if type(button.target) == "table" then
										add_unique(out, seen, "fontStrings", button.target)
										add_unique(out, seen, "textures", button.target.texture)
									end
								end
							end

							local req = talent.req
							if req then
								local lineElements = view:GetUIElement(tab, index, req)
								if type(lineElements) == "table" then
									for _, element in ipairs(lineElements) do
										add_unique(out, seen, "textures", element)
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return out
end
