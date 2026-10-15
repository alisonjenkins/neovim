local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, command, eq, fn = n.clear, n.command, t.eq, n.fn
local write_file = t.write_file

local function mkdir_p(dir)
  return n.mkdir_p(("'%s'"):format(dir))
end

-- The expected lists were produced by Nvim before 'runtimepath' and glob() expansion was optimised:
-- they pin the set of results and their order, which the optimisations must not change.

local function mkfile(path)
  mkdir_p('Xorder/' .. vim.fs.dirname(path))
  write_file('Xorder/' .. path, '')
end

local function setup_tree()
  for _, name in ipairs({
    'a',
    'A',
    'b',
    'a.txt',
    'A.txt',
    'a.TXT',
    'b.txt',
    'a.bak',
    'a.vim',
    'x.tar.gz',
    'x.gz',
    '.hidden',
    'a b',
    'a-b',
    'a_b',
    'a.b',
    'ab',
    'a1',
    'a10',
    'a2',
    'é',
    'e',
    'è.txt',
    'e.txt',
    '中.txt',
  }) do
    mkfile('top/' .. name)
  end
  for _, name in ipairs({
    'foo',
    'foo-bar',
    'foo.bar',
    'foo_bar',
    'foo bar',
    'foobar',
    'Foo',
    'FOO',
  }) do
    mkfile('ord/' .. name .. '/inner')
    mkfile('ord/' .. name .. '.d/inner')
  end
  mkfile('pre/in')
  mkfile('pre.fix/in')
  mkfile('pre-fix/in')
  mkfile('prefix/in')
  mkfile('Pre/in')
  for _, rt in ipairs({ 'rt1', 'rt2', 'rt3' }) do
    mkfile(rt .. '/plugin/a.vim')
    mkfile(rt .. '/plugin/b.vim')
    mkfile(rt .. '/plugin/c.lua')
    mkfile(rt .. '/plugin/d.txt')
    mkfile(rt .. '/plugin/sub/e.vim')
    mkfile(rt .. '/ftplugin/lua.vim')
    mkfile(rt .. '/ftplugin/lua_extra.vim')
    mkfile(rt .. '/ftplugin/lua/more.vim')
  end
  mkfile(('d'):rep(150) .. '/x/one.vim')
  mkfile(('d'):rep(150) .. '/x/two.vim')
  mkfile(('d'):rep(150) .. '/y/three.lua')
end

--- Each case is { kind, pattern[, nosuf] } or { 'globpath', path, pattern }, then the expected list.
local function check(cases)
  for _, case in ipairs(cases) do
    local call, expected = case[1], case[2]
    local kind = call[1]
    local actual
    if kind == 'glob' then
      actual = fn.glob(call[2], call[3] or 0, 1)
    else
      actual = fn.globpath(call[2], call[3], 0, 1)
    end
    eq(expected, actual, ('%s(%s)'):format(kind, table.concat(vim.list_slice(call, 2), ', ')))
  end
end

