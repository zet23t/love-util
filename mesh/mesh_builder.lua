---@class mesh_builder : object
---@field vertice_counter integer
---@field uvs number[]
---@field uv_size integer
---@field vertices number[]
---@field vertice_size integer
---@field normals number[]
---@field normal_size integer
---@field colors number[]
---@field color_size integer
---@field triangles integer[]
local mesh_builder = require "love-util.class" "mesh_builder"

function mesh_builder:new()
	return self:create {
		vertice_counter = 0,
		uvs = {},
		uv_size = 2,
		vertices = {},
		vertice_size = 3,
		normals = {},
		normal_size = 3,
		colors = {},
		color_size = 4,
		triangles = {},
	}
end

local function setVertexAttribute(mesh, attribute_index, data_size, data)
	for i = 1, #data / data_size do
		mesh:setVertexAttribute(i, attribute_index, 
			unpack(data, (i - 1) * data_size + 1, i * data_size))
	end
end

---Returns a new vertice that can be used for vertice data
---@param amount integer|nil the number of vertices to allocate
---@return integer
---@return ... 
function mesh_builder:allocate_vertices(amount)
	self.vertice_counter = self.vertice_counter + 1
	if amount and amount > 0 then
		return self.vertice_counter, self:allocate_vertices(amount - 1)
	end

	return self.vertice_counter
end

local function set_data(vertice_id, size, list, ...)
	if size <= 0 then return end
	local idx = (vertice_id - 1) * size
	for i=1,size do
		list[idx + i] = select(i, ...)
	end
end

---@param vertice_id integer
---@param ... number
---@return mesh_builder
function mesh_builder:set_position(vertice_id, ...)
	set_data(vertice_id, self.vertice_size, self.vertices, ...)
	return self
end

---@param vertice_id integer
---@param ... number
---@return mesh_builder
function mesh_builder:set_uv(vertice_id, ...)
	set_data(vertice_id, self.uv_size, self.uvs, ...)
	return self
end

---@param vertice_id integer
---@param ... number
---@return mesh_builder
function mesh_builder:set_normal(vertice_id, ...)
	set_data(vertice_id, self.normal_size, self.normals, ...)
	return self
end

---@param vertice_id integer
---@param ... number
---@return mesh_builder
function mesh_builder:set_color(vertice_id, ...)
	set_data(vertice_id, self.color_size, self.colors, ...)
	return self
end

---Adds triangles to the list of triangles
---@param vertice_id_a integer
---@param vertice_id_b integer
---@param vertice_id_c integer
---@param ... integer
---@return mesh_builder
function mesh_builder:add_triangles(vertice_id_a, vertice_id_b, vertice_id_c, ...)
	self.triangles[#self.triangles+1] = vertice_id_a
	self.triangles[#self.triangles+1] = vertice_id_b
	self.triangles[#self.triangles+1] = vertice_id_c
	if ... then
		return self:add_triangles(...)
	end
	return self
end

---creates a new mesh using the data from the inputs
---@return love.Mesh
function mesh_builder:create_mesh()
	local vertice_data_count = #self.vertices / self.vertice_size
	assert(vertice_data_count%1 == 0, "vertice_data_count = "..vertice_data_count.."; "..#self.vertices)
	local attribute_normal_index, attribute_uv_index, attribute_color_index
	local attributes = { { "VertexPosition", "float", self.vertice_size } }
	if #self.normals > 0 then
		assert(vertice_data_count == #self.normals / self.normal_size)
		attributes[#attributes + 1] = { "VertexNormal", "float", self.normal_size }
		attribute_normal_index = #attributes
	end
	if #self.uvs > 0 then
		assert(vertice_data_count == #self.uvs / self.uv_size)
		attributes[#attributes + 1] = { "VertexTexCoord", "float", self.uv_size }
		attribute_uv_index = #attributes
	end
	if #self.colors > 0 then
		assert(vertice_data_count == #self.colors / self.color_size)
		attributes[#attributes + 1] = { "VertexColor", "float", self.color_size }
		attribute_color_index = #attributes
	end

	local mesh = love.graphics.newMesh(attributes, #self.vertices, "triangles", "static")
	setVertexAttribute(mesh, 1, self.vertice_size, self.vertices)
	setVertexAttribute(mesh, attribute_normal_index, self.normal_size, self.normals)
	setVertexAttribute(mesh, attribute_uv_index, self.uv_size, self.uvs)
	setVertexAttribute(mesh, attribute_color_index, self.color_size, self.colors)
	if #self.triangles > 0 then 
		mesh:setVertexMap(self.triangles)
	else
		mesh:setDrawRange()
	end
	
	return mesh
end

return mesh_builder