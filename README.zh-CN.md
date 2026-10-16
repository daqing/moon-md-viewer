# moon-md-viewer

把 CommonMark 渲染成终端真正能显示的样子。

常见的 Markdown 工具走到 HTML 就停下了，而终端没有渲染 HTML 的引擎——你看到的
要么是裸标签，要么得再开一个浏览器。`moon-md-viewer` 直接遍历 CommonMark 的语法
树并输出 ANSI：标题保留 `##` 标记并着色，列表保留缩进，表格画成方框，链接变成可
点击的 OSC 8 超链接。

下面是在 56 列宽度下渲染的结果：

```
## Installation

Add the dependency and build:

bash
│ moon add daqing/moon-md-viewer

┌─────────┬───────────────────────┐
│ Option  │ Meaning               │
├─────────┼───────────────────────┤
│ --theme │ dark, light or none   │
│ --width │ wrap width in columns │
└─────────┴───────────────────────┘

- Headings keep their markers
- Links become OSC 8 hyperlinks
```

## 运行

需要先安装 MoonBit 工具链：

```bash
moon run cmd/main -- README.mbt.md
moon run cmd/main -- --width 60 docs/design.md
cat notes.md | moon run cmd/main
```

`moon build --release` 会生成独立可执行文件，位于
`_build/native/release/build/cmd/main/main.exe`。

### 选项

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `--theme <dark\|light\|none>` | `dark` | 配色方案；`none` 完全不输出颜色。 |
| `--width <columns>` | `$COLUMNS`，否则 80 | 折行宽度。 |
| `--color <auto\|always\|never>` | `auto` | `auto` 仅在 stdout 是支持颜色的终端时着色。 |
| `--pager <auto\|always\|never>` | `auto` | `auto` 在 stdout 是终端时通过 `$PAGER` 分页。 |

其余参数都是输入文件；`-` 或不传文件则读取标准输入。当 stdout 不是终端、`TERM`
为 `dumb`，或设置了 `NO_COLOR` 时，颜色会被关闭。

### 分页

输出到终端时，会通过 `$PAGER` 分页；未设置 `$PAGER` 时使用 `less`。`$LESS` 默认为
`FRX`——与 git 相同的设置——因此颜色能正确传给分页器，退出后内容仍留在屏幕上，而
内容不足一屏时 `less` 会自动退出。`--pager never` 直接打印，`--pager always` 即使
stdout 是管道也分页；分页器启动失败时则回退为直接打印。

## 作为库使用

```moonbit
let text = @moon-md-viewer.render(markdown, theme=@moon-md-viewer.Dark, width=80)
```

`render` 返回文档内容和结尾换行；如果输入里没有任何可显示的内容，则返回空字符串。
`Theme` 有 `Dark`、`Light`、`NoColor` 三种。另外还导出了 `char_width`、
`display_width` 和 `truncate_visible`，供需要自行度量或截断带样式文本的调用方使用。

## 支持的内容

- 宽度按终端列数计算，中文和 emoji 算两列；因此中文文档的折行、表格列宽和截断都
  能对齐。
- 中文在字符之间断行，收尾标点（`。`、`，`、`」` 等）不会出现在行首。
- 代码块原样输出，不做二次折行。
- 强调、删除线、任务列表、脚注、引用块、表格、分隔线、自动链接和数学公式
  （`$…$`，按原样显示）。

## 不支持的内容

- 图片：显示替代文本，并在旁边附上 URL。
- 代码块的语法高亮。
- 原始 HTML：行内直接丢弃，块级则原样以暗色显示。

## 开发

```bash
moon test          # 34 个行为测试与单元测试
moon info && moon fmt
```
