if vim.fn.has("nvim") ~= 1 then return end

local ok, client = pcall(require, "floaterm.client")
if ok then client.maybe_forward() end
