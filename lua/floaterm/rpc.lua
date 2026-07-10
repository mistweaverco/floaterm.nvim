local M = {}

local edit_handler = nil

---@param addr string
---@param startserver boolean
---@return string | integer | nil
function M.try_address(addr, startserver)
  if not addr:find("/") then addr = ("%s/%s"):format(vim.fn.stdpath("run"), addr) end
  if vim.uv.fs_stat(addr) then
    local ok, sock = M.connect(addr)
    if ok then return sock end
  elseif startserver then
    local ok = pcall(vim.fn.serverstart, addr)
    if ok then return addr end
  end
end

---@return string
function M.ensure_server()
  local addr = vim.v.servername
  if addr and addr ~= "" then return addr end

  local name = ("floaterm-%d"):format(vim.fn.getpid())
  if not name:find("/") then name = ("%s/%s"):format(vim.fn.stdpath("run"), name) end

  if not vim.uv.fs_stat(name) then pcall(vim.fn.serverstart, name) end
  return name
end

---@param fn fun(filepath: string, client_pipe?: string): integer
function M.set_edit_handler(fn)
  edit_handler = fn
end

---@param filepath string
---@param client_pipe? string
---@return integer
function M.host_edit_and_wait(filepath, client_pipe)
  if not edit_handler then
    require("floaterm")
  end
  if not edit_handler then error("floaterm: edit handler not registered") end

  vim.schedule(function()
    edit_handler(filepath, client_pipe)
  end)

  return 0
end

---@param chan integer
---@param fn fun(...:any): ...:any # must not depend on upvalues
---@param args any[]
---@param blocking boolean
---@return any ...
function M.exec_on_host(chan, fn, args, blocking)
  local req = vim.fn.rpcnotify
  if blocking then req = vim.fn.rpcrequest end

  local code = vim.base64.encode(string.dump(fn, true))

  local res = req(
    chan,
    "nvim_exec_lua",
    string.format(
      [[
      return loadstring(vim.base64.decode('%s'))(...)
    ]],
      code
    ),
    args
  )

  if blocking then return res end
end

---@param pipe_addr string
---@return boolean, integer
function M.connect(pipe_addr)
  if not pipe_addr:find("/") then pipe_addr = ("%s/%s"):format(vim.fn.stdpath("run"), pipe_addr) end
  return pcall(vim.fn.sockconnect, "pipe", pipe_addr, { rpc = true })
end

return M
