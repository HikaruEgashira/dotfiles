-- Cap open file buffers so navigation stays lean: on entering a buffer, if more
-- than this many normal file buffers are listed, close the least-recently-used
-- ones. The current buffer and any modified (unsaved) buffer are never closed.
local max_buffers = 3

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("lru_buffer_limit", { clear = true }),
  callback = function()
    local normal = vim.tbl_filter(function(b)
      return vim.bo[b.bufnr].buftype == ""
    end, vim.fn.getbufinfo({ buflisted = 1 }))
    if #normal - max_buffers <= 0 then
      return
    end

    local cur = vim.api.nvim_get_current_buf()
    local closable = vim.tbl_filter(function(b)
      return b.bufnr ~= cur and b.changed == 0
    end, normal)
    table.sort(closable, function(a, b)
      return a.lastused < b.lastused
    end)

    for i = 1, math.min(#normal - max_buffers, #closable) do
      pcall(vim.api.nvim_buf_delete, closable[i].bufnr, {})
    end
  end,
})
