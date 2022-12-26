--- creates a new object that inherits all members from t (without overwriting anything)
---@param t any
---@param ... any
---@return any
---@return table
local function proxy_instance(t,...)
	if t then
		return setmetatable({},{__index = t}),proxy_instance(...)
	end
end

return proxy_instance