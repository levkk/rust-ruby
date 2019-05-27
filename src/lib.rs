// C types
extern crate libc;
use libc::c_char;

// Foreign functions interface
// CStr = owned by the caller (i.e. Ruby)
// CString = owned by Rust
use std::ffi::{CStr, CString};

// Preserve the function name for calling from outside the library.
#[no_mangle]
// Makes it C compatible.
pub extern "C" fn add(i: i64, j: i64) -> i64 {
  i + j
}

// Same as above, but let's add floats now. Rust is statically typed,
// so we cannot re-use the fn add() above to add floats.
// This is good for safety because floats and integers behave
// differently (see fn test_add_floats() below)!
#[no_mangle]
pub extern "C" fn add_floats(i: f64, j: f64) -> f64 {
  i + j
}


/// Concatenate two strings together and return the result.
/// This function can be linked from any C interface.
///
/// Arguments:
///
/// * `a` - A C string
/// * `b` - A C string
#[no_mangle]
pub extern "C" fn concat(a: *const c_char, b: *const c_char) -> *const c_char {
  // Convert to Rust &str
  let a = unsafe { CStr::from_ptr(a) }.to_str().unwrap();
  let b = unsafe { CStr::from_ptr(b) }.to_str().unwrap();

  // Convert to String
  let a = String::from(a);
  let b = String::from(b);
  
  // Concatenate
  let together = a + &b;

  // Create a new *const c_char and give ownsership to the caller
  CString::new(together.as_str()).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn free_string(s: *const c_char) {
  unsafe {
    if s.is_null() { return }

    // Give ownership back to Rust
    CStr::from_ptr(s);
  }
}

// Benchamrk integer addition
#[no_mangle]
pub extern fn add_n_times(n: i64) {
  for i in 0..n {
    let _j = i + i;
  }
}

// Benchamrk string concatenation
#[no_mangle]
pub extern fn concat_n_times(n: i64) {
  for _i in 0..n {
    let _result = String::from("hello") + "world";
  }
}

// 100% test coverage!
#[cfg(test)]
mod tests {

  use super::*;

    #[test]
    fn test_add() {
      assert_eq!(add(1, 4), 5);
    }

    #[test]
    fn test_add_floats() {
      // This is ok
      assert_eq!(add_floats(5.6, 1.4), 7.0);

      // Floating points aren't that precise!
      assert_ne!(add_floats(5.6, 1.3), 6.9);
    }

    #[test]
    fn test_concat() {
      // Crate two raw C strings
      let a = CString::new("one").unwrap().into_raw();
      let b = CString::new("two").unwrap().into_raw();

      // fn concat() takes ownership or the two strings
      // and returns a C string for which we take ownership.
      let together = unsafe { CStr::from_ptr(concat(a, b)) }.to_str().unwrap();

      assert_eq!(together, "onetwo");
    }
}
