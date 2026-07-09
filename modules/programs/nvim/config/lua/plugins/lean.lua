-- Lean tuning over LazyVim defaults. Navigation (flash/telescope/neo-tree),
-- mouse (mouse=a + popup menu) and bufferline tabs are already on by default,
-- so this only shaves weight the defaults leave on.
return {
  {
    "folke/snacks.nvim",
    opts = {
      scroll = { enabled = false }, -- drop smooth-scroll animation: snappier, less CPU on fast paging
    },
  },
}
