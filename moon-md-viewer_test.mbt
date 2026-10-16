// Blackbox tests run against the package's public API. Use `@moon-md-viewer` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "heading keeps its marker on the first line" {
  assert_eq(
    @moon-md-viewer.render("## Sub heading", theme=@moon-md-viewer.NoColor),
    "## Sub heading\n",
  )
}

///|
test "heading body wraps under the marker" {
  assert_eq(
    @moon-md-viewer.render(
      "## alpha beta gamma",
      theme=@moon-md-viewer.NoColor,
      width=12,
    ),
    "## alpha\n   beta\n   gamma\n",
  )
}

///|
test "each heading level has its own colour" {
  let h1 = @moon-md-viewer.render("# Title", theme=@moon-md-viewer.Dark)
  let h2 = @moon-md-viewer.render("## Title", theme=@moon-md-viewer.Dark)
  assert_true(
    h1.contains("\u001b[38;5;240m# \u001b[0m\u001b[1;38;5;81mTitle\u001b[0m"),
  )
  assert_true(
    h2.contains("\u001b[38;5;240m## \u001b[0m\u001b[1;38;5;75mTitle\u001b[0m"),
  )
}

///|
test "paragraph wraps at the requested width" {
  assert_eq(
    @moon-md-viewer.render(
      "one two three four five six",
      theme=@moon-md-viewer.NoColor,
      width=12,
    ),
    "one two\nthree four\nfive six\n",
  )
}

///|
test "wide characters wrap by column, not by character count" {
  assert_eq(
    @moon-md-viewer.render(
      "中文断行测试一二三四五六七八九十",
      theme=@moon-md-viewer.NoColor,
      width=12,
    ),
    "中文断行测试\n一二三四五六\n七八九十\n",
  )
}

///|
test "list items align their continuation lines" {
  assert_eq(
    @moon-md-viewer.render(
      "- alpha beta gamma delta",
      theme=@moon-md-viewer.NoColor,
      width=12,
    ),
    "- alpha beta\n  gamma\n  delta\n",
  )
}

///|
test "nested lists step in by the marker width" {
  assert_eq(
    @moon-md-viewer.render(
      "- outer\n  - inner\n",
      theme=@moon-md-viewer.NoColor,
      width=40,
    ),
    "- outer\n  - inner\n",
  )
}

///|
test "ordered lists are numbered from their start value" {
  assert_eq(
    @moon-md-viewer.render("3. three\n4. four\n", theme=@moon-md-viewer.NoColor),
    "3. three\n4. four\n",
  )
}

///|
test "task list markers are rendered" {
  assert_eq(
    @moon-md-viewer.render(
      "- [x] done\n- [ ] todo\n",
      theme=@moon-md-viewer.NoColor,
    ),
    "- [x] done\n- [ ] todo\n",
  )
}

///|
test "code blocks are quoted and never wrapped" {
  let markdown = "```moonbit\nlet a_very_long_line_that_would_wrap = 1\n```\n"
  assert_eq(
    @moon-md-viewer.render(markdown, theme=@moon-md-viewer.NoColor, width=20),
    "moonbit\n│ let a_very_long_line_that_would_wrap = 1\n",
  )
}

///|
test "block quotes carry a bar on every line" {
  assert_eq(
    @moon-md-viewer.render(
      "> quoted text here",
      theme=@moon-md-viewer.NoColor,
      width=12,
    ),
    "│ quoted\n│ text here\n",
  )
}

///|
test "tables are boxed and cells truncate to the column budget" {
  let markdown = "| 中文标题特别长 | b |\n| --- | --- |\n| 一个非常非常非常长的单元格内容 | 短 |\n"
  assert_eq(
    @moon-md-viewer.render(markdown, theme=@moon-md-viewer.NoColor, width=30),
    "┌───────────────┬────┐\n" +
    "│ 中文标题特别… │ b  │\n" +
    "├───────────────┼────┤\n" +
    "│ 一个非常非常… │ 短 │\n" +
    "└───────────────┴────┘\n",
  )
}

///|
test "links carry their target as an OSC 8 hyperlink" {
  let out = @moon-md-viewer.render(
    "see [docs](https://example.com) now",
    theme=@moon-md-viewer.Dark,
  )
  assert_true(out.contains("\u001b]8;;https://example.com\u001b\\"))
  assert_true(out.contains("\u001b]8;;\u001b\\"))
}

///|
test "reference links resolve against the document definitions" {
  let markdown = "see [docs][d]\n\n[d]: https://example.com\n"
  let out = @moon-md-viewer.render(markdown, theme=@moon-md-viewer.Dark)
  assert_true(out.contains("\u001b]8;;https://example.com\u001b\\"))
}

///|
test "unsafe link targets are dropped" {
  let out = @moon-md-viewer.render(
    "[click](javascript:alert(1))",
    theme=@moon-md-viewer.Dark,
  )
  assert_false(out.contains("]8;;"))
  assert_true(out.contains("click"))
}

///|
test "footnote references and their definition share a label" {
  let markdown = "note[^1] and[^missing]\n\n[^1]: body\n"
  assert_eq(
    @moon-md-viewer.render(markdown, theme=@moon-md-viewer.NoColor),
    "note[^1] and[^missing]\n\n[^1]\n    body\n",
  )
}

///|
test "inline styles survive wrapping" {
  let out = @moon-md-viewer.render(
    "a `code` and **bold** text",
    theme=@moon-md-viewer.Dark,
  )
  assert_true(out.contains("\u001b[38;5;180mcode\u001b[0m"))
  assert_true(out.contains("\u001b[1mbold\u001b[0m"))
}

///|
test "NoColor emits no escape sequences at all" {
  let markdown = "# t\n\n- a `b` **c** [d](https://e.com)\n\n```\ncode\n```\n\n> q\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n"
  let out = @moon-md-viewer.render(markdown, theme=@moon-md-viewer.NoColor)
  assert_false(out.contains("\u001b"))
}

///|
test "empty input renders nothing" {
  assert_eq(@moon-md-viewer.render(""), "")
  assert_eq(@moon-md-viewer.render("\n\n"), "")
}

///|
test "thematic breaks span the requested width" {
  assert_eq(
    @moon-md-viewer.render("---", theme=@moon-md-viewer.NoColor, width=8),
    "────────\n",
  )
}

///|
test "character width follows the East Asian tables" {
  assert_eq(@moon-md-viewer.char_width('a'), 1)
  assert_eq(@moon-md-viewer.char_width('中'), 2)
  assert_eq(@moon-md-viewer.char_width('。'), 2)
  assert_eq(@moon-md-viewer.char_width('\u{300}'), 0)
}

///|
test "display width ignores escape sequences" {
  assert_eq(@moon-md-viewer.display_width("\u001b[1mab\u001b[0m"), 2)
  assert_eq(@moon-md-viewer.display_width("中文"), 4)
  assert_eq(
    @moon-md-viewer.display_width(
      "\u001b]8;;https://example.com\u001b\\x\u001b]8;;\u001b\\",
    ),
    1,
  )
}

///|
test "truncate_visible cuts on column boundaries" {
  assert_eq(@moon-md-viewer.truncate_visible("abcdef", 4), "abc…")
  assert_eq(@moon-md-viewer.truncate_visible("中文中文", 5), "中文…")
  assert_eq(@moon-md-viewer.truncate_visible("abc", 8), "abc")
  assert_eq(@moon-md-viewer.truncate_visible("abcdef", 0), "")
}
