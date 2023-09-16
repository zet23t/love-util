local class_registry = require "love-util.class_registry"
local struct = require "love-util.struct"
local binary_serialize = {}

local function collect_tables(tab, out)
    if type(tab) ~= "table" then return end
    if out[tab] then return end
    if class_registry[tab] then
        table.insert(out, 1, tab)
    else
        out[#out + 1] = tab
    end
    out[tab] = true
    if class_registry[tab] then return end
    collect_tables(getmetatable(tab), out)
    for k, v in pairs(tab) do
        collect_tables(k, out)
        collect_tables(v, out)
    end
end

local function collect_strings(tables, out)
    for i = 1, #tables do
        local tab = tables[i]
        if class_registry[tab] then
            local name = class_registry[tab]
            if not out[name] then
                out[name] = true
                out[#out + 1] = name
            end
        else
            for k, v in pairs(tab) do
                if type(k) == "string" and not out[k] then
                    out[k] = true
                    out[#out + 1] = k
                end
                if type(v) == "string" and not out[v] then
                    out[v] = true
                    out[#out + 1] = v
                end
            end
        end
    end
end

local function write_uint32(out, int)
    local addr = #out + 1
    struct.packIE(out, int)
    return addr
end

local function write_string(out, str)
    write_uint32(out, #str)
    local addr = #out + 1
    for i = 1, #str do
        out[addr + i - 1] = string.char(str:byte(i))
    end
    return addr
end

local type_to_char = {
    ["nil"] = "N",
    ["boolean"] = "b",
    ["number"] = "n",
    ["string"] = "s",
    ["table"] = "t",
    ["function"] = "f",
    ["userdata"] = "u",
    ["thread"] = "d",
    [true] = "T",
    [false] = "F",
    [0] = "0",
}

local function write_any(out, tabs, strings, v)
    local vtype = type(v)
    if v ~= nil and vtype ~= "string" and type_to_char[v] ~= nil then
        out[#out + 1] = type_to_char[v]
        return
    end

    out[#out + 1] = type_to_char[vtype]
    if vtype == "string" then
        write_uint32(out, strings[v])
    elseif vtype == "table" then
        write_uint32(out, tabs[v])
    elseif vtype == "number" then
        struct.packdE(out, v)
    elseif vtype == "nil" then
        -- nothing to do
    elseif vtype == "b" then
        error "This is not to happen"
    else
        error "todo"
    end
end

---serializes the data to a stream of bytes using a table - use table.concat to get a string
---@param tab table
---@return table stream of bytes
function binary_serialize:serialize(tab)
    local tabs, strings = {}, {}
    collect_tables(tab, tabs)
    for i = 1, #tabs do
        local t = tabs[i]
        tabs[t] = i
    end
    collect_strings(tabs, strings)
    local out = {}
    write_uint32(out, #strings)
    for i = 1, #strings do
        local s = strings[i]
        strings[s] = i
        write_string(out, s)
    end
    write_uint32(out, #tabs)
    for i = 1, #tabs do
        local t = tabs[i]
        if class_registry[t] then
            write_uint32(out, 0xffffffff)
            write_uint32(out, strings[class_registry[t]])
        else
            local mt = getmetatable(t)
            -- write metatable address or 0 if no metatable
            if not mt then
                write_uint32(out, 0)
            else
                write_uint32(out, tabs[mt])
            end
            -- write table length
            write_uint32(out, #t)
            for i = 1, #t do
                local v = t[i]
                write_any(out, tabs, strings, v)
            end
            local kcnt = 0
            for k, v in pairs(t) do
                if type(k) ~= "number" or k < 1 or k > #t then
                    kcnt = kcnt + 1
                end
            end
            write_uint32(out, kcnt)
            for k, v in pairs(t) do
                if type(k) ~= "number" or k < 1 or k > #t then
                    write_any(out, tabs, strings, k)
                    write_any(out, tabs, strings, v)
                end
            end
        end
    end
    write_uint32(out, tabs[tab])

    return out
end

local function read_any(bytes, pos, tabs, strings)
    local vtype = bytes:sub(pos, pos)
    local value
    pos = pos + 1
    if vtype == "n" then
        value = struct.unpackd(bytes, pos)
        pos = pos + 8
    elseif vtype == "s" then
        value = strings[struct.unpackI(bytes, pos)]
        pos = pos + 4
    elseif vtype == "t" then
        value = tabs[struct.unpackI(bytes, pos)]
        pos = pos + 4
    elseif vtype == "F" then
        value = false
    elseif vtype == "T" then
        value = true
    elseif vtype == "0" then
        value = 0
    elseif vtype == "N" then
        value = nil
    else
        error("unknown code: " .. vtype .. " @" .. (pos - 1))
    end
    return pos, value
end

function binary_serialize:deserialize(bytes)
    local tabs, strings = {}, {}
    local pos = 5
    for i = 1, struct.unpackI(bytes, 1) do
        local len = struct.unpackI(bytes, pos)
        strings[i] = bytes:sub(pos + 4, pos + 3 + len)
        pos = pos + len + 4
    end
    local tab_cnt = struct.unpackI(bytes, pos)
    pos = pos + 4
    for i = 1, tab_cnt do
        tabs[i] = {}
    end
    -- since meta tables can mess with writing and reading (unless using rawset/rawget,
    -- which I don't want to use), we delay metatable assignments
    local meta_tabs = {}
    for i = 1, tab_cnt do
        local mt_addr = struct.unpackI(bytes, pos)
        if mt_addr == 0xffffffff then
            local mt_name = struct.unpackI(bytes, pos + 4)
            pos = pos + 8
            local class_name = strings[mt_name]
            local class = class_registry[class_name]
            if not class then
                error("unknown class in serialization data: " .. class_name)
            end
            tabs[i] = class
        else
            pos = pos + 4
            local t = tabs[i]
            if mt_addr ~= 0 then
                local mt = tabs[mt_addr]
                meta_tabs[t] = mt
            end
            local len = struct.unpackI(bytes, pos)
            pos = pos + 4
            for j = 1, len do
                pos, t[j] = read_any(bytes, pos, tabs, strings)
            end
            local kcnt = struct.unpackI(bytes, pos)
            pos = pos + 4
            for j = 1, kcnt do
                local k
                pos, k = read_any(bytes, pos, tabs, strings)
                pos, t[k] = read_any(bytes, pos, tabs, strings)
            end
        end
    end
    for t, mt in pairs(meta_tabs) do
        setmetatable(t, mt)
    end
    local root_index = struct.unpackI(bytes, pos)
    return tabs[root_index]
end

return binary_serialize
