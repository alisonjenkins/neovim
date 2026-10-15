local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, command, eval, eq = n.clear, n.command, n.eval, t.eq
local mkdir, write_file = t.mkdir, t.write_file

-- Wildcards, "$", "~", quotes and backslashes are looked for in the whole pattern; a typical
-- 'runtimepath' pattern has a long directory prefix with only plain characters.
describe('glob() of a pattern with a long plain prefix', function()
  local long = ('p'):rep(120)
  local all = { long .. '/a[b', long .. '/one.vim', long .. '/tail$', long .. '/two.lua' }

  before_each(function()
    clear()
    mkdir('Xscan')
    command('silent cd Xscan')
    mkdir('Xscan/' .. long)
    write_file('Xscan/' .. long .. '/one.vim', '')
    write_file('Xscan/' .. long .. '/two.lua', '')
    write_file('Xscan/' .. long .. '/a[b', '')
    write_file('Xscan/' .. long .. '/tail$', '')
  end)

  after_each(function()
    n.rmdir('Xscan')
  end)

  it('finds the wildcard after the prefix', function()
    eq(all, eval(("glob('%s/*', 0, 1)"):format(long)))
    eq({ long .. '/one.vim' }, eval(("glob('%s/*.vim', 0, 1)"):format(long)))
    eq({ long .. '/two.lua' }, eval(("glob('%s/tw?.lua', 0, 1)"):format(long)))
    eq({ long .. '/one.vim' }, eval(("glob('%s/o[n]e.vim', 0, 1)"):format(long)))
  end)

  it('finds a wildcard in the prefix itself', function()
    eq(all, eval(("glob('p*/*', 0, 1)"):format(long)))
    eq({ long .. '/one.vim' }, eval(("glob('%s/one.v?m', 0, 1)"):format(('p'):rep(60) .. '*')))
  end)

  it('returns a name without wildcards as is', function()
    eq({ long .. '/one.vim' }, eval(("glob('%s/one.vim', 0, 1)"):format(long)))
    eq({}, eval(("glob('%s/none.vim', 0, 1)"):format(long)))
  end)

  it('treats a wildcard after a backslash as a plain character', function()
    eq({ long .. '/a[b' }, eval(("glob('%s/a\\[b', 0, 1)"):format(long)))
    eq({ long .. '/a[b' }, eval(("glob('%s/a\\[*', 0, 1)"):format(long)))
    eq({}, eval(("glob('%s/a\\*', 0, 1)"):format(long)))
    eq({ long .. '/one.vim' }, eval(("glob('%s/one\\.v*', 0, 1)"):format(long)))
  end)

  it('treats a backslash at the end as a plain character', function()
    eq({}, eval(("glob('%s/one.vim\\', 0, 1)"):format(long)))
  end)

  it('expands an environment variable after the prefix', function()
    command('let $XSCAN_NAME = "one"')
    eq({ long .. '/one.vim' }, eval(("glob('%s/$XSCAN_NAME.vim', 0, 1)"):format(long)))
    eq({ long .. '/one.vim' }, eval(("glob('%s/$XSCAN_NAME.v*', 0, 1)"):format(long)))
    -- a "$" after a backslash is not a variable
    eq({ long .. '/tail$' }, eval(("glob('%s/tail\\$', 0, 1)"):format(long)))
  end)

  it('expands braces after the prefix', function()
    eq(
      { long .. '/one.vim', long .. '/two.lua' },
      eval(("glob('%s/{one.vim,two.lua}', 0, 1)"):format(long))
    )
  end)

  it('expands "~" at the start only', function()
    command('let $HOME = getcwd()')
    local cwd = eval('getcwd()')
    eq({ cwd .. '/' .. long .. '/one.vim' }, eval(("glob('~/%s/one.v*', 0, 1)"):format(long)))
    eq({}, eval(("glob('%s/~/one.v*', 0, 1)"):format(long)))
  end)

  it('works with a multibyte character in the prefix', function()
    mkdir('Xscan/é' .. long)
    write_file('Xscan/é' .. long .. '/f.vim', '')
    eq({ 'é' .. long .. '/f.vim' }, eval(("glob('é%s/*', 0, 1)"):format(long)))
    eq({ 'é' .. long .. '/f.vim' }, eval(("glob('é*/f.vim', 0, 1)"):format(long)))
  end)

  it('works with globpath()', function()
    eq({ long .. '/one.vim' }, eval(("globpath('%s', '*.vim', 0, 1)"):format(long)))
    eq({ long .. '/two.lua' }, eval(("globpath('%s,nonexistent', 'two.*', 0, 1)"):format(long)))
  end)
end)
