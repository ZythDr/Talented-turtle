local Talented = _G.Talented
local L = _G.TalentedLocale or setmetatable({}, {__index = function(t, k)
	t[k] = k
	return k
end})
local ipairs, tonumber = ipairs, tonumber
local RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
local floor = math.floor or function(v)
	return tonumber(v) or 0
end
local fmod = math.fmod or math.mod or function(a, b)
	a = tonumber(a) or 0
	b = tonumber(b) or 1
	if b == 0 then
		return 0
	end
	return a - floor(a / b) * b
end

local CLASS_TO_SLUG = {
	WARRIOR = "warrior",
	PALADIN = "paladin",
	HUNTER = "hunter",
	ROGUE = "rogue",
	PRIEST = "priest",
	SHAMAN = "shaman",
	MAGE = "mage",
	WARLOCK = "warlock",
	DRUID = "druid"
}

local SLUG_TO_CLASS = {}
for class, slug in pairs(CLASS_TO_SLUG) do
	SLUG_TO_CLASS[slug] = class
end

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_INDEX = {}
do
	for i = 1, string.len(BASE64_ALPHABET) do
		local c = string.sub(BASE64_ALPHABET, i, i)
		BASE64_INDEX[c] = i - 1
	end
end

local function RTrim(s, c)
	local l = string.len(s)
	while l >= 1 and string.sub(s, l, l) == c do
		l = l - 1
	end
	return string.sub(s, 1, l)
end

local function Slice(list, first, last)
	local out = {}
	for i = first, last do
		out[table.getn(out) + 1] = list[i] or 0
	end
	return out
end

local function ToBinary(value, width)
	value = floor(tonumber(value) or 0)
	if value < 0 then
		value = 0
	end
	local out = {}
	for i = width, 1, -1 do
		local p = 2 ^ (i - 1)
		if value >= p then
			out[table.getn(out) + 1] = "1"
			value = value - p
		else
			out[table.getn(out) + 1] = "0"
		end
	end
	return table.concat(out)
end

local function BinaryToNumber(bits)
	local value = 0
	for i = 1, string.len(bits) do
		value = value * 2
		if string.sub(bits, i, i) == "1" then
			value = value + 1
		end
	end
	return value
end

local function Base64EncodeBytes(bytes)
	local out = {}
	local i = 1
	while i <= table.getn(bytes) do
		local b1 = bytes[i] or 0
		local has2 = (bytes[i + 1] ~= nil)
		local has3 = (bytes[i + 2] ~= nil)
		local b2 = has2 and bytes[i + 1] or 0
		local b3 = has3 and bytes[i + 2] or 0

		local c1 = floor(b1 / 4)
		local c2 = fmod(b1, 4) * 16 + floor(b2 / 16)
		local c3 = has2 and (fmod(b2, 16) * 4 + floor(b3 / 64)) or 64
		local c4 = has3 and fmod(b3, 64) or 64

		out[table.getn(out) + 1] = string.sub(BASE64_ALPHABET, c1 + 1, c1 + 1)
		out[table.getn(out) + 1] = string.sub(BASE64_ALPHABET, c2 + 1, c2 + 1)
		out[table.getn(out) + 1] = (c3 == 64) and "=" or string.sub(BASE64_ALPHABET, c3 + 1, c3 + 1)
		out[table.getn(out) + 1] = (c4 == 64) and "=" or string.sub(BASE64_ALPHABET, c4 + 1, c4 + 1)

		i = i + 3
	end
	return table.concat(out)
end

