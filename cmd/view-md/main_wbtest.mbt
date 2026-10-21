// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "split_words splits on whitespace and drops empty words" {
  assert_eq(split_words("less -FRX"), ["less", "-FRX"])
  assert_eq(split_words("  less\t-S  "), ["less", "-S"])
  assert_eq(split_words(""), [])
}

///|
test "should_page honours always and never" {
  assert_true(should_page("always"))
  assert_false(should_page("never"))
}
