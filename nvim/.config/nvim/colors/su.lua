-- 素 (Su) · Neovim colorscheme
-- 中国风浅色开发主题

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end

vim.o.background = "light"
vim.g.colors_name = "su"

-- 规范调色板
local colors = {
  -- 中性色
  bg = "#f3eee1", -- 宣纸
  bg_soft = "#e9e1cf",
  bg_code = "#eee6d5",
  bg_hl = "#e3dac3", -- 当前行
  sel = "#d6cbae", -- 选区
  border = "#ddd4bf",
  fg = "#38342c", -- 墨
  fg_dim = "#5f584c",
  comment = "#5f584c", -- 墨痕（注释；AA 对比，仍弱于正文）
  comment_dim = "#5f584c",

  -- 强调色（传统色）
  qinghua = "#295f8a", -- 青花（keyword）
  tianqing = "#236b5c", -- 天青（type）
  zhuqing = "#3f6428", -- 竹青（string）
  xiang = "#6a5d12", -- 缃色（function）
  zheshi = "#8f3c22", -- 赭石（number）
  zhusha = "#8c1234", -- 朱砂（error）
  daizi = "#5a4685", -- 黛紫（builtin）
  yanzhi = "#84394f", -- 胭脂（field）
}

local function hi(group, opts)
  local cmd = "hi " .. group
  if opts.fg then
    cmd = cmd .. " guifg=" .. opts.fg
  end
  if opts.bg then
    cmd = cmd .. " guibg=" .. opts.bg
  end
  if opts.style then
    cmd = cmd .. " gui=" .. opts.style
  end
  if opts.sp then
    cmd = cmd .. " guisp=" .. opts.sp
  end
  vim.cmd(cmd)
end

-- UI 元素
hi("Normal", { fg = colors.fg, bg = colors.bg })
hi("NormalFloat", { fg = colors.fg, bg = colors.bg_soft })
hi("FloatBorder", { fg = colors.border, bg = colors.bg_soft })
hi("Pmenu", { fg = colors.fg, bg = colors.bg_soft })
hi("PmenuSel", { fg = colors.fg, bg = colors.bg_hl })
hi("PmenuSbar", { bg = colors.bg_hl })
hi("PmenuThumb", { bg = colors.fg_dim })
hi("CursorLine", { bg = colors.bg_hl })
hi("CursorLineNr", { fg = colors.fg, bg = colors.bg_hl })
hi("LineNr", { fg = colors.fg_dim })
hi("SignColumn", { fg = colors.fg_dim, bg = colors.bg })
hi("StatusLine", { fg = colors.fg, bg = colors.bg_soft })
hi("StatusLineNC", { fg = colors.fg_dim, bg = colors.bg_soft })
hi("TabLine", { fg = colors.fg_dim, bg = colors.bg_soft })
hi("TabLineFill", { bg = colors.bg_soft })
hi("TabLineSel", { fg = colors.fg, bg = colors.bg })
hi("Visual", { bg = colors.sel })
hi("VisualNOS", { bg = colors.sel })
hi("Search", { fg = colors.fg, bg = colors.sel })
hi("IncSearch", { fg = colors.bg, bg = colors.xiang })
hi("MatchParen", { fg = colors.xiang, style = "bold" })
hi("Folded", { fg = colors.comment, bg = colors.bg_soft })
hi("FoldColumn", { fg = colors.fg_dim, bg = colors.bg })
hi("VertSplit", { fg = colors.border })
hi("WinSeparator", { fg = colors.border })

-- 语法高亮（按语义分配）
hi("Comment", { fg = colors.comment, style = "italic" })
hi("Constant", { fg = colors.zheshi }) -- 数字、常量
hi("String", { fg = colors.zhuqing }) -- 竹青（内容）
hi("Character", { fg = colors.zhuqing })
hi("Number", { fg = colors.zheshi })
hi("Boolean", { fg = colors.zheshi })
hi("Float", { fg = colors.zheshi })
hi("Identifier", { fg = colors.fg })
hi("Function", { fg = colors.xiang }) -- 缃色（调用）
hi("Statement", { fg = colors.qinghua }) -- 青花（关键字）
hi("Conditional", { fg = colors.qinghua })
hi("Repeat", { fg = colors.qinghua })
hi("Label", { fg = colors.qinghua })
hi("Operator", { fg = colors.fg_dim })
hi("Keyword", { fg = colors.qinghua })
hi("Exception", { fg = colors.zhusha })
hi("PreProc", { fg = colors.daizi }) -- 黛紫（特殊）
hi("Include", { fg = colors.qinghua })
hi("Define", { fg = colors.daizi })
hi("Macro", { fg = colors.daizi })
hi("PreCondit", { fg = colors.daizi })
hi("Type", { fg = colors.tianqing }) -- 天青（类型）
hi("StorageClass", { fg = colors.qinghua })
hi("Structure", { fg = colors.tianqing })
hi("Typedef", { fg = colors.tianqing })
hi("Special", { fg = colors.daizi })
hi("SpecialChar", { fg = colors.daizi })
hi("Tag", { fg = colors.tianqing })
hi("Delimiter", { fg = colors.fg_dim })
hi("SpecialComment", { fg = colors.comment })
hi("Debug", { fg = colors.zhusha })
hi("Error", { fg = colors.zhusha, style = "bold" })
hi("ErrorMsg", { fg = colors.zhusha, style = "bold" })
hi("WarningMsg", { fg = colors.xiang })
hi("Todo", { fg = colors.daizi, style = "bold" })

