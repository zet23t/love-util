---@class func_list
local func_list = require "love-util.class" "func_list"

function func_list:new()
	return func_list:create()
end

function func_list:add(f)
	if not self[f] then
		self[f] = true
		self[#self + 1] = f 
	end
end

function func_list:remove(f)
	if self[f] then
		for i=1,#self do
			if self[i] == f then
				self[f] = nil
				table.remove(self, i)
				break
			end
		end
	end
end

function func_list:invoke(...)
	for i=1,#self do
		self[i](...)
	end
end

return func_list