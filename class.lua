---@class object
---@field _mt table
local object = {}

---creates a new instance
---@generic T : object
---@param self T
---@param t table|nil to use as instance
---@return T
function object:create(t)
	local s = setmetatable(t or {}, self._mt)
	return s
end

function object:tostr()
	if self.tostring then return self:tostring() end
	return "[" .. self.class_name .. "]"
end

function object:extends(base)
	local mt = getmetatable(self) or {}
	mt.__index = base
	setmetatable(self, mt)
	return self
end

local class_registry = require "love-util.class_registry"

return function(name)
	local c = setmetatable({ class_name = name or "unnamed_class" }, { __index = object, __tostring = function(self) return self:tostr() end })
	c.class_type = c
	c._mt = { __index = c; class_name = name}
	assert(not class_registry[name], "name registered already: "..name)
	class_registry[name] = c._mt
	class_registry[c._mt] = name
	return c
end
