local M = {}

local defaults = {
  title = nil,
  title_pos = "center",
  relative = "editor",
  width = 0.6,
  height = 0.6,
  border = "rounded",
  style = "minimal",
  shell = nil,
}

local config = vim.deepcopy(defaults)

local state = {
  buf = nil,
  win = nil,
  job_id = nil,
  prev_win = nil,
  attach_id = nil,
  activity = false,
  shown_once = false,
}

local function refresh_lualine()
  vim.schedule(function()
    local ok, lualine = pcall(require, "lualine")
    if ok then lualine.refresh { place = { "statusline" } } end
  end)
end

local function reset_state()
  if state.attach_id and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_detach, state.buf, state.attach_id)
  end

  state.buf = nil
  state.win = nil
  state.job_id = nil
  state.prev_win = nil
  state.attach_id = nil
  state.activity = false
  state.shown_once = false
end

local function is_win_visible()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function is_buf_alive()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

local function calc_float_opts()
  local width = math.floor(vim.o.columns * config.width)
  local height = math.floor(vim.o.lines * config.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return {
    title = config.title and config.title or nil,
    title_pos = config.title and config.title_pos or nil,
    relative = config.relative,
    width = width,
    height = height,
    row = row,
    col = col,
    style = config.style,
    border = config.border,
  }
end

local function hide_float()
  if not is_win_visible() then return end

  local win = state.win
  state.win = nil
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end

  if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then vim.api.nvim_set_current_win(state.prev_win) end

  refresh_lualine()
end

local function on_terminal_exit()
  hide_float()
  reset_state()
end

local function enter_terminal_normal_mode()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
end

local function setup_buffer_keymaps(buf)
  vim.keymap.set("t", "<Esc>", function()
    enter_terminal_normal_mode()
  end, { buffer = buf, desc = "Exit terminal mode", silent = true })

  vim.keymap.set("n", "<Esc>", function()
    hide_float()
  end, { buffer = buf, desc = "Hide floaterm", silent = true, nowait = true })
end

local function setup_activity_tracking(buf)
  if state.attach_id then return end

  state.attach_id = vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if state.shown_once and not is_win_visible() and not state.activity then
        state.activity = true
        refresh_lualine()
      end
    end,
  })
end

local function create_terminal()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "floaterm"

  local shell = config.shell or vim.o.shell
  local job_id = vim.api.nvim_buf_call(buf, function()
    return vim.fn.jobstart({ shell }, {
      term = true,
      on_exit = function()
        vim.schedule(on_terminal_exit)
      end,
    })
  end)

  setup_buffer_keymaps(buf)
  setup_activity_tracking(buf)

  state.buf = buf
  state.job_id = job_id
end

local function open_float()
  if not is_buf_alive() then create_terminal() end

  setup_buffer_keymaps(state.buf)
  setup_activity_tracking(state.buf)
  state.activity = false

  state.prev_win = vim.api.nvim_get_current_win()
  state.win = vim.api.nvim_open_win(state.buf, true, calc_float_opts())

  local win_id = state.win
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win_id),
    once = true,
    callback = function()
      if state.win == win_id then state.win = nil end
    end,
  })

  state.shown_once = true
  vim.cmd.startinsert()
  refresh_lualine()
end

---Configure floaterm.nvim.
---@param opts table|nil
function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

---Toggle the floating terminal.
---Hides when visible, or opens/reopens in insert mode.
function M.toggle()
  if is_win_visible() then
    hide_float()
    return
  end

  open_float()
end

---@return boolean
function M.is_active()
  if not is_buf_alive() or not state.job_id or state.job_id <= 0 then return false end

  return vim.fn.jobwait({ state.job_id }, 0)[1] == -1
end

---@return boolean
function M.is_visible()
  return is_win_visible()
end

---@return boolean
function M.has_unseen_activity()
  return M.is_active() and not is_win_visible() and state.activity
end

return M
