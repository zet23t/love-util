---@class object_pool : object
local object_pool = require "love-util.class" "object_pool"

local pool_owner_map = setmetatable({},{__mode = "kv"})

function object_pool:new(factory_fn, ...)
	local pool = self:create {
		factory_fn = factory_fn,
		factory_fn_args = {...},
		pool = {},
		
	}
	return pool
end

function object_pool:release(obj)
	local owner = pool_owner_map[obj]
	if owner then
		table.insert(owner.pool, obj)
	end
end

function object_pool:acquire()
	if #self.pool == 0 then
		local obj = self.factory_fn(unpack(self.factory_fn_args))
		pool_owner_map[obj] = self
		return obj
	end

	return table.remove(self.pool)
end

return object_pool