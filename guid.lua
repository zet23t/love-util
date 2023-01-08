local cnt = 0
local r = math.random
---@return string guid a string similar like 63bb1c89-141c-5ad7-ebc6-0668f570000b
return function ()
	cnt = cnt + 1
	local t = math.floor(os.clock()*1000) % 0x10000
	return ("%08x-%04x-%04x-%04x-%04x%04x%04x"):format(os.time(),
		r(0,0xffff),r(0,0xffff),r(0,0xffff),r(0,0xffff),t,cnt)
end