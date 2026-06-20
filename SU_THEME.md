# 素 (Su) · 中国风浅色开发主题

**宣纸底、水墨字、传统色**

本主题已全面应用到所有配置文件。重启各工具后生效。

## 设计理念

**高级感 = 删**：只用 8 个传统强调色，饱和度压到 30–45%，删掉极端对比。

**中国风 = 色有出处**：每个颜色都对应一种传统色，带着典故和克制。

## 核心色彩

| 角色     | 传统色 | HEX       | 说明                     |
|----------|--------|-----------|--------------------------|
| 背景     | 宣纸   | `#f3eee1` | 暖米白，不刺眼           |
| 前景     | 墨     | `#38342c` | 墨色，不死黑             |
| 注释     | 墨痕   | `#5f584c` | 斜体，融进纸里           |
| keyword  | 青花   | `#295f8a` | 青花瓷蓝，结构骨架       |
| type     | 天青   | `#236b5c` | 汝窑天青，最高级的含蓄   |
| string   | 竹青   | `#3f6428` | 竹皮之绿，内容/数据      |
| function | 缃色   | `#6a5d12` | 浅黄绢，书卷暖意，调用点 |
| number   | 赭石   | `#8f3c22` | 国画矿物，常量           |
| error    | 朱砂   | `#8c1234` | 印泥红，**只给错误用**   |
| builtin  | 黛紫   | `#5a4685` | 画眉之黛，特殊/内建      |
| field    | 胭脂   | `#84394f` | 柔暖，对象字段           |

## 已应用的配置

### 终端
- **Ghostty**: `ghostty/.config/ghostty/config.ghostty`
  - 16 色 ANSI 调色板
  - 宣纸背景、墨色前景、朱砂光标
  - 重启 Ghostty 或 `Cmd+Shift+,` 重载配置
- **Windows Terminal**: `templates/windows-terminal-profile.example.jsonc`
  - 16 色 ANSI 调色板基于 Ghostty，并针对浅色背景可读性加深
  - 宣纸背景、墨色前景、朱砂光标
  - 将示例中的 `profiles.defaults` 与 `schemes` 合并到 Windows Terminal 设置

### Shell & 命令行工具
- **Starship** 提示符: `starship/.config/starship.toml`
  - `palette = "su"` 及完整色板定义
- **lsd** (ls 增强): `lsd/.config/lsd/colors.yaml`
  - 文件权限、大小、日期都用传统色映射
- **Git Delta** (diff 工具): `git/.gitconfig`
  - 添加/删除行用竹青/朱砂标记
  - 宣纸底差异背景

### 多路复用器
- **tmux**: `tmux/.tmux/.tmux.conf`
  - 状态栏：青花蓝当前窗口，宣纸/墨色文字，缃色边框
  - 活动 pane 用缃色粗边框突出
  - `C-q r` 重载配置或重启 tmux

### 编辑器
- **Neovim** (LazyVim): 
  - 主题文件：`nvim/.config/nvim/colors/su.lua`
  - 启用：`nvim/.config/nvim/lua/plugins/colorscheme.lua`
  - 支持 Treesitter、LSP 语义高亮、诊断
  - `:Lazy sync` 同步插件

- **Doom Emacs**:
  - 主题文件：`doom/.config/doom/themes/su-theme.el`
  - 启用：`doom/.config/doom/config.el` (`doom-theme 'su`)
  - 完整支持 org-mode、magit、treemacs、lsp
  - `doom sync --force --rebuild` 同步并重启 daemon

## 应用步骤

```bash
# 1. 拉取最新配置
cd ~/dotfiles && git pull

# 2. 应用 stow 链接
./sync.sh

# 3. 重载各工具
# Ghostty: Cmd+Shift+,
# tmux: C-q r 或 tmux source ~/.tmux.conf
# Neovim: nvim --headless "+Lazy! sync" +qa
# Doom: doom sync --force --rebuild && doom restart
```

## 设计规则（扩展用）

如遇到未列出的工具，按以下原则推导：

1. **背景/前景**：宣纸 `#f3eee1` / 墨 `#38342c`
2. **强调色分配**：
   - 结构/骨架 → 青花、天青（冷色后退）
   - 内容/数据 → 竹青（绿）
   - 行为/调用 → 缃色（暖黄）
   - 特殊/内建 → 黛紫
   - 错误专用 → 朱砂（最跳）
3. **饱和度**：30–45%，压住不跳
4. **注释**：墨痕 + 斜体，几乎融进背景

---

**题眼**：天青（汝窑）点出气质上限，朱砂（印泥）点出纪律——红只给错误用。
