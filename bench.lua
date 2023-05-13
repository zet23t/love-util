local bench = setmetatable({}, {__call = function(t,name) return t:mark(name) end})
local info_collection = {}
function bench:mark(name)
	local t = love.timer.getTime()
	return function()
		local dt = love.timer.getTime() - t
		local i = info_collection[name] or {
			name = name,
			n = 0,
			t = 0
		}
		info_collection[name] = i
		i.n = i.n + 1
		i.t = i.t + dt
	end
end

function bench:flush_info()
	for name,info in pairs(info_collection) do
		local dt = info.t / info.n
		print((" ---> %s[%d]: %.6f (%.1f fps)"):format(name, info.n,dt,1/dt))
		info_collection[name] = nil
	end
end

return bench