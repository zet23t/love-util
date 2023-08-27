local binary_serialize = require "love-util.binary_serialize"
local class_registry = require "love-util.class_registry"
local serialization_test_class = require "love-util.class" "serialization_test_class"

local function to_hex(str)
    local out = {}
    for i = 1, #str, 16 do
        local part = str:sub(i, i + 15)
        out[#out + 1] = string.format("%08i:  ", i - 1)
        if #part < 16 then
            part = part .. ("\0"):rep(16 - #part)
        end
        for i = 1, #part do
            out[#out + 1] = string.format("%02x", part:byte(i))
            if i % 4 == 0 then out[#out + 1] = " " end
        end
        out[#out + 1] = " | "
        out[#out + 1] = part:gsub("%c", " %0"):gsub(".", {["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\0"] = " "})
        out[#out + 1] = "\n"
    end
    return table.concat(out)
end
local data = {
    a = 1,
    b = 2,
    c = { d = 3 },
    [false] = true,
    [true] = { 1, 2, 3, 4, [23] = "hello!" },
    obj = serialization_test_class:create()
}
data[data] = data
data.trash = {}
setmetatable(data[true], { __newindex = data.trash, __index = data.trash })
data[true].x = "hu"

local bytes = table.concat(binary_serialize:serialize(data))
print(to_hex(bytes))
local data2 = binary_serialize:deserialize(bytes)
assert(data2.a == 1)
assert(data2.b == 2)
assert(data2.c.d == 3)
assert(data2[data2] == data2)
assert(data2[false] == true)
assert(data2[true][23] == "hello!")
assert(data2[true][4] == 4)
assert(data2[true].x == "hu")
assert(data2.trash.x == "hu")
assert(data2.trash[23] == nil)
data2[true].test = true
assert(data2.trash.test == true)
print(getmetatable(data.obj),serialization_test_class._mt)
print(getmetatable(data2.obj),serialization_test_class._mt)
assert(getmetatable(data2.obj) == serialization_test_class._mt)

serialization_test_class.some_class_field = true
assert(data2.obj.some_class_field == true)