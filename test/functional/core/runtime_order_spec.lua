local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, eq, write_file = n.clear, t.eq, t.write_file
local api, command, eval = n.api, n.command, n.eval

-- The order in which Nvim searches 'runtimepath' and 'packpath': the entries in order, the start
-- packages of a 'packpath' entry after the entry (or before the "after" entries when it is not in
-- 'runtimepath'), "after" directories last.
describe("'runtimepath' and 'packpath' search order", function()
  local root

  local function mkdir_p(dir)
    n.mkdir_p(("'%s'"):format(dir))
  end

  --- Files and directories under Xrt, relative to it.
  local function make(...)
    for _, path in ipairs({ ... }) do
      if path:sub(-1) == '/' then
        mkdir_p(root .. '/' .. path:sub(1, -2))
      else
        mkdir_p(vim.fs.dirname(root .. '/' .. path))
        write_file(root .. '/' .. path, ('call add(g:ran, %q)'):format(path))
      end
    end
  end

  --- Entries of the runtime search path below `root`, with the root removed.
  local function rtp()
    local paths = {}
    for _, path in ipairs(api.nvim_list_runtime_paths()) do
      if vim.startswith(path, root) then
        table.insert(paths, path:sub(#root + 2))
      end
    end
    return paths
  end

  local function ran()
    return eval('g:ran')
  end

  before_each(function()
    clear()
    root = vim.fs.normalize(vim.uv.cwd()) .. '/Xrt'
    make(
      'a/plugin/p.vim',
      'a/plugin/q.vim',
      'b,c/plugin/p.vim',
      'd e/plugin/p.vim',
      'd e/after/plugin/p.vim',
      'x/after/plugin/p.vim',
      'pk1/pack/n/start/s1/plugin/p.vim',
      'pk1/pack/n/start/s1/after/plugin/p.vim',
      'pk1/pack/n/start/s2/plugin/p.vim',
      'pk1/pack/m/start/s3/plugin/p.vim',
      'pk1/pack/n/opt/o1/plugin/p.vim',
      'pk1/start/s4/plugin/p.vim',
      'pk2/pack/n/start/s5/plugin/p.vim',
      'pk2/pack/n/start/s5/after/plugin/p.vim'
    )
    command('let g:ran = []')
  end)

  after_each(function()
    n.rmdir('Xrt')
  end)

  local function set(rtp_value, pp_value)
    command(('let &rtp = %s'):format(vim.inspect(rtp_value)))
    command(('let &pp = %s'):format(vim.inspect(pp_value)))
  end

  it('searches the entries in order, "after" directories last', function()
    set(('%s/a,%s/b\\,c,%s/d e,%s/d e/after,%s/x/after'):format(root, root, root, root, root), '')
    eq({ 'a', 'b,c', 'd e', 'd e/after', 'x/after' }, rtp())
    command('runtime! plugin/p.vim')
    eq({
      'a/plugin/p.vim',
      'b,c/plugin/p.vim',
      'd e/plugin/p.vim',
      'd e/after/plugin/p.vim',
      'x/after/plugin/p.vim',
    }, ran())
  end)

  it(':runtime without a bang stops at the first match', function()
    set(('%s/b\\,c,%s/a'):format(root, root), '')
    command('runtime plugin/p.vim')
    eq({ 'b,c/plugin/p.vim' }, ran())
  end)

  it('sorts the matches of a wildcard within an entry', function()
    set(('%s/a,%s/b\\,c'):format(root, root), '')
    command('runtime! plugin/*.vim')
    eq({ 'a/plugin/p.vim', 'a/plugin/q.vim', 'b,c/plugin/p.vim' }, ran())
  end)

  it('puts the start packages after the entry of their packpath directory', function()
    set(('%s/a,%s/pk1,%s/d e'):format(root, root, root), ('%s/pk1,%s/pk2'):format(root, root))
    eq({
      'a',
      'pk1',
      'pk1/pack/m/start/s3',
      'pk1/pack/n/start/s1',
      'pk1/pack/n/start/s2',
      'pk1/start/s4',
      'd e',
      'pk2/pack/n/start/s5',
      'pk1/pack/n/start/s1/after',
      'pk2/pack/n/start/s5/after',
    }, rtp())
  end)

  it('puts the packages of a directory not in runtimepath before the "after" entries', function()
    set(('%s/a,%s/x/after'):format(root, root), ('%s/pk2,%s/pk1'):format(root, root))
    eq({
      'a',
      'pk2/pack/n/start/s5',
      'pk1/pack/m/start/s3',
      'pk1/pack/n/start/s1',
      'pk1/pack/n/start/s2',
      'pk1/start/s4',
      'pk2/pack/n/start/s5/after',
      'pk1/pack/n/start/s1/after',
      'x/after',
    }, rtp())
    command('runtime! plugin/p.vim')
    eq({
      'a/plugin/p.vim',
      'pk2/pack/n/start/s5/plugin/p.vim',
      'pk1/pack/m/start/s3/plugin/p.vim',
      'pk1/pack/n/start/s1/plugin/p.vim',
      'pk1/pack/n/start/s2/plugin/p.vim',
      'pk1/start/s4/plugin/p.vim',
      'pk2/pack/n/start/s5/after/plugin/p.vim',
      'pk1/pack/n/start/s1/after/plugin/p.vim',
      'x/after/plugin/p.vim',
    }, ran())
  end)

  it('adds an optional package after the start packages with :packadd', function()
    set(('%s/a,%s/pk1,%s/d e'):format(root, root, root), ('%s/pk1'):format(root))
    command('packadd o1')
    eq({
      'a',
      'pk1',
      'pk1/pack/m/start/s3',
      'pk1/pack/n/start/s1',
      'pk1/pack/n/start/s2',
      'pk1/start/s4',
      'pk1/pack/n/opt/o1',
      'd e',
      'pk1/pack/n/start/s1/after',
    }, rtp())
    eq({ 'pk1/pack/n/opt/o1/plugin/p.vim' }, ran())
  end)

  it('finds runtime files in the same order', function()
    set(('%s/a,%s/pk1,%s/d e'):format(root, root, root), ('%s/pk1'):format(root))
    local found = {}
    for _, path in ipairs(api.nvim_get_runtime_file('plugin/p.vim', true)) do
      table.insert(found, path:sub(#root + 2))
    end
    eq({
      'a/plugin/p.vim',
      'pk1/pack/m/start/s3/plugin/p.vim',
      'pk1/pack/n/start/s1/plugin/p.vim',
      'pk1/pack/n/start/s2/plugin/p.vim',
      'pk1/start/s4/plugin/p.vim',
      'd e/plugin/p.vim',
      'pk1/pack/n/start/s1/after/plugin/p.vim',
    }, found)
  end)
end)
