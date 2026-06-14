local lualine_require = require("lualine_require")
local component = lualine_require.require("lualine.component")
local highlight = lualine_require.require("lualine.highlight")

local M = component:extend()

local default_options = {
  icons = {
    terminal = "",
    activity = "●",
  },
  colors = {
    visible = "#98c379",
    hidden = "#61afef",
    activity = "#e5c07b",
  },
  on_click = function()
    require("floaterm").toggle()
  end,
}

function M:init(options)
  M.super.init(self, options)

  self.options = vim.tbl_deep_extend("force", default_options, self.options or {})

  self.colors = {
    visible = highlight.create_component_highlight_group(
      { fg = self.options.colors.visible },
      "floaterm_visible",
      self.options
    ),
    hidden = highlight.create_component_highlight_group(
      { fg = self.options.colors.hidden },
      "floaterm_hidden",
      self.options
    ),
    activity = highlight.create_component_highlight_group(
      { fg = self.options.colors.activity },
      "floaterm_activity",
      self.options
    ),
  }
end

function M:update_status()
  local floaterm = require("floaterm")

  if not floaterm.is_active() then return "" end

  local icon = self.options.icons.terminal

  if floaterm.has_unseen_activity() then
    return highlight.component_format_highlight(self.colors.activity) .. icon .. " " .. self.options.icons.activity
  end

  if floaterm.is_visible() then return highlight.component_format_highlight(self.colors.visible) .. icon end

  return highlight.component_format_highlight(self.colors.hidden) .. icon
end

return M
