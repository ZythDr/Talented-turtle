local Talented = _G.Talented
if type(Talented) ~= "table" then
	return
end

-------------------------------------------------------------------------------
-- encode.lua
--

do
	local assert, ipairs = assert, ipairs
	local modf = math.modf or function(x)
		return math.floor(tonumber(x) or 0)
	end
	local fmod = math.fmod or math.mod or function(a, b)
		a = tonumber(a) or 0
		b = tonumber(b) or 1
		if b == 0 then
			return 0
		end
		return a - math.floor(a / b) * b
	end

	local stop = "Z"
	local talented_map = "012345abcdefABCDEFmnopqrMNOPQRtuvwxy*"
	local classmap = {
		"DRUID",
		"HUNTER",
		"MAGE",
		"PALADIN",
		"PRIEST",
		"ROGUE",
		"SHAMAN",
		"WARLOCK",
		"WARRIOR"
	}

	function Talented:GetTemplateStringClass(code, nmap)
		nmap = nmap or talented_map
		if string.len(code) <= 0 then return end
		local first = string.find(nmap, string.sub(code, 1, 1), 1, true)
		if not first then
			return
		end
		local index = modf((first - 1) / 3) + 1
		if not index or index > table.getn(classmap) then return end
		return classmap[index]
	end

	local function get_point_string(class, tabs, primary)
		if type(tabs) == "number" then
			return " - |cffffd200" .. tabs .. "|r"
		end
		local start = " - |cffffd200"
		if primary then
			start = start .. Talented.tabdata[class][primary].name .. " "
			tabs[primary] = "|cffffffff" .. tostring(tabs[primary]) .. "|cffffd200"
		end
		return start .. table.concat(tabs, "/", 1, 3) .. "|r"
	end

	local temp_tabcount = {}
		local function GetTemplateStringInfo(code)
		if string.len(code) <= 0 then return end

			local first = string.find(talented_map, string.sub(code, 1, 1), 1, true)
			if not first then
				return
			end
			local index = modf((first - 1) / 3) + 1
			if not index or index > table.getn(classmap) then return end
			local class = classmap[index]
			local talents = Talented:UncompressSpellData(class)
			if not talents then
				return
			end
		local tabs, count, t = 1, 0, 0
		for i = 2, string.len(code) do
			local char = string.sub(code, i, i)
			if char == stop then
				if t >= table.getn(talents[tabs]) then
					temp_tabcount[tabs] = count
					tabs = tabs + 1
					count, t = 0, 0
				end
				temp_tabcount[tabs] = count
				tabs = tabs + 1
				count, t = 0, 0
			else
				index = string.find(talented_map, char, 1, true) - 1
				if not index then
					return
				end
				local b = fmod(index, 6)
				local a = (index - b) / 6
				if t >= table.getn(talents[tabs]) then
					temp_tabcount[tabs] = count
					tabs = tabs + 1
					count, t = 0, 0
				end
				t = t + 2
				count = count + a + b
			end
		end
		if count > 0 then
			temp_tabcount[tabs] = count
		else
			tabs = tabs - 1
		end
		for i = tabs + 1, table.getn(talents) do
			temp_tabcount[i] = 0
		end
		tabs = table.getn(talents)
		if tabs == 1 then
			return get_point_string(class, temp_tabcount[1])
		else -- tab == 3
			local primary, min, max, total = 0, 0, 0, 0
			for i = 1, tabs do
				local points = temp_tabcount[i]
				if points < min then
					min = points
				end
				if points > max then
					primary, max = i, points
				end
				total = total + points
			end
			local middle = total - min - max
			if 3 * (middle - min) >= 2 * (max - min) then
				primary = nil
			end
			return get_point_string(class, temp_tabcount, primary)
		end
	end

	function Talented:GetTemplateInfo(template)
		self:Debug("GET TEMPLATE INFO", template.name)
		if template.code then
			return GetTemplateStringInfo(template.code)
		else
			local tabs = table.getn(template)
			if tabs == 1 then
				return get_point_string(template.class, self:GetPointCount(template))
			else
				local primary, min, max, total = 0, 0, 0, 0
				for i = 1, tabs do
					local points = 0
					for _, value in ipairs(template[i]) do
						points = points + value
					end
					temp_tabcount[i] = points
					if points < min then
						min = points
					end
					if points > max then
						primary, max = i, points
					end
					total = total + points
				end
				local middle = total - min - max
				if 3 * (middle - min) >= 2 * (max - min) then
					primary = nil
				end
				return get_point_string(template.class, temp_tabcount, primary)
			end
		end
	end

		function Talented:StringToTemplate(code, template, nmap)
			nmap = nmap or talented_map
			if type(code) ~= "string" or string.len(code) <= 0 then return end

			local first = string.find(nmap, string.sub(code, 1, 1), 1, true)
			if not first then
				return
			end
			local index = modf((first - 1) / 3) + 1
			if not index or index > table.getn(classmap) then
				return
			end

			local class = classmap[index]
			template = template or {}
			template.class = class
			for i = 1, table.getn(template) do
				template[i] = nil
			end

				local talents = self:UncompressSpellData(class)
				if type(talents) ~= "table" then
					return
				end

			local function tree_size(tree)
				if type(tree) ~= "table" then
					return nil
				end
				return table.getn(tree)
			end
			local function reset_tab(tabIndex)
				local tbl = template[tabIndex]
				if type(tbl) ~= "table" then
					tbl = {}
				else
					wipe(tbl)
				end
				template[tabIndex] = tbl
				return tbl
			end

			local tab = 1
			local t = reset_tab(tab)

			for i = 2, string.len(code) do
				local char = string.sub(code, i, i)
				if char == stop then
					local tree = talents[tab]
					local treeCount = tree_size(tree)
					if not treeCount then
						return
					end
					if table.getn(t) >= treeCount then
						tab = tab + 1
						tree = talents[tab]
						treeCount = tree_size(tree)
						if not treeCount then
							return
						end
						t = reset_tab(tab)
					end
					tab = tab + 1
					if not talents[tab] then
						return
					end
					t = reset_tab(tab)
				else
					local pos = string.find(nmap, char, 1, true)
					if not pos then
						return
					end
					index = pos - 1
					local b = fmod(index, 6)
					local a = (index - b) / 6

					local tree = talents[tab]
					local treeCount = tree_size(tree)
					if not treeCount then
						return
					end
					if table.getn(t) >= treeCount then
						tab = tab + 1
						tree = talents[tab]
						treeCount = tree_size(tree)
						if not treeCount then
							return
						end
						t = reset_tab(tab)
					end
					t[table.getn(t) + 1] = a

					if table.getn(t) < treeCount then
						t[table.getn(t) + 1] = b
					else
						if b ~= 0 then
							return
						end
					end
				end
			end

			if table.getn(template) > table.getn(talents) then
				return
			end
				do
					for tb, tree in ipairs(talents) do
						if type(tree) ~= "table" then
							return
						end
						local _t = template[tb] or {}
						template[tb] = _t
					for i = 1, table.getn(tree) do
					_t[i] = _t[i] or 0
				end
			end
		end

		return template, class
	end

	local function rtrim(s, c)
		local l = string.len(s)
		while l >= 1 and string.sub(s, l, l) == c do
			l = l - 1
		end
		return string.sub(s, 1, l)
	end

	local function get_next_valid_index(tmpl, index, talents)
		if not talents[index] then
			return 0, index
		else
			return tmpl[index], index + 1
		end
	end

	function Talented:TemplateToString(template, nmap)
		nmap = nmap or talented_map

		local class = template.class

		local code, ccode = ""
		do
				for index, c in ipairs(classmap) do
					if c == class then
						local i = (index - 1) * 3 + 1
						ccode = string.sub(nmap, i, i)
						break
					end
				end
			end
			assert(ccode, "invalid class")
			local s = string.sub(nmap, 1, 1)
		local info = self:UncompressSpellData(class)
		for tab, talents in ipairs(info) do
			local tmpl = template[tab]
			local index = 1
			while index <= table.getn(tmpl) do
				local r1, r2
				r1, index = get_next_valid_index(tmpl, index, talents)
				r2, index = get_next_valid_index(tmpl, index, talents)
				local v = r1 * 6 + r2 + 1
				local c = string.sub(nmap, v, v)
				assert(c)
				code = code .. c
			end
			local ncode = rtrim(code, s)
			if ncode ~= code then
				code = ncode .. stop
			end
		end
		local output = ccode .. rtrim(code, stop)

		return output
	end

	function Talented:PackTemplate(template)
		if not template or template.talentGroup or template.code then return end
		self:Debug("PACK TEMPLATE", template.name)
		template.code = self:TemplateToString(template)
		for tab in ipairs(template) do
			template[tab] = nil
		end
	end

	function Talented:UnpackTemplate(template)
		if not template.code then return end
		self:Debug("UNPACK TEMPLATE", template.name)
		local decoded = {}
		local parsed = self:StringToTemplate(template.code, decoded)
		if not parsed or type(decoded.class) ~= "string" then
			return
		end
		for i = 1, table.getn(template) do
			template[i] = nil
		end
		template.class = decoded.class
		for tab, tree in ipairs(decoded) do
			template[tab] = tree
		end
		template.code = nil
		if not RAID_CLASS_COLORS[template.class] then
			self:FixPetTemplate(template)
		end
	end

	function Talented:CopyPackedTemplate(src, dst)
		local packed = src.code
		if packed then
			self:UnpackTemplate(src)
		end
		dst.code = nil
		dst.class = src.class
		for i = 1, table.getn(dst) do
			dst[i] = nil
		end
		for tab, talents in ipairs(src) do
			local d = {}
			dst[tab] = d
			for index, value in ipairs(talents) do
				d[index] = value
			end
		end
		if packed then
			self:PackTemplate(src)
		end
	end
end

