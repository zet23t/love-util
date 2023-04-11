return function(t, ...)
	local index = #t
	for i = 1, select('#', ...) do
		t[i + index] = select(i, ...)
	end
end
