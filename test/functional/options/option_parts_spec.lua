local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, eq, mkdir, write_file = n.clear, t.eq, t.mkdir, t.write_file
local api = n.api

describe('comma-separated option parts', function()
  local dirs = { 'Xrtp_plain', 'Xrtp,comma', 'Xrtp space', 'Xrtp_\195\169\226\130\172' }

  before_each(function()
    clear()
    for _, dir in ipairs(dirs) do
      mkdir(dir)
      write_file(dir .. '/marker.txt', dir)
    end
  end)

  after_each(function()
    for _, dir in ipairs(dirs) do
      n.rmdir(dir)
    end
  end)

  local function marker_dirs()
    local found = {}
    for _, file in ipairs(api.nvim_get_runtime_file('marker.txt', true)) do
      table.insert(found, vim.fs.basename(vim.fs.dirname(file)))
    end
    return found
  end

  it("splits 'runtimepath' on commas, in order", function()
    api.nvim_set_option_value('runtimepath', 'Xrtp_plain,Xrtp space', {})
    eq({ 'Xrtp_plain', 'Xrtp space' }, marker_dirs())
    api.nvim_set_option_value('runtimepath', 'Xrtp space,Xrtp_plain', {})
    eq({ 'Xrtp space', 'Xrtp_plain' }, marker_dirs())
  end)

  it('keeps a backslash-escaped comma inside a part', function()
    api.nvim_set_option_value('runtimepath', [[Xrtp\,comma,Xrtp_plain]], {})
    eq({ 'Xrtp,comma', 'Xrtp_plain' }, marker_dirs())
  end)

  it('handles multibyte parts', function()
    api.nvim_set_option_value('runtimepath', 'Xrtp_\195\169\226\130\172,Xrtp_plain', {})
    eq({ 'Xrtp_\195\169\226\130\172', 'Xrtp_plain' }, marker_dirs())
  end)

  it('ignores empty parts and surrounding separators', function()
    api.nvim_set_option_value('runtimepath', ',Xrtp_plain,,Xrtp space,', {})
    eq({ 'Xrtp_plain', 'Xrtp space' }, marker_dirs())
  end)
end)
