---returns the keys of a table as a (unordered) table
---@param t table
---@return table
return function (t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys+1] = k
	end
	return keys
end