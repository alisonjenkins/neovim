local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local clear, command, eval, eq = n.clear, n.command, n.eval, t.eq
local mkdir, write_file = t.mkdir, t.write_file
local is_os = t.is_os

describe('glob() and completion of files, directories and links', function()
  before_each(function()
    clear()
    mkdir('Xtypes')
    command('silent cd Xtypes')
    mkdir('Xtypes/Dir')
    mkdir('Xtypes/Dir/Sub')
    write_file('Xtypes/File', '')
    write_file('Xtypes/Dir/Sub/Inner', '')
    if not is_os('win') then
      local cwd = eval('getcwd()')
      assert(vim.uv.fs_symlink(cwd .. '/Dir', cwd .. '/LinkDir'))
      assert(vim.uv.fs_symlink(cwd .. '/File', cwd .. '/LinkFile'))
      assert(vim.uv.fs_symlink(cwd .. '/Gone', cwd .. '/LinkGone'))
      assert(vim.uv.fs_symlink(cwd .. '/Gone', cwd .. '/Dir/LinkGone'))
      assert(vim.uv.fs_symlink(cwd .. '/File', cwd .. '/Dir/LinkFile'))
    end
  end)

  after_each(function()
    n.rmdir('Xtypes')
  end)

  it('glob() of a literal name returns what exists', function()
    eq({ 'File' }, eval([[glob('File', 0, 1)]]))
    eq({ 'Dir' }, eval([[glob('Dir', 0, 1)]]))
    eq({}, eval([[glob('Missing', 0, 1)]]))
  end)

  it('glob() of a wildcard returns what exists', function()
    eq({ 'Dir', 'File' }, eval([[glob('[DF]*', 0, 1)]]))
    eq({ 'Dir/Sub/Inner' }, eval([[glob('Dir/*/Inner', 0, 1)]]))
    eq({}, eval([[glob('Dir/*/Missing', 0, 1)]]))
  end)

  it('glob() follows links to existing files and directories', function()
    if is_os('win') then
      pending('symbolic links')
    end
    eq({ 'LinkDir', 'LinkFile' }, eval([[glob('Link[DF]*', 0, 1)]]))
    eq({ 'LinkDir' }, eval([[glob('LinkDir', 0, 1)]]))
    eq({ 'LinkFile' }, eval([[glob('LinkFile', 0, 1)]]))
    eq({ 'LinkDir/Sub/Inner' }, eval([[glob('LinkDir/*/Inner', 0, 1)]]))
    eq({ 'Dir/LinkFile' }, eval([[glob('Dir/Link*', 0, 1)]]))
  end)

  it('glob() does not return a link to a missing file', function()
    if is_os('win') then
      pending('symbolic links')
    end
    eq({}, eval([[glob('LinkGone', 0, 1)]]))
    eq({}, eval([[glob('LinkG*', 0, 1)]]))
    eq({}, eval([[glob('Dir/LinkG*', 0, 1)]]))
  end)

  it('glob() with {alllinks} also returns links to missing files', function()
    if is_os('win') then
      pending('symbolic links')
    end
    eq({ 'LinkDir', 'LinkFile', 'LinkGone' }, eval([[glob('Link*', 0, 1, 1)]]))
    eq({ 'LinkGone' }, eval([[glob('LinkGone', 0, 1, 1)]]))
    eq({ 'LinkDir', 'LinkFile', 'LinkGone' }, eval([[glob('Link[DFG]*', 0, 1, 1)]]))
    eq({ 'Dir/LinkFile', 'Dir/LinkGone' }, eval([[glob('Dir/Link*', 0, 1, 1)]]))
    eq({ 'Dir/LinkGone', 'LinkDir/LinkGone' }, eval([[glob('*/LinkG*', 0, 1, 1)]]))
    eq({}, eval([[glob('Missing', 0, 1, 1)]]))
  end)

  it('completion of directories only lists directories, with a slash', function()
    eq({ 'Dir/' }, eval([[getcompletion('Dir', 'dir')]]))
    eq({}, eval([[getcompletion('File', 'dir')]]))
    eq({ 'File' }, eval([[getcompletion('File', 'file')]]))
    eq({ 'Dir/Sub/' }, eval([[getcompletion('Dir/S', 'dir')]]))
  end)

  it('a pattern that matches nothing is kept when editing, but not by glob()', function()
    command('edit Missing')
    eq('Missing', eval([[bufname('%')]]))
    command('edit Missing*')
    eq('Missing*', eval([[bufname('%')]]))
    command('edit Dir/*/Missing')
    eq('Dir/*/Missing', eval([[bufname('%')]]))
    eq({}, eval([[glob('Dir/*/Missing', 0, 1)]]))
  end)
end)
