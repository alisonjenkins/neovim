local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, command, eq, fn = n.clear, n.command, t.eq, n.fn
local mkdir, write_file = t.mkdir, t.write_file

-- A pattern is copied character by character while Nvim looks for the wildcard component. A
-- character is not a byte: an ASCII letter may carry composing characters, and bytes of an
-- invalid sequence are kept as they are.
describe('glob() of patterns with multibyte characters', function()
  if
    t.skip(t.is_os('win') or t.is_os('mac'), 'needs a file system that keeps the byte sequence')
  then
    return
  end

  local e_acute = '\xc3\xa9' -- precomposed
  local e_comb = 'e\xcc\x81' -- "e" and a combining acute accent

  before_each(function()
    clear()
    mkdir('Xmb')
    command('silent cd Xmb')
    mkdir('Xmb/d' .. e_comb)
    mkdir('Xmb/d' .. e_acute)
    mkdir('Xmb/plain')
    mkdir('Xmb/\xe4\xb8\xad\xe6\x96\x87')
    for _, name in ipairs({
      e_comb .. '.txt',
      e_acute .. '.txt',
      'e.txt',
      'E.txt',
      'a' .. e_comb .. 'b',
      'ab',
      '\xff.bad',
      'x\xff',
      'x\xc3',
      'plain/' .. e_comb .. 'e.vim',
      'plain/' .. e_acute .. 'e.vim',
      'd' .. e_comb .. '/in.vim',
      'd' .. e_acute .. '/in.vim',
      '\xe4\xb8\xad\xe6\x96\x87/n.vim',
    }) do
      write_file('Xmb/' .. name, '')
    end
  end)

  after_each(function()
    n.rmdir('Xmb')
  end)

  it('matches a letter with a composing character literally', function()
    eq({ e_comb .. '.txt' }, fn.glob(e_comb .. '*', 0, 1))
    eq({ e_acute .. '.txt' }, fn.glob(e_acute .. '*', 0, 1))
    eq({ e_comb .. '.txt' }, fn.glob(e_comb .. '.txt', 0, 1))
    eq({ 'a' .. e_comb .. 'b' }, fn.glob('a' .. e_comb .. '?', 0, 1))
    eq({ 'a' .. e_comb .. 'b' }, fn.glob('a' .. e_comb .. 'b', 0, 1))
    eq({ 'ab' }, fn.glob('a?', 0, 1))
  end)

  it('keeps a composing character in a directory before the wildcard', function()
    eq({ 'd' .. e_comb .. '/in.vim' }, fn.glob('d' .. e_comb .. '/*', 0, 1))
    eq({ 'd' .. e_acute .. '/in.vim' }, fn.glob('d' .. e_acute .. '/*', 0, 1))
    eq({ 'd' .. e_comb .. '/in.vim' }, fn.glob('d' .. e_comb .. '/in.v*', 0, 1))
    eq({ 'plain/' .. e_comb .. 'e.vim' }, fn.glob('plain/' .. e_comb .. '*', 0, 1))
    eq({ 'plain/' .. e_acute .. 'e.vim' }, fn.glob('plain/' .. e_acute .. '*', 0, 1))
  end)

  it('keeps multibyte characters in a directory before the wildcard', function()
    eq({ '\xe4\xb8\xad\xe6\x96\x87/n.vim' }, fn.glob('\xe4\xb8\xad\xe6\x96\x87/*', 0, 1))
    eq({ '\xe4\xb8\xad\xe6\x96\x87/n.vim' }, fn.glob('\xe4\xb8\xad*/n.v?m', 0, 1))
  end)

  it('matches bytes that are not valid UTF-8', function()
    eq({ '\xff.bad' }, fn.glob('\xff*', 0, 1))
    eq({ '\xff.bad' }, fn.glob('\xff.bad', 0, 1))
    eq({ 'x\xc3', 'x\xff' }, fn.glob('x?', 0, 1))
    eq({ 'x\xc3' }, fn.glob('x\xc3*', 0, 1))
  end)

  it("with 'wildignorecase' matches the letter whatever its case", function()
    command('set wildignorecase')
    eq({ 'E.txt', 'e.txt' }, fn.glob('e.t*', 0, 1))
    eq({ 'E.txt', 'e.txt' }, fn.glob('E.T*', 0, 1))
    eq({ 'd' .. e_acute .. '/in.vim' }, fn.glob('D' .. e_acute .. '/*', 0, 1))
    eq({ 'd' .. e_comb .. '/in.vim' }, fn.glob('D' .. e_comb .. '/*', 0, 1))
    eq({ 'plain/' .. e_comb .. 'e.vim' }, fn.glob('PLAIN/' .. e_comb .. '*', 0, 1))
  end)
end)
