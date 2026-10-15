local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, command, eval, eq = n.clear, n.command, n.eval, t.eq
local mkdir, write_file = t.mkdir, t.write_file
local is_os = t.is_os

-- A name without wildcards, quotes, "$", "~" or backslashes has nothing to expand: it is only
-- looked up. All the others must still get their special treatment.
describe('glob() and expand() of a plain file name', function()
  before_each(function()
    clear()
    mkdir('Xplain')
    mkdir('Xplain/sub')
    command('silent cd Xplain')
    write_file('Xplain/plain.txt', '')
    write_file('Xplain/two words.txt', '')
    write_file('Xplain/sub/inner.txt', '')
    write_file('Xplain/a$b', '')
    write_file('Xplain/a~b', '')
    write_file('Xplain/a#b', '')
    write_file('Xplain/50%', '')
    write_file('Xplain/a,b;c', '')
  end)

  after_each(function()
    n.rmdir('Xplain')
  end)

  it('finds an existing file, directory and nested file', function()
    eq({ 'plain.txt' }, eval([[glob('plain.txt', 0, 1)]]))
    eq({ 'sub' }, eval([[glob('sub', 0, 1)]]))
    eq({ 'sub/inner.txt' }, eval([[glob('sub/inner.txt', 0, 1)]]))
    eq({ 'two words.txt' }, eval([[glob('two words.txt', 0, 1)]]))
    eq({ 'a,b;c' }, eval([[glob('a,b;c', 0, 1)]]))
  end)

  it('finds nothing for a missing name', function()
    eq({}, eval([[glob('missing.txt', 0, 1)]]))
    eq({}, eval([[glob('sub/missing.txt', 0, 1)]]))
    eq({}, eval([[glob('missing/inner.txt', 0, 1)]]))
    eq('', eval([[glob('missing.txt')]]))
  end)

  it('keeps a name that does not exist for expand()', function()
    eq({ 'missing.txt' }, eval([[expand('missing.txt', 0, 1)]]))
    eq({ 'sub/missing.txt' }, eval([[expand('sub/missing.txt', 0, 1)]]))
    eq({ 'plain.txt' }, eval([[expand('plain.txt', 0, 1)]]))
    eq('missing.txt', eval([[expand('missing.txt')]]))
  end)

  it('removes backslashes', function()
    if t.skip(is_os('win'), 'backslash is a path separator') then
      return
    end
    eq({ 'two words.txt' }, eval([[glob('two\ words.txt', 0, 1)]]))
    eq({ 'plain.txt' }, eval([[glob('p\lain.txt', 0, 1)]]))
    eq({ 'a$b' }, eval([[glob('a\$b', 0, 1)]]))
  end)

  it('expands $VAR, but not after a backslash', function()
    if t.skip(is_os('win'), 'backslash is a path separator') then
      return
    end
    command('let $XPLAIN = "sub"')
    eq({ 'sub/inner.txt' }, eval([[glob('$XPLAIN/inner.txt', 0, 1)]]))
    eq({ 'sub' }, eval([[glob('$XPLAIN', 0, 1)]]))
    eq({}, eval([[glob('\$XPLAIN/inner.txt', 0, 1)]]))
  end)

  it(
    'treats "$" as the start of a variable, "~" and others inside a name as plain characters',
    function()
      eq({}, eval([[glob('a$b', 0, 1)]]))
      eq({ 'a~b' }, eval([[glob('a~b', 0, 1)]]))
      eq({ 'a#b' }, eval([[glob('a#b', 0, 1)]]))
      eq({ '50%' }, eval([[glob('50%', 0, 1)]]))
    end
  )

  it('expands "~" at the start of a name', function()
    command('let $HOME = getcwd()')
    local cwd = eval('getcwd()')
    eq({ cwd .. '/plain.txt' }, eval([[glob('~/plain.txt', 0, 1)]]))
    eq({ cwd }, eval([[glob('~', 0, 1)]]))
  end)

  it('expands braces', function()
    eq({ 'plain.txt' }, eval([[glob('{plain,missing}.txt', 0, 1)]]))
    eq({ 'plain.txt', 'sub' }, eval([[glob('{sub,plain.txt}', 0, 1)]]))
  end)

  it("honours 'wildignorecase'", function()
    if t.skip(is_os('win') or is_os('mac'), 'case-insensitive file system') then
      return
    end
    eq({}, eval([[glob('PLAIN.TXT', 0, 1)]]))
    command('set wildignorecase')
    eq({ 'plain.txt' }, eval([[glob('PLAIN.TXT', 0, 1)]]))
  end)

  it("honours 'wildignore'", function()
    command('set wildignore=*.txt')
    eq({}, eval([[glob('plain.txt', 0, 1)]]))
    eq({ 'sub' }, eval([[glob('sub', 0, 1)]]))
  end)

  it('skips a dangling symlink unless {alllinks} is set', function()
    if t.skip(is_os('win'), 'symlinks need privileges on Windows') then
      return
    end
    assert(vim.uv.fs_symlink('nowhere', 'Xplain/dangling'))
    eq({}, eval([[glob('dangling', 0, 1)]]))
    eq({ 'dangling' }, eval([[glob('dangling', 0, 1, 1)]]))
    eq({ 'dangling' }, eval([[expand('dangling', 0, 1)]]))
  end)
end)
