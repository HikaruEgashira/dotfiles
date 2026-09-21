local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = true, notify = false },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})

-- LazyVim's own options run during setup, so these must come after it.
-- native statusline shows only the mode (lualine is disabled)
_G.__modmode = function()
  local labels = { n = "NORMAL", i = "INSERT", v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK", s = "SELECT", R = "REPLACE", c = "COMMAND", t = "TERMINAL", ["!"] = "SHELL" }
  return labels[vim.fn.mode(1)] or vim.fn.mode(1):upper()
end
vim.opt.laststatus = 3 -- single global statusline
vim.opt.statusline = "%{v:lua.__modmode()}"

vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.signcolumn = "no" -- hide git/diagnostic signs
vim.opt.guicursor = "a:ver25" -- fixed thin cursor in every mode

-- macOS-style shortcuts: Ghostty sends cmd+z/c/v as raw ctrl bytes
vim.keymap.set({ "n" }, "<C-z>", "u", { desc = "Undo" })
vim.keymap.set({ "i" }, "<C-z>", "<C-o>u", { desc = "Undo" })
vim.keymap.set({ "x" }, "<C-z>", "<Esc>u", { desc = "Undo" })
vim.keymap.set({ "x" }, "<C-c>", "y", { desc = "Copy selection" })
vim.keymap.set({ "n" }, "<C-v>", '"+p', { desc = "Paste" })
vim.keymap.set({ "i" }, "<C-v>", "<C-r>+", { desc = "Paste" })
vim.keymap.set({ "x" }, "<C-v>", '"+p', { desc = "Paste" }) -- block visual stays on <C-q>

-- system clipboard: LazyVim resets it on VeryLazy, so restore after that
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    vim.g.clipboard = {
      name = "macOS clipboard",
      copy = { ["+"] = "pbcopy", ["*"] = "pbcopy" },
      paste = { ["+"] = "pbpaste", ["*"] = "pbpaste" },
      cache_enabled = true,
    }
    vim.opt.clipboard = "unnamedplus"
  end,
})
