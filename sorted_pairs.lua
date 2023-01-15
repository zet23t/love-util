local keys = require "love-util.keys"
local function compare(a, b)
	local ta, tb = type(a), type(b)
	if ta ~= tb then
		return ta < tb
	end
	if ta == "number" or ta == "string" then
		return a < b
	end
	if ta == "boolean" then
		return (a and 1 or 0) < (b and 1 or 0)
	end
	return false
end

return function(t)
	local ks = keys(t)
	table.sort(ks, compare)
	local i = 0
	return function()
		i = i + 1
		if i > #ks then
			return
		end
		local k = ks[i]
		return k, t[k]
	end
end
