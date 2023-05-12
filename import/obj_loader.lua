--[[
------------------------------------------------------------------------------
Wavefront Object Loader is licensed under the MIT Open Source License.
(http://www.opensource.org/licenses/mit-license.html)
------------------------------------------------------------------------------

Copyright (c) 2014 Landon Manning - LManning17@gmail.com - LandonManning.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]
   --

local path = ... .. "."
local loader = {}

loader.version = "0.0.2"

local function file_exists(file)
	if love then return love.filesystem.getInfo(file) ~= nil end

	local f = io.open(file, "r")
	if f then f:close() end
	return f ~= nil
end

function loader.load(file)
	assert(file_exists(file), "File not found: " .. file)

	local get_lines

	if love then
		get_lines = love.filesystem.lines
	else
		get_lines = io.lines
	end

	local lines = {}

	for line in get_lines(file) do
		table.insert(lines, line)
	end

	return loader.parse(lines)
end

local function split_by_whitespaces(line)
	local pos = 1
	local l = {}
	while pos <= #line and line:byte(pos) <= 32 do pos = pos + 1 end
	while pos <= #line do
		local start = pos
		while pos <= #line and line:byte(pos) > 32 do pos = pos + 1 end
		local part = line:sub(start, pos - 1)
		l[#l + 1] = part
		while pos <= #line and line:byte(pos) <= 32 do pos = pos + 1 end
	end
	return l
end

local slash = ("/"):byte()
local function split_by_slashes(line)
	local pos = 1
	local l = {}
	while pos <= #line do
		local start = pos
		while pos <= #line and line:byte(pos) ~= slash do pos = pos + 1 end
		local part = line:sub(start, pos - 1)
		l[#l + 1] = part
		while pos <= #line and line:byte(pos) == slash do pos = pos + 1 end
	end
	return l
end

---@param object string[]
---@return table
function loader.parse(object)
	local obj = {
		v = {}, -- List of vertices - x, y, z, [w]=1.0
		vt = {}, -- Texture coordinates - u, v, [w]=0
		vn = {}, -- Normals - x, y, z
		vp = {}, -- Parameter space vertices - u, [v], [w]
		f = {}, -- Faces
	}

	for k = 1, #object do
		local line = object[k]

		local l = split_by_whitespaces(line)

		if l[1] == "v" then
			local v = {
				x = tonumber(l[2]),
				y = tonumber(l[3]),
				z = tonumber(l[4]),
				w = tonumber(l[5]) or 1.0
			}
			table.insert(obj.v, v)
		elseif l[1] == "vt" then
			local vt = {
				u = tonumber(l[2]),
				v = tonumber(l[3]),
				w = tonumber(l[4]) or 0
			}
			table.insert(obj.vt, vt)
		elseif l[1] == "vn" then
			local vn = {
				x = tonumber(l[2]),
				y = tonumber(l[3]),
				z = tonumber(l[4]),
			}
			table.insert(obj.vn, vn)
		elseif l[1] == "vp" then
			local vp = {
				u = tonumber(l[2]),
				v = tonumber(l[3]),
				w = tonumber(l[4]),
			}
			table.insert(obj.vp, vp)
		elseif l[1] == "f" then
			local f = {}

			for i = 2, #l do
				local split = split_by_slashes(l[i])
				local v = {}

				v.v = tonumber(split[1])
				if split[2] ~= "" then v.vt = tonumber(split[2]) end
				v.vn = tonumber(split[3])

				table.insert(f, v)
			end

			table.insert(obj.f, f)
		end
	end

	return obj
end

return loader
