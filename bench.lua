local bench = setmetatable({}, {__call = function(t,name) return t:mark(name) end})
local info_collection = {}
local groups = {}
function bench:mark(name, group)
	local t = love.timer.getTime()
	local function close()
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
	if group then
		local list = groups[group]
		if not list then
			list = {}
			groups[group] = list
		end
		list[#list+1] = close
	end
	return close
end

function bench:close_group(group)
	local list = groups[group]
	if list then
		for i=#list,-1 do
			list[i]()
		end
		groups[group] = nil
	end
end

function bench:flush_info()
	for group,list in pairs(groups) do
		for i=#list,1,-1 do
			list[i]()
		end
		groups[group] = nil
	end
	for name,info in pairs(info_collection) do
		local dt = info.t / info.n
		print((" ---> %s[%d]: %.6f (%.1f fps)"):format(name, info.n,dt,1/dt))
		info_collection[name] = nil
	end
end

return bench