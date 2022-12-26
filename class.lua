local object = {}
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



return function(name)
	local c = setmetatable({ class_name = name or "unnamed_class" }, { __index = object, __tostring = function(self) return self:tostr() end })
	c.class_type = c
	c._mt = { __index = c}
	return c
end
