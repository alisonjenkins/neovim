local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, command, eval, eq = n.clear, n.command, n.eval, t.eq
local mkdir, write_file = t.mkdir, t.write_file
local is_os = t.is_os

describe('glob() with "*" and "*.ext" patterns', function()
  before_each(function()
    clear()
    mkdir('test-star')
    mkdir('test-star/sub')
    mkdir('test-star/sub.vim')
    command('silent cd test-star')
    for _, name in ipairs({
      'a.vim',
      'b.lua',
      'x.vim.bak',
      'vim',
      '.hidden.vim',
      '.vim',
      'é.vim',
      'a-b_c.txt',
      'sub/c.vim',
    }) do
      command(('call writefile([], "%s")'):format(name))
    end
  end)

  after_each(function()
    n.rmdir('test-star')
  end)

  it('"*" matches every name but the hidden ones', function()
    eq(
      { 'a-b_c.txt', 'a.vim', 'b.lua', 'sub', 'sub.vim', 'vim', 'x.vim.bak', 'é.vim' },
      eval([[sort(glob('*', 0, 1))]])
    )
  end)

  it('"*.ext" matches files and directories ending in the suffix', function()
    eq({ 'a.vim', 'sub.vim', 'é.vim' }, eval([[glob('*.vim', 0, 1)]]))
    eq({ 'b.lua' }, eval([[glob('*.lua', 0, 1)]]))
    eq({ 'x.vim.bak' }, eval([[glob('*.vim.bak', 0, 1)]]))
    eq({ 'a-b_c.txt' }, eval([[glob('*-b_c.txt', 0, 1)]]))
  end)

  it('"*suffix" needs no dot', function()
    eq({ 'a.vim', 'sub.vim', 'vim', 'é.vim' }, eval([[glob('*vim', 0, 1)]]))
  end)

  it('matches nothing when the suffix is absent or longer than the name', function()
    eq({}, eval([[glob('*.v', 0, 1)]]))
    eq({}, eval([[glob('*.avery_long_suffix_that_no_name_has', 0, 1)]]))
    eq({}, eval([[glob('*.VIM', 0, 1)]]))
  end)

  it("honours 'fileignorecase' and 'wildignorecase'", function()
    command('set fileignorecase')
    eq({ 'a.vim', 'sub.vim', 'é.vim' }, eval([[glob('*.VIM', 0, 1)]]))
    command('set nofileignorecase wildignorecase')
    eq({ 'a.vim', 'sub.vim', 'é.vim' }, eval([[glob('*.VIM', 0, 1)]]))
  end)

  it('hidden names need a leading dot in the pattern', function()
    eq({ '.hidden.vim' }, eval([[glob('.*.vim', 0, 1)]]))
  end)

  it('works in the last component of a longer pattern', function()
    eq({ 'sub/c.vim' }, eval([[glob('s*/*.vim', 0, 1)]]))
    eq({ 'sub/c.vim' }, eval([[glob('*/*.vim', 0, 1)]]))
    eq({ 'sub/c.vim' }, eval([[glob('sub/*', 0, 1)]]))
  end)

  it('works below a directory with a non-ASCII name', function()
    if t.skip(is_os('mac'), 'the file system normalizes names') then
      return
    end
    mkdir('test-star/é-dir')
    mkdir('test-star/e\xCC\x81-dir')
    command([[call writefile([], "é-dir/f.vim")]])
    command([[call writefile([], "é-dir/g.lua")]])
    command('call writefile([], "e\xCC\x81-dir/h.vim")')
    eq({ 'é-dir/f.vim' }, eval([[glob('é-dir/*.vim', 0, 1)]]))
    eq({ 'é-dir/f.vim', 'é-dir/g.lua' }, eval([[glob('é-dir/*', 0, 1)]]))
    eq({ 'e\xCC\x81-dir/h.vim' }, eval([[glob('e]] .. '\xCC\x81' .. [[-dir/*.vim', 0, 1)]]))
    eq({ 'é-dir/f.vim' }, eval([[glob('é*/f.vim', 0, 1)]]))
  end)

  it('matches names with unusual characters', function()
    if t.skip(is_os('win') or is_os('mac'), 'needs unusual file names') then
      return
    end
    for _, name in ipairs({
      'sp ace.vim',
      'new\nline.vim',
      'tab\t.vim',
      "q'uote.vim",
      'dollar$.vim',
      'tilde~.vim',
      'br[ack]et.vim',
      'st*r.vim',
      'bad\xff.vim',
      'comp\xcc\x81.vim',
      'x.vim\xcc\x81',
      'ends.vi\xcc\x81m',
      'none.vim\xff',
    }) do
      write_file('test-star/' .. name, '')
    end
    eq({
      'a.vim',
      'bad\xff.vim',
      'br[ack]et.vim',
      'comp\xcc\x81.vim',
      'dollar$.vim',
      'new\nline.vim',
      "q'uote.vim",
      'sp ace.vim',
      'st*r.vim',
      'sub.vim',
      'tab\t.vim',
      'tilde~.vim',
      'é.vim',
    }, eval([[sort(glob('*.vim', 0, 1))]]))
    eq({ 'x.vim\xcc\x81' }, eval([[glob('*.vim' . "\u0301", 0, 1)]]))
    eq({ 'none.vim\xff' }, eval([[glob('*.vim' . "\xff", 0, 1)]]))
  end)

  it('works with "**"', function()
    eq({ 'a.vim', 'sub.vim', 'sub/c.vim', 'é.vim' }, eval([[sort(glob('**/*.vim', 0, 1))]]))
  end)

  it('works with globpath()', function()
    eq({ './a.vim', './sub.vim', './é.vim' }, eval([[globpath('.', '*.vim', 0, 1)]]))
  end)
end)
