// Blackbox tests run against the package's public API. Use `@duplix` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "propagate changed input" {
  let (x, set_x) = @duplix.input(10)
  let y = x.map(x => x + 1).map(x => "\{x}")

  inspect(y.read(), content="11")
  set_x(20)
  inspect(y.read(), content="21")
}

///|
test "cutoff skips unchanged downstream" {
  let (x, set_x) = @duplix.input(10)
  let mut parent_runs = 0
  let mut child_runs = 0
  let parent = x.map(_ => {
    parent_runs = parent_runs + 1
    10
  })
  let child = parent.map(x => {
    child_runs = child_runs + 1
    "\{x}"
  })

  inspect(child.read(), content="10")
  inspect(parent_runs, content="1")
  inspect(child_runs, content="1")
  set_x(20)
  inspect(child.read(), content="10")
  inspect(parent_runs, content="2")
  inspect(child_runs, content="1")
}

///|
test "setting same input value cuts off mapped parent" {
  let (x, set_x) = @duplix.input(10)
  let mut parent_runs = 0
  let mut child_runs = 0
  let parent = x.map(x => {
    parent_runs = parent_runs + 1
    x + 1
  })
  let child = parent.map(x => {
    child_runs = child_runs + 1
    "\{x}"
  })

  inspect(child.read(), content="11")
  inspect(parent_runs, content="1")
  inspect(child_runs, content="1")
  set_x(10)
  inspect(child.read(), content="11")
  inspect(parent_runs, content="1")
  inspect(child_runs, content="1")
}

///|
test "clean reads do not recompute" {
  let (x, _) = @duplix.input(1)
  let mut runs = 0
  let y = x.map(x => {
    runs = runs + 1
    x + 1
  })

  inspect(y.read(), content="2")
  inspect(y.read(), content="2")
  inspect(y.read(), content="2")
  inspect(runs, content="1")
}

///|
test "bind switches dynamic child and detaches inactive child" {
  let (use_left, set_use_left) = @duplix.input(true)
  let (left_input, set_left_input) = @duplix.input(1)
  let (right_input, set_right_input) = @duplix.input(10)
  let mut choose_runs = 0
  let mut left_runs = 0
  let mut right_runs = 0
  let mut output_runs = 0
  let left = left_input.map(x => {
    left_runs = left_runs + 1
    x + 100
  })
  let right = right_input.map(x => {
    right_runs = right_runs + 1
    x + 1000
  })
  let bound = use_left.bind(enabled => {
    choose_runs = choose_runs + 1
    if enabled {
      left
    } else {
      right
    }
  })
  let output = bound.map(x => {
    output_runs = output_runs + 1
    x * 2
  })

  inspect(output.read(), content="202")
  inspect(choose_runs, content="1")
  inspect(left_runs, content="1")
  inspect(right_runs, content="0")
  inspect(output_runs, content="1")

  set_left_input(2)
  inspect(output.read(), content="204")
  inspect(choose_runs, content="2")
  inspect(left_runs, content="2")
  inspect(right_runs, content="0")
  inspect(output_runs, content="2")

  set_use_left(false)
  inspect(output.read(), content="2020")
  inspect(choose_runs, content="3")
  inspect(left_runs, content="2")
  inspect(right_runs, content="1")
  inspect(output_runs, content="3")

  set_left_input(3)
  inspect(output.read(), content="2020")
  inspect(choose_runs, content="3")
  inspect(left_runs, content="2")
  inspect(right_runs, content="1")
  inspect(output_runs, content="3")

  set_right_input(20)
  inspect(output.read(), content="2040")
  inspect(choose_runs, content="4")
  inspect(left_runs, content="2")
  inspect(right_runs, content="2")
  inspect(output_runs, content="4")

  set_use_left(true)
  inspect(output.read(), content="206")
  inspect(choose_runs, content="5")
  inspect(left_runs, content="3")
  inspect(right_runs, content="2")
  inspect(output_runs, content="5")

  set_right_input(30)
  inspect(output.read(), content="206")
  inspect(choose_runs, content="5")
  inspect(left_runs, content="3")
  inspect(right_runs, content="2")
  inspect(output_runs, content="5")
}

///|
test "bind cuts off downstream when switched child has same value" {
  let (use_left, set_use_left) = @duplix.input(true)
  let (left_input, _) = @duplix.input(10)
  let (right_input, set_right_input) = @duplix.input(10)
  let mut choose_runs = 0
  let mut output_runs = 0
  let bound = use_left.bind(enabled => {
    choose_runs = choose_runs + 1
    if enabled {
      left_input
    } else {
      right_input
    }
  })
  let output = bound.map(x => {
    output_runs = output_runs + 1
    x + 1
  })

  inspect(output.read(), content="11")
  inspect(choose_runs, content="1")
  inspect(output_runs, content="1")
  set_use_left(false)
  inspect(output.read(), content="11")
  inspect(choose_runs, content="2")
  inspect(output_runs, content="1")
  set_right_input(11)
  inspect(output.read(), content="12")
  inspect(choose_runs, content="3")
  inspect(output_runs, content="2")
}

