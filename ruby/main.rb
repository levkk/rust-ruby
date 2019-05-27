require 'ffi'
require 'benchmark'

# Our foreign functions interface
module Rust
  extend FFI::Library

  # Wrapper around strings returned from Rust.
  class SafeString < FFI::AutoPointer
    # Automatically give the string back to Rust
    # for deallocation.
    def self.release(ptr)
      Rust::free_string(ptr)
    end

    def to_s
      @str ||= self.read_string.force_encoding('UTF-8')
    end
  end

  # Load the Rust library
  ffi_lib begin
    prefix = Gem.win_platform? ? "" : "lib"
    base_path = File.expand_path("../target/release/", __dir__)
    lib_name = "rust_ruby"
    lib_file_extension = FFI::Platform::LIBSUFFIX

    library = "#{base_path}/#{prefix}#{lib_name}.#{lib_file_extension}"

    # Some logging
    puts "Loading foreign C library \"#{library}\""

    library
  end

  # Declare functions

  # add(int, int) -> int
  # Adds two numbers together and returns the result.
  attach_function :add, [:int, :int], :int

  # add_floats(double, double) -> double
  attach_function :add_floats, [:double, :double], :double

  # concat(string, string) -> string
  # Concatenates two strings together.
  # We are aliasing :concat to two different functions, because
  # the first ones result is returned in a wrapper, while the second
  # is returned raw.
  attach_function :concat_safe, :concat, [:string, :string], SafeString
  attach_function :concat_unsafe, :concat, [:string, :string], :string

  # Benchmarking helpers
  attach_function :add_n_times, [:int], :void
  attach_function :concat_n_times, [:int], :void

  # Memory clean-up
  attach_function :free_string, [:string], :void
end

puts Rust::add(5, 10)
puts Rust::add_floats(4.3, 5.7)

# No memory leaks
puts Rust::concat_safe("hello", "world")

# Likely memory leaks
puts Rust::concat_unsafe("hello", "unsafe world")

# Give ownership back to Rust to prevent memory leaks
result = Rust::concat_unsafe("hello", "please free me")
Rust::free_string(result)

# Let's do some benchmarking!
n = 500000

Benchmark.bm(20) do |benchmark|
  benchmark.report "Ruby add" do
    for i in 0..n
      i + i
    end
  end

  benchmark.report "Rust::add" do
    for i in 0..n
      Rust::add(i, i)
    end
  end

  benchmark.report "Rust::add_n_times" do
    Rust::add_n_times(n)
  end
end

puts # Space

Benchmark.bm(20) do |benchmark|
  benchmark.report "String#+" do
    for i in 0..n
      "hello" + "world"
    end
  end

  benchmark.report "Rust::concat_safe" do
    for i in 0..n
      Rust::concat_safe("hello", "world")
    end
  end

  benchmark.report "Rust::concat_unsafe" do
    for i in 0..n
      result = Rust::concat_unsafe("hello", "world")
      Rust::free_string(result)
    end
  end

  benchmark.report "Rust::concat_n_times" do
    Rust::concat_n_times(n)
  end
end
