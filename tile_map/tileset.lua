
---@class tile_corner_info
---@field type string
---@field level integer
---@field key string = type .. "-" .. level

---@class tile_info
---@field name string
---@field mesh love.Mesh
---@field types string[] list of types - used for mapping corner types
---@field variant integer the variant of the tile
---@field corners tile_corner_info

---@class tileset : object
---@field lookup_table table<string, table[]> example key: "grass-0:*:grass-0:water-1"
---@field surface_lut table<string, table[]> same as lookup table, but simplified: only same type configurations are stored.
---@field surface_types table<string, boolean>
---@field floor_types table<string, boolean>
local tileset = require "love-util.class" "tileset"
function tileset:new()
	return self:create {
		lookup_table = {},
		surface_lut = {},
		floor_types = {},
		surface_types = {}
	}
end

local function corner_info(type, types)
	local idx = math.floor(type / 2 + 1)
	local level = type % 2
	local type = assert(types[idx])
	return { type = type, level = level, key = type .. "-" .. level, idx = idx }
end

local function add_to_dictionary_list(dict, key, value)
	local list = dict[key]
	if not list then
		list = {}
		dict[key] = list
	end
	list[#list + 1] = value
end

local function insert_into_lut(a, b, c, d, lookup_table, tile_info)
	for rotation = 0, 3 do
		local key = a .. ":" .. b .. ":" .. c .. ":" .. d
		add_to_dictionary_list(lookup_table, key, { rotation = rotation, tile_info = tile_info })
		a, b, c, d = b, c, d, a
	end
	-- produce all permutations for wildcards - 
	-- note: commented out because I can't make something of this
	-- if a ~= "*" then insert_into_lut("*", b, c, d) end
	-- if b ~= "*" then insert_into_lut(a, "*", c, d) end
	-- if c ~= "*" then insert_into_lut(a, b, "*", d) end
	-- if d ~= "*" then insert_into_lut(a, b, c, "*") end
end

local function insert_tile(tileset, name, corners, names, floor_types, variant, lookup_table)
	local a, b, c, d = corners:match "(.)(.)(.)(.)"
	a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)

	local mesh = tileset:load_tile(name)
	local types = {}
	for type_name in names:gmatch "[^%-]+" do
		types[#types + 1] = type_name
		floor_types[type_name] = true
	end

	local tile_info = {
		name = name,
		mesh = mesh,
		types = types,
		variant = variant,
		corners = {
			corner_info(a, types),
			corner_info(b, types),
			corner_info(c, types),
			corner_info(d, types)
		}
	}

	local lookup_table = lookup_table
	insert_into_lut(
		tile_info.corners[1].key,
		tile_info.corners[2].key,
		tile_info.corners[3].key,
		tile_info.corners[4].key,
		lookup_table,
		tile_info
	)
	return tile_info
end

local function mktypekey(t, delta) return t == "*" and "*" or (t .. "-" .. delta) end

function tileset:mktypekey_full(ta, tb, tc, td, da, db, dc, dd)
	return mktypekey(ta, da or 0) ..
	":" .. mktypekey(tb, db or 0) .. ":" .. mktypekey(tc, dc or 0) .. ":" .. mktypekey(td, dd or 0)
end

function tileset:add_tile_surface_type(name)
	local type_name, corners, variant = name:match "ts_([^%-]*)%-(%d%d%d%d)%-(%d+)$"
	if not type_name then
		print("Warning: not matching pattern: " .. name)
		return
	end

	local tile_info = insert_tile(self, name, corners, type_name, self.surface_types, variant, self.surface_lut)
	local a,b,c,d = corners:sub(1,1), corners:sub(2,2), corners:sub(3,3), corners:sub(4,4)
	for rotation = 0, 3 do
		add_to_dictionary_list(self.surface_lut, type_name.."-"..a..b..c..d, { rotation = rotation, tile_info = tile_info })
		a,b,c,d = b,c,d,a
	end
end

function tileset:add_tile_ground_type(name)
	local names, corners, variant = name:match "t_(.*)%-(%d%d%d%d)%-(%d+)$"
	if not names then
		names, corners = name:match "t_(.*)%-(%d%d%d%d)$"
		if not names then
			print("not matched: ", name)
			names, variant = name:match "t_(.*)%-(%d+)$"
			corners = "0000"
		else
			variant = "0"
		end
	end
	if not names then
		print("could not parse name: " .. name)
		return
	end

	insert_tile(self, name, corners, names, self.floor_types, variant, self.lookup_table)
end

function tileset:add_tile_types(list)
	for i = 1, #list do
		self:add_tile_ground_type(list[i])
	end
end

return tileset