///|
fn assert_int_eq(label : String, actual : Int, expected : Int) -> Unit raise {
  if actual != expected {
    fail("\{label}: expected \{expected}, got \{actual}")
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
fn main raise {
  for i in 0..<80 {
    let offset = i * 10000
    stress_nested_bind(offset)
    stress_shared_diamond(offset)
    stress_cutoff_clean_reads(offset)
    stress_wide_map_zip(offset)
    stress_branch_flip(offset)
  }
}
