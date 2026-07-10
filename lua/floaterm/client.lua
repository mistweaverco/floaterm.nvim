local M = {}

local SERVER_ENV = "NVIM_FLOATERM_SERVER"

---@param server string
---@return boolean
local function is_host_server(server)
  if vim.v.servername ~= "" and vim.v.servername == server then return true end
  return server:find("floaterm-" .. vim.fn.getpid(), 1, true) ~= nil
end

---@return string?
function M.first_file_arg()
  local args = vim.fn.argv()
  local skip = false

  for i = 1, #args do
    local value = args[i]
    if skip then
      skip = false
    elseif value == "-c" or value == "--cmd" or value == "-S" or value == "-s" then
      skip = true
    elseif value:sub(1, 1) ~= "-" then
      return vim.fn.fnamemodify(value, ":p")
    end
  end
end

---Intercept nested nvim and forward file edits to the host floaterm session.
---@return boolean handled
function M.maybe_forward()
  local server = os.getenv(SERVER_ENV)
  if not server or server == "" then return false end

  if is_host_server(server) then return false end

  local rpc = require("floaterm.rpc")
  local ok, chan = rpc.connect(server)
  if not ok then return false end

  local filepath = M.first_file_arg()
  if not filepath then
    vim.fn.chanclose(chan)
    return false
  end

  vim.o.shadafile = "NONE"

  _G.floaterm_done = function()
    vim.cmd("quit")
  end

  local response_pipe = vim.fn.serverstart()
  vim.fn.rpcrequest(
    chan,
    "nvim_exec_lua",
    "return require('floaterm.rpc').host_edit_and_wait(...)",
    { filepath, response_pipe }
  )
  vim.fn.chanclose(chan)

  while true do
    vim.cmd("sleep 1")
  end
end

return M
