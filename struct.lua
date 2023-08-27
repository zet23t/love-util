--[[
 * Copyright (c) 2015-2020 Iryont <https://github.com/iryont/lua-struct>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
]]

-- Note: I've modified this file to be more in line with my needs;
-- reducing the amount of garbage created, not creating strings but writing
-- into a table that is assumed to hold single byte values. This makes the API
-- incompatible with the original, otherwise I would fork & improve it & submit
-- a pull request.
-- TODO: replace :find with something more efficient


local unpack = table.unpack or _G.unpack

local struct = {}

local function append_string(stream, str)
    local start = #stream
    for i=1,#str do
        stream[start+i] = string.char(str:byte(i))
    end
end

local function append_table(stream, tab)
    local start = #stream
    for i=1,#tab do
        stream[start+i] = tab[i]
    end
end

local function append_table_reversed(stream, tab)
    local start = #stream+1
    local len = #tab
    for i=0,#tab-1 do
        stream[start+i] = tab[len-i]
    end
end

---format is expected to be a string, which may contain the following format codes:
---* "b" a signed char.
---* "B" an unsigned char.
---* "h" a signed short (2 bytes).
---* "H" an unsigned short (2 bytes).
---* "i" a signed int (4 bytes).
---* "I" an unsigned int (4 bytes).
---* "l" a signed long (8 bytes).
---* "L" an unsigned long (8 bytes).
---* "f" a float (4 bytes).
---* "d" a double (8 bytes).
---* "s" a zero-terminated string.
---* "cn" a sequence of exactly n chars corresponding to a single Lua string (if n <= 0 then for packing - the string length is taken, unpacking - the number value of the previous unpacked value which is not returned).
---@param format string
---@param stream table
---@param ... unknown
---@return nil
function struct.pack(format, stream, ...)
    local endianness = true
    local var_index = 1

    for i = 1, format:len() do
        local opt = format:sub(i, i)

        if opt == '<' then
            endianness = true
        elseif opt == '>' then
            endianness = false
        elseif opt:find('[bBhHiIlL]') then
            local n = opt:find('[hH]') and 2 or opt:find('[iI]') and 4 or opt:find('[lL]') and 8 or 1
            local val = tonumber(select(var_index, ...)) or 0
            var_index = var_index + 1

            local bytes = {}
            for j = 1, n do
                table.insert(bytes, string.char(val % (0x100)))
                val = math.floor(val / (0x100))
            end

            if not endianness then
                append_table_reversed(stream, bytes)
            else
                append_table(stream, bytes)
            end
        elseif opt:find('[fd]') then
            local val = tonumber(select(var_index, ...)) or 0
            var_index = var_index + 1
            local sign = 0

            if val < 0 then
                sign = 1
                val = -val
            end

            local mantissa, exponent = math.frexp(val)
            if val == 0 then
                mantissa = 0
                exponent = 0
            else
                mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, (opt == 'd') and 53 or 24)
                exponent = exponent + ((opt == 'd') and 1022 or 126)
            end

            local bytes = {}
            if opt == 'd' then
                val = mantissa
                for i = 1, 6 do
                    table.insert(bytes, string.char(math.floor(val) % (0x100)))
                    val = math.floor(val / (0x100))
                end
            else
                table.insert(bytes, string.char(math.floor(mantissa) % (0x100)))
                val = math.floor(mantissa / (0x100))
                table.insert(bytes, string.char(math.floor(val) % (0x100)))
                val = math.floor(val / (0x100))
            end

            table.insert(bytes, string.char(math.floor(exponent * ((opt == 'd') and 16 or 128) + val) % (0x100)))
            val = math.floor((exponent * ((opt == 'd') and 16 or 128) + val) / (0x100))
            table.insert(bytes, string.char(math.floor(sign * 128 + val) % (0x100)))
            val = math.floor((sign * 128 + val) / (0x100))

            if not endianness then
                append_table_reversed(stream, bytes)
            else
                append_table(stream, bytes)
            end
        elseif opt == 's' then
            local val = tostring(select(var_index, ...))
            var_index = var_index + 1
            append_string(stream, val)
            table.insert(stream, string.char(0))
        elseif opt == 'c' then
            local n = format:sub(i + 1):match('%d+')
            local len = tonumber(n)
            local str = tostring(select(var_index, ...))
            var_index = var_index + 1
            if len <= 0 then
                len = str:len()
            end
            if len - str:len() > 0 then
                str = str .. string.rep(' ', len - str:len())
            end
            append_string(stream, str:sub(1, len))
            i = i + n:len()
        end
    end
end

function struct.unpack(format, stream, pos)
    local vars = {}
    local iterator = pos or 1
    local endianness = true

    for i = 1, format:len() do
        local opt = format:sub(i, i)

        if opt == '<' then
            endianness = true
        elseif opt == '>' then
            endianness = false
        elseif opt:find('[bBhHiIlL]') then
            local n = opt:find('[hH]') and 2 or opt:find('[iI]') and 4 or opt:find('[lL]') and 8 or 1
            local signed = opt:lower() == opt

            local val = 0
            for j = 1, n do
                local byte = string.byte(stream,iterator)
                if endianness then
                    val = val + byte * (2 ^ ((j - 1) * 8))
                else
                    val = val + byte * (2 ^ ((n - j) * 8))
                end
                iterator = iterator + 1
            end

            if signed and val >= 2 ^ (n * 8 - 1) then
                val = val - 2 ^ (n * 8)
            end

            table.insert(vars, math.floor(val))
        elseif opt:find('[fd]') then
            local n = (opt == 'd') and 8 or 4
            local x = stream:sub(iterator, iterator + n - 1)
            iterator = iterator + n

            if not endianness then
                x = string.reverse(x)
            end

            local sign = 1
            local mantissa = string.byte(x, (opt == 'd') and 7 or 3) % ((opt == 'd') and 16 or 128)
            for i = n - 2, 1, -1 do
                mantissa = mantissa * (0x100) + string.byte(x, i)
            end

            if string.byte(x, n) > 127 then
                sign = -1
            end

            local exponent = (string.byte(x, n) % 128) * ((opt == 'd') and 16 or 2) +
                math.floor(string.byte(x, n - 1) / ((opt == 'd') and 16 or 128))
            if exponent == 0 then
                table.insert(vars, 0.0)
            else
                mantissa = (math.ldexp(mantissa, (opt == 'd') and -52 or -23) + 1) * sign
                table.insert(vars, math.ldexp(mantissa, exponent - ((opt == 'd') and 1023 or 127)))
            end
        elseif opt == 's' then
            local bytes = {}
            for j = iterator, stream:len() do
                if stream:sub(j, j) == string.char(0) or stream:sub(j) == '' then
                    break
                end

                table.insert(bytes, stream:sub(j, j))
            end

            local str = table.concat(bytes)
            iterator = iterator + str:len() + 1
            table.insert(vars, str)
        elseif opt == 'c' then
            local n = format:sub(i + 1):match('%d+')
            local len = tonumber(n)
            if len <= 0 then
                len = table.remove(vars)
            end

            table.insert(vars, stream:sub(iterator, iterator + len - 1))
            iterator = iterator + len
            i = i + n:len()
        end
    end

    return unpack(vars)
end

return struct
