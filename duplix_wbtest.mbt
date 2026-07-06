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

///|
fn has_dirty_parent(child : DirtyFlag, parent : DirtyFlag) -> Bool {
  child.parents.any(x => x.id == parent.id)
}

///|
test "scope dispose detaches dirty edge from owned mapped node" {
  let (root, _) = input(1)
  let derived = root.map(x => x + 1)
  let scope = Scope::Scope()
  scope.add_node(derived)

  inspect(root.dirty_flag.parents.length(), content="0")
  inspect(derived.read(), content="2")
  assert_true(has_dirty_parent(root.dirty_flag, derived.dirty_flag))
  inspect(derived.childs.length(), content="1")

  scope.dispose()

  assert_true(!has_dirty_parent(root.dirty_flag, derived.dirty_flag))
  inspect(derived.childs.length(), content="0")
}

///|
test "scope dispose keeps unrelated dirty parents on shared child" {
  let (root, set_root) = input(1)
  let kept = root.map(x => x + 10)
  let disposed = root.map(x => x + 20)
  let scope = Scope::Scope()
  scope.add_node(disposed)

  inspect(kept.read(), content="11")
  inspect(disposed.read(), content="21")
  assert_true(has_dirty_parent(root.dirty_flag, kept.dirty_flag))
  assert_true(has_dirty_parent(root.dirty_flag, disposed.dirty_flag))

  scope.dispose()

  assert_true(has_dirty_parent(root.dirty_flag, kept.dirty_flag))
  assert_true(!has_dirty_parent(root.dirty_flag, disposed.dirty_flag))
  set_root(2)
  inspect(kept.read(), content="12")
}

///|
test "scope dispose recurses into sub scopes and runs cleanups" {
  let (root, _) = input(1)
  let parent_owned = root.map(x => x + 1)
  let child_owned = root.map(x => x + 2)
  let parent_scope = Scope::Scope()
  let child_scope = Scope::Scope()
  let cleanup_log : Array[String] = []
  parent_scope.add_node(parent_owned)
  child_scope.add_node(child_owned)
  parent_scope.add_scope(child_scope)
  child_scope.add_cleanup(() => cleanup_log.push("child"))
  parent_scope.add_cleanup(() => cleanup_log.push("parent"))

  inspect(parent_owned.read(), content="2")
  inspect(child_owned.read(), content="3")
  assert_true(has_dirty_parent(root.dirty_flag, parent_owned.dirty_flag))
  assert_true(has_dirty_parent(root.dirty_flag, child_owned.dirty_flag))

  parent_scope.dispose()

  assert_true(!has_dirty_parent(root.dirty_flag, parent_owned.dirty_flag))
  assert_true(!has_dirty_parent(root.dirty_flag, child_owned.dirty_flag))
  debug_inspect(cleanup_log, content="[\"child\", \"parent\"]")
}

///|
test "scope dispose detaches current bind branch" {
  let (use_left, _) = input(true)
  let (left, _) = input(1)
  let (right, _) = input(10)
  let bound = use_left.bind(enabled => if enabled { left } else { right })
  let scope = Scope::Scope()
  scope.add_node(bound)

  inspect(bound.read(), content="1")
  assert_true(has_dirty_parent(use_left.dirty_flag, bound.dirty_flag))
  assert_true(has_dirty_parent(left.dirty_flag, bound.dirty_flag))
  assert_true(!has_dirty_parent(right.dirty_flag, bound.dirty_flag))
  inspect(bound.childs.length(), content="2")

  scope.dispose()

  assert_true(!has_dirty_parent(use_left.dirty_flag, bound.dirty_flag))
  assert_true(!has_dirty_parent(left.dirty_flag, bound.dirty_flag))
  assert_true(!has_dirty_parent(right.dirty_flag, bound.dirty_flag))
  inspect(bound.childs.length(), content="0")
}
