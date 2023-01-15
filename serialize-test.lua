local serialize = require "love-util.serialize"
local class = require "love-util.class"
local class_registry = require "love-util.class_registry"

local test_ca = class "test_ca"
assert(class_registry.test_ca == test_ca._mt)
test_ca.x = true
local test_cb = class "test_cb"
local a = test_ca:create {}
local b = test_cb:create {[a] = 2}
a.b = b
b.a = a
local s = serialize:serialize_to_string(a)

local result = serialize:deserialize_from_string(s)
assert(class_registry.test_ca == test_ca._mt)
assert(result.b.a == result)
assert(getmetatable(result))
assert(getmetatable(result) == test_ca._mt, s)
assert(result.x)
assert(result.b[result] == 2)