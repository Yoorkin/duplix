///|
extern "c" fn monotonic_us() -> Int64 = "duplix_probe_monotonic_us"

///|
extern "c" fn current_rss_kb() -> Int64 = "duplix_probe_current_rss_kb"

///|
extern "c" fn release_unused_memory() -> Unit = "duplix_probe_release_unused_memory"

///|
let steady_iterations = 200

///|
fn timed_us(f : () -> Int) -> (Int64, Int) {
  let start = monotonic_us()
  let checksum = f()
  let stop = monotonic_us()
  (stop - start, checksum)
}

///|
fn print_header() -> Unit {
  println(
    "scenario,n,depth,fan_in,rss_before_kb,rss_after_build_kb,rss_delta_kb,first_dirty_us,steady_total_us,steady_iterations,steady_avg_ns,checksum",
  )
}

///|
fn print_row(
  scenario : String,
  n : Int,
  depth : Int,
  fan_in : Int,
  rss_before : Int64,
  rss_after_build : Int64,
  first_dirty_us : Int64,
  steady_total_us : Int64,
  checksum : Int,
) -> Unit {
  let steady_avg_ns = if steady_iterations == 0 {
    0L
  } else {
    steady_total_us * 1000L / Int64::from_int(steady_iterations)
  }
  println(
    "\{scenario},\{n},\{depth},\{fan_in},\{rss_before},\{rss_after_build},\{rss_after_build - rss_before},\{first_dirty_us},\{steady_total_us},\{steady_iterations},\{steady_avg_ns},\{checksum}",
  )
}

///|
fn warmup() -> Unit {
  let root = @duplix.input(0)
  let root_node = root.to_node()
  let live = root_node.map(x => x)
  ignore(live.read())
  for i in 0..<200 {
    let derived = root_node.map(x => x + i)
    ignore(derived.read())
  }
  root.set(1)
  ignore(live.read())
}

///|
fn measure_steady(
  root : @duplix.Input[Int],
  live : @duplix.Node[Int],
  start_value : Int,
) -> (Int64, Int) {
  timed_us(() => {
    let mut checksum = 0
    for i in 0..<steady_iterations {
      root.set(start_value + i)
      checksum += live.read()
    }
    checksum
  })
}

///|
fn create_dead_map_fanout(root_node : @duplix.Node[Int], n : Int) -> Int {
  let mut checksum = 0
  for i in 0..<n {
    let derived = root_node.map(x => x + i)
    checksum += derived.read()
  }
  checksum
}

///|
fn create_dead_chain(root_node : @duplix.Node[Int], n : Int) -> Int {
  let mut checksum = 0
  for i in 0..<n {
    let one = root_node.map(x => x + i)
    let two = one.map(x => x + 1)
    let three = two.map(x => x + 1)
    let four = three.map(x => x + 1)
    checksum += four.read()
  }
  checksum
}

///|
fn create_dead_bind(
  selector_node : @duplix.Node[Bool],
  left_node : @duplix.Node[Int],
  right_node : @duplix.Node[Int],
  n : Int,
) -> Int {
  let mut checksum = 0
  for _ in 0..<n {
    let derived = selector_node.bind(use_left => {
      if use_left {
        left_node
      } else {
        right_node
      }
    })
    checksum += derived.read()
  }
  checksum
}

///|
fn create_dead_map12(
  n1 : @duplix.Node[Int],
  n2 : @duplix.Node[Int],
  n3 : @duplix.Node[Int],
  n4 : @duplix.Node[Int],
  n5 : @duplix.Node[Int],
  n6 : @duplix.Node[Int],
  n7 : @duplix.Node[Int],
  n8 : @duplix.Node[Int],
  n9 : @duplix.Node[Int],
  n10 : @duplix.Node[Int],
  n11 : @duplix.Node[Int],
  n12 : @duplix.Node[Int],
  n : Int,
) -> Int {
  let mut checksum = 0
  for i in 0..<n {
    let derived = n1.map12(n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, (
      a,
      b,
      c,
      d,
      e,
      f,
      g,
      h,
      i2,
      j,
      k,
      l,
    ) => a + b + c + d + e + f + g + h + i2 + j + k + l + i)
    checksum += derived.read()
  }
  checksum
}

///|
fn create_dead_zip12(
  n1 : @duplix.Node[Int],
  n2 : @duplix.Node[Int],
  n3 : @duplix.Node[Int],
  n4 : @duplix.Node[Int],
  n5 : @duplix.Node[Int],
  n6 : @duplix.Node[Int],
  n7 : @duplix.Node[Int],
  n8 : @duplix.Node[Int],
  n9 : @duplix.Node[Int],
  n10 : @duplix.Node[Int],
  n11 : @duplix.Node[Int],
  n12 : @duplix.Node[Int],
  n : Int,
) -> Int {
  let mut checksum = 0
  for i in 0..<n {
    let derived = n1
      .zip12(n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12)
      .map(items => {
        let (a, b, c, d, e, f, g, h, i2, j, k, l) = items
        a + b + c + d + e + f + g + h + i2 + j + k + l + i
      })
    checksum += derived.read()
  }
  checksum
}

