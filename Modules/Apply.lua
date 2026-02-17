-------------------------------------------------------------------------------
-- apply.lua
--

local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

local L = _G.TalentedLocale or {}

local function SafeGetUnspentTalentPoints()
	if type(_G.GetUnspentTalentPoints) == "function" then
		local ok, points = pcall(_G.GetUnspentTalentPoints)
		if ok and type(points) == "number" then
			return points
		end
	end
	if type(_G.UnitCharacterPoints) == "function" then
		local ok, cp = pcall(_G.UnitCharacterPoints, "player")
		if ok and type(cp) == "number" then
			return cp
		end
	end
	return 0
end

local function SafeLearnTalent(tab, index)
	if type(_G.LearnTalent) ~= "function" then
		return
	end
	local ok = pcall(_G.LearnTalent, tab, index, false)
	if not ok then
		pcall(_G.LearnTalent, tab, index)
	end
end

do
	function Talented:ApplyCurrentTemplate()
		local template = self.template
		local pet = not RAID_CLASS_COLORS[template.class]
		if pet then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your pet's class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local _, playerClass = UnitClass("player")
		if playerClass ~= template.class then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local count = 0
		local current = self:GetActiveSpec()
		-- check if enough talent points are available
		local available = SafeGetUnspentTalentPoints()
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			for index = 1, table.getn(tree) do
				local delta = template[tab][index] - current[tab][index]
				if delta > 0 then
					count = count + delta
				end
			end
		end
		if count == 0 then
			self:Print(L["Nothing to do"])
			self.mode = "view"
			self:UpdateView()
		elseif count > available then
			self:Print(L["Sorry, I can't apply this template because you don't have enough talent points available (need %d)!"], count)
			self.mode = "view"
			self:UpdateView()
		else
			self:EnableUI(false)
			self:ApplyTalentPoints()
		end
	end

	function Talented:ApplyTalentPoints()
		local template = self.template
		local current = self:GetActiveSpec()
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			for index = 1, table.getn(tree) do
				local target = template[tab][index]
				local rank = current[tab][index]
				if rank < target then
					local state = self:GetTalentState(current, tab, index)
					if state == "available" or state == "empty" then
						SafeLearnTalent(tab, index)
						-- Vanilla/Turtle talent updates are asynchronous.
						-- Apply one point per pass and continue on CHARACTER_POINTS_CHANGED.
						return true
					end
				end
			end
		end
		return self:CheckTalentPointsApplied()
	end

	function Talented:CheckTalentPointsApplied()
		local template = self.template
		local failed
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			local ttab = template[tab]
			for index = 1, table.getn(tree) do
				local _, _, _, _, currentRank = GetTalentInfo(tab, index)
				local delta = ttab[index] - (currentRank or 0)
				if delta > 0 then
					failed = true
					break
				end
			end
		end
		if failed then
			Talented:Print(L["Error while applying talents! some of the request talents were not set!"])
		else
			local cp = SafeGetUnspentTalentPoints()
			Talented:Print(L["Template applied successfully, %d talent points remaining."], cp)
		end
		Talented:OpenTemplate(self:GetActiveSpec())
		Talented:EnableUI(true)

		return not failed
	end
end
