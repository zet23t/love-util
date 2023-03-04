---Checks if a value is of an expected base type and throws an error if it's not
---@param v any
---@param ... "string"|"nil"|"number"|"table"|"function"|"thread"|"boolean"|"userdata"|table either the string type or the metatable that is expected
---@return any v The value passed
return function (v, ...)
	local t = type(v)
	for i=1,select("#", ...) do
		local expected_type = select(i, ...)
		if expected_type == t then
			return v
		end
	end

	local expected_types = table.concat({...}, ", ")
	error("Value "..tostring(v).." is not one of the expected types: "..expected_types)
end