///|
fn run_map_fanout(n : Int) -> Unit {
  release_unused_memory()
  let root = @duplix.input(1)
  let root_node = root.to_node()
  let live = root_node.map(x => x)
  ignore(live.read())
  let rss_before = current_rss_kb()
  let mut checksum = create_dead_map_fanout(root_node, n)
  let rss_after_build = current_rss_kb()
  let (first_dirty_us, first_result) = timed_us(() => {
    root.set(10)
    live.read()
  })
  checksum += first_result
  let (steady_total_us, steady_checksum) = measure_steady(root, live, 1000)
  checksum += steady_checksum
  print_row(
    "map_fanout", n, 1, 1, rss_before, rss_after_build, first_dirty_us, steady_total_us,
    checksum,
  )
}

///|
fn run_chain(n : Int) -> Unit {
  release_unused_memory()
  let root = @duplix.input(1)
  let root_node = root.to_node()
  let live = root_node.map(x => x)
  ignore(live.read())
  let rss_before = current_rss_kb()
  let mut checksum = create_dead_chain(root_node, n)
  let rss_after_build = current_rss_kb()
  let (first_dirty_us, first_result) = timed_us(() => {
    root.set(10)
    live.read()
  })
  checksum += first_result
  let (steady_total_us, steady_checksum) = measure_steady(root, live, 1000)
  checksum += steady_checksum
  print_row(
    "chain_depth4", n, 4, 1, rss_before, rss_after_build, first_dirty_us, steady_total_us,
    checksum,
  )
}

///|
fn run_bind_branch(n : Int) -> Unit {
  release_unused_memory()
  let selector = @duplix.input(true)
  let left = @duplix.input(1)
  let right = @duplix.input(100)
  let selector_node = selector.to_node()
  let left_node = left.to_node()
  let right_node = right.to_node()
  let live = selector_node.map(use_left => if use_left { 1 } else { 0 })
  ignore(live.read())
  let rss_before = current_rss_kb()
  let mut checksum = create_dead_bind(selector_node, left_node, right_node, n)
  let rss_after_build = current_rss_kb()
  let (first_dirty_us, first_result) = timed_us(() => {
    selector.set(false)
    live.read()
  })
  checksum += first_result
  let (steady_total_us, steady_checksum) = timed_us(() => {
    let mut checksum = 0
    for i in 0..<steady_iterations {
      selector.set(i % 2 == 0)
      checksum += live.read()
    }
    checksum
  })
  checksum += steady_checksum
  print_row(
    "bind_branch", n, 1, 2, rss_before, rss_after_build, first_dirty_us, steady_total_us,
    checksum,
  )
}

///|
fn run_bind_live_root_subgraph(n : Int) -> Unit {
  release_unused_memory()
  let selector = @duplix.input(0)
  let payload = @duplix.input(1)
  let selector_node = selector.to_node()
  let payload_node = payload.to_node()
  let output = selector_node.bind(token => {
    let mapped = payload_node.map(value => value + token)
    mapped.map(value => value * 2)
  })
  ignore(output.read())
  let rss_before = current_rss_kb()
  let mut checksum = 0
  for i in 1..<=n {
    selector.set(i)
    checksum += output.read()
  }
  let rss_after_build = current_rss_kb()
  let (first_dirty_us, first_result) = timed_us(() => {
    payload.set(10)
    output.read()
  })
  checksum += first_result
  let (steady_total_us, steady_checksum) = measure_steady(payload, output, 1000)
  checksum += steady_checksum
  print_row(
    "bind_live_root_subgraph", n, 2, 1, rss_before, rss_after_build, first_dirty_us,
    steady_total_us, checksum,
  )
}

///|
fn run_bind_live_local_subgraph(n : Int) -> Unit {
  release_unused_memory()
  let selector = @duplix.input(0)
  let selector_node = selector.to_node()
  let output = selector_node.bind(token => {
    let temp_input = @duplix.input(token)
    let mapped = temp_input.to_node().map(value => value + 1)
    mapped.map(value => value * 2)
  })
  ignore(output.read())
  let rss_before = current_rss_kb()
  let mut checksum = 0
  for i in 1..<=n {
    selector.set(i)
    checksum += output.read()
  }
  let rss_after_build = current_rss_kb()
  let (first_dirty_us, first_result) = timed_us(() => {
    selector.set(n + 1)
    output.read()
  })
  checksum += first_result
  let (steady_total_us, steady_checksum) = timed_us(() => {
    let mut checksum = 0
    for i in 0..<steady_iterations {
      selector.set(n + 1000 + i)
      checksum += output.read()
    }
    checksum
  })
  checksum += steady_checksum
  print_row(
    "bind_live_local_subgraph", n, 2, 0, rss_before, rss_after_build, first_dirty_us,
    steady_total_us, checksum,
  )
}