///|
test "map2 recomputes when one parent changes" {
  let (x, set_x) = @duplix.input(1)
  let (y, set_y) = @duplix.input(10)
  let mut runs = 0
  let sum = x.map2(y, (x, y) => {
    runs = runs + 1
    x + y
  })

  inspect(sum.read(), content="11")
  inspect(runs, content="1")
  set_x(2)
  inspect(sum.read(), content="12")
  inspect(runs, content="2")
  set_y(20)
  inspect(sum.read(), content="22")
  inspect(runs, content="3")
}

///|
test "assoc reuses keyed child graphs" {
  let (dict, set_dict) = @duplix.input(Map([(1, 10), (2, 20)]))
  let mut created = 0
  let mut runs = 0
  let values = dict.assoc((key, value) => {
    created = created + 1
    value.map(v => {
      runs = runs + 1
      key * 100 + v
    })
  })

  debug_inspect(values.read(), content="[110, 220]")
  inspect(created, content="2")
  inspect(runs, content="2")

  set_dict(Map([(1, 10), (2, 21)]))
  debug_inspect(values.read(), content="[110, 221]")
  inspect(created, content="2")
  inspect(runs, content="3")

  set_dict(Map([(2, 21), (3, 30)]))
  debug_inspect(values.read(), content="[221, 330]")
  inspect(created, content="3")
  inspect(runs, content="4")

  set_dict(Map([(3, 30)]))
  debug_inspect(values.read(), content="[330]")
  inspect(created, content="3")
  inspect(runs, content="4")

  set_dict(Map([(1, 11), (3, 30)]))
  debug_inspect(values.read(), content="[111, 330]")
  inspect(created, content="4")
  inspect(runs, content="5")
}

///|
test "assoc reuses entries and aggregates active results" {
  let (source, set_source) = @duplix.input(Map([(1, 10), (2, 20)]))
  let mut build_runs = 0
  let mut compute_runs = 0
  let mut output_runs = 0
  let assoc = source.assoc((k, value) => {
    build_runs = build_runs + 1
    value.map1(v => {
      compute_runs = compute_runs + 1
      k + v * 10
    })
  })
  let total = assoc.map1(xs => {
    output_runs = output_runs + 1
    let mut sum = 0
    for x in xs {
      sum = sum + x
    }
    sum
  })

  inspect(total.read(), content="303")
  inspect(build_runs, content="2")
  inspect(compute_runs, content="2")
  inspect(output_runs, content="1")

  set_source(Map([(1, 11), (2, 20)]))
  inspect(total.read(), content="313")
  inspect(build_runs, content="2")
  inspect(compute_runs, content="3")
  inspect(output_runs, content="2")

  set_source(Map([(1, 11)]))
  inspect(total.read(), content="111")
  inspect(build_runs, content="2")
  inspect(compute_runs, content="3")
  inspect(output_runs, content="3")

  set_source(Map([(1, 11), (3, 30)]))
  inspect(total.read(), content="414")
  inspect(build_runs, content="3")
  inspect(compute_runs, content="4")
  inspect(output_runs, content="4")

  set_source(Map([(1, 11), (3, 30)]))
  inspect(total.read(), content="414")
  inspect(build_runs, content="3")
  inspect(compute_runs, content="4")
  inspect(output_runs, content="4")

  set_source(Map([(2, 25), (3, 30)]))
  inspect(total.read(), content="555")
  inspect(build_runs, content="4")
  inspect(compute_runs, content="5")
  inspect(output_runs, content="5")
}

///|
enum Route {
  Home
  Detail
} derive(Eq)

///|
impl @duplix.Enumerate for Route with fn tag(self) {
  match self {
    Home => "home"
    Detail => "detail"
  }
}

///|
test "enumerate caches branches and switches by tag" {
  let (route, set_route) = @duplix.input(Home)
  let (home_input, set_home_input) = @duplix.input(1)
  let (detail_input, _) = @duplix.input(10)
  let mut build_runs = 0
  let mut home_runs = 0
  let mut detail_runs = 0
  let mut output_runs = 0
  let selected = route.enumerate(route => {
    build_runs = build_runs + 1
    match route {
      Home =>
        home_input.map1(x => {
          home_runs = home_runs + 1
          x + 100
        })
      Detail =>
        detail_input.map1(x => {
          detail_runs = detail_runs + 1
          x + 1000
        })
    }
  })
  let output = selected.map1(x => {
    output_runs = output_runs + 1
    x * 2
  })

  inspect(output.read(), content="202")
  inspect(build_runs, content="1")
  inspect(home_runs, content="1")
  inspect(detail_runs, content="0")
  inspect(output_runs, content="1")

  set_home_input(2)
  inspect(output.read(), content="204")
  inspect(build_runs, content="1")
  inspect(home_runs, content="2")
  inspect(detail_runs, content="0")
  inspect(output_runs, content="2")

  set_route(Detail)
  inspect(output.read(), content="2020")
  inspect(build_runs, content="2")
  inspect(home_runs, content="2")
  inspect(detail_runs, content="1")
  inspect(output_runs, content="3")

  set_home_input(3)
  inspect(output.read(), content="2020")
  inspect(build_runs, content="2")
  inspect(home_runs, content="2")
  inspect(detail_runs, content="1")
  inspect(output_runs, content="3")

  set_route(Home)
  inspect(output.read(), content="206")
  inspect(build_runs, content="2")
  inspect(home_runs, content="3")
  inspect(detail_runs, content="1")
  inspect(output_runs, content="4")
}

