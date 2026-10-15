local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, command, eval, eq = n.clear, n.command, n.eval, t.eq
local mkdir, write_file = t.mkdir, t.write_file
local is_os = t.is_os

describe('glob() of a pattern below a directory', function()
  before_each(function()
    clear()
    mkdir('Xglobdir')
    command('silent cd Xglobdir')
    mkdir('Xglobdir/Real')
    mkdir('Xglobdir/Real/sub')
    write_file('Xglobdir/Real/sub/a.txt', '')
    write_file('Xglobdir/file', '')
  end)

  after_each(function()
    n.rmdir('Xglobdir')
  end)

  it('finds nothing if the directory does not exist', function()
    eq({}, eval([[glob('Nodir/*', 0, 1)]]))
    eq({}, eval([[glob('Nodir/sub/*', 0, 1)]]))
    eq({}, eval([[glob('Real/Nodir/*', 0, 1)]]))
    eq({}, eval([[glob('Real/*/Nodir/*', 0, 1)]]))
    eq({}, eval([[glob(getcwd() . '/Nodir/*/sub/*', 0, 1)]]))
    eq({}, eval([[glob('/Xnonexistent_root/pack/*/start/*', 0, 1)]]))
  end)

  it('still reports an invalid collection below a missing directory', function()
    t.matches('E944', t.pcall_err(n.eval, [[glob('/Xnonexistent_root/[z-a]*', 0, 1)]]))
    t.matches('E944', t.pcall_err(n.eval, [[glob('Nodir/*[z-a]', 0, 1)]]))
    t.matches('E944', t.pcall_err(n.eval, [[glob('Real/[z-a]*', 0, 1)]]))
  end)

  it('finds nothing if the directory is a file', function()
    eq({}, eval([[glob('file/*', 0, 1)]]))
    eq({}, eval([[glob(getcwd() . '/file/pack/*/start/*', 0, 1)]]))
  end)

  it('finds a directory that appears after a failed search', function()
    local pattern = [[glob(getcwd() . '/Later/pack/*/start/*', 0, 1)]]
    eq({}, eval(pattern))
    mkdir('Xglobdir/Later')
    mkdir('Xglobdir/Later/pack')
    mkdir('Xglobdir/Later/pack/p')
    mkdir('Xglobdir/Later/pack/p/start')
    mkdir('Xglobdir/Later/pack/p/start/plug')
    eq({ eval('getcwd()') .. '/Later/pack/p/start/plug' }, eval(pattern))
  end)

  it('finds matches below an existing directory', function()
    eq({ 'Real/sub/a.txt' }, eval([[glob('Real/*/*.txt', 0, 1)]]))
    eq({ eval('getcwd()') .. '/Real/sub/a.txt' }, eval([[glob(getcwd() . '/Real/s*/a.txt', 0, 1)]]))
  end)

  it('finds a directory through a symbolic link, but not through a dangling one', function()
    if is_os('win') then
      pending('symbolic links')
    end
    local cwd = eval('getcwd()')
    assert(vim.uv.fs_symlink(cwd .. '/Real', cwd .. '/Link'))
    assert(vim.uv.fs_symlink(cwd .. '/Gone', cwd .. '/Dangling'))
    eq({ cwd .. '/Link/sub/a.txt' }, eval([[glob(getcwd() . '/Link/*/*.txt', 0, 1)]]))
    eq({}, eval([[glob(getcwd() . '/Dangling/*/*.txt', 0, 1)]]))
  end)

  it("respects 'wildignorecase' for the directory", function()
    if is_os('win') or is_os('mac') then
      pending('case sensitive file system')
    end
    eq({}, eval([[glob('real/*/*.txt', 0, 1)]]))
    command('set wildignorecase')
    eq({ 'Real/sub/a.txt' }, eval([[glob('real/*/*.txt', 0, 1)]]))
  end)

  it('expands $VAR and ~ in the directory', function()
    command('let $XGLOBREAL = getcwd() . "/Real"')
    command('let $XGLOBNONE = getcwd() . "/Nodir"')
    eq({ eval('getcwd()') .. '/Real/sub/a.txt' }, eval([[glob('$XGLOBREAL/*/*.txt', 0, 1)]]))
    eq({}, eval([[glob('$XGLOBNONE/*/*.txt', 0, 1)]]))
    command('let $HOME = getcwd() . "/Real"')
    eq({ eval('getcwd()') .. '/Real/sub/a.txt' }, eval([[glob('~/*/*.txt', 0, 1)]]))
  end)

  it('keeps a pattern with no match when editing it', function()
    -- :edit adds names that are not found, so the pattern stays as it is.
    command([[edit Nodir/*.txt]])
    eq('Nodir/*.txt', eval([[bufname('%')]]))
  end)
end)

describe("'runtimepath' and 'packpath' entries that do not exist", function()
  local plug = 'Xpackdir/pack/p/start/plug'

  before_each(function()
    clear()
    mkdir('Xpackdir')
    mkdir('Xpackdir/pack')
    mkdir('Xpackdir/pack/p')
    mkdir('Xpackdir/pack/p/start')
    mkdir(plug)
    mkdir(plug .. '/lua')
    write_file(plug .. '/lua/xplug.lua', 'return 1')
  end)

  after_each(function()
    n.rmdir('Xpackdir')
  end)

  it('are skipped, the others still work', function()
    local cwd = eval('getcwd()')
    command(('set packpath=%s/Xnodir1,%s/Xpackdir,%s/Xnodir2'):format(cwd, cwd, cwd))
    command(('set rtp=%s/Xnodir3'):format(cwd))
    eq(1, eval([[luaeval('require("xplug")')]]))
  end)

  it('are picked up when they appear later', function()
    local cwd = eval('getcwd()')
    command(('set packpath=%s/Xlater'):format(cwd))
    eq({}, eval([[globpath(&packpath, 'pack/*/start/*', 0, 1)]]))
    mkdir('Xlater')
    mkdir('Xlater/pack')
    mkdir('Xlater/pack/p')
    mkdir('Xlater/pack/p/start')
    mkdir('Xlater/pack/p/start/later')
    eq(
      { cwd .. '/Xlater/pack/p/start/later' },
      eval([[globpath(&packpath, 'pack/*/start/*', 0, 1)]])
    )
    n.rmdir('Xlater')
  end)
end)
