// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "line-breaking punctuation" {
  for c in "。，、；：？！）」』】》〉〕｝·…—～" {
    assert_true(is_no_break_before(c))
  }
  for c in "a中 1" {
    assert_false(is_no_break_before(c))
  }
}

///|
test "wide characters break without a space" {
  let w = Wrap::new(4)
  w.text("中文测试", plain_style())
  assert_eq(w.finish(), "中文\n测试")
}

///|
test "a closing punctuation mark overflows rather than starting a line" {
  let w = Wrap::new(4)
  w.text("ab 。", plain_style())
  assert_eq(w.finish(), "ab 。")
}

///|
test "words move to the next line as a whole" {
  let w = Wrap::new(6)
  w.text("ab cdef", plain_style())
  assert_eq(w.finish(), "ab\ncdef")
}

///|
test "styles are closed before a break" {
  let w = Wrap::new(4)
  w.text("ab cd", sgr("1"))
  assert_eq(w.finish(), "\u001b[1mab\u001b[0m\n\u001b[1mcd\u001b[0m")
}

///|
test "indent_lines decorates only non-empty lines" {
  assert_eq(indent_lines("a\n\nb", "> ", "> "), "> a\n\n> b")
  assert_eq(indent_lines("a\nb", "- ", "  "), "- a\n  b")
}

///|
test "escape sequences do not count towards the display width" {
  assert_eq(display_width("\u001b[38;5;240m# \u001b[0mTitle"), 7)
}

///|
test "truncate_visible closes a style left open by the cut" {
  let out = truncate_visible("\u001b[1mabcdef\u001b[0m", 4)
  assert_eq(out, "\u001b[1mabc…\u001b[0m")
}

///|
test "repeat repeats" {
  assert_eq(repeat("ab", 3), "ababab")
  assert_eq(repeat("ab", 0), "")
}
