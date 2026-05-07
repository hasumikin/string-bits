# frozen_string_literal: true
#
# Benchmark: set_bit_positions
#
# Collects all set-bit positions into an Array (order: :lsb).
# Three bitmap densities show how ctz-based iteration compares to a plain
# Pure Ruby bit-scan at different set-bit densities.
#
# Pure Ruby: each_byte.with_index + 8.times bit-shift, append to Array
# string-bits gem: set_bit_positions(order: :lsb)
#
# Usage: ruby benchmark/set_bit_positions.rb

require_relative "runner"

DATA_BYTES = 125_000   # 1M bits
ITERATIONS = 50

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

def make_scripts(density)
  setup = <<~RUBY
    srand(42)
    DATA = Array.new(#{DATA_BYTES}) do
      byte = 0
      8.times { |i| byte |= (1 << i) if rand < #{density} }
      byte
    end.pack("C*")
    ITERATIONS = #{ITERATIONS}
  RUBY

  pure_ruby = setup + <<~'RUBY'
    def run
      positions = []
      DATA.each_byte.with_index do |byte, bi|
        8.times { |bit| positions << bi * 8 + bit if (byte >> bit) & 1 == 1 }
      end
      positions
    end
  RUBY

  gem_script = setup + <<~RUBY
    $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
    require "string_bits"
    def run
      DATA.set_bit_positions(order: :lsb)
    end
  RUBY

  { "Pure Ruby" => pure_ruby, "string-bits gem" => gem_script }
end

[0.05, 0.50, 0.95].each do |density|
  pct = (density * 100).to_i
  BenchmarkRunner.run(
    title:       "set_bit_positions benchmark (#{pct}% density)",
    description: "#{DATA_BYTES / 1000}KB bitmap (1M bits)",
    configs:     make_scripts(density),
    runner:      RUNNER_SCRIPT,
    iterations:  ITERATIONS
  )
end
