# Duplix testing

`Yoorkin/duplix/testing` provides lazy instrumentation for Duplix graphs. Add
it only to the test imports of a consuming package:

```moonbit nocheck
import {
  "Yoorkin/duplix/testing",
} for "test"
```

`Probe` records how often propagation reaches an observation point. It does not
turn Duplix into an eager graph: writes remain lazy, clean reads are not counted,
and upstream cutoffs do not increment the counter.

```mbt check
///|
test {
  let (source, set_source) = @duplix.input(1)
  let probe = @testing.probe(source)

  assert_eq(probe.recompute_count(), 0)
  assert_eq(probe.read(), 1)
  assert_eq(probe.recompute_count(), 1)

  set_source(2)
  assert_eq(probe.read(), 2)
  assert_eq(probe.recompute_count(), 2)
}
```
