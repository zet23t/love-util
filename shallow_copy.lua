---Creates a simple (shallow) copy of a table
---@param t table
---@return table
return function (t)
	local cp = {}
	for k,v in pairs(t) do cp[k] = v end
	return cp
end