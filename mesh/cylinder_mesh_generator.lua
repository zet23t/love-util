local mat4x4 = require "love-math.affine.mat4x4"

---@class cylinder_mesh_generator : object
local cylinder_mesh_generator = require "love-util.class" "cylinder_mesh_generator"

function cylinder_mesh_generator:new(mat, radius, height, subdivisions, has_top, has_bottom, color)
	return self:create {
		matrix = mat4x4:new():copy(mat),
		radius = radius,
		height = height,
		subdivisions = subdivisions,
		has_top = has_top,
		has_bottom = has_bottom,
		color = color or { 1, 1, 1, 1 }
	}
end

---@param mesh_builder mesh_builder
function cylinder_mesh_generator:generate(mesh_builder)
	local first_bottom, first_top
	local subdivs = self.subdivisions
	local radius = self.radius
	local half_height = self.height / 2
	local color = self.color
	local prev_bottom, prev_top
	for i = 1, subdivs do
		local u = (i - 1) / (subdivs - 1)
		local angle = math.pi * i / subdivs * 2
		local nx, nz = math.sin(angle), math.cos(angle)
		local x, z = nx * radius, nz * radius
		local bottom, top = mesh_builder:allocate_vertices(2)
		mesh_builder:set_color(bottom, unpack(color)):set_color(top, unpack(color))
		mesh_builder:set_normal(bottom, nx, 0, nz):set_normal(top, nx, 0, nz)
		mesh_builder:set_position(bottom, x, -half_height, z):set_position(top, x, half_height, z)
		mesh_builder:set_uv(bottom, u, 0):set_uv(top, u, 1)
		if i == 1 then
			first_bottom, first_top = bottom, top
		else
			mesh_builder:add_triangles(prev_bottom, prev_top, top, prev_bottom, top, bottom)
		end
		prev_bottom, prev_top = bottom, top
	end
	mesh_builder:add_triangles(prev_bottom, prev_top, first_top, prev_bottom, first_top, first_bottom)
end

return cylinder_mesh_generator