///|
test "enumerate preserves state created inside cached page branches" {
  let (route, set_route) = @duplix.input(Home)
  let mut home_state : ((Int) -> Unit)? = None
  let mut detail_state : ((Int) -> Unit)? = None
  let mut build_runs = 0
  let mut home_runs = 0
  let mut detail_runs = 0
  let mut output_runs = 0
  let selected = route.enumerate(route => {
    build_runs = build_runs + 1
    match route {
      Home => {
        let (state, set_state) = @duplix.input(1)
        home_state = Some(set_state)
        state.map1(x => {
          home_runs = home_runs + 1
          x + 100
        })
      }
      Detail => {
        let (state, set_state) = @duplix.input(10)
        detail_state = Some(set_state)
        state.map1(x => {
          detail_runs = detail_runs + 1
          x + 1000
        })
      }
    }
  })
  let output = selected.map1(x => {
    output_runs = output_runs + 1
    x * 2
  })

  inspect(output.read(), content="202")
  inspect(build_runs, content="1")
  inspect(home_runs, content="1")
  inspect(detail_runs, content="0")
  inspect(output_runs, content="1")

  guard home_state is Some(set_home_state) else {
    fail("expected cached home state")
  }
  set_home_state(2)
  inspect(output.read(), content="204")
  inspect(build_runs, content="1")
  inspect(home_runs, content="2")
  inspect(detail_runs, content="0")
  inspect(output_runs, content="2")

  set_route(Detail)
  inspect(output.read(), content="2020")
  inspect(build_runs, content="2")
  inspect(home_runs, content="2")
  inspect(detail_runs, content="1")
  inspect(output_runs, content="3")

  set_home_state(3)
  inspect(output.read(), content="2020")
  inspect(build_runs, content="2")
  inspect(home_runs, content="2")
  inspect(detail_runs, content="1")
  inspect(output_runs, content="3")

  guard detail_state is Some(set_detail_state) else {
    fail("expected cached detail state")
  }
  set_detail_state(20)
  inspect(output.read(), content="2040")
  inspect(build_runs, content="2")
  inspect(home_runs, content="2")
  inspect(detail_runs, content="2")
  inspect(output_runs, content="4")

  set_route(Home)
  inspect(output.read(), content="206")
  inspect(build_runs, content="2")
  inspect(home_runs, content="3")
  inspect(detail_runs, content="2")
  inspect(output_runs, content="5")
}

///|
test "map12 wrapper" {
  let (x1, _) = @duplix.input(1)
  let (x2, _) = @duplix.input(2)
  let (x3, _) = @duplix.input(3)
  let (x4, _) = @duplix.input(4)
  let (x5, _) = @duplix.input(5)
  let (x6, _) = @duplix.input(6)
  let (x7, _) = @duplix.input(7)
  let (x8, _) = @duplix.input(8)
  let (x9, _) = @duplix.input(9)
  let (x10, _) = @duplix.input(10)
  let (x11, _) = @duplix.input(11)
  let (x12, set_x12) = @duplix.input(12)
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

  inspect(sum.read(), content="78")
  set_x12(20)
  inspect(sum.read(), content="86")
}

///|
test "zip12 wrapper" {
  let (x1, _) = @duplix.input(1)
  let (x2, _) = @duplix.input(2)
  let (x3, _) = @duplix.input(3)
  let (x4, _) = @duplix.input(4)
  let (x5, _) = @duplix.input(5)
  let (x6, _) = @duplix.input(6)
  let (x7, _) = @duplix.input(7)
  let (x8, _) = @duplix.input(8)
  let (x9, _) = @duplix.input(9)
  let (x10, _) = @duplix.input(10)
  let (x11, _) = @duplix.input(11)
  let (x12, set_x12) = @duplix.input(12)
  let tuple = x1.zip12(x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12)
  let sum = tuple.map(items => {
    let (a, b, c, d, e, f, g, h, i, j, k, l) = items
    a + b + c + d + e + f + g + h + i + j + k + l
  })

  inspect(sum.read(), content="78")
  set_x12(20)
  inspect(sum.read(), content="86")
}
