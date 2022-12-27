local inrange2d = require "love-math.inrange2d"
---@class quadtree : object
local quadtree = require "love-util.class" "quadtree"

---@param min_x number
---@param min_y number
---@param max_x number
---@param max_y number
---@return quadtree
function quadtree:new(min_x, min_y, max_x, max_y)
	self = self:create {
		entries = {};
		min_x = min_x;
		min_y = min_y;
		max_x = max_x;
		max_y = max_y;
		cen_x = min_x * .5 + max_x * .5;
		cen_y = min_y * .5 + max_y * .5;
		level = 0;
	}

	return self
end

---@param x number
---@param y number
---@param radius number
---@return table
function quadtree:find(x, y, radius)
	local result = {}
	radius = radius or 0

	local function find(qt)
		for i = 1, #qt.entries do
			local e = qt.entries[i]
			if inrange2d(e[3] + radius, e[1] - x, e[2] - y) then
				result[#result+1] = e.data
				assert(e.owner)
			end
		end
		if qt.tl then
			find(qt.tl)(qt.tr)(qt.bl)(qt.br)
		end
		return find
	end

	find(self)

	return result
end

---@param entry table
function quadtree:remove(entry)
	for i = 1, #entry.owner do
		if entry.owner[i] == entry then
			table.remove(entry.owner, i)
			break
		end
	end
end

---@param x number
---@param y number
---@param radius number
---@param data any
---@return table the entry
function quadtree:insert(x, y, radius, data)
	local entry = { x, y, radius, data = data }
	local function insert(self, entry)
		local min_x, min_y, max_x, max_y, cen_x, cen_y = self.min_x, self.min_y, self.max_x, self.max_y, self.cen_x, self.cen_y
		if x - radius < min_x or y - radius < min_y or x + radius > max_x or y + radius > max_y then
			return false
		end

		local tl, tr, bl, br
		if not self.tl then
			entry.owner = self.entries
			self.entries[#self.entries + 1] = entry
			if #self.entries < 20 then
				return true
			end

			tl, tr, bl, br = self:new(min_x, min_y, cen_x, cen_y),
				self:new(cen_x, min_y, max_x, cen_y),
				self:new(min_x, cen_y, cen_x, max_y),
				self:new(cen_x, cen_y, max_x, max_y)
			tl.level = self.level + 1
			tr.level = self.level + 1
			bl.level = self.level + 1
			br.level = self.level + 1
			self.tl, self.tr, self.bl, self.br = tl, tr, bl, br

			for i = #self.entries, 1, -1 do
				local e = self.entries[i]
				if insert(tl, e) or insert(tr, e) or insert(bl, e) or insert(br, e) then
					table.remove(self.entries, i)
				end
			end

			return true
		else
			tl, tr, bl, br = self.tl, self.tr, self.bl, self.br
		end

		if not insert(tl, entry) and not insert(tr, entry) and not insert(bl, entry) and not insert(br, entry) then
			entry.owner = self.entries
			self.entries[#self.entries + 1] = entry
		end

		return true
	end

	insert(self, entry)
	-- local n = 0
	-- local ins_info = {}
	-- local function check_for_duplication(self)
	-- 	for i=1,#self.entries do
	-- 		if self.entries[i] == entry then
	-- 			ins_info[#ins_info+1] = self
	-- 			n = n + 1
	-- 		end
	-- 	end
	-- 	if self.tl then
	-- 		check_for_duplication(self.tl) (self.tr) (self.br) (self.bl)
	-- 	end
	-- 	return check_for_duplication
	-- end
	-- check_for_duplication(self)
	-- if n~=1 then
	-- 	for i=1,#ins_info do
	-- 		local q = ins_info[i]
	-- 		require "log"("%d %.2f %.2f %.2f %.2f",q.level,
	-- 			q.min_x, q.min_y, q.max_x, q.max_y)
	-- 	end
	-- 	assert(n == 1,"? "..n.." - "..tostring(data))
	-- end

	return entry
end

return quadtree
