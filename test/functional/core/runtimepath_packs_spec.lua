local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, eq, mkdir_p, write_file = n.clear, t.eq, n.mkdir_p, t.write_file
local api, command, eval, exec_lua = n.api, n.command, n.eval, n.exec_lua

--- Paths of the search path items below "root", in order, as "name" or "name (after)".
local function packs(root)
  local items = {}
  api.nvim_get_runtime_file('Xno-such-file', false) -- validates the cached search path
  for _, item in ipairs(api.nvim__runtime_inspect()) do
    if vim.startswith(item.path, root) then
      local name = item.path:sub(#root + 2)
      table.insert(items, item.after and (name .. ' (after)') or name)
    end
  end
  return items
end

describe('start packages in the cached runtime search path', function()
  local root

  before_each(function()
    clear()
    root = vim.fs.normalize(vim.uv.cwd()) .. '/Xpackroot'
    mkdir_p(root)
  end)

  after_each(function()
    n.rmdir('Xpackroot')
  end)

  local function setup_packages(...)
    for _, dir in ipairs({ ... }) do
      mkdir_p(root .. '/' .. dir)
    end
    command(('set packpath=%s,%s/missing'):format(root, root))
    command(('set rtp=%s/rtp'):format(root))
  end

  it('lists start packages and their "after" directories in order', function()
    setup_packages(
      'rtp',
      'pack/p/start/a/after',
      'pack/p/start/b',
      'pack/q/start/c/after',
      'start/d',
      'start/e/after'
    )
    eq({
      'rtp',
      'pack/p/start/a',
      'pack/p/start/b',
      'pack/q/start/c',
      'start/d',
      'start/e',
      'pack/p/start/a/after (after)',
      'pack/q/start/c/after (after)',
      'start/e/after (after)',
    }, packs(root))
  end)

  it('has no "after" directories without start packages', function()
    setup_packages('rtp', 'pack/p/opt/a/after', 'pack/p/start')
    eq({ 'rtp' }, packs(root))
  end)

  it('ignores a package directory that is a file, or hidden', function()
    setup_packages('rtp', 'pack/p/start/.hidden/after', 'pack/p/start/real')
    write_file(root .. '/pack/p/start/file', '')
    eq({ 'rtp', 'pack/p/start/real' }, packs(root))
  end)

  it('keeps an "after" directory of a package with a wildcard in its packpath entry', function()
    mkdir_p(root .. '/rtp')
    mkdir_p(root .. '/wild1/pack/p/start/a/after')
    mkdir_p(root .. '/wild2/start/b')
    command(('set packpath=%s/wild*'):format(root))
    command(('set rtp=%s/rtp'):format(root))
    eq({
      'rtp',
      'wild1/pack/p/start/a',
      'wild2/start/b',
      'wild1/pack/p/start/a/after (after)',
    }, packs(root))
  end)

  it('notices packages and "after" directories created after the first lookup', function()
    setup_packages('rtp', 'pack/p/start/a')
    eq({ 'rtp', 'pack/p/start/a' }, packs(root))
    mkdir_p(root .. '/pack/p/start/a/after')
    mkdir_p(root .. '/pack/p/start/b')
    -- The cached search path is rebuilt when 'runtimepath' or 'packpath' is set.
    command(('set packpath=%s'):format(root))
    eq({ 'rtp', 'pack/p/start/a', 'pack/p/start/b', 'pack/p/start/a/after (after)' }, packs(root))
  end)

  it('finds files in start packages and their "after" directories', function()
    setup_packages('rtp', 'pack/p/start/a/after/plugin', 'pack/p/start/a/plugin')
    write_file(root .. '/pack/p/start/a/plugin/x.lua', 'vim.g.order = (vim.g.order or "") .. "a"')
    write_file(
      root .. '/pack/p/start/a/after/plugin/x.lua',
      'vim.g.order = (vim.g.order or "") .. "z"'
    )
    exec_lua('vim.cmd("runtime! plugin/x.lua")')
    eq('az', eval('g:order'))
  end)
end)
