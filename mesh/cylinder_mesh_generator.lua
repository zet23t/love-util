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
	local first_bottom, first_top, first_cap_bottom, first_cap_top
	local subdivs = self.subdivisions
	local radius = self.radius
	local half_height = self.height / 2
	local prev_bottom, prev_top, prev_cap_top, prev_cap_bottom
	local center_bottom, center_top = mesh_builder:allocate_vertices(2)
	local u,v = .5, .5
	self:set_vertice(mesh_builder, center_bottom, 0, -half_height, 0, u, v, 0, -1, 0)
	self:set_vertice(mesh_builder, center_top, 0, half_height, 0, u, v, 0, 1, 0)
	-- print("??",center_bottom, center_top)
	for i = 0, subdivs do
		local u = i / subdivs
		local angle = math.pi * i / subdivs * 2
		local nx, nz = math.sin(angle), math.cos(angle)
		local x, z = nx * radius, nz * radius
		local bottom, top = mesh_builder:allocate_vertices(2)
		-- print(bottom,top)
		self:set_vertice(mesh_builder, bottom, x, -half_height, z, u, 0, nx, 0, nz)
		self:set_vertice(mesh_builder, top, x, half_height, z, u, 1, nx, 0, nz)
		local cap_bottom, cap_top = mesh_builder:allocate_vertices(2)
		local u, v = nx * .5 + .5, nz * .5 + .5
		self:set_vertice(mesh_builder, cap_bottom, x, -half_height, z, u, v, 0, -1, 0)
		self:set_vertice(mesh_builder, cap_top, x, half_height, z, u, v, 0, 1, 0)
		if i == 0 then
			-- first_bottom, first_top = bottom, top
			-- first_cap_bottom, first_cap_top = cap_bottom, cap_top
		else
			mesh_builder:add_triangles(cap_top, prev_cap_top, center_top)
			mesh_builder:add_triangles(prev_cap_bottom, cap_bottom, center_bottom)
			mesh_builder:add_triangles(prev_bottom, prev_top, top, prev_bottom, top, bottom)
		end
		prev_bottom, prev_top = bottom, top
		prev_cap_bottom, prev_cap_top = cap_bottom, cap_top
	end
end

function cylinder_mesh_generator:set_vertice(mesh_builder, id, x, y, z, u, v, nx, ny, nz)
	assert(u and v)
	assert(x and y and z)
	assert(nx and ny and nz)
	mesh_builder:set_color(id, unpack(self.color))
	mesh_builder:set_normal(id, nx, nz, nz)
	mesh_builder:set_position(id, x, y, z)
	mesh_builder:set_uv(id, u, v)
	local vertice_data_count = #mesh_builder.vertices / mesh_builder.vertice_size

	-- print(id,x,y,z,u,v,nx,ny,nz)
	assert(vertice_data_count == #mesh_builder.uvs / mesh_builder.uv_size, "#uvs="..(#mesh_builder.uvs / mesh_builder.uv_size).." vertice_data_count="..vertice_data_count)

	return self
end

return cylinder_mesh_generator
