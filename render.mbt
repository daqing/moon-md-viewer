///|
/// Everything the rendering functions need to read.
priv struct DocCtx {
  pal : Palette
  color : Bool
  defs : Map[String, @cmark.LabelDef]
}

///|
/// Columns left for content once `indent` columns are taken by decoration.
fn remaining(width : Int32, indent : Int32) -> Int32 {
  if width > indent + 4 {
    width - indent
  } else {
    4
  }
}

///|
fn hyperlink(url : String, text : String) -> String {
  "\u001b]8;;\{url}\u001b\\\{text}\u001b]8;;\u001b\\"
}

///|
fn render_blocks(
  ctx : DocCtx,
  blocks : Array[@cmark.Block],
  width : Int32,
  tight : Bool,
) -> String {
  let parts : Array[String] = []
  for b in blocks {
    let text = render_block(ctx, b, width)
    if text != "" {
      parts.push(text)
    }
  }
  parts.join(if tight { "\n" } else { "\n\n" })
}

///|
/// Render a block that is really a container: `Blocks` is unwrapped so that the
/// separator between children follows `tight`.
fn render_block_seq(
  ctx : DocCtx,
  b : @cmark.Block,
  width : Int32,
  tight : Bool,
) -> String {
  match b {
    @cmark.Blocks(bs) => render_blocks(ctx, bs.v.to_array(), width, tight)
    _ => render_block(ctx, b, width)
  }
}

///|
fn render_block(ctx : DocCtx, b : @cmark.Block, width : Int32) -> String {
  match b {
    @cmark.Blocks(bs) => render_blocks(ctx, bs.v.to_array(), width, false)
    @cmark.Heading(h) => render_heading(ctx, h.v, width)
    @cmark.Paragraph(p) => render_paragraph(ctx, p.v, width)
    @cmark.BlockQuote(q) => render_quote(ctx, q.v, width)
    @cmark.List(l) => render_list(ctx, l.v, width)
    @cmark.CodeBlock(cb) => render_code_block(ctx, cb.v)
    @cmark.ExtMathBlock(cb) => render_code_block(ctx, cb.v)
    @cmark.ThematicBreak(_) => render_rule(ctx, width)
    @cmark.ExtTable(t) => render_table(ctx, t.v, width)
    @cmark.HtmlBlock(lines) => {
      let parts : Array[String] = []
      for line in lines.v.0 {
        parts.push(paint(line.v, ctx.pal.dim))
      }
      parts.join("\n")
    }
    @cmark.ExtFootnoteDefinition(f) => render_footnote(ctx, f.v, width)
    @cmark.BlankLine(_) => ""
    @cmark.LinkRefDefinition(_) => ""
  }
}

///|
fn render_heading(
  ctx : DocCtx,
  h : @cmark.BlockHeading,
  width : Int32,
) -> String {
  let level = if h.level < 1 { 1 } else if h.level > 6 { 6 } else { h.level }
  let indent = level + 1
  let w = Wrap::new(remaining(width, indent))
  render_inline(ctx, h.inline, w, ctx.pal.heading[level - 1])
  let marker = paint(repeat("#", level) + " ", ctx.pal.heading_marker)
  indent_lines(w.finish(), marker, repeat(" ", indent))
}

///|
fn render_paragraph(
  ctx : DocCtx,
  p : @cmark.BlockParagraph,
  width : Int32,
) -> String {
  let w = Wrap::new(width)
  render_inline(ctx, p.inline, w, plain_style())
  w.finish()
}

///|
fn render_quote(ctx : DocCtx, q : @cmark.BlockQuote, width : Int32) -> String {
  let bar = paint("│ ", ctx.pal.quote_bar)
  indent_lines(
    render_block_seq(ctx, q.block, remaining(width, 2), false),
    bar,
    bar,
  )
}

///|
fn render_list(ctx : DocCtx, l : @cmark.BlockList, width : Int32) -> String {
  let parts : Array[String] = []
  let mut index = match l.ty {
    @cmark_base.Ordered(start, _) => start
    @cmark_base.Unordered(_) => 1
  }
  for item in l.items {
    let marker = match l.ty {
      @cmark_base.Ordered(_, _) => "\{index}. "
      @cmark_base.Unordered(delim) => "\{delim} "
    }
    let task = match item.v.ext_task_marker {
      None => ""
      Some(mark) =>
        match @cmark.ListTaskStatus::from_marker(mark.v) {
          @cmark.Checked => "[x] "
          @cmark.Cancelled => "[-] "
          @cmark.Unchecked | @cmark.Other(_) => "[ ] "
        }
    }
    let head_width = display_width(marker) + display_width(task)
    let prefix = paint(marker, ctx.pal.list_marker) + paint(task, ctx.pal.dim)
    let body = render_block_seq(
      ctx,
      item.v.block,
      remaining(width, head_width),
      l.tight,
    )
    parts.push(indent_lines(body, prefix, repeat(" ", head_width)))
    index = index + 1
  }
  parts.join(if l.tight { "\n" } else { "\n\n" })
}

