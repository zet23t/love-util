local assert_type      = require "love-util.assert_type"
local class            = require "love-util.class"

---@class entity_component : object
---@field entity entity_node
---@field component_type entity_component|nil

---@class entity_node : object An entity represents an element in a tree structure
---@field parent entity_node|nil
---@field children entity_node[]
---@field components table[]
---@field component_data table
---@field is_enabled boolean
---@field name string
local entity_node      = class "entity_node"
entity_node.is_enabled = true
entity_node.name       = "unnamed entity_node"

local function call_on(t, name, ...)
	if type(t[name]) ~= "function" then return false, t[name] end
	return true, t[name](t, ...)
end

function entity_node:new(name)
	return self:create {
		name = assert_type(name, "string", "nil"),
		component_data = {},
		children = {},
		components = {},
	}
end

---A query to search an entity in the entity nodes by name
---@param path string[]
function entity_node:query(path)
	local node = self
	for i = 1, #path do
		local name = path[i]
		local next_node
		for k = 1, #node.children do
			local child = node.children[k]
			if child.name == name then
				next_node = child
				break
			end
		end
		if not next_node then
			return nil
		end
		node = next_node
	end
	return node
end

function entity_node:set_parent(parent)
	parent:add_child(self)
	return self
end

function entity_node:add_child(node)
	node:remove()
	if self:has_parent(node) then
		print("Warning: rejected element in add_child")
		return self
	end
	node.parent = self
	self.children[#self.children + 1] = node
	return self
end

---@param func fun(node:entity_node, ...):boolean|nil breaks iteration when returning true
function entity_node:for_each(func, ...)
	if func(self, ...) then return true end
	for i = 1, #self.children do
		if self.children[i]:for_each(func, ...) then
			return true
		end
	end
end

---returns a list of all entity parent names in order of hierarchy level
---@return string[]
function entity_node:get_name_path()
	local path = {}
	local node = self
	repeat
		table.insert(path, 1, node.name)
		node = node.parent
	until not node
	return path
end

---retrieve element by name path
---@param path string[]
---@param index integer|nil
---@return entity_node|nil
function entity_node:get_by_path(path, index)
	index = index or 1
	if path[index] ~= self.name then return end
	if index >= #path then return self end
	for i = 1, #self.children do
		local element = self.children[i]:get_by_path(path, index + 1)
		if element then
			return element
		end
	end

	return nil
end

---@param func fun(node:entity_component, ...):boolean|nil breaks iteration when returning true
function entity_node:for_each_component(func, ...)
	for i = 1, #self.components do
		if func(self.components[i], ...) then
			return true
		end
	end
	for i = 1, #self.children do
		if self.children[i]:for_each_component(func, ...) then
			return true
		end
	end
end

function entity_node:has_parent(parent)
	if self.parent == parent then return true end
	return self.parent and self.parent:has_parent(parent)
end

function entity_node:remove_all_children()
	for i = 1, #self.children do
		local child = self.children[i]
		child.parent = nil
		self.children[i] = nil
	end
	return self
end

function entity_node:remove()
	local parent = self.parent
	if not parent then return end
	self.parent = nil
	for i = #parent.children, 1, -1 do
		if parent.children[i] == self then
			table.remove(parent.children, i)
			break
		end
	end
	return self
end

function entity_node:call_on_components(name, ...)
	for i = #self.components, 1, -1 do
		call_on(self.components[i], name, ...)
	end
	return self
end

---@param steps table
---@param ... any
function entity_node:call(steps, ...)
	for i = 1, #steps do
		local step = steps[i]
		local mode = step.mode
		if mode == "ignore_disabled" then
			if not self.is_enabled then
				return
			end
		elseif mode == "filter" then
			if step:filter_fn(self) then
				return
			end
		elseif mode == "select" then
			local name = step.name
			for i = 1, #self.components do
				local cmp = self.components[i]
				local selected = false
				if cmp[name] then
					if cmp[name](cmp, self, ...) then
						selected = true
						break
					else
						return
					end
				end
				if not selected then
					return
				end
			end
		elseif mode == "components" then
			local name = step.name
			for i = #self.components, 1, -1 do
				call_on(self.components[i], name, ...)
			end
		elseif mode == "children" then
			for i = #self.children, 1, -1 do
				self.children[i]:call(steps, ...)
			end
		end
	end
end

local mode_ignore_disabled = { mode = "ignore_disabled" }
local mode_children = { mode = "children" }
local function mode_components_call(call) return { mode = "components", name = call } end

local on_entity_node_enabled = { mode_ignore_disabled, mode_components_call "on_entity_node_enabled", mode_children }
local on_entity_node_disabled = { mode_ignore_disabled, mode_components_call "on_entity_node_disabled", mode_children }

function entity_node:set_enabled(enabled)
	if self.is_enabled == enabled then return self end
	if not enabled then
		self:call(on_entity_node_disabled)
	end
	self.is_enabled = enabled
	if enabled then
		self:call(on_entity_node_enabled)
	end

	return self
end

function entity_node:add_component(cmp)
	self.components[#self.components + 1] = cmp
	cmp.entity = self
	self:call_on_components("on_component_added", cmp)
	return self
end

function entity_node:remove_component(cmp)
	for i = 1, #self.components do
		if self.components[i] == cmp then
			table.remove(self.components, i)
			self:call_on_components("on_component_removed", cmp)
			break
		end
	end
	return self
end

return entity_node
