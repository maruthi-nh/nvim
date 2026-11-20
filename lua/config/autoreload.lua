-- Pick up edits made outside Neovim (e.g. by Claude Code in another terminal):
-- reload changed buffers, which also refreshes gitsigns, and refresh an open Diffview.
vim.opt.autoread = true

local group = vim.api.nvim_create_augroup("ConfigAutoreload", { clear = true })
local uv = vim.uv

local function refresh()
  if vim.fn.getcmdwintype() ~= "" or vim.api.nvim_get_mode().mode:sub(1, 1) == "c" then
    return
  end
  vim.cmd("silent! checktime")
  local ok, lib = pcall(require, "diffview.lib")
  if ok and lib.get_current_view() then
    vim.cmd("DiffviewRefresh")
  end
end

-- `autoread` alone only acts on focus/buffer events, which never fire while
-- Neovim sits idle in another window, so also watch the working tree.
local watcher, debounce
local function watch(dir)
  if watcher then
    watcher:stop()
    watcher:close()
  end
  debounce = debounce or uv.new_timer()
  watcher = uv.new_fs_event()
  -- `recursive` is honoured on macOS (FSEvents) and Windows; on Linux only the top directory is watched.
  watcher:start(dir, { recursive = true }, function(err)
    if err then
      return
    end
    debounce:stop()
    debounce:start(300, 0, vim.schedule_wrap(refresh))
  end)
end

watch(uv.cwd())

vim.api.nvim_create_autocmd("DirChanged", {
  group = group,
  callback = function()
    watch(uv.cwd())
  end,
})

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermLeave" }, {
  group = group,
  callback = refresh,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = group,
  callback = function(event)
    vim.notify("Reloaded " .. vim.fn.fnamemodify(event.file, ":~:."), vim.log.levels.INFO)
  end,
})
