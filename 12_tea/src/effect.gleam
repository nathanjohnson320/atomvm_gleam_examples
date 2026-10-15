//// Elm-shaped managed side effects for badge TEA.

import gleam/list

pub opaque type Effect(msg) {
  None
  Batch(List(Effect(msg)))
  Perform(fn(fn(msg) -> Nil) -> Nil)
}

pub fn none() -> Effect(msg) {
  None
}

pub fn batch(effects: List(Effect(msg))) -> Effect(msg) {
  Batch(effects)
}

pub fn from(run: fn(fn(msg) -> Nil) -> Nil) -> Effect(msg) {
  Perform(run)
}

pub fn map(effect: Effect(a), tag: fn(a) -> b) -> Effect(b) {
  case effect {
    None -> None
    Batch(effects) -> Batch(list.map(effects, fn(e) { map(e, tag) }))
    Perform(run) ->
      Perform(fn(dispatch) { run(fn(msg) { dispatch(tag(msg)) }) })
  }
}

pub fn perform(effect: Effect(msg), dispatch: fn(msg) -> Nil) -> Nil {
  case effect {
    None -> Nil
    Batch(effects) -> list.each(effects, fn(e) { perform(e, dispatch) })
    Perform(run) -> run(dispatch)
  }
}
