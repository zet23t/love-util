local id_counter = {id = 0}
id_counter.__index = id_counter

function id_counter:new()
	return setmetatable({},self)
end

function id_counter:acquire()
	self.id = self.id + 1
	return self.id
end

return id_counter