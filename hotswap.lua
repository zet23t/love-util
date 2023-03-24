local excluded_unload = {nativefs = true}
-- exclude all packages that are present when this file gets required (it should be required first!)
for k in pairs(package.loaded) do
	excluded_unload[k] = true
end

local all      = require "love-util.all"
local nativefs = require "nativefs"

local STOP_ALL = false

local function safecall(f, ...)
	return xpcall(f, function(err)
		STOP_ALL = true
		print(debug.traceback("ERROR: " .. err, 3))
	end, ...)
end

local function reload_all()
	print "reload initialized"
	if love.quit and love.quit() then
		print "love.quit did not return true; reload cancelled"
		return
	end
	for k, v in pairs(package.loaded) do
		if not excluded_unload[k] then
			-- #print("Unload: ", k)
			package.loaded[k] = nil
		end
	end
	dofile "main.lua"
	if love.load then
		love.load()
	end
	STOP_ALL = false
end

local function safe_reload()
	xpcall(reload_all, function(msg)
		print(debug.traceback("Error reloading:\n  " .. msg, 3))
	end)
end

local scripts_cache = {}
local last_scan = 0
local function scan_scripts(is_init)
	if not is_init and love.timer.getTime() - last_scan < 1 then return end
	last_scan = love.timer.getTime()
	local is_changed
	local function scan(dir)
		local files = nativefs.getDirectoryItems(dir)
		for file in all(files) do
			if coroutine.isyieldable() then
				coroutine.yield()
			end
			local path = dir .. file
			local info = nativefs.getInfo(path)
			if info and info.type == "file" and file:match "%.lua$" then
				local content = info.modtime
				if not content then
					io.flush()
					local fp = assert(io.open(path))
					content = fp:read "*a"
					fp:close()
				end
				is_changed = is_changed or scripts_cache[path] ~= content
				scripts_cache[path] = content
			elseif info and info.type == "directory" then
				scan(path .. "/")
			end
		end
	end

	scan "./"
	
	if not is_init and is_changed then
		print("change detected, reloading")
		safe_reload()
	end
end

local handlers = {}

function handlers.keypressed(key)
	if key == "f5" then
		safe_reload()
	end
end

local scan_step
function handlers.update(dt)
	if not scan_step or coroutine.status(scan_step) == "dead" then
		scan_step = coroutine.create(scan_scripts)
	end
	local tstart = love.timer.getTime()
	repeat
		coroutine.resume(scan_step)
	until love.timer.getTime() - tstart > 0.02
end

function handlers.draw()
end

function love.run()

	if love.load then safecall(love.load, love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0
	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a, b, c, d, e, f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				if handlers[name] then
					handlers[name](a, b, c, d, e, f)
				end
				if not STOP_ALL then
					safecall(love.handlers[name], a, b, c, d, e, f)
				end
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

		-- Call update and draw
		handlers.update(dt)
		if love.update and not STOP_ALL then safecall(love.update, dt) end -- will pass 0 if love.timer is disabled

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())

			if love.draw and not STOP_ALL then
				safecall(love.draw)
			end

			love.graphics.setCanvas()
			love.graphics.present()
		end

		if STOP_ALL then
			safecall(scan_scripts)
		end

		if love.timer then love.timer.sleep(0.001) end
	end
end

scan_scripts(true)
