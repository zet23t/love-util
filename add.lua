return function (t,...)
	for i=1, select('#', ...) do
		table.insert(t,select(i,...))
	end
end