-- Treesitter
hi("@variable", { fg = colors.fg })
hi("@variable.builtin", { fg = colors.daizi })
hi("@variable.parameter", { fg = colors.fg })
hi("@variable.member", { fg = colors.yanzhi }) -- 胭脂（字段）
hi("@property", { fg = colors.yanzhi })
hi("@constant", { fg = colors.zheshi })
hi("@constant.builtin", { fg = colors.daizi })
hi("@module", { fg = colors.tianqing })
hi("@label", { fg = colors.qinghua })
hi("@string", { fg = colors.zhuqing })
hi("@string.escape", { fg = colors.daizi })
hi("@string.regexp", { fg = colors.daizi })
hi("@character", { fg = colors.zhuqing })
hi("@number", { fg = colors.zheshi })
hi("@boolean", { fg = colors.zheshi })
hi("@float", { fg = colors.zheshi })
hi("@function", { fg = colors.xiang })
hi("@function.builtin", { fg = colors.daizi })
hi("@function.macro", { fg = colors.daizi })
hi("@function.method", { fg = colors.xiang })
hi("@constructor", { fg = colors.tianqing })
hi("@keyword", { fg = colors.qinghua })
hi("@keyword.function", { fg = colors.qinghua })
hi("@keyword.operator", { fg = colors.qinghua })
hi("@keyword.return", { fg = colors.qinghua })
hi("@operator", { fg = colors.fg_dim })
hi("@punctuation.delimiter", { fg = colors.fg_dim })
hi("@punctuation.bracket", { fg = colors.fg_dim })
hi("@type", { fg = colors.tianqing })
hi("@type.builtin", { fg = colors.daizi })
hi("@type.qualifier", { fg = colors.qinghua })
hi("@tag", { fg = colors.tianqing })
hi("@tag.attribute", { fg = colors.yanzhi })
hi("@tag.delimiter", { fg = colors.fg_dim })
hi("@comment", { fg = colors.comment, style = "italic" })
hi("@comment.documentation", { fg = colors.comment, style = "italic" })

-- Markdown / rendered code blocks
hi("markdownCode", { fg = colors.fg, bg = colors.bg_code })
hi("markdownCodeBlock", { fg = colors.fg, bg = colors.bg_code })
hi("markdownCodeDelimiter", { fg = colors.comment, bg = colors.bg_code })
hi("@markup.raw", { fg = colors.fg, bg = colors.bg_code })
hi("@markup.raw.block", { fg = colors.fg, bg = colors.bg_code })
hi("@markup.raw.delimiter", { fg = colors.comment, bg = colors.bg_code })
hi("@markup.link", { fg = colors.qinghua })
hi("@markup.heading", { fg = colors.qinghua, style = "bold" })
hi("RenderMarkdownCode", { fg = colors.fg, bg = colors.bg_code })
hi("RenderMarkdownCodeInline", { fg = colors.fg, bg = colors.bg_code })
hi("RenderMarkdownCodeBorder", { fg = colors.border, bg = colors.bg_code })
hi("RenderMarkdownCodeFallback", { fg = colors.fg, bg = colors.bg_code })
hi("RenderMarkdownCodeInfo", { fg = colors.comment, bg = colors.bg_code })

-- LSP 语义
hi("@lsp.type.class", { fg = colors.tianqing })
hi("@lsp.type.decorator", { fg = colors.daizi })
hi("@lsp.type.enum", { fg = colors.tianqing })
hi("@lsp.type.enumMember", { fg = colors.zheshi })
hi("@lsp.type.function", { fg = colors.xiang })
hi("@lsp.type.interface", { fg = colors.tianqing })
hi("@lsp.type.macro", { fg = colors.daizi })
hi("@lsp.type.method", { fg = colors.xiang })
hi("@lsp.type.namespace", { fg = colors.tianqing })
hi("@lsp.type.parameter", { fg = colors.fg })
hi("@lsp.type.property", { fg = colors.yanzhi })
hi("@lsp.type.struct", { fg = colors.tianqing })
hi("@lsp.type.type", { fg = colors.tianqing })
hi("@lsp.type.typeParameter", { fg = colors.tianqing })
hi("@lsp.type.variable", { fg = colors.fg })

-- 诊断
hi("DiagnosticError", { fg = colors.zhusha })
hi("DiagnosticWarn", { fg = colors.xiang })
hi("DiagnosticInfo", { fg = colors.tianqing })
hi("DiagnosticHint", { fg = colors.fg_dim })
hi("DiagnosticUnderlineError", { sp = colors.zhusha, style = "undercurl" })
hi("DiagnosticUnderlineWarn", { sp = colors.xiang, style = "undercurl" })
hi("DiagnosticUnderlineInfo", { sp = colors.tianqing, style = "undercurl" })
hi("DiagnosticUnderlineHint", { sp = colors.fg_dim, style = "undercurl" })

-- Git signs
hi("DiffAdd", { fg = colors.zhuqing, bg = colors.bg_soft })
hi("DiffChange", { fg = colors.xiang, bg = colors.bg_soft })
hi("DiffDelete", { fg = colors.zhusha, bg = colors.bg_soft })
hi("DiffText", { fg = colors.tianqing, bg = colors.bg_hl })

-- 插件支持
hi("TelescopeBorder", { fg = colors.border, bg = colors.bg_soft })
hi("TelescopeNormal", { fg = colors.fg, bg = colors.bg_soft })
hi("TelescopeSelection", { fg = colors.fg, bg = colors.bg_hl })
hi("NeoTreeNormal", { fg = colors.fg, bg = colors.bg })
hi("NeoTreeNormalNC", { fg = colors.fg, bg = colors.bg })
hi("NvimTreeNormal", { fg = colors.fg, bg = colors.bg })