///|
/// Code is emitted verbatim: long lines are left for the terminal to fold.
fn render_code_block(ctx : DocCtx, cb : @cmark.CodeBlock) -> String {
  let parts : Array[String] = []
  let lang = match cb.info_string {
    None => ""
    Some(info) =>
      match @cmark.CodeBlock::language_of_info_string(info.v) {
        Some((lang, _)) => lang
        None => ""
      }
  }
  if lang != "" {
    parts.push(paint(lang, ctx.pal.dim))
  }
  let bar = paint("│ ", ctx.pal.code_bar)
  for line in cb.code {
    parts.push(bar + paint(line.v, ctx.pal.code_text))
  }
  parts.join("\n")
}

///|
fn render_rule(ctx : DocCtx, width : Int32) -> String {
  let n = if width > 0 { width } else { 72 }
  paint(repeat("─", n), ctx.pal.rule)
}

///|
fn render_footnote(ctx : DocCtx, f : @cmark.Footnote, width : Int32) -> String {
  let label = paint("[\{f.label.key}]", ctx.pal.dim)
  let body = render_block_seq(ctx, f.block, remaining(width, 4), false)
  label + "\n" + indent_lines(body, "    ", "    ")
}

///|
fn render_inline(
  ctx : DocCtx,
  i : @cmark.Inline,
  w : Wrap,
  base : Style,
) -> Unit {
  match i {
    @cmark.Text(t) => w.text(t.v, base)
    @cmark.Inlines(inlines) =>
      for x in inlines.v {
        render_inline(ctx, x, w, base)
      }
    @cmark.CodeSpan(cs) => w.text(cs.v.code(), base.then(ctx.pal.code_span))
    @cmark.Emphasis(e) =>
      render_inline(ctx, e.v.inline, w, base.then(ctx.pal.emphasis))
    @cmark.StrongEmphasis(e) =>
      render_inline(ctx, e.v.inline, w, base.then(ctx.pal.strong))
    @cmark.ExtStrikethrough(s) =>
      render_inline(ctx, s.v.0, w, base.then(ctx.pal.strike))
    @cmark.Link(l) => render_link(ctx, l.v, w, base)
    @cmark.Image(l) => render_image(ctx, l.v, w, base)
    @cmark.Autolink(a) => render_autolink(ctx, a.v, w, base)
    @cmark.Break(b) =>
      match b.v.ty {
        @cmark.Hard => w.hard_break()
        @cmark.Soft => w.space()
      }
    @cmark.ExtMathSpan(ms) =>
      w.text("$\{ms.v.tex()}$", base.then(ctx.pal.code_span))
    @cmark.RawHtml(_) => ()
  }
}

///|
/// Destination of a link or image, resolving reference-style links against the
/// document's definitions. Unsafe destinations are dropped.
fn link_dest(ctx : DocCtx, l : @cmark.InlineLink) -> String? {
  let def = match l.reference {
    @cmark.Inline(def) => Some(def)
    @cmark.Ref(_, _, _) =>
      match l.reference_definition(ctx.defs) {
        Some(@cmark.LinkDef(def)) => Some(def)
        _ => None
      }
  }
  match def {
    None => None
    Some(def) =>
      match def.v.dest {
        None => None
        Some(dest) =>
          if @cmark.InlineLink::is_unsafe(dest.v) {
            None
          } else {
            Some(dest.v)
          }
      }
  }
}

///|
fn link_text(ctx : DocCtx, text : String, dest : String?) -> String {
  match dest {
    Some(url) => if ctx.color { hyperlink(url, text) } else { text }
    None => text
  }
}

///|
/// Key of the footnote a link refers to, when it is a footnote reference.
///
/// Footnote references are labels rather than prose, so they print as `[^key]`,
/// which is also how their definition is labelled.
fn footnote_key(ctx : DocCtx, l : @cmark.InlineLink) -> String? {
  match l.referenced_label() {
    None => None
    Some(label) =>
      if !label.key.has_prefix("^") {
        None
      } else {
        match l.reference_definition(ctx.defs) {
          Some(@cmark.LinkDef(_)) => None
          _ => Some(label.key)
        }
      }
  }
}

///|
fn render_link(
  ctx : DocCtx,
  l : @cmark.InlineLink,
  w : Wrap,
  base : Style,
) -> Unit {
  match footnote_key(ctx, l) {
    Some(key) => {
      let text = paint("[\{key}]", base.then(ctx.pal.dim))
      w.push(text, display_width(text))
    }
    None => {
      let inner = Wrap::new(0)
      render_inline(ctx, l.text, inner, base.then(ctx.pal.link))
      let text = inner.finish()
      let width = display_width(text)
      w.push(link_text(ctx, text, link_dest(ctx, l)), width)
    }
  }
}

