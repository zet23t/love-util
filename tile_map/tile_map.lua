---@class tile_map : object
---@field tileset tileset
---@field types table<string, string> map of types at corners
---@field surfacetypes table<string, string> map of surface types at corners
---@field heights table<string, integer> elevation of corners
---@field positions table<string, integer[]> coordinate pair for given key
---@field dirty table<string, integer[]>
local tile_map = require "love-util.class" "tile_map"

---@param ts tileset
---@return tile_map
function tile_map:new(ts)
	self = self:create {
		tileset = ts,
		types = {},
		positions = {},
		surfacetypes = {},
		heights = {},
		dirty = {},
	}
	self:init()
	return self
end

function tile_map:init()
end

function tile_map:dispose()
end

local version_identifier = "tilemap data version: 1"
function tile_map:deserialize(content, no_dirty_update)
	local bench = require "love-util.bench"

	local deserialize_mark = bench:mark("deserialize_header")

	local header, floor_names, surface_names, data = content:match(("([^\n]+)[\n\r]?"):rep(4))
	assert(header == version_identifier, "unexpected version version_identifier: '" .. tostring(header) .. "'")
	local floor_name_map = {}
	local surface_name_map = {}

	deserialize_mark()


	local deserialize_mark = bench:mark("deserialize_floor_names")
	for floor_name in floor_names:gmatch "([^;]*);" do
		floor_name_map[#floor_name_map + 1] = floor_name
	end
	deserialize_mark()

	local deserialize_mark = bench:mark("deserialize_surface_names")
	for surface_name in surface_names:gmatch "([^;]*);" do
		surface_name_map[#surface_name_map + 1] = surface_name
	end
	deserialize_mark()

	local deserialize_mark = bench:mark("deserialize_tile_data")
	for key, x, y, name_id, height, surface_id in data:gmatch "(([%d%-]+),([%d%-]+)),(%d+),([%d%-]+),(%d+)" do
		local floor_name = assert(floor_name_map[tonumber(name_id)])
		local surface_name = surface_name_map[tonumber(surface_id)]
		height = assert(tonumber(height))
		x, y = tonumber(x), tonumber(y)
		self.types[key] = floor_name
		self.positions[key] = { x, y }
		self.heights[key] = height
		self.dirty[key] = { x, y }
		self.surfacetypes[key] = surface_name
	end
	deserialize_mark()

	if not no_dirty_update then
		local deserialize_mark = bench:mark("deserialize_update_dirty")
		self:update_dirty()
		deserialize_mark()
	end


	bench:flush_info()
end

function tile_map:serialize()
	local output = { version_identifier, "\n" }
	local floor_name_map = {}
	local i = 1
	for name in pairs(self.tileset.floor_types) do
		floor_name_map[name] = tostring(i)
		output[#output + 1] = name .. ";"
		i = 1 + i
	end
	output[#output + 1] = "\n"
	i = 1
	local surface_name_map = {}
	for name in pairs(self.tileset.surface_types) do
		surface_name_map[name] = tostring(i)
		output[#output + 1] = name .. ";"
		i = 1 + i
	end
	output[#output + 1] = "\n"
	for key, floor_type_name in pairs(self.types) do
		local surface_type_name = self.surfacetypes[key]
		output[#output + 1] = key ..
		"," ..
		floor_name_map[floor_type_name] ..
		"," .. self.heights[key] .. "," .. (surface_name_map[surface_type_name] or 0) .. ";"
	end
	return table.concat(output)
end

local function mkkey(x, y) return x .. "," .. y end

function tile_map:on_tile_does_not_exist(x, y, z, key_coordinate, tilekey)
	error "overload on_tile_does_not_exist for functionality"
end

function tile_map:on_update_tile(x, y, z, key_coordinate, tilekey, tile_info, tile_rotation, surface_tiles)
	error "overload on_update_tile for functionality"
end

function tile_map:on_tile_remove(k)
	error "overload on_update_tile for functionality"
end

function tile_map:update(x, y, update_map)
	local mark = require "love-util.bench":mark("tile_map:update")

	local a, b, c, d = mkkey(x + 1, y + 1), mkkey(x + 1, y), mkkey(x, y), mkkey(x, y + 1)
	if update_map then
		local tile_key = a .. b .. c .. d
		if update_map[tile_key] then
			return
		end
		update_map[tile_key] = true
	end

	local types = self.types
	local ta, tb, tc, td = types[a], types[b], types[c], types[d]
	if not ta or not tb or not tc or not td then
		self:on_tile_remove(c)
		return mark()
	end
	local heights = self.heights
	local ha, hb, hc, hd = heights[a], heights[b], heights[c], heights[d]
	local fallback_height = ha or hb or hc or hd
	ha, hb, hc, hd = ha or fallback_height, hb or fallback_height, hc or fallback_height, hd or fallback_height
	local min = math.min(ha, hb, hc, hd)
	local da, db, dc, dd = ha - min, hb - min, hc - min, hd - min

	--local tilekey = mktypekey(ta, da) .. ":" .. mktypekey(tb, db) .. ":" .. mktypekey(tc, dc) .. ":" .. mktypekey(td, dd)
	local tilekey = self.tileset:mktypekey_full(ta,tb,tc,td,da,db,dc,dd)
	local matches = self.tileset.lookup_table[tilekey]

	if not matches then
		self:on_tile_does_not_exist(x, min, y, c, tilekey)
		return mark()
	end
	local rnd = ((x * 17 + y * 7 + 2348421) % 11493) % #matches + 1
	local select = matches[rnd]
	local tile_info = select.tile_info
	local tile_rotation = select.rotation

	local surface_tiles = {}

	-- handling surfac tile types. These are special in some ways:
	-- - they are flat; no height differences
	-- - they can be combined (to decrease tile number complexity)
	-- - we group corners of same height and type to find matches
	local surfacetypes = self.surfacetypes
	local sta, stb, stc, std = surfacetypes[a], surfacetypes[b], surfacetypes[c], surfacetypes[d]
	local tracked = {}
	local function handle_surface_tile(type, height)
		if not type then return end
		local ka = sta == type and da == height and "1" or "0"
		local kb = stb == type and db == height and "1" or "0"
		local kc = stc == type and dc == height and "1" or "0"
		local kd = std == type and dd == height and "1" or "0"
		local key = type .. "-" .. ka .. kb .. kc .. kd
		local track_key = height .. key
		if tracked[track_key] then return end
		tracked[track_key] = true

		local tile_infos = self.tileset.surface_lut[key]
		-- print(key, tile_infos)
		if tile_infos then
			local rnd = ((x * 17 + y * 7 + 2348424) % 11447) % #tile_infos + 1
			surface_tiles[#surface_tiles + 1] = { tile_info = tile_infos[rnd], height = height }
		end
	end
	handle_surface_tile(sta, da)
	handle_surface_tile(stb, db)
	handle_surface_tile(stc, dc)
	handle_surface_tile(std, dd)
	-- if sta ~= stb or db ~= da then
	-- 	handle_surface_tile(sta, da)
	-- end
	-- if (sta ~= stc or dc ~= da) and (stb ~= stc or dc ~= db) then
	-- 	handle_surface_tile(stc, dc)
	-- end
	-- if (sta ~= std or dd ~= da) and (stb ~= std or dd ~= db) and (stc ~= std or dd ~= hc) then
	-- 	handle_surface_tile(std, dd)
	-- end

	self:on_update_tile(x, min, y, c, tilekey, tile_info, tile_rotation, surface_tiles)
	mark()
	return true
end

function tile_map:get_height(x, y, search_rad)
	local height, dist_h
	search_rad = search_rad or 1
	for i = 0, search_rad do
		for sx = x - search_rad, x + search_rad do
			for sy = y - search_rad, y + search_rad do
				local key = mkkey(sx, sy)
				local h = self.heights[key]
				if h then
					local dx, dy = sx - x, sy - y
					local d = dx * dx + dy * dy
					if not dist_h or d < dist_h then
						height = h
						dist_h = d
					end
				end
			end
		end
	end
	return height
end

function tile_map:put_surface(x, y, type)
	local key = mkkey(x, y)
	if self.types[key] and self.surfacetypes[key] ~= type then
		self.dirty[key] = { x, y }
		self.surfacetypes[key] = type
	end
end

function tile_map:put(x, y, type, height, no_overwrite)
	local key = mkkey(x, y)
	if not self.types[key] or (not no_overwrite and (self.types[key] ~= type or self.heights[key] ~= height)) then
		self.types[key] = type
		self.heights[key] = height
		self.dirty[key] = { x, y }
	end
end

function tile_map:update_dirty()
	local mark = require "love-util.bench":mark("tile_map:update_dirty")
	local update_map = {}
	for k, v in pairs(self.dirty) do
		local x, y = unpack(v)
		local a = self:update(x, y, update_map)
		local b = self:update(x - 1, y, update_map)
		local c = self:update(x - 1, y - 1, update_map)
		local d = self:update(x, y - 1, update_map)
		--if a and b and c and d then
		self.dirty[k] = nil
		--end
	end
	mark()
end

return tile_map
