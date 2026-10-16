///|
const DEFAULT_WIDTH : Int32 = 80

///|
/// Floor for the wrap width: a terminal column count can be arbitrary, but
/// rendering needs at least room for one indent and a few characters.
const MIN_WIDTH : Int32 = 4

///|
struct Options {
  theme : @lib.Theme
  width : Int32
}

///|
extern "C" fn isatty(fd : Int32) -> Int32 = "isatty"

///|
/// `SIGPIPE`, with `SIG_DFL` as the handler: writing into a pipe that has been
/// closed (`mdview file.md | head`) should end the process the way every other
/// Unix filter ends, rather than surfacing `EPIPE` as an error.
extern "C" fn signal(sig : Int32, handler : Int64) -> Int64 = "signal"

///|
const SIGPIPE : Int32 = 13

///|
const SIG_DFL : Int64 = 0

///|
fn command() -> @argparse.Command {
  Command(
    "mdview",
    about="Render a CommonMark file for the terminal.",
    version="0.1.0",
    options=[
      OptionArg("theme", about="colour theme: dark, light or none", default_values=[
        "dark",
      ]),
      OptionArg(
        "width",
        about="wrap width in columns; defaults to $COLUMNS or 80",
      ),
      OptionArg("color", about="when to emit colour: auto, always or never", default_values=[
        "auto",
      ]),
    ],
    positionals=[
      PositionArg(
        "file",
        about="file to read; use - or no file for stdin",
        num_args=ValueRange(lower=0),
        allow_hyphen_values=true,
      ),
    ],
  )
}

///|
fn option_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => if values.is_empty() { None } else { Some(values[0]) }
    None => None
  }
}

///|
fn env_text(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn parse_width(text : String) -> Int32? {
  let mut value = 0
  let mut digits = 0
  for c in text {
    let d = c.to_int() - '0'.to_int()
    if d < 0 || d > 9 {
      return None
    }
    value = value * 10 + d
    digits = digits + 1
  }
  if digits == 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn clamp_width(width : Int32) -> Int32 {
  if width < MIN_WIDTH {
    MIN_WIDTH
  } else {
    width
  }
}

///|
/// Colour is only emitted when stdout is a terminal that advertises colour
/// support, so piping the output into a file or a pager stays plain text.
fn terminal_color() -> Bool {
  if isatty(1) == 0 || env_text("NO_COLOR") is Some(_) {
    return false
  }
  match env_text("TERM") {
    Some(term) => term != "dumb"
    None => false
  }
}

///|
fn options_from_matches(matches : @argparse.Matches) -> Options raise {
  let theme = match option_value(matches, "theme") {
    Some("dark") | None => @lib.Dark
    Some("light") => @lib.Light
    Some("none") => @lib.NoColor
    Some(other) => fail("unknown theme: \{other}; expected dark, light or none")
  }
  let width = match option_value(matches, "width") {
    Some(text) =>
      match parse_width(text) {
        Some(n) => n
        None => fail("invalid width: \{text}")
      }
    None =>
      match env_text("COLUMNS") {
        Some(text) =>
          match parse_width(text) {
            Some(n) => n
            None => DEFAULT_WIDTH
          }
        None => DEFAULT_WIDTH
      }
  }
  let colored = match option_value(matches, "color") {
    Some("always") => true
    Some("never") => false
    Some("auto") | None => terminal_color()
    Some(other) =>
      fail("invalid color mode: \{other}; expected auto, always or never")
  }
  {
    theme: if colored {
      theme
    } else {
      @lib.NoColor
    },
    width: clamp_width(width),
  }
}

///|
fn input_paths(matches : @argparse.Matches) -> Array[String] {
  match matches.values {
    { "file": files, .. } if !files.is_empty() => files
    _ => ["-"]
  }
}

///|
async fn read_input(path : String) -> String {
  if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file(path).text()
  }
}

///|
async fn main {
  signal(SIGPIPE, SIG_DFL) |> ignore
  let matches = command().parse()
  let options = options_from_matches(matches)
  for path in input_paths(matches) {
    @stdio.stdout.write(
      @lib.render(read_input(path), theme=options.theme, width=options.width),
    )
  }
}
