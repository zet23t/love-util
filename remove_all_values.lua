return function(t,v)
	for i=#t,1,-1 do
		if t[i] == v then
			table.remove(t,i)
		end
	end
end