local uid_counter = {}

return function(key)
	local n = uid_counter[key] or 1
	uid_counter[key] = n + 1
	return key.."@"..n
end