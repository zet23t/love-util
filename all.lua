return function(t)
	local iter = pairs(t)
	local k,v
	return function ()
		k, v = iter(t, k)
		return v
	end
end