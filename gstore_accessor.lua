local gstore = require "love-util.gstore"
return function(t,key)
	t["set_"..key] = function(self,v)
		if self.uid then
			gstore(self.uid)[key] = v
		else
			self[key] = v
		end
	end
	t["get_"..key] = function(self,def)
		local v
		if self.uid then
			v = gstore(self.uid)[key]
		else
			v = self[key]
		end
		return v or def
	end
end