import gleam/erlang/process
import gleam/int
import gleam/io

pub fn start() -> Nil {
  io.println("Hello from AtomVM!")
  loop(0)
}

fn loop(count: Int) -> Nil {
  process.sleep(1000)
  io.println(alive_line(count))
  loop(count + 1)
}

pub fn alive_line(count: Int) -> String {
  "Still alive, " <> int.to_string(count) <> " seconds"
}
