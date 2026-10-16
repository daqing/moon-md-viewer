///|
/// Render CommonMark into text meant to be read in a terminal.
///
/// The document is parsed with the `cmark` extensions enabled (tables, task
/// lists, strikethrough, footnotes, math) and laid out to `width` columns.
/// `Theme::NoColor` produces plain text with no escape sequences at all.
pub fn render(markdown : String, theme? : Theme, width? : Int32) -> String {
  let theme = theme.unwrap_or(Dark)
  let width = width.unwrap_or(80)
  let color = match theme {
    NoColor => false
    _ => true
  }
  let doc = @cmark.Doc::from_string(strict=false, markdown)
  let ctx : DocCtx = { pal: palette_of(theme), color, defs: doc.defs, }
  let body = render_block_seq(ctx, doc.block, width, false)
  if body == "" {
    ""
  } else {
    body + "\n"
  }
}
