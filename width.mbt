///|
/// Characters that occupy no column on screen: combining marks, joiners,
/// variation selectors and skin tone modifiers.
fn is_zero_width(cp : Int32) -> Bool {
  (cp >= 0x0300 && cp <= 0x036F) ||
  (cp >= 0x200B && cp <= 0x200F) ||
  (cp >= 0xFE00 && cp <= 0xFE0F) ||
  (cp >= 0x1F3FB && cp <= 0x1F3FF) ||
  cp == 0xFEFF
}

///|
/// East Asian Wide and Fullwidth ranges, which take two columns.
fn is_wide(cp : Int32) -> Bool {
  (cp >= 0x1100 && cp <= 0x115F) ||
  (cp >= 0x2E80 && cp <= 0x303E) ||
  (cp >= 0x3041 && cp <= 0x33FF) ||
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0xA000 && cp <= 0xA4CF) ||
  (cp >= 0xAC00 && cp <= 0xD7A3) ||
  (cp >= 0xF900 && cp <= 0xFAFF) ||
  (cp >= 0xFE30 && cp <= 0xFE6F) ||
  (cp >= 0xFF00 && cp <= 0xFF60) ||
  (cp >= 0xFFE0 && cp <= 0xFFE6) ||
  (cp >= 0x1F300 && cp <= 0x1F64F) ||
  (cp >= 0x1F900 && cp <= 0x1F9FF) ||
  (cp >= 0x20000 && cp <= 0x3FFFD)
}

///|
/// Number of terminal columns a single character occupies.
pub fn char_width(c : Char) -> Int32 {
  let cp = c.to_int()
  if cp < 0x20 || cp == 0x7F {
    0
  } else if is_zero_width(cp) {
    0
  } else if is_wide(cp) {
    2
  } else {
    1
  }
}

///|
/// Escape scanner states shared by `display_width` and `truncate_visible`.
///
/// `0` is plain text, `1` follows `ESC`, `2` is inside a CSI sequence, `3` is
/// inside an OSC sequence and `4` is the `ESC` that ends one.
fn next_escape_state(state : Int32, cp : Int32) -> Int32 {
  if state == 0 {
    if cp == 0x1B {
      1
    } else {
      0
    }
  } else if state == 1 {
    if cp == '['.to_int() {
      2
    } else if cp == ']'.to_int() {
      3
    } else {
      0
    }
  } else if state == 2 {
    if cp >= 0x40 && cp <= 0x7E {
      0
    } else {
      2
    }
  } else if state == 3 {
    if cp == 0x07 {
      0
    } else if cp == 0x1B {
      4
    } else {
      3
    }
  } else {
    0
  }
}

///|
/// Number of terminal columns `s` occupies, ignoring ANSI escape sequences.
pub fn display_width(s : String) -> Int32 {
  let mut w = 0
  let mut state = 0
  for c in s {
    if state == 0 {
      w = w + char_width(c)
    }
    state = next_escape_state(state, c.to_int())
  }
  w
}

///|
/// Cut `s` down to at most `max` columns, appending an ellipsis when something
/// was dropped. Escape sequences pass through untouched and a style left open
/// by the cut is closed.
pub fn truncate_visible(s : String, max : Int32) -> String {
  if max <= 0 {
    return ""
  }
  if display_width(s) <= max {
    return s
  }
  let budget = if max > 1 { max - 1 } else { max }
  let out = StringBuilder()
  let mut w = 0
  let mut state = 0
  let mut styled = false
  for c in s {
    let cp = c.to_int()
    if state != 0 || cp == 0x1B {
      styled = true
      out.write_char(c)
    } else {
      let cw = char_width(c)
      if w + cw > budget {
        break
      }
      w = w + cw
      out.write_char(c)
    }
    state = next_escape_state(state, cp)
  }
  out.write_string("…")
  if styled {
    out.write_string("\u001b[0m")
  }
  out.to_string()
}

///|
/// `s` repeated `n` times.
fn repeat(s : String, n : Int32) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i < n {
    out.write_string(s)
    i = i + 1
  }
  out.to_string()
}
