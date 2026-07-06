///|
fn assert_int_eq(label : String, actual : Int, expected : Int) -> Unit raise {
  if actual != expected {
    fail("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
enum StressRoute {
  StressHome
  StressDetail
} derive(Eq)

///|
impl @duplix.Enumerate for StressRoute with fn tag(self) {
  match self {
    StressHome => "home"
    StressDetail => "detail"
  }
}

///|
fn stress_branch_flip(offset : Int) -> Unit raise {
  let (selector, set_selector) = @duplix.input(true)
  let (left, set_left) = @duplix.input(offset)
  let (right, set_right) = @duplix.input(offset + 1000)
  let left_node = left
  let right_node = right
  let left_mapped = left_node.map(x => x + 1)
  let right_mapped = right_node.map(x => x + 1)
  let selected = selector.bind(use_left => {
    if use_left {
      left_mapped
    } else {
      right_mapped
    }
  })
  let observed = selected.map(x => x * 2)

  for step in 0..<12 {
    let use_left = step % 2 == 0
    set_selector(use_left)
    set_left(offset + step)
    set_right(offset + 1000 + step)
    let expected = if use_left {
      (offset + step + 1) * 2
    } else {
      (offset + 1000 + step + 1) * 2
    }
    assert_int_eq("branch flip step \{step}", observed.read(), expected)
  }
}

///|
fn stress_nested_bind(offset : Int) -> Unit raise {
  let (outer_selector, set_outer_selector) = @duplix.input(true)
  let (inner_selector, set_inner_selector) = @duplix.input(true)
  let (x, set_x) = @duplix.input(offset)
  let (y, set_y) = @duplix.input(offset + 100)
  let (z, set_z) = @duplix.input(offset + 1000)
  let x_mapped = x.map(x => x + 1)
  let y_mapped = y.map(y => y + 2)
  let z_mapped = z.map(z => z + 3)
  let inner = inner_selector.bind(use_x => {
    if use_x {
      x_mapped
    } else {
      y_mapped
    }
  })
  let outer = outer_selector.bind(use_inner => {
    if use_inner {
      inner
    } else {
      z_mapped
    }
  })
  let doubled = outer.map(x => x * 2)

  assert_int_eq("nested initial", doubled.read(), (offset + 1) * 2)
  set_inner_selector(false)
  assert_int_eq("nested inner false", doubled.read(), (offset + 102) * 2)
  set_outer_selector(false)
  assert_int_eq("nested outer false", doubled.read(), (offset + 1003) * 2)
  set_y(offset + 200)
  assert_int_eq("nested inactive update", doubled.read(), (offset + 1003) * 2)
  set_z(offset + 2000)
  assert_int_eq("nested active update", doubled.read(), (offset + 2003) * 2)
  set_outer_selector(true)
  assert_int_eq("nested outer true", doubled.read(), (offset + 202) * 2)
  set_inner_selector(true)
  set_x(offset + 10)
  assert_int_eq("nested inner true", doubled.read(), (offset + 11) * 2)
}

///|
fn stress_shared_diamond(offset : Int) -> Unit raise {
  let (source, set_source) = @duplix.input(offset)
  let source_node = source
  let left = source_node.map(x => x + 10)
  let right = source_node.map(x => x + 20)
  let sum = left.map2(right, (left, right) => left + right)
  let fanout = sum.map2(left, (sum, left) => sum + left)

  for step in 0..<8 {
    set_source(offset + step)
    assert_int_eq(
      "shared diamond step \{step}",
      fanout.read(),
      3 * (offset + step) + 40,
    )
  }
}

///|
fn stress_cutoff_clean_reads(offset : Int) -> Unit raise {
  let (source, set_source) = @duplix.input(offset)
  let constant = source.map(_ => 10)
  let downstream = constant.map(x => x * 3)

  assert_int_eq("cutoff initial", downstream.read(), 30)
  assert_int_eq("cutoff clean initial", downstream.read(), 30)
  for step in 0..<10 {
    set_source(offset + step)
    assert_int_eq("cutoff dirty step \{step}", downstream.read(), 30)
    assert_int_eq("cutoff clean step \{step}", downstream.read(), 30)
  }
}

///|
fn stress_wide_map_zip(offset : Int) -> Unit raise {
  let (x1, set_x1) = @duplix.input(offset + 1)
  let (x2, _) = @duplix.input(offset + 2)
  let (x3, _) = @duplix.input(offset + 3)
  let (x4, _) = @duplix.input(offset + 4)
  let (x5, _) = @duplix.input(offset + 5)
  let (x6, _) = @duplix.input(offset + 6)
  let (x7, _) = @duplix.input(offset + 7)
  let (x8, _) = @duplix.input(offset + 8)
  let (x9, _) = @duplix.input(offset + 9)
  let (x10, _) = @duplix.input(offset + 10)
  let (x11, _) = @duplix.input(offset + 11)
  let (x12, set_x12) = @duplix.input(offset + 12)
  let (y1, set_y1) = @duplix.input(offset + 1)
  let (y2, _) = @duplix.input(offset + 2)
  let (y3, _) = @duplix.input(offset + 3)
  let (y4, _) = @duplix.input(offset + 4)
  let (y5, _) = @duplix.input(offset + 5)
  let (y6, _) = @duplix.input(offset + 6)
  let (y7, _) = @duplix.input(offset + 7)
  let (y8, _) = @duplix.input(offset + 8)
  let (y9, _) = @duplix.input(offset + 9)
  let (y10, _) = @duplix.input(offset + 10)
  let (y11, _) = @duplix.input(offset + 11)
  let (y12, set_y12) = @duplix.input(offset + 12)
  let sum = x1.map12(x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, (
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
  ) => a + b + c + d + e + f + g + h + i + j + k + l)
  let zipped = y1.zip12(y2, y3, y4, y5, y6, y7, y8, y9, y10, y11, y12)
  let zip_sum = zipped.map(items => {
    let (a, b, c, d, e, f, g, h, i, j, k, l) = items
    a + b + c + d + e + f + g + h + i + j + k + l
  })

  assert_int_eq("wide map initial", sum.read(), 12 * offset + 78)
  assert_int_eq("wide zip initial", zip_sum.read(), 12 * offset + 78)
  set_x1(offset + 20)
  set_x12(offset + 40)
  set_y1(offset + 20)
  set_y12(offset + 40)
  assert_int_eq("wide map update", sum.read(), 12 * offset + 125)
  assert_int_eq("wide zip update", zip_sum.read(), 12 * offset + 125)
}

///|
fn stress_assoc(offset : Int) -> Unit raise {
  let (source, set_source) = @duplix.input(
    Map([(1, offset + 10), (2, offset + 20)]),
  )
  let mut build_runs = 0
  let mut compute_runs = 0
  let mut output_runs = 0
  let assoc = source.assoc((k, value) => {
    build_runs += 1
    value.map(v => {
      compute_runs += 1
      k + v * 10
    })
  })
  let total = assoc.map(xs => {
    output_runs += 1
    let mut sum = 0
    for x in xs {
      sum += x
    }
    sum
  })

  assert_int_eq("assoc initial", total.read(), 20 * offset + 303)
  assert_int_eq("assoc builds initial", build_runs, 2)
  assert_int_eq("assoc computes initial", compute_runs, 2)
  assert_int_eq("assoc outputs initial", output_runs, 1)

  set_source(Map([(1, offset + 11), (2, offset + 20)]))
  assert_int_eq("assoc update one key", total.read(), 20 * offset + 313)
  assert_int_eq("assoc builds update one key", build_runs, 2)
  assert_int_eq("assoc computes update one key", compute_runs, 3)
  assert_int_eq("assoc outputs update one key", output_runs, 2)

  set_source(Map([(1, offset + 11)]))
  assert_int_eq("assoc remove key", total.read(), 10 * offset + 111)
  assert_int_eq("assoc builds remove key", build_runs, 2)
  assert_int_eq("assoc computes remove key", compute_runs, 3)
  assert_int_eq("assoc outputs remove key", output_runs, 3)

  set_source(Map([(1, offset + 11), (3, offset + 30)]))
  assert_int_eq("assoc add key", total.read(), 20 * offset + 414)
  assert_int_eq("assoc builds add key", build_runs, 3)
  assert_int_eq("assoc computes add key", compute_runs, 4)
  assert_int_eq("assoc outputs add key", output_runs, 4)

  set_source(Map([(1, offset + 11), (3, offset + 30)]))
  assert_int_eq("assoc same map", total.read(), 20 * offset + 414)
  assert_int_eq("assoc builds same map", build_runs, 3)
  assert_int_eq("assoc computes same map", compute_runs, 4)
  assert_int_eq("assoc outputs same map", output_runs, 4)

  set_source(Map([(2, offset + 25), (3, offset + 30)]))
  assert_int_eq("assoc replace key", total.read(), 20 * offset + 555)
  assert_int_eq("assoc builds replace key", build_runs, 4)
  assert_int_eq("assoc computes replace key", compute_runs, 5)
  assert_int_eq("assoc outputs replace key", output_runs, 5)
}

///|
fn stress_enumerate(offset : Int) -> Unit raise {
  let (route, set_route) = @duplix.input(StressHome)
  let mut home_state : ((Int) -> Unit)? = None
  let mut detail_state : ((Int) -> Unit)? = None
  let mut build_runs = 0
  let mut home_runs = 0
  let mut detail_runs = 0
  let mut output_runs = 0
  let selected = route.enumerate(route => {
    build_runs += 1
    match route {
      StressHome => {
        let (state, set_state) = @duplix.input(offset + 1)
        home_state = Some(set_state)
        state.map(x => {
          home_runs += 1
          x + 100
        })
      }
      StressDetail => {
        let (state, set_state) = @duplix.input(offset + 10)
        detail_state = Some(set_state)
        state.map(x => {
          detail_runs += 1
          x + 1000
        })
      }
    }
  })
  let output = selected.map(x => {
    output_runs += 1
    x * 2
  })

  assert_int_eq("enumerate initial", output.read(), 2 * offset + 202)
  assert_int_eq("enumerate builds initial", build_runs, 1)
  assert_int_eq("enumerate home initial", home_runs, 1)
  assert_int_eq("enumerate detail initial", detail_runs, 0)
  assert_int_eq("enumerate outputs initial", output_runs, 1)

  guard home_state is Some(set_home_state) else {
    fail("expected cached home state")
  }
  set_home_state(offset + 2)
  assert_int_eq("enumerate home update", output.read(), 2 * offset + 204)
  assert_int_eq("enumerate builds home update", build_runs, 1)
  assert_int_eq("enumerate home update runs", home_runs, 2)
  assert_int_eq("enumerate detail update runs", detail_runs, 0)
  assert_int_eq("enumerate output home update", output_runs, 2)

  set_route(StressDetail)
  assert_int_eq("enumerate detail switch", output.read(), 2 * offset + 2020)
  assert_int_eq("enumerate builds detail switch", build_runs, 2)
  assert_int_eq("enumerate home detail switch", home_runs, 2)
  assert_int_eq("enumerate detail detail switch", detail_runs, 1)
  assert_int_eq("enumerate output detail switch", output_runs, 3)

  set_home_state(offset + 3)
  assert_int_eq(
    "enumerate inactive home update",
    output.read(),
    2 * offset + 2020,
  )
  assert_int_eq("enumerate builds inactive home update", build_runs, 2)
  assert_int_eq("enumerate home inactive update", home_runs, 2)
  assert_int_eq("enumerate detail inactive update", detail_runs, 1)
  assert_int_eq("enumerate output inactive update", output_runs, 3)

  guard detail_state is Some(set_detail_state) else {
    fail("expected cached detail state")
  }
  set_detail_state(offset + 20)
  assert_int_eq("enumerate detail update", output.read(), 2 * offset + 2040)
  assert_int_eq("enumerate builds detail update", build_runs, 2)
  assert_int_eq("enumerate home detail update", home_runs, 2)
  assert_int_eq("enumerate detail update runs", detail_runs, 2)
  assert_int_eq("enumerate output detail update", output_runs, 4)

  set_route(StressHome)
  assert_int_eq("enumerate home switch back", output.read(), 2 * offset + 206)
  assert_int_eq("enumerate builds home switch back", build_runs, 2)
  assert_int_eq("enumerate home switch back runs", home_runs, 3)
  assert_int_eq("enumerate detail switch back runs", detail_runs, 2)
  assert_int_eq("enumerate output home switch back", output_runs, 5)
}

///|
fn main raise {
  for i in 0..<80 {
    let offset = i * 10000
    stress_nested_bind(offset)
    stress_shared_diamond(offset)
    stress_cutoff_clean_reads(offset)
    stress_wide_map_zip(offset)
    stress_assoc(offset)
    stress_enumerate(offset)
    stress_branch_flip(offset)
  }
}