///|
fn run_map12(n : Int) -> Unit {
  release_unused_memory()
  let i1 = @duplix.input(1)
  let i2 = @duplix.input(2)
  let i3 = @duplix.input(3)
  let i4 = @duplix.input(4)
  let i5 = @duplix.input(5)
  let i6 = @duplix.input(6)
  let i7 = @duplix.input(7)
  let i8 = @duplix.input(8)
  let i9 = @duplix.input(9)
  let i10 = @duplix.input(10)
  let i11 = @duplix.input(11)
  let i12 = @duplix.input(12)
  let n1 = i1.to_node()
  let n2 = i2.to_node()
  let n3 = i3.to_node()
  let n4 = i4.to_node()
  let n5 = i5.to_node()
  let n6 = i6.to_node()
  let n7 = i7.to_node()
  let n8 = i8.to_node()
  let n9 = i9.to_node()
  let n10 = i10.to_node()
  let n11 = i11.to_node()
  let n12 = i12.to_node()
  let live = n1.map(x => x)
  ignore(live.read())
  let rss_before = current_rss_kb()
  let mut checksum = create_dead_map12(
    n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n,
  )
  let rss_after_build = current_rss_kb()
  let (first_dirty_us, first_result) = timed_us(() => {
    i1.set(10)
    live.read()
  })
  checksum += first_result
  let (steady_total_us, steady_checksum) = measure_steady(i1, live, 1000)
  checksum += steady_checksum
  print_row(
    "map12", n, 1, 12, rss_before, rss_after_build, first_dirty_us, steady_total_us,
    checksum,
  )
}

///|
fn run_zip12(n : Int) -> Unit {
  release_unused_memory()
  let i1 = @duplix.input(1)
  let i2 = @duplix.input(2)
  let i3 = @duplix.input(3)
  let i4 = @duplix.input(4)
  let i5 = @duplix.input(5)
  let i6 = @duplix.input(6)
  let i7 = @duplix.input(7)
  let i8 = @duplix.input(8)
  let i9 = @duplix.input(9)
  let i10 = @duplix.input(10)
  let i11 = @duplix.input(11)
  let i12 = @duplix.input(12)
  let n1 = i1.to_node()
  let n2 = i2.to_node()
  let n3 = i3.to_node()
  let n4 = i4.to_node()
  let n5 = i5.to_node()
  let n6 = i6.to_node()
  let n7 = i7.to_node()
  let n8 = i8.to_node()
  let n9 = i9.to_node()
  let n10 = i10.to_node()
  let n11 = i11.to_node()
  let n12 = i12.to_node()
  let live = n1.map(x => x)
  ignore(live.read())
  let rss_before = current_rss_kb()
  let mut checksum = create_dead_zip12(
    n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n,
  )
  let rss_after_build = current_rss_kb()
  let (first_dirty_us, first_result) = timed_us(() => {
    i1.set(10)
    live.read()
  })
  checksum += first_result
  let (steady_total_us, steady_checksum) = measure_steady(i1, live, 1000)
  checksum += steady_checksum
  print_row(
    "zip12", n, 2, 12, rss_before, rss_after_build, first_dirty_us, steady_total_us,
    checksum,
  )
}

///|
fn run_baseline_ephemeral(n : Int) -> Unit {
  release_unused_memory()
  let rss_before = current_rss_kb()
  let (build_us, checksum) = timed_us(() => {
    let mut checksum = 0
    for i in 0..<n {
      let root = @duplix.input(i)
      let derived = root.to_node().map(x => x + 1)
      checksum += derived.read()
    }
    checksum
  })
  release_unused_memory()
  let rss_after_build = current_rss_kb()
  print_row(
    "baseline_ephemeral", n, 1, 1, rss_before, rss_after_build, build_us, 0L, checksum,
  )
}

///|
fn run_interleaved_map(batch_size : Int, batches : Int) -> Unit {
  release_unused_memory()
  let root = @duplix.input(1)
  let root_node = root.to_node()
  let live = root_node.map(x => x)
  ignore(live.read())
  let rss_before = current_rss_kb()
  let (total_us, checksum) = timed_us(() => {
    let mut checksum = 0
    for batch in 0..<batches {
      checksum += create_dead_map_fanout(root_node, batch_size)
      root.set(batch + 1)
      checksum += live.read()
    }
    checksum
  })
  let rss_after_build = current_rss_kb()
  print_row(
    "interleaved_map_batch",
    batch_size * batches,
    1,
    1,
    rss_before,
    rss_after_build,
    total_us,
    0L,
    checksum,
  )
}

///|
fn main {
  warmup()
  print_header()
  let sizes = [1000, 2500, 5000, 10000, 20000, 40000]
  for n in sizes {
    run_baseline_ephemeral(n)
  }
  for n in sizes {
    run_map_fanout(n)
  }
  for n in sizes {
    run_chain(n)
  }
  for n in sizes {
    run_map12(n)
  }
  for n in sizes {
    run_zip12(n)
  }
  for n in sizes {
    run_bind_branch(n)
  }
  for n in sizes {
    run_bind_live_root_subgraph(n)
  }
  for n in sizes {
    run_bind_live_local_subgraph(n)
  }
  run_interleaved_map(1000, 20)
}
