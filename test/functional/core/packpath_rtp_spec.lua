local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, eq, mkdir_p, write_file = n.clear, t.eq, n.mkdir_p, t.write_file
local api, eval = n.api, n.eval
local is_os = t.is_os

describe("start packages are added to 'runtimepath' at startup", function()
  local root

  before_each(function()
    root = vim.fs.normalize(vim.uv.cwd()) .. '/Xrtproot'
    mkdir_p(root)
  end)

  after_each(function()
    n.rmdir('Xrtproot')
  end)

  --- Starts Nvim with the given 'runtimepath' and 'packpath', which are relative to "root".
  local function start(rtp, pp)
    local function abs(list)
      return table.concat(
        vim.tbl_map(function(entry)
          return root .. '/' .. entry
        end, list),
        ','
      )
    end
    clear({
      args = { '-u', 'NORC', '--cmd', 'set rtp^=' .. abs(rtp), '--cmd', 'set pp=' .. abs(pp) },
      args_rm = { '-u' },
    })
  end

  --- The entries of 'runtimepath' below "root", relative to it.
  local function rtp()
    local entries = {}
    for entry in vim.gsplit(eval('&rtp'), ',', { plain = true }) do
      if vim.startswith(entry, root .. '/') then
        table.insert(entries, entry:sub(#root + 2))
      end
    end
    return entries
  end

  it('puts packages after the entry of their packpath directory', function()
    for _, dir in ipairs({ 'rtp1', 'rtp2', 'pp1/pack/p/start/a', 'pp3/start/c/after' }) do
      mkdir_p(root .. '/' .. dir)
    end
    start({ 'rtp1', 'pp1', 'rtp2', 'pp3' }, { 'pp1', 'pp3' })
    eq({
      'rtp1',
      'pp3/start/*',
      'pp1',
      'pp1/pack/*/start/*',
      'rtp2',
      'pp3',
      'pp3/start/*/after',
    }, rtp())
  end)

  it('puts packages of a directory not in the runtimepath before the "after" entries', function()
    for _, dir in ipairs({ 'rtp1', 'after', 'pp1/pack/p/start/a', 'pp2/start/b' }) do
      mkdir_p(root .. '/' .. dir)
    end
    start({ 'rtp1', 'after' }, { 'pp1', 'pp2' })
    eq({ 'rtp1', 'pp2/start/*', 'pp1/pack/*/start/*', 'after' }, rtp())
  end)

  it('finds the runtimepath entry of a packpath directory through a symbolic link', function()
    if is_os('win') then
      pending('symbolic links')
    end
    for _, dir in ipairs({ 'rtp1', 'rtp2', 'real/pack/p/start/a' }) do
      mkdir_p(root .. '/' .. dir)
    end
    assert(vim.uv.fs_symlink(root .. '/real', root .. '/link'))
    start({ 'rtp1', 'real', 'rtp2' }, { 'link' })
    eq({ 'rtp1', 'real', 'link/pack/*/start/*', 'rtp2' }, rtp())
  end)

  it('works with many packpath directories, some in the runtimepath', function()
    local rtp_entries, pp_entries = {}, {}
    for i = 1, 12 do
      local pp = 'pp' .. i
      mkdir_p(('%s/%s/pack/p/start/plug%d/after'):format(root, pp, i))
      table.insert(pp_entries, pp)
      if i % 3 == 0 then
        table.insert(rtp_entries, pp)
      end
    end
    mkdir_p(root .. '/after')
    table.insert(rtp_entries, 'after')
    start(rtp_entries, pp_entries)

    local expected = {}
    -- After the entry of their directory, if it is in the runtimepath ...
    for _, i in ipairs({ 3, 6, 9, 12 }) do
      table.insert(expected, 'pp' .. i)
      table.insert(expected, 'pp' .. i .. '/pack/*/start/*')
    end
    -- ... else before the first "after" entry.
    for _, i in ipairs({ 1, 2, 4, 5, 7, 8, 10, 11 }) do
      table.insert(expected, 'pp' .. i .. '/pack/*/start/*')
    end
    -- The "after" directories of the packages, the last package first.
    for i = 12, 1, -1 do
      table.insert(expected, 'pp' .. i .. '/pack/*/start/*/after')
    end
    table.insert(expected, 'after')
    eq(expected, rtp())
  end)

  it('loads the plugins of all packages', function()
    for i = 1, 5 do
      mkdir_p(('%s/pp%d/pack/p/start/plug%d/plugin'):format(root, i, i))
      write_file(
        ('%s/pp%d/pack/p/start/plug%d/plugin/x.lua'):format(root, i, i),
        ('vim.g.loaded_%d = true'):format(i)
      )
    end
    start({ 'pp1', 'pp3' }, { 'pp1', 'pp2', 'pp3', 'pp4', 'pp5' })
    for i = 1, 5 do
      eq(true, api.nvim_get_var('loaded_' .. i))
    end
  end)
end)
