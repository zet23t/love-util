-- method to iterate over a table but splitting the keys at undescores and treating
-- the 2nd value as index. E.g. foo_1 is returned as index_1 element with "foo" as name
local function desuffixed_pairs(t)
	local values = {}
	local max_id
	for k, v in pairs(t) do
		local name, id, icon = k:match "([^_]*)_?([^_]+)_?([^_]*)"
		id = tonumber(id)
		icon = tonumber(icon)
		-- require "log"("%s %s %s %s",tostring(id),tostring(name),tostring(id), tostring(icon))
		assert(id, k)
		max_id = math.max(id, max_id or id)
		values[(id)] = { name, v, icon }
	end
	local i = 0
	
	return function()
		repeat
			i = i + 1
		until values[i] or i > max_id
		if not values[i] then return end
		return unpack(values[i])
	end
end

return desuffixed_pairs