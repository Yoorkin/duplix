///|
struct Scope {
  owned : Array[&ErasedNode]
  sub_scopes : Array[Scope]
  cleanups : Array[() -> Unit]
}

///|
pub fn Scope::Scope() -> Self {
  { owned: [], sub_scopes: [], cleanups: [] }
}

///|
pub fn Scope::add_scope(self : Self, sub_scope : Scope) -> Unit {
  self.sub_scopes.push(sub_scope)
}

///|
pub fn[A : Eq] Scope::add_node(self : Self, node : Node[A]) -> Unit {
  self.owned.push(node)
}

///|
pub fn Scope::add_cleanup(self : Self, cleanup : () -> Unit) -> Unit {
  self.cleanups.push(cleanup)
}

///|
pub fn Scope::dispose(self : Self) -> Unit {
  for sub in self.sub_scopes {
    sub.dispose()
  }

  for node in self.owned {
    // cut `Dirty(current) <--ref--- Dirty(child)`
    let dirty_id = node.dirty_flag().id
    for child in node.childs() {
      let keep = []
      for parent in child.dirty_flag().parents {
        if parent.id != dirty_id {
          keep.push(parent)
        }
      }
      child.dirty_flag().parents..clear().push_iter(keep.iter())
    }

    // cut `Node(current) ---ref---> Dirty(child)`
    node.childs().clear()
  }

  for cleanup in self.cleanups {
    cleanup()
  }
}
