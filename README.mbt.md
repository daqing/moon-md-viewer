# moon-md-viewer

Render CommonMark as text a terminal can actually display.

Markdown tooling usually stops at HTML, and a terminal has no engine to render
HTML — you either look at raw tags or you open a browser. `moon-md-viewer` walks
the CommonMark AST and writes ANSI instead: headings keep their `##` markers and
gain a colour, lists keep their indentation, tables are drawn as boxes, and
links become OSC 8 hyperlinks you can click.

Rendered at 56 columns:

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

## Running

With the MoonBit toolchain installed:

```bash
moon run cmd/main -- README.mbt.md
moon run cmd/main -- --width 60 docs/design.md
cat notes.md | moon run cmd/main
```

`moon build --release` writes a standalone binary to
`_build/native/release/build/cmd/main/main.exe`.

### Options

| Option | Default | Meaning |
| --- | --- | --- |
| `--theme <dark\|light\|none>` | `dark` | Colour palette; `none` emits no colour at all. |
| `--width <columns>` | `$COLUMNS`, else 80 | Wrap width. |
| `--color <auto\|always\|never>` | `auto` | `auto` colours only when stdout is a terminal that supports it. |
| `--pager <auto\|always\|never>` | `auto` | `auto` pages through `$PAGER` when stdout is a terminal. |

Any remaining arguments are input files; `-`, or no file at all, reads standard
input. Colour is suppressed when stdout is not a terminal, `TERM` is `dumb`, or
`NO_COLOR` is set.

### Paging

Output going to a terminal is piped through `$PAGER`, or through `less` when
`$PAGER` is unset. `$LESS` defaults to `FRX` — the settings git uses — so colour
reaches the pager, the text stays on screen after quitting, and `less` exits by
itself when the document already fits on one screen. `--pager never` prints
directly, `--pager always` pages even when stdout is a pipe, and a pager that
cannot be started falls back to printing.

## Library

```moonbit nocheck
///|
let text = @moon-md-viewer.render(
  markdown,
  theme=@moon-md-viewer.Dark,
  width=80,
)
```

`render` returns the document and a trailing newline, or an empty string for
input that holds nothing printable. `Theme` is `Dark`, `Light` or `NoColor`.
`char_width`, `display_width` and `truncate_visible` are exported for callers
that need to measure or cut styled text themselves.

## What it handles

- Widths are measured in terminal columns, so CJK and emoji count as two;
  wrapping, table columns and truncation stay aligned in a CJK document.
- CJK text breaks between characters, and closing punctuation (`。`, `，`, `」` …)
  never starts a line.
- Code blocks are emitted verbatim and are never rewrapped.
- Emphasis, strikethrough, task lists, footnotes, block quotes, tables, thematic
  breaks, autolinks and math spans (`$…$`, shown as written).

## What it does not do

- Images: the alt text is shown with the URL beside it.
- Syntax highlighting inside code blocks.
- Raw HTML: dropped inline, shown dimmed and verbatim as a block.

## Development

```bash
moon test          # 34 behavioural and unit tests
moon info && moon fmt
```
