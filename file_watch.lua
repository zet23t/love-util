local nativefs = require "nativefs"

local file_watch = {
	watches = {},
}

local function check_watch(self, watch)
	local path = watch.path
	local info = nativefs.getInfo(path)
	if info and info.type == "file" and info.modtime ~= watch.modtime then
		watch.modtime = info.modtime
		watch.callback(path)
	end
end

function file_watch:add(path, callback)
	local watch = {
		path = path,
		callback = callback
	}
	self.watches[#self.watches+1] = watch
	check_watch(self, watch)
	return function ()
		return callback(path)
	end
end

function file_watch:remove(path)
	for i=#self.watches,1,-1 do
		if self.watches[i].path == path then
			table.remove(self,i)
		end
	end
	return self
end

function file_watch:check()
	for i=1,#self.watches do
		local watch = self.watches[i]
		check_watch(self, watch)
	end
end

return file_watch
