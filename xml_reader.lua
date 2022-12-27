---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--
-- xml_reader.lua - XML reader
--
-- version: 1.3
--
-- CHANGELOG:
--
-- 1.3 - Simplified syntax, ensured no global variable assignments, renaming 
--       according to my naming schema, removing unused code, removing 
--       concept of private members with function getters, removing 
--       some ease-of-access functionality of the node objects
-- 1.2 - Created new structure for returned table
-- 1.1 - Fixed base directory issue with the loadFile() function.
--
-- NOTE: 1.3 is a fork of https://github.com/Cluain/Lua-Simple-XML-Parser/
-- NOTE: This is a modified version of Alexander Makeev's Lua-only XML parser
-- found here: http://lua-users.org/wiki/LuaXml
--
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

local function from_xml_string(value)
	value = value:gsub("&#x([%x]+)%;",
		function(h)
			return string.char(tonumber(h, 16))
		end)
	value = value:gsub("&#([0-9]+)%;",
		function(h)
			return string.char(tonumber(h, 10))
		end)
	value = value:gsub("&quot;", "\"")
		:gsub("&apos;", "'")
		:gsub("&gt;", ">")
		:gsub("&lt;", "<")
		:gsub("&amp;", "&")
	return value
end

local function parse_attributes(node, s)
	for w, _, a in s:gmatch "(%w+)=([\"'])(.-)%2" do
		node:add_attribute(w, from_xml_string(a))
	end
end

local node = {}
node._mt = { __index = node }
function node:add_child(child)
	table.insert(self.children, child)
end

function node:add_attribute(name, value)
	if self.attributes[name] ~= nil then
		if type(self.attributes[name]) == "string" then
			local tempTable = {}
			table.insert(tempTable, self.attributes[name])
			self.attributes[name] = tempTable
		end
		table.insert(self.attributes[name], value)
	else
		self.attributes[name] = value
	end

	table.insert(self.attributes, { name = name, value = value })
end

local function new_node(tag)
	local node = setmetatable({
		value = "";
		tag = tag;
		children = {};
		attributes = {};
	}, node._mt)
	return node
end

local xml_reader = {}

function xml_reader:parse_xml_text(xmlText)
	local stack = {}
	local top = new_node()
	table.insert(stack, top)
	local ni, c, label, xarg, empty
	local i, j = 1, 1
	while true do
		ni, j, c, label, xarg, empty = xmlText:find("<(%/?)([%w_:]+)(.-)(%/?)>", i)
		if not ni then break end
		local text = string.sub(xmlText, i, ni - 1)
		if not string.find(text, "^%s*$") then
			local lVal = (top.value or "") .. from_xml_string(text)
			stack[#stack].value = lVal
		end
		if empty == "/" then -- empty element tag
			local lNode = new_node(label)
			parse_attributes(lNode, xarg)
			top:add_child(lNode)
		elseif c == "" then -- start tag
			local lNode = new_node(label)
			parse_attributes(lNode, xarg)
			table.insert(stack, lNode)
			top = lNode
		else -- end tag
			local toclose = table.remove(stack) -- remove top
			top = stack[#stack]
			if #stack < 1 then
				error("XmlParser: nothing to close with " .. label)
			end
			if toclose.tag ~= label then
				error("XmlParser: trying to close " .. toclose.tag .. " with " .. label)
			end
			top:add_child(toclose)
		end
		i = j + 1
	end
	if #stack > 1 then
		error("xml_reader: unclosed " .. stack[#stack].tag)
	end
	return top
end

function xml_reader:load_file(path)
	local hFile = assert(io.open(path, "r"))
	local xmlText = hFile:read "*a"
	hFile:close()
	return self:parse_xml_text(xmlText)
end

return xml_reader
