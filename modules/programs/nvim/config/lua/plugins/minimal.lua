return {
  -- chrome: off
  { "akinsho/bufferline.nvim", enabled = false },
  { "nvim-lualine/lualine.nvim", enabled = false },
  { "folke/noice.nvim", enabled = false },

  -- snacks: no dashboard / indent guides / scope / word highlight / toasts
  { "folke/snacks.nvim", opts = {
    indent = { enabled = false },
    scope = { enabled = false },
    words = { enabled = false },
    notifier = { enabled = false },
    dashboard = { enabled = false },
  } },

  -- explorer: file tree only (no search bar), closes when a file is opened
  { "folke/snacks.nvim", opts = {
    picker = {
      sources = {
        explorer = {
          jump = { close = true },
          layout = {
            preset = "sidebar",
            layout = {
              backdrop = false,
              width = 40,
              min_width = 40,
              height = 0,
              position = "left",
              border = "none",
              box = "vertical",
              { win = "list", border = "none" },
            },
          },
        },
      },
    },
  } },
}