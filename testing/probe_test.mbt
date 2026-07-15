///|
test "probe counts lazy recomputations" {
  let (source, set_source) = @duplix.input(1)
  let probe = @testing.probe(source)

  assert_eq(probe.recompute_count(), 0)
  assert_eq(probe.read(), 1)
  assert_eq(probe.recompute_count(), 1)

  assert_eq(probe.read(), 1)
  assert_eq(probe.recompute_count(), 1)

  set_source(2)
  assert_eq(probe.recompute_count(), 1)
  assert_eq(probe.read(), 2)
  assert_eq(probe.recompute_count(), 2)
}

///|
test "probe observes cutoffs and resets independently" {
  let (source, set_source) = @duplix.input(7)
  let probe = @testing.probe(source)

  assert_eq(probe.read(), 7)
  assert_eq(probe.recompute_count(), 1)

  set_source(7)
  assert_eq(probe.read(), 7)
  assert_eq(probe.recompute_count(), 1)

  probe.reset()
  assert_eq(probe.recompute_count(), 0)
  assert_eq(probe.read(), 7)
  assert_eq(probe.recompute_count(), 0)

  set_source(8)
  assert_eq(probe.read(), 8)
  assert_eq(probe.recompute_count(), 1)
}

///|
test "probe node can feed a downstream graph" {
  let (source, set_source) = @duplix.input(3)
  let probe = @testing.probe(source)
  let doubled = probe.node().map(value => value * 2)

  assert_eq(doubled.read(), 6)
  assert_eq(probe.recompute_count(), 1)

  set_source(4)
  assert_eq(doubled.read(), 8)
  assert_eq(probe.recompute_count(), 2)
}