local function Base64DecodeToBytes(base64)
	if type(base64) ~= "string" then
		return {}
	end
	local clean = {}
	for i = 1, string.len(base64) do
		local c = string.sub(base64, i, i)
		if c == "=" or BASE64_INDEX[c] ~= nil then
			clean[table.getn(clean) + 1] = c
		end
	end
	local s = table.concat(clean)
	local rem = fmod(string.len(s), 4)
	if rem ~= 0 then
		s = s .. string.rep("=", 4 - rem)
	end

	local bytes = {}
	local i = 1
	while i <= string.len(s) do
		local c1 = string.sub(s, i, i)
		local c2 = string.sub(s, i + 1, i + 1)
		local c3 = string.sub(s, i + 2, i + 2)
		local c4 = string.sub(s, i + 3, i + 3)
		if c1 == "" or c2 == "" or c1 == "=" or c2 == "=" then
			break
		end

		local v1 = BASE64_INDEX[c1] or 0
		local v2 = BASE64_INDEX[c2] or 0
		local v3 = (c3 == "=") and 0 or (BASE64_INDEX[c3] or 0)
		local v4 = (c4 == "=") and 0 or (BASE64_INDEX[c4] or 0)

		local b1 = v1 * 4 + floor(v2 / 16)
		local b2 = fmod(v2, 16) * 16 + floor(v3 / 4)
		local b3 = fmod(v3, 4) * 64 + v4

		bytes[table.getn(bytes) + 1] = b1
		if c3 ~= "=" then
			bytes[table.getn(bytes) + 1] = b2
		end
		if c4 ~= "=" then
			bytes[table.getn(bytes) + 1] = b3
		end
		i = i + 4
	end

	return bytes
end

local function BytesToBinaryString(bytes)
	local out = {}
	for _, byte in ipairs(bytes) do
		out[table.getn(out) + 1] = ToBinary(byte, 8)
	end
	return table.concat(out)
end

local function BinaryStringToValues(binary, size)
	local values = {}
	local i = 1
	while i <= string.len(binary) do
		local bits = string.sub(binary, i, i + size - 1)
		if bits == "" then
			break
		end
		values[table.getn(values) + 1] = BinaryToNumber(bits)
		i = i + size
	end
	return values
end

local function SplitByHyphen(s)
	local out = {}
	local start = 1
	while true do
		local dash = string.find(s, "-", start, true)
		if not dash then
			out[table.getn(out) + 1] = string.sub(s, start)
			break
		end
		out[table.getn(out) + 1] = string.sub(s, start, dash - 1)
		start = dash + 1
	end
	return out
end

local function UrlDecode(s)
	if type(s) ~= "string" then
		return nil
	end
	s = string.gsub(s, "%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16) or 0)
	end)
	return s
end

