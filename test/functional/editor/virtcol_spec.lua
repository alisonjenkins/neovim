local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, command, eq, fn, api = n.clear, n.command, t.eq, n.fn, n.api

--- Printable ASCII without blanks.
--- @param len integer
local function ascii(len)
  local chars = {} --- @type string[]
  for i = 1, len do
    chars[i] = string.char(0x21 + i % 94)
  end
  return table.concat(chars)
end

describe('virtual columns', function()
  before_each(clear)

  -- Runs of printable ASCII are skipped when they are 4 bytes or longer, in words of 8 bytes, after
  -- 16 bytes in chunks of 64, 128, ... bytes.
  local runs =
    { 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 79, 80, 81, 207, 208, 209, 4095, 4096, 4097, 8200 }
  local after = {
    'TAB',
    'control character',
    'DEL',
    'invalid byte',
    'wide character',
    'emoji',
    'combining character',
    'variation selector',
    'nothing',
  }
  local text_of = {
    ['TAB'] = '\t',
    ['control character'] = '\1',
    ['DEL'] = '\127',
    ['invalid byte'] = '\255',
    ['wide character'] = '中',
    ['emoji'] = '😀',
    ['combining character'] = '\204\129',
    ['variation selector'] = '\239\184\143',
    ['nothing'] = '',
  }

  for _, opts in ipairs({ 'nolist', 'list', 'nolist tabstop=3', 'nolist nowrap' }) do
    it(('counts cells after a run of ASCII with %s'):format(opts), function()
      command('set ' .. opts)
      local got, want = {}, {}
      for _, name in ipairs(after) do
        for _, len in ipairs(runs) do
          -- The run is measured in bulk but for its last character, which is measured with what
          -- follows it. So measure those alone, starting at the same column, for comparison.
          local run = ascii(len)
          local line = run .. text_of[name] .. 'abc'
          local tail_width = fn.strdisplaywidth(run:sub(-1) .. text_of[name] .. 'abc', len - 1)
          local key = ('%d ASCII, %s'):format(len, name)
          want[key] = { len - 1 + tail_width, len + tail_width, len + tail_width - 3 }

          api.nvim_buf_set_lines(0, 0, -1, true, { line })
          fn.cursor(1, #line + 1)
          local virtcol_end = fn.virtcol('$')
          fn.cursor(1, #line - 2) -- on "a"
          got[key] = { fn.strdisplaywidth(line), virtcol_end, fn.virtcol('.') }
        end
      end
      eq(want, got)
    end)
  end

  it('counts a TAB, a control character and a wide character after ASCII', function()
    command('set tabstop=8')
    api.nvim_buf_set_lines(0, 0, -1, true, { ascii(20) .. '\t\1中x' })
    -- 20 cells, TAB to column 24, "^A", "中" and "x"
    eq(20 + 4 + 2 + 2 + 1, fn.strdisplaywidth(fn.getline(1)))
    eq(20 + 4 + 2 + 2 + 2, fn.virtcol('$'))
  end)

  it('scrolls horizontally across a run of ASCII', function()
    local screen = Screen.new(10, 2)
    command('set nowrap nonumber sidescroll=0')
    local width = 10
    -- Suffix text and the cells it takes on the screen.
    local suffixes = {
      { '', {} },
      { '\1', { '^', 'A' } },
      { '\255', { '<', 'f', 'f', '>' } },
      { '\204\129', {} }, -- joins the last character of the run
      { '\t', {} }, -- fills up to the next multiple of 8
    }
    local got, want = {}, {}
    for _, len in ipairs({ 9, 16, 17, 30 }) do
      for _, suffix in ipairs(suffixes) do
        local run = ascii(len)
        local cells = {} --- @type string[]
        for i = 1, len do
          cells[i] = run:sub(i, i)
        end
        vim.list_extend(cells, suffix[2])
        if suffix[1] == '\204\129' then
          cells[len] = cells[len] .. suffix[1]
        elseif suffix[1] == '\t' then
          vim.list_extend(cells, vim.split((' '):rep(8 - len % 8), ''))
        end
        vim.list_extend(cells, { 'E', 'N', 'D' })
        api.nvim_buf_set_lines(0, 0, -1, true, { run .. suffix[1] .. 'END' })
        for _, leftcol in ipairs({ 0, 7, 8, 9, len - 2, len - 1, len, len + 1 }) do
          command('normal! 0')
          if leftcol > 0 then
            command(('normal! %dzl'):format(leftcol))
          end
          command('redraw')
          local key = ('%d ASCII, %q, leftcol %d'):format(len, suffix[1], leftcol)
          local row, expected = {}, {}
          for col = 1, width do
            row[col] = fn.screenstring(1, col)
            expected[col] = cells[leftcol + col] or ' '
          end
          local actual_leftcol = fn.winsaveview().leftcol
          if actual_leftcol ~= leftcol or table.concat(row) ~= table.concat(expected) then
            got[key] = actual_leftcol .. table.concat(row)
            want[key] = leftcol .. table.concat(expected)
          end
        end
      end
    end
    eq(want, got)
    screen:detach()
  end)

  it('measures a long line of ASCII in bulk', function()
    t.skip(t.is_asan(), 'N/A: sanitizers slow down the bulk scan')
    local ratio = n.exec_lua(function()
      local bytes = 16 * 1024 * 1024
      local function best_ms(text)
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { text })
        local best = math.huge
        for _ = 1, 5 do
          local start = vim.uv.hrtime()
          vim.fn.virtcol('$')
          best = math.min(best, (vim.uv.hrtime() - start) / 1e6)
        end
        return best
      end
      -- Compare with a line of the same size where every ASCII run is a single character.
      return best_ms(('a\127'):rep(bytes / 2)) / best_ms(('a'):rep(bytes))
    end)
    t.ok(ratio > 10, 'more than 10x as fast as single characters', ('%.1fx'):format(ratio))
  end)
end)
