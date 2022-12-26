local add = require "love-util.add"
local late_command = { list = {} }

setmetatable(late_command, {__call = function(t,...) t:queue(...) end})

function late_command:queue(f, ...)
	add(self.list, { f = f, ... })
end

function late_command:flush()
	for i = 1, #self.list do
		local cmd = self.list[i]
		cmd.f(unpack(cmd))
	end
	self.list = {}
end

return late_command