local function UrlEncode(s)
	if type(s) ~= "string" then
		return ""
	end
	return string.gsub(s, "([^%w%-_%.~])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
end

local function BitPack(raw)
	local trees = {}
	for _, tree in ipairs(raw) do
		local bits = {}
		for _, num in ipairs(tree) do
			num = floor(tonumber(num) or 0)
			if num < 0 then
				num = 0
			elseif num > 7 then
				num = 7
			end
			bits[table.getn(bits) + 1] = ToBinary(num, 3)
		end
		local binary = table.concat(bits)
		local bytes = {}
		local i = 1
		while i <= string.len(binary) do
			local chunk = string.sub(binary, i, i + 7)
			bytes[table.getn(bytes) + 1] = BinaryToNumber(chunk)
			i = i + 8
		end
		local base64 = Base64EncodeBytes(bytes)
		if string.len(base64) > 0 then
			base64 = string.sub(base64, 1, -2) -- JS .slice(0, -1)
		end
		base64 = RTrim(base64, "A")
		trees[table.getn(trees) + 1] = base64
	end
	return table.concat(trees, "-")
end

local function LegacyBitUnpack(base64)
	local binary = BytesToBinaryString(Base64DecodeToBytes(base64))
	local raw = BinaryStringToValues(binary, 3)
	local chunk = 4 * 7
	return {
		Slice(raw, 1, chunk),
		Slice(raw, chunk + 1, chunk * 2),
		Slice(raw, chunk * 2 + 1, chunk * 3)
	}
end

local function BitUnpack(base64)
	if type(base64) ~= "string" or base64 == "" then
		return nil
	end
	if string.sub(base64, -1) == "=" then
		return LegacyBitUnpack(base64)
	end

	local trees = SplitByHyphen(base64)
	if table.getn(trees) ~= 3 then
		return nil
	end

	local out = {}
	for _, tree in ipairs(trees) do
		local padded = tree
		if string.len(padded) < 14 then
			padded = padded .. string.rep("A", 14 - string.len(padded))
		end
		local binary = BytesToBinaryString(Base64DecodeToBytes(padded))
		local values = BinaryStringToValues(binary, 3)
		values[table.getn(values) + 1] = 0
		out[table.getn(out) + 1] = values
	end
	return out
end

local function BuildSlotMaps(self, class)
	local info = self:UncompressSpellData(class)
	if type(info) ~= "table" then
		return nil
	end
	local maps = {}
	for tab, tree in ipairs(info) do
		local m = {slotToIndex = {}, indexToSlot = {}}
		if type(tree) == "table" then
			for index, talent in ipairs(tree) do
				local row = talent and tonumber(talent.row)
				local column = talent and tonumber(talent.column)
				if row and column and row >= 1 and row <= 7 and column >= 1 and column <= 4 then
					local slot = (row - 1) * 4 + column
					m.indexToSlot[index] = slot
					m.slotToIndex[slot] = index
				end
			end
		end
		maps[tab] = m
	end
	return maps, info
end

Talented.importers["talents%.turtlecraft%.gg/"] = function(self, url, dst)
	local slug = string.match(url, "talents%.turtlecraft%.gg/([%a]+)")
	if not slug then
		return
	end
	slug = string.lower(slug)
	local class = SLUG_TO_CLASS[slug]
	if not class then
		return
	end

	local points = string.match(url, "[%?&]points=([^&#]+)")
	points = UrlDecode(points)
	if not points or points == "" then
		return
	end

	local raw = BitUnpack(points)
	if type(raw) ~= "table" then
		return
	end

	local maps, info = BuildSlotMaps(self, class)
	if not maps or not info then
		return
	end

	dst.class = class
	for tab, tree in ipairs(info) do
		local source = raw[tab] or {}
		local t = dst[tab] or {}
		dst[tab] = t
		local map = maps[tab] or {}
		for index = 1, table.getn(tree) do
			local slot = map.indexToSlot and map.indexToSlot[index] or nil
			local value = floor(tonumber(slot and source[slot] or 0) or 0)
			if value < 0 then
				value = 0
			elseif value > 7 then
				value = 7
			end
			t[index] = value
		end
	end
	return dst
end

Talented.exporters["Turtlecraft Talents"] = function(self, template)
	if type(template) ~= "table" then
		return
	end
	local class = template.class
	if not class or not RAID_CLASS_COLORS[class] then
		return
	end
	local slug = CLASS_TO_SLUG[class]
	if not slug then
		return
	end

	local source = template
	if template.code then
		source = {}
		local ok = pcall(self.StringToTemplate, self, template.code, source)
		if not ok or type(source.class) ~= "string" then
			return
		end
		class = source.class
		slug = CLASS_TO_SLUG[class]
		if not slug then
			return
		end
	end

	local maps, info = BuildSlotMaps(self, class)
	if not maps or not info then
		return
	end

	local raw = {}
	for tab = 1, 3 do
		local tree = info[tab] or {}
		local map = maps[tab] or {}
		local srcTree = source[tab] or {}
		local outTree = {}
		for slot = 1, 28 do
			outTree[slot] = 0
		end
		for index = 1, table.getn(tree) do
			local slot = map.indexToSlot and map.indexToSlot[index] or nil
			local value = floor(tonumber(srcTree[index]) or 0)
			if value < 0 then
				value = 0
			elseif value > 7 then
				value = 7
			end
			if slot and slot >= 1 and slot <= 28 then
				outTree[slot] = value
			end
		end
		raw[tab] = outTree
	end

	local points = BitPack(raw)
	return string.format("https://talents.turtlecraft.gg/%s?points=%s", slug, UrlEncode(points))
end
