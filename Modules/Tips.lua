local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

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


-------------------------------------------------------------------------------
-- tips.lua
--

do
	local type = type
	local ipairs = ipairs
	local GameTooltip = GameTooltip
	local IsAltKeyDown = IsAltKeyDown
	local GREEN_FONT_COLOR = GREEN_FONT_COLOR
	local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
	local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
	local RED_FONT_COLOR = RED_FONT_COLOR

	local function addline(line, color, split)
		GameTooltip:AddLine(line, color.r, color.g, color.b, split)
	end

	local function TrySetNativeSpellTooltip(tooltip, spell)
		if type(spell) ~= "number" then
			return false
		end
		if type(tooltip.SetSpell) ~= "function" then
			if type(tooltip.SetHyperlink) == "function" and _G.SUPERWOW_VERSION then
				tooltip:ClearLines()
				local okEnchant = pcall(tooltip.SetHyperlink, tooltip, "enchant:" .. tostring(spell))
				return okEnchant and (tooltip:NumLines() or 0) > 0 or false
			end
			return false
		end
		tooltip:ClearLines()
		local ok = pcall(tooltip.SetSpell, tooltip, spell)
		if ok and (tooltip:NumLines() or 0) > 0 then
			return true
		end
		if type(tooltip.SetHyperlink) == "function" and _G.SUPERWOW_VERSION then
			tooltip:ClearLines()
			local okEnchant = pcall(tooltip.SetHyperlink, tooltip, "enchant:" .. tostring(spell))
			if okEnchant and (tooltip:NumLines() or 0) > 0 then
				return true
			end
		end
		return false
	end

		local function addtipline(tip)
			local color = HIGHLIGHT_FONT_COLOR
			tip = tip or ""
			if type(tip) == "string" then
				addline(tip, NORMAL_FONT_COLOR, true)
			else
				for _, i in ipairs(tip) do
					if (_ == table.getn(tip)) then
						color = NORMAL_FONT_COLOR
					end
					local left = i and i.left or ""
					local right = i and i.right or ""
					if type(left) == "string" and left == "" then
						left = nil
					end
					if type(right) == "string" and right == "" then
						right = nil
					end
					if left and right then
						GameTooltip:AddDoubleLine(left, right, color.r, color.g, color.b, color.r, color.g, color.b)
					elseif right then
						addline(right, color, true)
					elseif left then
						addline(left, color, true)
					end
				end
			end
		end

		local function tiphasline(tip, needle)
			if type(needle) ~= "string" or needle == "" then
				return false
			end
			if type(tip) == "string" then
				return string.find(tip, needle, 1, true) ~= nil
			end
			if type(tip) ~= "table" then
				return false
			end
			for _, row in ipairs(tip) do
				if type(row) == "string" then
					if string.find(row, needle, 1, true) then
						return true
					end
				elseif type(row) == "table" then
					local left = row.left
					local right = row.right
					if type(left) == "string" and string.find(left, needle, 1, true) then
						return true
					end
					if type(right) == "string" and string.find(right, needle, 1, true) then
						return true
					end
				end
			end
			return false
		end

	local lastTooltipInfo = {}
	local function TooltipIsOwnedByFrame(frame)
		if not frame or type(GameTooltip.IsOwned) ~= "function" then
			return false
		end
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, frame)
		return ok and owned
	end

		local function IsValidTooltipFrame(frame)
			if not frame then
				return false
			end
		if type(frame.GetParent) ~= "function" then
			return false
		end
		local parent = frame:GetParent()
		if not parent or type(parent.view) ~= "table" then
			return false
		end
			return true
		end

		local function TooltipHasLineText(needle)
			if type(needle) ~= "string" or needle == "" then
				return false
			end
			local count = (type(GameTooltip.NumLines) == "function" and GameTooltip:NumLines()) or 0
			for i = 1, count do
				local fs = _G["GameTooltipTextLeft" .. i]
				if fs and type(fs.GetText) == "function" then
					local text = fs:GetText()
					if type(text) == "string" and string.find(text, needle, 1, true) then
						return true
					end
				end
			end
			return false
		end

		function Talented:SetTooltipInfo(frame, class, tab, index)
		if not IsValidTooltipFrame(frame) then
			wipe(lastTooltipInfo)
			if GameTooltip:IsShown() then
				GameTooltip:Hide()
			end
			return
		end
			lastTooltipInfo[1] = frame
			lastTooltipInfo[2] = class
			lastTooltipInfo[3] = tab
			lastTooltipInfo[4] = index
				if not TooltipIsOwnedByFrame(frame) then
					local ok = pcall(GameTooltip.SetOwner, GameTooltip, frame, "ANCHOR_RIGHT")
					if not ok then
						wipe(lastTooltipInfo)
						return
					end
				end

			GameTooltip:ClearLines()
				local template = frame:GetParent().view.template
				self:UnpackTemplate(template)
				local rank = template[tab][index]
				local _, playerClass = UnitClass("player")
				local usingDefaultTooltip = false
				local allowNativeTooltip = (class == playerClass and template and template.talentGroup and not IsAltKeyDown())
				if allowNativeTooltip and type(GameTooltip.SetTalent) == "function" then
					local ok = pcall(GameTooltip.SetTalent, GameTooltip, tab, index)
					if ok and (GameTooltip:NumLines() or 0) > 0 then
						usingDefaultTooltip = true
					else
						GameTooltip:ClearLines()
					end
				end

				if not usingDefaultTooltip and allowNativeTooltip then
					local spell = self:GetTalentSpellID(class, tab, index, rank > 0 and rank or 1)
					if TrySetNativeSpellTooltip(GameTooltip, spell) then
						usingDefaultTooltip = true
					end
				end

				if not usingDefaultTooltip then
					local tree = self.spelldata[class][tab]
					local info = tree[index]
					local tier = (info.row - 1) * self:GetSkillPointsPerTier(class)
					local ranks, req = table.getn(info.ranks), info.req
					local hasLearnHint = false
					addline(self:GetTalentName(class, tab, index), HIGHLIGHT_FONT_COLOR)
					addline(SafeFormat(TOOLTIP_TALENT_RANK or "Rank %d/%d", rank, ranks), HIGHLIGHT_FONT_COLOR)
				if req then
					local oranks = table.getn(tree[req].ranks)
					if template[tab][req] < oranks then
						addline(SafeFormat(TOOLTIP_TALENT_PREREQ or "", oranks, self:GetTalentName(class, tab, req)), RED_FONT_COLOR)
					end
				end
				if tier >= 1 and self:GetTalentTabCount(template, tab) < tier then
					addline(SafeFormat(TOOLTIP_TALENT_TIER_POINTS or "", tier, self.tabdata[class][tab].name), RED_FONT_COLOR)
				end
					if IsAltKeyDown() then
						for i = 1, ranks do
								local tip = self:GetTalentDesc(class, tab, index, i, allowNativeTooltip)
							if type(tip) == "table" then
								tip = tip[table.getn(tip)].left
						end
						addline(tip, i == rank and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR, true)
						end
					else
							if rank > 0 then
									local currentTip = self:GetTalentDesc(class, tab, index, rank, allowNativeTooltip)
									addtipline(currentTip)
									hasLearnHint = tiphasline(currentTip, TOOLTIP_TALENT_LEARN)
								end
								if rank < ranks then
									addline("|n" .. (TOOLTIP_TALENT_NEXT_RANK or "Next rank:"), HIGHLIGHT_FONT_COLOR)
									local nextTip = self:GetTalentDesc(class, tab, index, rank + 1, allowNativeTooltip)
									addtipline(nextTip)
									if not hasLearnHint then
										hasLearnHint = tiphasline(nextTip, TOOLTIP_TALENT_LEARN)
									end
								end
							end
						end
			local s = self:GetTalentState(template, tab, index)
		if self.mode == "edit" then
			if template.talentGroup then
				if (s == "available" or s == "empty") and not hasLearnHint and not TooltipHasLineText(TOOLTIP_TALENT_LEARN) then
					addline(TOOLTIP_TALENT_LEARN, GREEN_FONT_COLOR)
				end
			elseif s == "full" then
				addline(TALENT_TOOLTIP_REMOVEPREVIEWPOINT, GREEN_FONT_COLOR)
			elseif s == "available" then
				GameTooltip:AddDoubleLine(
					TALENT_TOOLTIP_ADDPREVIEWPOINT,
					TALENT_TOOLTIP_REMOVEPREVIEWPOINT,
					GREEN_FONT_COLOR.r,
					GREEN_FONT_COLOR.g,
					GREEN_FONT_COLOR.b,
					GREEN_FONT_COLOR.r,
					GREEN_FONT_COLOR.g,
					GREEN_FONT_COLOR.b
				)
			elseif s == "empty" then
				addline(TALENT_TOOLTIP_ADDPREVIEWPOINT, GREEN_FONT_COLOR)
			end
		end
		GameTooltip:Show()
	end

	function Talented:HideTooltipInfo()
		GameTooltip:Hide()
		wipe(lastTooltipInfo)
	end

		function Talented:UpdateTooltip()
			local frame = lastTooltipInfo[1]
			if next(lastTooltipInfo) and IsValidTooltipFrame(frame) then
				self:SetTooltipInfo(unpack(lastTooltipInfo))
			elseif next(lastTooltipInfo) then
				self:HideTooltipInfo()
			end
		end

	function Talented:MODIFIER_STATE_CHANGED(mod)
		if string.sub(mod or "", -3) == "ALT" then
			self:UpdateTooltip()
		end
	end
end
