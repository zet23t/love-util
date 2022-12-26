_G.GStore = _G.GStore or {}
local store = _G.GStore

return function (uid)
	local t = store[uid]
	if not t then
		t = {}
		store[uid] = t
	end
	return t
end
