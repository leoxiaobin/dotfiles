vim.cmd("highlight clear")

if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "mai"
vim.o.background = "light"

local c = {
  bg = "#FBF0DC",
  bg_soft = "#FEF9ED",
  bg_panel = "#F7ECD9",
  bg_muted = "#EDE1C7",
  bg_select = "#D8C8A8",
  fg = "#1F1412",
  fg_soft = "#3D332E",
  muted = "#51453E",
  subtle = "#8D7F70",
  accent = "#946A3A",
  red = "#74312B",
  green = "#435B31",
  yellow = "#744D27",
  blue = "#284867",
  purple = "#604159",
  cyan = "#3D625D",
}

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

hi("Normal", { fg = c.fg, bg = c.bg })
hi("NormalNC", { fg = c.fg_soft, bg = c.bg })
hi("NormalFloat", { fg = c.fg, bg = c.bg_panel })
hi("FloatBorder", { fg = c.accent, bg = c.bg_panel })
hi("Pmenu", { fg = c.fg, bg = c.bg_panel })
hi("PmenuSel", { fg = c.bg_soft, bg = c.accent })
hi("Cursor", { fg = c.bg, bg = c.fg })
hi("CursorLine", { bg = c.bg_panel })
hi("CursorLineNr", { fg = c.fg, bg = c.bg_panel, bold = true })
hi("LineNr", { fg = c.subtle, bg = c.bg })
hi("SignColumn", { fg = c.subtle, bg = c.bg })
hi("WinSeparator", { fg = c.bg_select, bg = c.bg })
hi("StatusLine", { fg = c.bg_soft, bg = c.fg, bold = true })
hi("StatusLineNC", { fg = c.muted, bg = c.bg_muted })
hi("TabLine", { fg = c.muted, bg = c.bg_muted })
hi("TabLineFill", { fg = c.muted, bg = c.bg_muted })
hi("TabLineSel", { fg = c.bg_soft, bg = c.fg, bold = true })
hi("Visual", { bg = c.bg_select })
hi("Search", { fg = c.fg, bg = "#E0C082" })
hi("IncSearch", { fg = c.bg_soft, bg = c.accent })
hi("MatchParen", { fg = c.fg, bg = c.bg_select, bold = true })
hi("Comment", { fg = c.subtle, italic = true })
hi("NonText", { fg = c.subtle })
hi("Whitespace", { fg = "#C6B799" })
hi("EndOfBuffer", { fg = c.bg })
hi("Title", { fg = c.fg, bold = true })
hi("Directory", { fg = c.blue, bold = true })
hi("WarningMsg", { fg = c.yellow, bold = true })
hi("ErrorMsg", { fg = c.red, bold = true })
hi("Constant", { fg = c.yellow })
hi("String", { fg = c.green })
hi("Number", { fg = c.accent })
hi("Boolean", { fg = c.accent, bold = true })
hi("Function", { fg = c.blue, bold = true })
hi("Statement", { fg = c.purple, bold = true })
hi("Keyword", { fg = c.purple, bold = true })
hi("Type", { fg = c.cyan, bold = true })
hi("Special", { fg = c.accent })
hi("Delimiter", { fg = c.muted })
hi("Underlined", { fg = c.blue, underline = true })
hi("Todo", { fg = c.fg, bg = "#E0C082", bold = true })
hi("DiagnosticError", { fg = c.red })
hi("DiagnosticWarn", { fg = c.yellow })
hi("DiagnosticInfo", { fg = c.blue })
hi("DiagnosticHint", { fg = c.cyan })
hi("DiagnosticUnderlineError", { sp = c.red, undercurl = true })
hi("DiagnosticUnderlineWarn", { sp = c.yellow, undercurl = true })
hi("DiagnosticUnderlineInfo", { sp = c.blue, undercurl = true })
hi("DiagnosticUnderlineHint", { sp = c.cyan, undercurl = true })
hi("DiffAdd", { fg = c.green, bg = "#E5E8C8" })
hi("DiffChange", { fg = c.yellow, bg = c.bg_muted })
hi("DiffDelete", { fg = c.red, bg = "#E8CFC7" })
hi("DiffText", { fg = c.fg, bg = "#E0C082", bold = true })
hi("GitSignsAdd", { fg = c.green, bg = c.bg })
hi("GitSignsChange", { fg = c.yellow, bg = c.bg })
hi("GitSignsDelete", { fg = c.red, bg = c.bg })
hi("TelescopeNormal", { fg = c.fg, bg = c.bg_panel })
hi("TelescopeBorder", { fg = c.accent, bg = c.bg_panel })
hi("TelescopeSelection", { fg = c.fg, bg = c.bg_select })
hi("TelescopeMatching", { fg = c.accent, bold = true })
hi("WhichKey", { fg = c.accent, bold = true })
hi("WhichKeyDesc", { fg = c.fg })
hi("WhichKeyGroup", { fg = c.blue })
hi("LazyNormal", { fg = c.fg, bg = c.bg_panel })
hi("CmpItemAbbrMatch", { fg = c.accent, bold = true })
hi("@variable", { fg = c.fg })
hi("@constant", { fg = c.yellow })
hi("@string", { fg = c.green })
hi("@number", { fg = c.accent })
hi("@boolean", { fg = c.accent, bold = true })
hi("@type", { fg = c.cyan, bold = true })
hi("@property", { fg = c.blue })
hi("@function", { fg = c.blue, bold = true })
hi("@keyword", { fg = c.purple, bold = true })
hi("@operator", { fg = c.fg_soft })
hi("@punctuation.delimiter", { fg = c.muted })
hi("@punctuation.bracket", { fg = c.muted })
hi("@comment", { fg = c.subtle, italic = true })
hi("@markup.heading", { fg = c.fg, bold = true })
hi("@markup.link", { fg = c.blue, underline = true })
