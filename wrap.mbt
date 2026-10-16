///|
/// Line wrapper for one block of text.
///
/// Text arrives as words. A word is held back until the next space or line
/// break, so it can be moved to the next line as a whole when it does not fit.
/// East Asian characters are their own break opportunity, which is what makes
/// wrapping work for text without spaces.
priv struct Wrap {
  buf : StringBuilder
  limit : Int32
  mut col : Int32
  pending : StringBuilder
  mut pending_width : Int32
  mut pending_nobreak : Bool
  mut space : Bool
  mut started : Bool
}

///|
fn Wrap::new(limit : Int32) -> Wrap {
  {
    buf: StringBuilder(),
    limit,
    col: 0,
    pending: StringBuilder(),
    pending_width: 0,
    pending_nobreak: false,
    space: false,
    started: false,
  }
}

///|
fn Wrap::push(self : Wrap, styled : String, width : Int32) -> Unit {
  self.pending.write_string(styled)
  self.pending_width = self.pending_width + width
}

///|
/// Push a chunk that must not start a line, such as a closing CJK bracket or
/// full stop: when it does not fit it overflows the line instead of wrapping.
fn Wrap::push_glued(self : Wrap, styled : String, width : Int32) -> Unit {
  if self.pending.is_empty() {
    self.pending_nobreak = true
  }
  self.push(styled, width)
}

///|
fn Wrap::newline(self : Wrap) -> Unit {
  self.buf.write_char('\n')
  self.col = 0
  self.started = false
  self.space = false
}

///|
fn Wrap::flush(self : Wrap) -> Unit {
  if self.pending.is_empty() {
    return
  }
  let gap = if self.space && self.started { 1 } else { 0 }
  let overflow = self.pending_nobreak && self.started
  if !overflow &&
    self.started &&
    self.limit > 0 &&
    self.col + gap + self.pending_width > self.limit {
    self.newline()
  }
  if self.space && self.started {
    self.buf.write_char(' ')
    self.col = self.col + 1
  }
  self.space = false
  self.pending_nobreak = false
  self.started = true
  self.buf.write_string(self.pending.to_string())
  self.col = self.col + self.pending_width
  self.pending.reset()
  self.pending_width = 0
}

///|
fn Wrap::space(self : Wrap) -> Unit {
  self.flush()
  if self.started {
    self.space = true
  }
}

///|
fn Wrap::hard_break(self : Wrap) -> Unit {
  self.flush()
  self.newline()
}

///|
/// Append text with `style`, breaking at spaces and between East Asian
/// characters.
fn Wrap::text(self : Wrap, t : String, style : Style) -> Unit {
  let word = StringBuilder()
  let mut word_width = 0
  for c in t {
    let cw = char_width(c)
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      if !word.is_empty() {
        self.push(paint(word.to_string(), style), word_width)
        word.reset()
        word_width = 0
      }
      self.space()
    } else if cw > 1 {
      if !word.is_empty() {
        self.push(paint(word.to_string(), style), word_width)
        word.reset()
        word_width = 0
      }
      if is_no_break_before(c) {
        self.push_glued(paint(c.to_string(), style), cw)
      } else {
        self.flush()
        self.push(paint(c.to_string(), style), cw)
      }
    } else {
      word.write_char(c)
      word_width = word_width + cw
    }
  }
  if !word.is_empty() {
    self.push(paint(word.to_string(), style), word_width)
  }
}

///|
fn Wrap::finish(self : Wrap) -> String {
  self.flush()
  self.buf.to_string()
}

///|
/// Characters that may not begin a line.
fn is_no_break_before(c : Char) -> Bool {
  match c {
    '。'
    | '，'
    | '、'
    | '；'
    | '：'
    | '？'
    | '！'
    | '）'
    | '」'
    | '』'
    | '】'
    | '》'
    | '〉'
    | '〕'
    | '｝'
    | '·'
    | '…'
    | '—'
    | '～' => true
    _ => false
  }
}

///|
/// Prefix every line of `text`: `first` on the first line, `cont` on the rest.
/// Empty lines are left alone so trailing blanks carry no decoration.
fn indent_lines(text : String, first : String, cont : String) -> String {
  let out = StringBuilder()
  for i, line in text.split("\n").collect() {
    if i > 0 {
      out.write_char('\n')
    }
    let line = line.to_owned()
    if line != "" {
      out.write_string(if i == 0 { first } else { cont })
      out.write_string(line)
    }
  }
  out.to_string()
}
