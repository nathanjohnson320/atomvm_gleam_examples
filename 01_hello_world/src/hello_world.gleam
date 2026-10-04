import gleam/int
import gleam/io

@external(erlang, "timer", "sleep")
fn sleep(milliseconds: Int) -> Nil

/// AtomVM entrypoint. The package name in `gleam.toml` is `hello_world`, so
/// this module is the one Orbital marks as the start module.
///
/// `start` must not return: when it does, AtomVM stops the application.
pub fn start() -> Nil {
  io.println("Hello from AtomVM!")
  loop(0)
}

fn loop(count: Int) -> Nil {
  sleep(1000)
  io.println(alive_line(count))
  loop(count + 1)
}

pub fn alive_line(count: Int) -> String {
  "Still alive, " <> int.to_string(count) <> " seconds"
}
