// // Whitebox tests run within the package scope.
// // Use them to validate internal helpers or invariants.
// // Keep them focused; public behavior belongs in `_test.mbt`.

// ///|
// // `child.parents` stores dirty edges in the child -> parent direction.
// fn has_dirty_parent(child : DirtyFlag, parent : DirtyFlag) -> Bool {
//   child.parents.any(x => x.id == parent.id)
// }

// ///|
// test "map2 records only child to parent dirty edges" {
//   let x = input(1)
//   let y = input(2)
//   let x_node = x.to_node()
//   let y_node = y.to_node()
//   let sum = x_node.map2(y_node, (x, y) => x + y)

//   assert_true(has_dirty_parent(x_node.dirty_flag, sum.dirty_flag))
//   assert_true(has_dirty_parent(y_node.dirty_flag, sum.dirty_flag))
//   assert_true(!has_dirty_parent(sum.dirty_flag, x_node.dirty_flag))
//   assert_true(!has_dirty_parent(sum.dirty_flag, y_node.dirty_flag))
//   inspect(sum.read(), content="3")
// }

// ///|
// test "bind detaches previous dynamic dirty parent" {
//   let use_left = input(true)
//   let left_input = input(1)
//   let right_input = input(10)
//   let left = left_input.to_node().map(x => x + 100)
//   let right = right_input.to_node().map(x => x + 1000)
//   let bound = use_left
//     .to_node()
//     .bind(enabled => if enabled { left } else { right })

//   inspect(bound.read(), content="101")
//   assert_true(has_dirty_parent(left.dirty_flag, bound.dirty_flag))
//   assert_true(!has_dirty_parent(right.dirty_flag, bound.dirty_flag))

//   use_left.set(false)
//   inspect(bound.read(), content="1010")
//   assert_true(!has_dirty_parent(left.dirty_flag, bound.dirty_flag))
//   assert_true(has_dirty_parent(right.dirty_flag, bound.dirty_flag))
// }

// ///|
// test "bind keeps static selector dirty parent when selector was dynamic child" {
//   let selector = input(1)
//   let fallback = input(10)
//   let selector_node = selector.to_node()
//   let fallback_node = fallback.to_node()
//   let bound = selector_node.bind(x => {
//     if x == 1 {
//       selector_node
//     } else {
//       fallback_node
//     }
//   })

//   inspect(bound.read(), content="1")
//   assert_true(has_dirty_parent(selector_node.dirty_flag, bound.dirty_flag))

//   selector.set(2)
//   inspect(bound.read(), content="10")
//   assert_true(has_dirty_parent(selector_node.dirty_flag, bound.dirty_flag))
//   assert_true(has_dirty_parent(fallback_node.dirty_flag, bound.dirty_flag))
// }
