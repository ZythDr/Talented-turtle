local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local TALENT_SPEC_PRIMARY = _G.TALENT_SPEC_PRIMARY or TALENTS or "Primary"
local TALENT_SPEC_SECONDARY = _G.TALENT_SPEC_SECONDARY or "Secondary"
local internals = Talented._internals or {}

local function CompatGetNumTalentGroups()
	if type(_G.GetNumTalentGroups) == "function" then
		local ok, value = pcall(_G.GetNumTalentGroups)
		if ok and type(value) == "number" and value > 0 then
			return value
		end
	end
	return 1
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

-------------------------------------------------------------------------------
-- viewmode.lua
--

do
	local ipairs = ipairs
	local GetNumTalentTabs = internals.GetNumTalentTabs or _G.GetNumTalentTabs
	local GetTalentInfo = internals.GetTalentInfo or _G.GetTalentInfo
	local GetNumTalentGroups = CompatGetNumTalentGroups
	local GetActiveTalentGroup = CompatGetActiveTalentGroup

	function Talented:UpdatePlayerSpecs()
		if GetNumTalentTabs() == 0 then return end
		local _, class = UnitClass("player")
		local info = self:UncompressSpellData(class)
		if not self.alternates then
			self.alternates = {}
		end
		for talentGroup = 1, GetNumTalentGroups() do
			local template = self.alternates[talentGroup]
			if not template then
				template = {
					talentGroup = talentGroup,
					name = talentGroup == 1 and TALENT_SPEC_PRIMARY or TALENT_SPEC_SECONDARY,
					class = class
				}
			else
				template.points = nil
			end
			for tab, tree in ipairs(info) do
				local ttab = template[tab]
				if not ttab then
					ttab = {}
					template[tab] = ttab
				end
				for index = 1, table.getn(tree) do
					local _, _, _, _, rank = GetTalentInfo(tab, index, nil, nil, talentGroup)
					ttab[index] = rank or 0
				end
			end
			self.alternates[talentGroup] = template
			if self.template == template then
				self:UpdateTooltip()
			end
			for _, view in self:IterateTalentViews(template) do
				view:Update()
			end
		end
	end

	function Talented:GetActiveSpec()
		if not self.alternates then
			self:UpdatePlayerSpecs()
		end
		return self.alternates[GetActiveTalentGroup()]
	end

	function Talented:UpdateView()
		if not self.base then return end
		self.base.view:Update()
	end
end

-------------------------------------------------------------------------------
