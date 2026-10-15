local t = require('test.unit.testutil')
local describe = t.describe
local itp = t.gen_itp(t.it)

local eq = t.eq
local ffi = t.ffi
local to_cstr = t.to_cstr

local option = t.cimport('./src/nvim/option.h')

describe('copy_option_part()', function()
  --- Splits `value` with copy_option_part() until it is exhausted.
  --- @return table[] list of { text, len } pairs
  local function split(value, maxlen, sep_chars)
    local str = to_cstr(value)
    local pp = ffi.new('char *[1]', str)
    local buf = ffi.new('char[?]', maxlen)
    local parts = {}
    local guard = 0
    while pp[0][0] ~= 0 and guard < 100 do
      local len = tonumber(option.copy_option_part(pp, buf, maxlen, to_cstr(sep_chars)))
      table.insert(parts, { ffi.string(buf), len })
      guard = guard + 1
    end
    return parts
  end

  itp('splits at the separator', function()
    eq({ { 'a', 1 }, { 'bc', 2 }, { 'def', 3 } }, split('a,bc,def', 100, ','))
  end)

  itp('skips the space after a separator', function()
    eq({ { 'a', 1 }, { 'b', 1 } }, split('a, b', 100, ','))
  end)

  itp('returns an empty part for an empty entry', function()
    eq({ { 'a', 1 }, { '', 0 }, { 'b', 1 } }, split('a,,b', 100, ','))
  end)

  itp('removes a backslash before a separator', function()
    eq({ { 'a,b', 3 }, { 'c', 1 } }, split([[a\,b,c]], 100, ','))
    eq({ { 'a b', 3 }, { 'c', 1 } }, split([[a\ b c]], 100, ' '))
  end)

  itp('keeps a backslash before another character', function()
    eq({ { [[a\b]], 3 }, { 'c', 1 } }, split([[a\b,c]], 100, ','))
    eq({ { 'a', 1 }, { [[b\]], 2 } }, split([[a,b\]], 100, ','))
  end)

  itp('handles a backslash after a long run', function()
    local run = ('x'):rep(300)
    eq({ { run .. ',' .. run, 601 }, { 'y', 1 } }, split(run .. [[\,]] .. run .. ',y', 1000, ','))
  end)

  itp('truncates to the buffer but still consumes the whole part', function()
    eq({ { 'abc', 3 }, { 'z', 1 } }, split('abcdefghij,z', 4, ','))
    eq({ { 'ab,', 3 }, { 'z', 1 } }, split([[ab\,cdef,z]], 4, ','))
  end)

  itp('fills the buffer exactly', function()
    eq({ { 'abcd', 4 }, { 'e', 1 } }, split('abcd,e', 5, ','))
    eq({ { 'abcd', 4 }, { 'e', 1 } }, split('abcdX,e', 5, ','))
  end)

  itp('keeps a leading dot, as in the suffixes option', function()
    eq({ { '.bak', 4 }, { '.swp', 4 } }, split('.bak,.swp', 100, ','))
    eq({ { '.', 1 }, { 'a', 1 } }, split('.,a', 100, ','))
  end)

  itp('supports several separator characters', function()
    eq({ { 'a', 1 }, { 'b', 1 }, { 'c', 1 } }, split('a b,c', 100, ' ,'))
    eq({ { 'a', 1 }, { 'b', 1 } }, split('a\tb', 100, '\t '))
  end)

  itp('passes multibyte characters through', function()
    eq({ { 'é', 2 }, { 'ü,x', 4 } }, split('é,ü\\,x', 100, ','))
  end)
end)
