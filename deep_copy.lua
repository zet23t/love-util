return function(t)
	local copy_map = {}
	local function copy(t)
		if type(t) ~= "table" then
			return t
		end
		if copy_map[t] then
			return copy_map[t]
		end
		local c = {}
		copy_map[t] = c
		for k,v in pairs(t) do
			c[copy(k)] = copy(v)
		end
		return c
	end
	return copy(t)
end