describe('glob() and globpath() results and their order', function()
  if t.skip(t.is_os('win') or t.is_os('mac'), 'needs a case-sensitive file system') then
    return
  end

  before_each(function()
    clear()
    mkdir_p('Xorder')
    command('silent cd Xorder')
    setup_tree()
  end)

  after_each(function()
    n.rmdir('Xorder')
  end)

  it('sorts names bytewise, a path separator first', function()
    check({
      {
        { 'glob', 'top/a*' },
        {
          'top/a',
          'top/a b',
          'top/a-b',
          'top/a.TXT',
          'top/a.b',
          'top/a.txt',
          'top/a.vim',
          'top/a1',
          'top/a10',
          'top/a2',
          'top/a_b',
          'top/ab',
          'top/a.bak',
        },
      },
      { { 'glob', 'top/.*' }, { 'top/.', 'top/..', 'top/.hidden' } },
      { { 'glob', 'top/?' }, { 'top/A', 'top/a', 'top/b', 'top/e', 'top/é' } },
      { { 'glob', 'top/a?' }, { 'top/a1', 'top/a2', 'top/ab' } },
      {
        { 'glob', 'top/*.txt' },
        { 'top/A.txt', 'top/a.txt', 'top/b.txt', 'top/e.txt', 'top/è.txt', 'top/中.txt' },
      },
      { { 'glob', 'top/a?b' }, { 'top/a b', 'top/a-b', 'top/a.b', 'top/a_b' } },
      { { 'glob', 'top/[eé]*' }, { 'top/e', 'top/e.txt', 'top/é' } },
      {
        { 'glob', 'ord/foo*' },
        {
          'ord/foo',
          'ord/foo bar',
          'ord/foo bar.d',
          'ord/foo-bar',
          'ord/foo-bar.d',
          'ord/foo.bar',
          'ord/foo.bar.d',
          'ord/foo.d',
          'ord/foo_bar',
          'ord/foo_bar.d',
          'ord/foobar',
          'ord/foobar.d',
        },
      },
      {
        { 'glob', 'ord/foo*/' },
        {
          'ord/foo/',
          'ord/foo bar/',
          'ord/foo bar.d/',
          'ord/foo-bar/',
          'ord/foo-bar.d/',
          'ord/foo.bar/',
          'ord/foo.bar.d/',
          'ord/foo.d/',
          'ord/foo_bar/',
          'ord/foo_bar.d/',
          'ord/foobar/',
          'ord/foobar.d/',
        },
      },
      {
        { 'glob', 'ord/*.d/*' },
        {
          'ord/FOO.d/inner',
          'ord/Foo.d/inner',
          'ord/foo bar.d/inner',
          'ord/foo-bar.d/inner',
          'ord/foo.bar.d/inner',
          'ord/foo.d/inner',
          'ord/foo_bar.d/inner',
          'ord/foobar.d/inner',
        },
      },
      { { 'glob', 'ord/F*' }, { 'ord/FOO', 'ord/FOO.d', 'ord/Foo', 'ord/Foo.d' } },
      { { 'glob', 'pre*' }, { 'pre', 'pre-fix', 'pre.fix', 'prefix' } },
      { { 'glob', 'pre*/in' }, { 'pre/in', 'pre-fix/in', 'pre.fix/in', 'prefix/in' } },
      { { 'glob', '*/in' }, { 'Pre/in', 'pre/in', 'pre-fix/in', 'pre.fix/in', 'prefix/in' } },
      { { 'glob', 'pre?fix/in' }, { 'pre-fix/in', 'pre.fix/in' } },
    })
  end)

  it("honours 'fileignorecase'", function()
    command('set fileignorecase')
    check({
      {
        { 'glob', 'top/a*' },
        {
          'top/A',
          'top/a',
          'top/a b',
          'top/a-b',
          'top/a.b',
          'top/A.txt',
          'top/a.TXT',
          'top/a.txt',
          'top/a.vim',
          'top/a1',
          'top/a10',
          'top/a2',
          'top/a_b',
          'top/ab',
          'top/a.bak',
        },
      },
      {
        { 'glob', 'top/A*' },
        {
          'top/A',
          'top/a',
          'top/a b',
          'top/a-b',
          'top/a.b',
          'top/A.txt',
          'top/a.TXT',
          'top/a.txt',
          'top/a.vim',
          'top/a1',
          'top/a10',
          'top/a2',
          'top/a_b',
          'top/ab',
          'top/a.bak',
        },
      },
      {
        { 'glob', 'top/*.txt' },
        {
          'top/A.txt',
          'top/a.TXT',
          'top/a.txt',
          'top/b.txt',
          'top/e.txt',
          'top/è.txt',
          'top/中.txt',
        },
      },
      {
        { 'glob', 'ord/*.d' },
        {
          'ord/foo bar.d',
          'ord/foo-bar.d',
          'ord/foo.bar.d',
          'ord/FOO.d',
          'ord/Foo.d',
          'ord/foo.d',
          'ord/foo_bar.d',
          'ord/foobar.d',
        },
      },
      {
        { 'glob', 'ord/F*' },
        {
          'ord/FOO',
          'ord/Foo',
          'ord/foo',
          'ord/foo bar',
          'ord/foo bar.d',
          'ord/foo-bar',
          'ord/foo-bar.d',
          'ord/foo.bar',
          'ord/foo.bar.d',
          'ord/FOO.d',
          'ord/Foo.d',
          'ord/foo.d',
          'ord/foo_bar',
          'ord/foo_bar.d',
          'ord/foobar',
          'ord/foobar.d',
        },
      },
      { { 'glob', '*/in' }, { 'Pre/in', 'pre/in', 'pre-fix/in', 'pre.fix/in', 'prefix/in' } },
      { { 'glob', 'top/A.TXT' }, {} },
    })
  end)

  it("honours 'wildignorecase'", function()
    command('set wildignorecase')
    check({
      {
        { 'glob', 'top/A*' },
        {
          'top/A',
          'top/A.txt',
          'top/a',
          'top/a b',
          'top/a-b',
          'top/a.TXT',
          'top/a.b',
          'top/a.txt',
          'top/a.vim',
          'top/a1',
          'top/a10',
          'top/a2',
          'top/a_b',
          'top/ab',
          'top/a.bak',
        },
      },
      {
        { 'glob', 'top/*.TXT' },
        {
          'top/A.txt',
          'top/a.TXT',
          'top/a.txt',
          'top/b.txt',
          'top/e.txt',
          'top/è.txt',
          'top/中.txt',
        },
      },
      { { 'glob', 'TOP/*.vim' }, { 'top/a.vim' } },
      { { 'glob', 'top/E*' }, { 'top/e', 'top/e.txt' } },
      { { 'glob', 'Pre*/in' }, { 'Pre/in', 'pre/in', 'pre-fix/in', 'pre.fix/in', 'prefix/in' } },
    })
  end)

  it("removes what 'wildignore' matches", function()
    command('set wildignore=*.bak,*.gz,.hidden*')
    check({
      { { 'glob', 'top/a.*' }, { 'top/a.TXT', 'top/a.b', 'top/a.txt', 'top/a.vim' } },
      { { 'glob', 'top/.*' }, { 'top/.', 'top/..' } },
      { { 'glob', 'top/x*' }, {} },
      { { 'glob', 'top/a.bak' }, {} },
    })
  end)

  it("puts the 'suffixes' matches last unless {nosuf} is given", function()
    command('set suffixes=.bak,.txt,.gz')
    check({
      { { 'glob', 'top/a.*' }, { 'top/a.TXT', 'top/a.b', 'top/a.vim', 'top/a.bak', 'top/a.txt' } },
      {
        { 'glob', 'top/a.*', 1 },
        { 'top/a.TXT', 'top/a.b', 'top/a.bak', 'top/a.txt', 'top/a.vim' },
      },
      { { 'glob', 'top/[xb]*' }, { 'top/b', 'top/b.txt', 'top/x.gz', 'top/x.tar.gz' } },
      { { 'glob', 'top/[xb]*', 1 }, { 'top/b', 'top/b.txt', 'top/x.gz', 'top/x.tar.gz' } },
    })
  end)

  it('globpath() lists the directories in order', function()
    check({
      {
        { 'globpath', 'rt1,rt2,rt3', 'plugin/*.vim' },
        {
          'rt1/plugin/a.vim',
          'rt1/plugin/b.vim',
          'rt2/plugin/a.vim',
          'rt2/plugin/b.vim',
          'rt3/plugin/a.vim',
          'rt3/plugin/b.vim',
        },
      },
      {
        { 'globpath', 'rt3,rt1,rt2', 'plugin/[ab].vim' },
        {
          'rt3/plugin/a.vim',
          'rt3/plugin/b.vim',
          'rt1/plugin/a.vim',
          'rt1/plugin/b.vim',
          'rt2/plugin/a.vim',
          'rt2/plugin/b.vim',
        },
      },
      {
        { 'globpath', 'rt1,rt2,rt3', 'plugin/**/*.vim' },
        {
          'rt1/plugin/a.vim',
          'rt1/plugin/b.vim',
          'rt1/plugin/sub/e.vim',
          'rt2/plugin/a.vim',
          'rt2/plugin/b.vim',
          'rt2/plugin/sub/e.vim',
          'rt3/plugin/a.vim',
          'rt3/plugin/b.vim',
          'rt3/plugin/sub/e.vim',
        },
      },
      {
        { 'globpath', 'rt1,rt2,rt3', 'ftplugin/lua*.vim' },
        {
          'rt1/ftplugin/lua.vim',
          'rt1/ftplugin/lua_extra.vim',
          'rt2/ftplugin/lua.vim',
          'rt2/ftplugin/lua_extra.vim',
          'rt3/ftplugin/lua.vim',
          'rt3/ftplugin/lua_extra.vim',
        },
      },
      {
        { 'globpath', 'rt1,nonexistent,rt3', 'plugin/c.lua' },
        { 'rt1/plugin/c.lua', 'rt3/plugin/c.lua' },
      },
      {
        { 'globpath', 'rt?', 'plugin/*.lua' },
        { 'rt1/plugin/c.lua', 'rt2/plugin/c.lua', 'rt3/plugin/c.lua' },
      },
    })
  end)

  it('handles a long directory prefix', function()
    check({
      {
        {
          'glob',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/*/*',
        },
        {
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/x/one.vim',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/x/two.vim',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/y/three.lua',
        },
      },
      {
        {
          'glob',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/x/*.vim',
        },
        {
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/x/one.vim',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/x/two.vim',
        },
      },
      {
        {
          'glob',
          'ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd*/x/one.v?m',
        },
        {
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/x/one.vim',
        },
      },
      {
        {
          'globpath',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,rt1',
          'x/*.vim',
        },
        {
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/x/one.vim',
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd/x/two.vim',
        },
      },
    })
  end)
end)
