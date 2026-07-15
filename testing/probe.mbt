///|
/// A lazy observation point for a Duplix node.
///
/// `Probe` counts only computations that reach the observation point. Writing
/// an input does not increment the count until the probe is pulled, and a
/// cutoff upstream leaves the count unchanged.
struct Probe[T] {
  node : @duplix.Node[T]
  recompute_count : Ref[Int]
}

///|
/// Create a lazy observation point for `node`.
pub fn[T : Eq] probe(node : @duplix.Node[T]) -> Probe[T] {
  let recompute_count = Ref(0)
  let observed = node.map(value => {
    recompute_count.val += 1
    value
  })
  { node: observed, recompute_count }
}

///|
/// Read the observed node.
pub fn[T : Eq] Probe::read(self : Self[T]) -> T {
  self.node.read()
}

///|
/// Return the instrumented node so it can feed another derived graph.
pub fn[T] Probe::node(self : Self[T]) -> @duplix.Node[T] {
  self.node
}

///|
/// Return how many times the observation point has recomputed.
pub fn[T] Probe::recompute_count(self : Self[T]) -> Int {
  self.recompute_count.val
}

///|
/// Reset the recomputation count without dirtying the observed node.
pub fn[T] Probe::reset(self : Self[T]) -> Unit {
  self.recompute_count.val = 0
}
