
---@class tile_map : object
---@field tileset tileset
---@field types table<string, string> map of types at corners
---@field heights table<string, integer> elevation of corners
---@field dirty table<string, integer[]>
local tile_map = require "love-util.class" "tile_map"

---@param ts tileset
---@return tile_map
function tile_map:new(ts)
    self = self:create {
        tileset = ts,
        types = {},
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
function tile_map:deserialize(content)
    local header, names, data = content:match(("([^\n]+)[\n\r]?"):rep(3))
    assert(header == version_identifier, "unexpected version version_identifier: '"..tostring(header).."'")
    local floor_name_map = {}
    for floor_name in names:gmatch "([^;]*);" do
        floor_name_map[#floor_name_map+1] = floor_name
    end
    for key, x, y, name_id, height in data:gmatch"(([%d%-]+),([%d%-]+)),(%d+),([%d%-]+)" do
        local floor_name = assert(floor_name_map[tonumber(name_id)])
        height = assert(tonumber(height))
        x,y = tonumber(x), tonumber(y)
        self.types[key] = floor_name
        self.heights[key] = height
        self.dirty[key] = { x, y }
    end
    self:update_dirty()
end

function tile_map:serialize()
    local output = {version_identifier, "\n"}
    local floor_name_map = {}
    local i = 1
    for name in pairs(self.tileset.floor_types) do
        floor_name_map[name] = tostring(i)
        output[#output+1] = name..";"
        i = 1 + i
    end
    output[#output+1] = "\n"
    for key,floor_type_name in pairs(self.types) do
        output[#output+1] = key..","..floor_name_map[floor_type_name]..","..self.heights[key]..";"
    end
    return table.concat(output)
end

local function mkkey(x, y) return x .. "," .. y end
local function mktypekey(t, delta) return t == "*" and "*" or (t .. "-" .. delta) end

function tile_map:on_tile_does_not_exist(x, y, z, key_coordinate, tilekey)
    error "overload on_tile_does_not_exist for functionality"
end

function tile_map:on_update_tile(x, y, z, key_coordinate, tilekey, tile_info, tile_rotation)
    error "overload on_update_tile for functionality"
end

function tile_map:update(x, y)
    local a, b, c, d = mkkey(x + 1, y + 1), mkkey(x + 1, y), mkkey(x, y), mkkey(x, y + 1)


    local types = self.types
    local ta, tb, tc, td = types[a], types[b], types[c], types[d]
    if not ta or not tb or not tc or not td then
        return
    end
    local heights = self.heights
    local ha, hb, hc, hd = heights[a], heights[b], heights[c], heights[d]
    local fallback_height = ha or hb or hc or hd
    ha, hb, hc, hd = ha or fallback_height, hb or fallback_height, hc or fallback_height, hd or fallback_height
    local min = math.min(ha, hb, hc, hd)
    local da, db, dc, dd = ha - min, hb - min, hc - min, hd - min

    local tilekey = mktypekey(ta, da) .. ":" .. mktypekey(tb, db) .. ":" .. mktypekey(tc, dc) .. ":" .. mktypekey(td, dd)
    local matches = self.tileset.lookup_table[tilekey]

    if not matches then
        self:on_tile_does_not_exist(x,min,y,c,tilekey)
        return
    end
    local rnd = ((x * 17 + y * 7 + 2348421) % 11493) % #matches + 1
    local select = matches[rnd]
    local tile_info = select.tile_info
    local tile_rotation = select.rotation
    self:on_update_tile(x, min, y, c, tilekey, tile_info, tile_rotation)
    return true
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
    for k, v in pairs(self.dirty) do
        local x, y = unpack(v)
        local a = self:update(x, y)
        local b = self:update(x - 1, y)
        local c = self:update(x - 1, y - 1)
        local d = self:update(x, y - 1)
        --if a and b and c and d then
        self.dirty[k] = nil
        --end
    end
end

return tile_map