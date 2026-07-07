///|
let global_scopes : @slotmap.SlotMap[Scope] = SlotMap()

///|
let root_scope : @slotmap.Id = global_scopes.allocate_with(id => {
  id,
  parent: None,
  sub_scopes: Set([]),
  cleanups: [],
})

///|
let current_scope : Ref[@slotmap.Id] = Ref(root_scope)

///|
fn get_scope() -> Scope {
  global_scopes[current_scope.val]
}

///|
priv struct Scope {
  id : @slotmap.Id
  parent : @slotmap.Id?
  sub_scopes : Set[@slotmap.Id]
  cleanups : Array[() -> Unit]
}

///|
fn[A] with_scope(f : (@slotmap.Id) -> A) -> A {
  let id = global_scopes.allocate_with(id => {
    id,
    parent: Some(current_scope.val),
    sub_scopes: Set([]),
    cleanups: [],
  })
  let result = current_scope.protect(id, () => f(id))
  if global_scopes.get(current_scope.val) is Some(scope) {
    scope.sub_scopes.add(id)
  }
  result
}

///|
pub fn on_cleanup(f : () -> Unit) -> Unit {
  get_scope().cleanups.push(f)
}

///|
pub fn cleanup() -> Unit {
  global_scopes[root_scope].dispose()
}

///|
fn Scope::dispose(self : Self) -> Unit {
  for id in self.sub_scopes {
    if global_scopes.get(id) is Some(scope) {
      scope.dispose()
    }
  }

  for cleanup in self.cleanups {
    cleanup()
  }

  if self.parent is Some(p) {
    global_scopes[p].sub_scopes.remove(self.id)
  }

  global_scopes.free(self.id)
}
