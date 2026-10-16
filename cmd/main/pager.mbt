///|
/// Whether to page, given the value of `--pager`.
fn should_page(mode : String) -> Bool {
  match mode {
    "always" => true
    "never" => false
    _ => isatty(1) != 0
  }
}

///|
/// Split `text` into words on whitespace, dropping empty ones.
fn split_words(text : String) -> Array[String] {
  let words : Array[String] = []
  for word in text.replace_all(old="\t", new=" ").split(" ") {
    if !word.is_empty() {
      words.push(word.to_owned())
    }
  }
  words
}

///|
/// Pagers to try in order: the user's `$PAGER` when set, otherwise the
/// conventional ones.
fn pager_candidates() -> Array[Array[String]] {
  match env_text("PAGER") {
    Some(pager) =>
      match split_words(pager) {
        [] => [["less"], ["more"]]
        words => [words]
      }
    None => [["less"], ["more"]]
  }
}

///|
/// `less` passes ANSI colour through only with `-R`, and reads its defaults
/// from `$LESS`. Set the same default git uses, unless the user has their own
/// `$LESS` to keep.
fn pager_env() -> Map[String, String] {
  match env_text("LESS") {
    Some(_) => Map([])
    None => Map([("LESS", "FRX")])
  }
}

///|
/// Run `command` with `content` on its standard input, sharing our terminal
/// with it.
async fn run_pager(command : Array[String], content : String) -> Unit {
  @async.with_task_group <| group => {
    let (input, writer) = @process.write_to_process()
    let pager = @process.spawn(
      group,
      command[0],
      command[1:],
      extra_env=pager_env(),
      stdin=input,
      stdout=@stdio.stdout,
    )
    group.spawn_bg() <| () => { ignore(pager.wait()) }
    writer.write(content)
    writer.close()
  }
}

///|
/// Show `content` in the first pager that starts. Returns `false` when none of
/// them could be run, so the caller can print the text itself.
async fn page(content : String) -> Bool {
  for command in pager_candidates() {
    let mut started = true
    run_pager(command, content) catch {
      _ => started = false
    }
    if started {
      return true
    }
  }
  false
}
