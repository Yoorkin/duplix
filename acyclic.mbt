// Main package file for your library code.
// Put public APIs and shared helpers here.
// Keep blocks small and focused for easy refactors.

///|
let uuid : Ref[Int] = Ref(0)

///|
fn get_uuid() -> Int {
  uuid.val += 1
  uuid.val
}

///|
trait ErasedNode {
  /// child1 ---+
  ///           |----derived----> parent
  /// child2 ---+
  ///
  /// parent_expr = child1_expr + child2_expr
  fn get_id(Self) -> Int
  fn childs(Self) -> Array[&ErasedNode]
  fn dirty_flag(Self) -> DirtyFlag
  fn recompute(Self, Set[Int]) -> Unit
}

///|
///       child ---derived---> parent
/// 
/// 
///          Node(parent) ---ref---> Node(child)
///              |                        |
///             ref                      ref
///              |                        |
///              v                        v
///     DirtyFlag(parent) <---ref--- DirtyFlag(child)
struct Node[T] {
  id : Int
  mut value : T?
  mut compute : () -> T
  childs : Array[&ErasedNode]
  dirty_flag : DirtyFlag
}

///|
impl[T] Eq for Node[T] with fn equal(a, b) {
  a.id == b.id
}

///|
impl[T] Compare for Node[T] with fn compare(a, b) {
  a.id.compare(b.id)
}

///|
impl[T : Eq] ErasedNode for Node[T] with fn get_id(self) {
  self.id
}

///|
impl[T : Eq] ErasedNode for Node[T] with fn childs(self) {
  self.childs
}

///|
impl[T : Eq] ErasedNode for Node[T] with fn dirty_flag(self) {
  self.dirty_flag
}

///|
impl[T : Eq] ErasedNode for Node[T] with fn recompute(self, changed) {
  match self.value {
    None => {
      let new = (self.compute)()
      self.value = Some(new)
      changed.add(self.id)
    }
    Some(old) if self.dirty_flag().dirty => {
      if self.childs is [] || self.childs.any(x => changed.contains(x.get_id())) {
        let new = (self.compute)()
        if !Eq::equal(old, new) {
          changed.add(self.id)
        }
        self.value = Some(new)
      }
      self.dirty_flag().dirty = false
    }
    Some(_) => ()
  }
}

///|
/// DirtyFlag(parent) <--ref--- DirtyFlag(child)
struct DirtyFlag {
  id : Int
  mut dirty : Bool
  parents : Array[DirtyFlag]
}

///|
pub impl Eq for DirtyFlag with fn equal(a, b) {
  a.id == b.id
}

///|
pub impl Compare for DirtyFlag with fn compare(a, b) {
  a.id.compare(b.id)
}

///|
struct Input[T](Node[T])

///|
pub fn[T] input(x : T) -> Input[T] {
  {
    id: get_uuid(),
    value: None,
    compute: () => x,
    childs: [],
    dirty_flag: { dirty: true, parents: [], id: get_uuid() },
  }
}

///|
/// child_a ---derived---> parent_b
pub fn[A : Eq, B] Node::map(a : Node[A], f : (A) -> B) -> Node[B] {
  let dirty_b = { dirty: true, parents: [], id: get_uuid() }
  a.dirty_flag.parents.push(dirty_b)
  {
    id: get_uuid(),
    value: None,
    compute: () => f(a.value.unwrap()),
    childs: [a],
    dirty_flag: dirty_b,
  }
}

///|
pub fn[A : Eq, B : Eq] Node::bind(a : Node[A], f : (A) -> Node[B]) -> Node[B] {
  let prev_dirty_sub : DirtyFlag? = None
  {
    id: get_uuid(),
    value: None,
    compute: () => {
      // delete Da -> Db1
      if prev_dirty_sub is Some(p) && a.dirty_flag.parents.search(p) is Some(i) {
        ignore(a.dirty_flag.parents.remove(i))
      }
      let b = f(a.value.unwrap())

      // add Nb2 -> Na
      if !b.childs.any(x => x.get_id() == a.id) {
        b.childs.push(a)
      }

      // add Da -> Db2
      if !a.dirty_flag.parents.any(x => x.id == b.dirty_flag.id) {
        a.dirty_flag.parents.push(b.dirty_flag)
      }
      b.read()
    },
    childs: [a],
    dirty_flag: { dirty: true, parents: [a.dirty_flag], id: get_uuid() },
  }
}

///|
pub fn[A : Eq] Node::read(a : Node[A]) -> A {
  stabilize(a)
  a.value.unwrap()
}

///|
pub fn stabilize(node : &ErasedNode) -> Unit {
  let stack = [(node, false)]
  let seen = Set([])
  let recomputes = []

  while stack.pop() is Some((x, expanded)) {
    guard x.dirty_flag().dirty else { continue }
    let id = x.get_id()
    if expanded {
      recomputes.push(x)
    } else if !seen.contains(id) {
      seen.add(id)
      stack.push((x, true))

      for child in x.childs() {
        if child.dirty_flag().dirty {
          stack.push((child, false))
        }
      }
    }
  }

  let changed_nodes = Set([])
  for node in recomputes {
    node.recompute(changed_nodes)
  }
}

///|
pub fn[T : Eq] Input::set(input : Input[T], x : T) -> Unit {
  input.0.compute = () => x
  mark_dirty(input.0)
}

///|
fn mark_dirty(node : &ErasedNode) -> Unit {
  let traverses = @queue.Queue([node.dirty_flag()])
  while traverses.pop() is Some(x) {
    guard !x.dirty else { continue }
    x.dirty = true
    for p in x.parents {
      traverses.push(p)
    }
  }
}
