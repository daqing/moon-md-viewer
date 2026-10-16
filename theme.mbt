///|
/// Colour theme for terminal output.
///
/// `NoColor` emits no SGR escape sequences at all and is meant for output that
/// is piped into a file or another program.
pub(all) enum Theme {
  Dark
  Light
  NoColor
}

///|
/// An SGR style, stored as the parameter list of `ESC [ <params> m`.
///
/// Styles compose by concatenating parameter lists, so `bold` then `cyan`
/// yields `ESC [ 1;36 m`.
priv struct Style {
  params : String
}

///|
fn sgr(params : String) -> Style {
  { params, }
}

///|
/// The style that adds nothing, used as the base for body text.
fn plain_style() -> Style {
  { params: "", }
}

///|
fn Style::then(self : Style, other : Style) -> Style {
  if self.params == "" {
    other
  } else if other.params == "" {
    self
  } else {
    { params: "\{self.params};\{other.params}", }
  }
}

///|
/// Wrap `text` in `style`, leaving it untouched when the style is empty.
fn paint(text : String, style : Style) -> String {
  if style.params == "" || text == "" {
    text
  } else {
    "\u001b[\{style.params}m\{text}\u001b[0m"
  }
}

///|
/// The styles used for one rendered document.
priv struct Palette {
  heading : Array[Style]
  heading_marker : Style
  code_span : Style
  code_text : Style
  code_bar : Style
  link : Style
  image : Style
  strong : Style
  emphasis : Style
  strike : Style
  quote_bar : Style
  list_marker : Style
  rule : Style
  border : Style
  dim : Style
}

///|
fn no_color_palette() -> Palette {
  {
    heading: Array::make(6, sgr("")),
    heading_marker: sgr(""),
    code_span: sgr(""),
    code_text: sgr(""),
    code_bar: sgr(""),
    link: sgr(""),
    image: sgr(""),
    strong: sgr(""),
    emphasis: sgr(""),
    strike: sgr(""),
    quote_bar: sgr(""),
    list_marker: sgr(""),
    rule: sgr(""),
    border: sgr(""),
    dim: sgr(""),
  }
}

///|
fn palette_of(theme : Theme) -> Palette {
  match theme {
    NoColor => no_color_palette()
    Dark =>
      {
        heading: [
          sgr("1;38;5;81"),
          sgr("1;38;5;75"),
          sgr("1;38;5;74"),
          sgr("1;38;5;110"),
          sgr("1;38;5;110"),
          sgr("1;38;5;110"),
        ],
        heading_marker: sgr("38;5;240"),
        code_span: sgr("38;5;180"),
        code_text: sgr("38;5;252"),
        code_bar: sgr("38;5;240"),
        link: sgr("4;38;5;45"),
        image: sgr("38;5;108"),
        strong: sgr("1"),
        emphasis: sgr("3"),
        strike: sgr("9;38;5;245"),
        quote_bar: sgr("38;5;240"),
        list_marker: sgr("38;5;214"),
        rule: sgr("38;5;240"),
        border: sgr("38;5;240"),
        dim: sgr("38;5;245"),
      }
    Light =>
      {
        heading: [
          sgr("1;38;5;25"),
          sgr("1;38;5;26"),
          sgr("1;38;5;31"),
          sgr("1;38;5;60"),
          sgr("1;38;5;60"),
          sgr("1;38;5;60"),
        ],
        heading_marker: sgr("38;5;250"),
        code_span: sgr("38;5;130"),
        code_text: sgr("38;5;238"),
        code_bar: sgr("38;5;250"),
        link: sgr("4;38;5;25"),
        image: sgr("38;5;100"),
        strong: sgr("1"),
        emphasis: sgr("3"),
        strike: sgr("9;38;5;245"),
        quote_bar: sgr("38;5;250"),
        list_marker: sgr("38;5;130"),
        rule: sgr("38;5;250"),
        border: sgr("38;5;250"),
        dim: sgr("38;5;243"),
      }
  }
}
