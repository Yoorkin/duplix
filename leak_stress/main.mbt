///|
fn assert_int_eq(label : String, actual : Int, expected : Int) -> Unit raise {
  if actual != expected {
    fail("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
fn stress_branch_flip(offset : Int) -> Unit raise {
  let selector = @acyclic.input(true)
  let left = @acyclic.input(offset)
  let right = @acyclic.input(offset + 1000)
  let left_node = left.to_node()
  let right_node = right.to_node()
  let left_mapped = left_node.map(x => x + 1)
  let right_mapped = right_node.map(x => x + 1)
  let selected = selector
    .to_node()
    .bind(use_left => if use_left { left_mapped } else { right_mapped })
  let observed = selected.map(x => x * 2)

  for step in 0..<12 {
    let use_left = step % 2 == 0
    selector.set(use_left)
    left.set(offset + step)
    right.set(offset + 1000 + step)
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
  let outer_selector = @acyclic.input(true)
  let inner_selector = @acyclic.input(true)
  let x = @acyclic.input(offset)
  let y = @acyclic.input(offset + 100)
  let z = @acyclic.input(offset + 1000)
  let x_mapped = x.to_node().map(x => x + 1)
  let y_mapped = y.to_node().map(y => y + 2)
  let z_mapped = z.to_node().map(z => z + 3)
  let inner = inner_selector
    .to_node()
    .bind(use_x => if use_x { x_mapped } else { y_mapped })
  let outer = outer_selector
    .to_node()
    .bind(use_inner => if use_inner { inner } else { z_mapped })
  let doubled = outer.map(x => x * 2)

  assert_int_eq("nested initial", doubled.read(), (offset + 1) * 2)
  inner_selector.set(false)
  assert_int_eq("nested inner false", doubled.read(), (offset + 102) * 2)
  outer_selector.set(false)
  assert_int_eq("nested outer false", doubled.read(), (offset + 1003) * 2)
  y.set(offset + 200)
  assert_int_eq("nested inactive update", doubled.read(), (offset + 1003) * 2)
  z.set(offset + 2000)
  assert_int_eq("nested active update", doubled.read(), (offset + 2003) * 2)
  outer_selector.set(true)
  assert_int_eq("nested outer true", doubled.read(), (offset + 202) * 2)
  inner_selector.set(true)
  x.set(offset + 10)
  assert_int_eq("nested inner true", doubled.read(), (offset + 11) * 2)
}

///|
fn stress_shared_diamond(offset : Int) -> Unit raise {
  let source = @acyclic.input(offset)
  let source_node = source.to_node()
  let left = source_node.map(x => x + 10)
  let right = source_node.map(x => x + 20)
  let sum = left.map2(right, (left, right) => left + right)
  let fanout = sum.map2(left, (sum, left) => sum + left)

  for step in 0..<8 {
    source.set(offset + step)
    assert_int_eq(
      "shared diamond step \{step}",
      fanout.read(),
      3 * (offset + step) + 40,
    )
  }
}

///|
fn stress_cutoff_clean_reads(offset : Int) -> Unit raise {
  let source = @acyclic.input(offset)
  let constant = source.to_node().map(_ => 10)
  let downstream = constant.map(x => x * 3)

  assert_int_eq("cutoff initial", downstream.read(), 30)
  assert_int_eq("cutoff clean initial", downstream.read(), 30)
  for step in 0..<10 {
    source.set(offset + step)
    assert_int_eq("cutoff dirty step \{step}", downstream.read(), 30)
    assert_int_eq("cutoff clean step \{step}", downstream.read(), 30)
  }
}

///|
fn stress_wide_map_zip(offset : Int) -> Unit raise {
  let x1 = @acyclic.input(offset + 1)
  let x2 = @acyclic.input(offset + 2)
  let x3 = @acyclic.input(offset + 3)
  let x4 = @acyclic.input(offset + 4)
  let x5 = @acyclic.input(offset + 5)
  let x6 = @acyclic.input(offset + 6)
  let x7 = @acyclic.input(offset + 7)
  let x8 = @acyclic.input(offset + 8)
  let x9 = @acyclic.input(offset + 9)
  let x10 = @acyclic.input(offset + 10)
  let x11 = @acyclic.input(offset + 11)
  let x12 = @acyclic.input(offset + 12)
  let y1 = @acyclic.input(offset + 1)
  let y2 = @acyclic.input(offset + 2)
  let y3 = @acyclic.input(offset + 3)
  let y4 = @acyclic.input(offset + 4)
  let y5 = @acyclic.input(offset + 5)
  let y6 = @acyclic.input(offset + 6)
  let y7 = @acyclic.input(offset + 7)
  let y8 = @acyclic.input(offset + 8)
  let y9 = @acyclic.input(offset + 9)
  let y10 = @acyclic.input(offset + 10)
  let y11 = @acyclic.input(offset + 11)
  let y12 = @acyclic.input(offset + 12)
  let sum = x1
    .to_node()
    .map12(
      x2.to_node(),
      x3.to_node(),
      x4.to_node(),
      x5.to_node(),
      x6.to_node(),
      x7.to_node(),
      x8.to_node(),
      x9.to_node(),
      x10.to_node(),
      x11.to_node(),
      x12.to_node(),
      (a, b, c, d, e, f, g, h, i, j, k, l) => {
        a + b + c + d + e + f + g + h + i + j + k + l
      },
    )
  let zipped = y1
    .to_node()
    .zip12(
      y2.to_node(),
      y3.to_node(),
      y4.to_node(),
      y5.to_node(),
      y6.to_node(),
      y7.to_node(),
      y8.to_node(),
      y9.to_node(),
      y10.to_node(),
      y11.to_node(),
      y12.to_node(),
    )
  let zip_sum = zipped.map(items => {
    let (a, b, c, d, e, f, g, h, i, j, k, l) = items
    a + b + c + d + e + f + g + h + i + j + k + l
  })

  assert_int_eq("wide map initial", sum.read(), 12 * offset + 78)
  assert_int_eq("wide zip initial", zip_sum.read(), 12 * offset + 78)
  x1.set(offset + 20)
  x12.set(offset + 40)
  y1.set(offset + 20)
  y12.set(offset + 40)
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