///|
fn render_image(
  ctx : DocCtx,
  l : @cmark.InlineLink,
  w : Wrap,
  base : Style,
) -> Unit {
  let inner = Wrap::new(0)
  render_inline(ctx, l.text, inner, base.then(ctx.pal.image))
  let alt = inner.finish()
  let label = if display_width(alt) == 0 {
    paint("image", ctx.pal.image)
  } else {
    alt
  }
  let shown = match link_dest(ctx, l) {
    Some(url) => label + " " + paint("(\{url})", ctx.pal.dim)
    None => label
  }
  w.push(shown, display_width(shown))
}

///|
fn render_autolink(
  ctx : DocCtx,
  a : @cmark.InlineAutolink,
  w : Wrap,
  base : Style,
) -> Unit {
  let url = a.link.v
  let text = paint(url, base.then(ctx.pal.link))
  let target = if a.is_email { "mailto:\{url}" } else { url }
  w.push(link_text(ctx, text, Some(target)), display_width(url))
}

///|
fn pad_to(s : String, width : Int32, align : @cmark.TableAlign?) -> String {
  let w = display_width(s)
  if w >= width {
    return s
  }
  let pad = width - w
  match align {
    Some(@cmark.Right) => repeat(" ", pad) + s
    Some(@cmark.Center) => repeat(" ", pad / 2) + s + repeat(" ", pad - pad / 2)
    _ => s + repeat(" ", pad)
  }
}

///|
fn cell_texts(
  ctx : DocCtx,
  cells : Array[(@cmark.Inline, @cmark.TableCellLayout)],
  ncols : Int32,
) -> Array[String] {
  let out : Array[String] = []
  for cell in cells {
    let w = Wrap::new(0)
    render_inline(ctx, cell.0, w, plain_style())
    out.push(w.finish().replace_all(old="\n", new=" "))
  }
  while out.length() < ncols {
    out.push("")
  }
  out
}

///|
fn table_rule(
  widths : Array[Int32],
  left : String,
  mid : String,
  right : String,
) -> String {
  let parts : Array[String] = []
  for w in widths {
    parts.push(repeat("─", w + 2))
  }
  left + parts.join(mid) + right
}

///|
fn table_row(
  ctx : DocCtx,
  cells : Array[String],
  widths : Array[Int32],
  aligns : Array[@cmark.TableAlign?],
) -> String {
  let parts : Array[String] = []
  for i, w in widths {
    let cell = if i < cells.length() {
      truncate_visible(cells[i], w)
    } else {
      ""
    }
    let align = if i < aligns.length() { aligns[i] } else { None }
    parts.push(pad_to(cell, w, align))
  }
  let bar = paint("│", ctx.pal.border)
  bar + " " + parts.join(" " + bar + " ") + " " + bar
}

///|
/// Tables are laid out in a box. Columns keep their natural width until the
/// table no longer fits `width`, at which point every column is capped and
/// cells are truncated with an ellipsis.
fn render_table(ctx : DocCtx, t : @cmark.Table, width : Int32) -> String {
  let ncols = t.col_count
  if ncols <= 0 {
    return ""
  }
  let rows : Array[(Array[String], Bool)] = []
  let aligns : Array[@cmark.TableAlign?] = []
  let mut col = 0
  while col < ncols {
    aligns.push(None)
    col = col + 1
  }
  for entry in t.rows {
    match entry.0.v {
      @cmark.Header(cells) =>
        rows.push((cell_texts(ctx, cells.to_array(), ncols), true))
      @cmark.Data(cells) =>
        rows.push((cell_texts(ctx, cells.to_array(), ncols), false))
      @cmark.Sep(seps) => {
        let mut i = 0
        for sep in seps {
          if i < ncols {
            aligns[i] = sep.v.0.0
          }
          i = i + 1
        }
      }
    }
  }
  if rows.is_empty() {
    return ""
  }
  let widths : Array[Int32] = []
  let mut col = 0
  while col < ncols {
    widths.push(0)
    col = col + 1
  }
  for row in rows {
    for i, w in widths {
      if i < row.0.length() {
        let cell = display_width(row.0[i])
        if cell > w {
          widths[i] = cell
        }
      }
    }
  }
  let budget = if width > ncols * 4 + ncols + 1 {
    width - (ncols + 1)
  } else {
    ncols * 4
  }
  let cap = budget / ncols
  let mut col = 0
  while col < ncols {
    if widths[col] > cap {
      widths[col] = cap
    }
    col = col + 1
  }
  let parts : Array[String] = []
  parts.push(paint(table_rule(widths, "┌", "┬", "┐"), ctx.pal.border))
  for i, row in rows {
    parts.push(table_row(ctx, row.0, widths, aligns))
    if row.1 && i + 1 < rows.length() {
      parts.push(paint(table_rule(widths, "├", "┼", "┤"), ctx.pal.border))
    }
  }
  parts.push(paint(table_rule(widths, "└", "┴", "┘"), ctx.pal.border))
  parts.join("\n")
}
