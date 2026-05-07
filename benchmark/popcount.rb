# frozen_string_literal: true
#
# Benchmark: String#popcount
#
# Measures 4 configurations:
#   (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Pure Ruby baseline: str.bytes.sum { |b| b.to_s(2).count("1") }
#   - allocates a binary string per byte -> O(n) GC pressure
#
# string-bits gem: str.popcount
#   - processes 8 bytes per POPCNT instruction
#
# Usage: ruby docs/benchmark/popcount.rb

require_relative "runner"

ITERATIONS = 100
DATA_SIZE  = 1_000_000  # 1 MB

PURE_RUBY_SCRIPT = <<~'RUBY'
  def run(data, n)
    n.times { data.bytes.sum { |b| b.to_s(2).count("1") } }
  end
RUBY

GEM_SCRIPT = <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def run(data, n)
    n.times { data.popcount }
  end
RUBY

RUNNER_SCRIPT = <<~RUBY
  data = Random.bytes(#{DATA_SIZE})
  run(data, 5)  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  run(data, #{ITERATIONS})
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "String#popcount benchmark",
  description: "#{DATA_SIZE / 1000}KB random data",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
