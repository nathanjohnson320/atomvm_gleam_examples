import gleeunit
import power

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn percent_empty_test() {
  assert power.percent(3300) == 0
  assert power.percent(3000) == 0
}

pub fn percent_full_test() {
  assert power.percent(4200) == 100
  assert power.percent(4500) == 100
}

pub fn percent_mid_test() {
  // (3960 - 3300) * 100 / 900 = 73
  assert power.percent(3960) == 73
}

pub fn usb_present_test() {
  assert power.usb_present(3999) == False
  assert power.usb_present(4000) == True
  assert power.usb_present(5020) == True
}
