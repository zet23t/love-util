local mat4x4 = require "love-math.affine.mat4x4"
local add = require "love-math.geom.3d.add3d3d"
local multiply1d3d = require "love-math.geom.3d.multiply1d3d"

---@class box_mesh_generator : object
---@field matrix mat4x4
---@field position number[]
---@field size number[]
---@field color number[]
local box_mesh_generator = require "love-util.class" "box_mesh_generator"

---@param mat mat4x4
---@param x number
---@param y number
---@param z number
---@param size_x number
---@param size_y number
---@param size_z number
---@return box_mesh_generator
function box_mesh_generator:new(mat, x, y, z, size_x, size_y, size_z, r, g, b, a)
	return self:create {
		matrix = mat4x4:new():copy(mat),
		position = { x, y, z },
		size = { size_x, size_y, size_z },
		color = { r, g, b, a },
	}
end

local m_tmp = mat4x4:new()
local m_tmp2 = mat4x4:new()
local box_axis = {
	{ 1,  0, 0 }, { 0, 1, 0 }, { 0, 0, 1 },
	{ -1, 0, 0 }, { 0, 1, 0 }, { 0, 0, -1 },
	{ 0, 0,  1 }, { 0, -1, 0 }, { 1, 0, 0 },
	{ 0, -1, 0 }, { 0, 0, 1 }, { -1, 0, 0 },
	{ 1, 0, 0 }, { 0, 0, -1 }, { 0, 1, 0 },
	{ -1, 0, 0 }, { 0, 0, -1 }, { 0, -1, 0 },
}

---@param mesh_builder mesh_builder
function box_mesh_generator:generate(mesh_builder)
	local x, y, z = unpack(self.position)
	local sx, sy, sz = unpack(self.size)
	local ex, ey, ez = sx * .5, sy * .5, sz * .5
	m_tmp2:identity():scale(ex,ey,ez)
	for i = 1, #box_axis, 3 do
		local a, b, c, d = mesh_builder:allocate_vertices(4)
		m_tmp:identity():set_x(multiply1d3d(1, unpack(box_axis[i])))
			:set_y(multiply1d3d(1, unpack(box_axis[i + 1])))
			:set_z(multiply1d3d(1, unpack(box_axis[i + 2])))
			:set_position(x,y,z):multiply_left(m_tmp2):multiply_left(self.matrix)
		mesh_builder:set_position(a, m_tmp:multiply_point(1, 1, 1))
		mesh_builder:set_position(b, m_tmp:multiply_point(1, -1, 1))
		mesh_builder:set_position(c, m_tmp:multiply_point(-1, -1, 1))
		mesh_builder:set_position(d, m_tmp:multiply_point(-1, 1, 1))
		mesh_builder:set_color(a, unpack(self.color)):set_color(b, unpack(self.color))
		mesh_builder:set_color(c, unpack(self.color)):set_color(d, unpack(self.color))
		mesh_builder:set_normal(a, m_tmp:get_z()):set_normal(b, m_tmp:get_z())
		mesh_builder:set_normal(c, m_tmp:get_z()):set_normal(d, m_tmp:get_z())
		mesh_builder:set_uv(a, 1, 1):set_uv(b, 1, 0):set_uv(c, 0, 0):set_uv(d, 0, 1)
		mesh_builder:add_triangles(a, b, c, a, c, d)
	end
end

return box_mesh_generator