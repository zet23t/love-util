local class_registry = require "love-util.class_registry"
local sorted_pairs = require "love-util.sorted_pairs"

local writer = {}
writer._mt = { __index = writer }
function writer:write(...)
	for i = 1, select("#", ...) do
		local t = tostring(select(i, ...))
		table.insert(self, t)
	end
	return self
end

function writer:tostring()
	return table.concat(self)
end

local serialize = {
	["nil"] = function(_, _, out) out:write "nil" end;
	number = function(_, n, out) out:write(tostring(n)) end;
	boolean = function(_, b, out) return out:write(b and "true" or "false") end;
	["function"] = function() error "can't serialize functions" end;
	["thread"] = function() error "can't serialize threads" end;
	["userdata"] = function() error "can't serialize userdata" end;
}

serialize._mt = { __index = serialize }

function serialize:new()
	return setmetatable({
		tables = {};
		id_count = 0;
	}, self._mt)
end

function serialize:acquire_id(v)
	local id = self.tables[v]
	if id then return id end
	id = self.id_count + 1
	self.id_count = id
	self.tables[v] = id
	self.tables[id] = v
	return id, true
end

function serialize:any(any, out)
	assert(out)
	return self[type(any)](self, any, out)
end

function serialize:string(s, out)
	out:write "\""
		:write((s:gsub(".",
			function(s)
				if s < " " then
					return ("\\x%02x"):format(s:byte())
				end
				if s == "\\" then return "\\\\" end
				if s == "\"" then return "\\\"" end
			end)))
		:write "\""
end

local any = {}
setmetatable(any, { __index = function() return true end })
function serialize:table(t, out)
	local id, is_new = self:acquire_id(t)
	assert(not is_new, id .. " - " .. tostring(t))
	out:write(("tabs[%d]"):format(id))
end

local function get_serialized_keys(t)
	local mt = getmetatable(t)
	local serialized_keys = mt and mt.serialized_keys or any
	return serialized_keys
end

function serialize:table_content(t, out)
	local id = self:acquire_id(t)
	local mt = getmetatable(t)
	if mt and class_registry[mt] then
		out:write(("setmetatable(tabs[%d],class_registry["):format(id))
		serialize:any(mt.class_name, out)
		out:write("])\n")
	end
	local serialized_keys = get_serialized_keys(t)
	for k, v in sorted_pairs(t) do
		if serialized_keys[k] then
			local fn = serialized_keys[k]
			if type(fn) == "function" then v = fn(v) end
			out:write(("tabs[%d]["):format(id))
			self:any(k, out)
			out:write("] = ")
			-- print(k,v,type(fn),mt and mt.serialized_keys and mt.serialized_keys.controller)
			self:any(v, out)
			out:write "\n"
		end
	end
	out:write "\n"
end

local serialize_public = {}

---Serializes the table t into a string that can be loaded as lua code.
---Serialized objects will have their metatables restored as well, as long as these are
---registered under the same names.
---@param t table
---@return string
function serialize_public:serialize_to_string(t)
	local out = setmetatable({ [[
local class_registry = ...
return function ()
local tabs = {}
]]
	}, writer._mt)
	local s = serialize:new()

	local function id_all(s, t, ...)
		if type(t) ~= "table" then return end
		local _, is_new = s:acquire_id(t)
		if is_new then
			local serialized_keys = get_serialized_keys(t)
			for k, v in sorted_pairs(t) do
				-- if serialized_keys ~= any then
				-- 	print("allowed ? ", k, serialized_keys[k])
				-- else
				-- 	print("allowed: ", k)
				-- end
				if serialized_keys[k] then
					if type(serialized_keys[k]) == "function" then
						v = serialized_keys[k](v)
					end
					if type(v) == "function" then
						local keypath = ""
						for i = select('#', ...), 1, -1 do
							keypath = keypath .. "." .. tostring(select(i, ...))
						end
						error("Function stored in " .. keypath)
					end

					id_all(s, k, "[" .. tostring(k) .. "]", ...)
					id_all(s, v, k, ...)
				end
			end
		end
	end

	id_all(s, t)

	out:write(("for i=1,%d do tabs[i] = {} end\n\n"):format(s.id_count))

	for _, t in ipairs(s.tables) do
		s:table_content(t, out)
	end

	out:write "return tabs[1]\nend"

	return out:tostring()
end

function serialize_public:deserialize_from_string(string)
	local fn = assert(loadstring(string))
	return fn(class_registry)()
end

return serialize_public
