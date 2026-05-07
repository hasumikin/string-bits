# frozen_string_literal: true
#
# Benchmark: Apache Arrow validity iteration with Red Arrow gem
#
# Requires: red-arrow gem and Apache Arrow C++ libraries.
#   Installation: https://arrow.apache.org/install/
#                 gem install red-arrow
#
# Scenario: 1M-row Int32 column with ~50% nulls. Sum all valid values.
#
# Configs:
#   Red Arrow (each)  -- col.each { |v| sum += v if v }
#                        idiomatic Red Arrow, validity checked per element
#
#   string-bits gem   -- validity bitmap pre-built once (setup cost), then
#                        each_set_bit(order: :lsb) for repeated iteration
#
# NOTE on bitmap extraction:
#   Arrow stores the validity bitmap as raw bytes internally, but
#   Red Arrow does not currently expose it as a Ruby String.
#   (Arrow::Array#null_bitmap is not part of the public API.)
#   The setup step here reconstructs the bitmap from the source Ruby array.
#   If Red Arrow exposed null_bitmap as Arrow::Buffer#data -> String,
#   the pre-build step would become a zero-copy read instead.
#
# The pre-build cost is amortized outside timing, representing a pipeline
# where a column is loaded once and iterated many times.
#
# (YJIT off | YJIT on) x (Red Arrow each | string-bits gem)
#
# Usage: ruby docs/benchmark/arrow_red_arrow.rb

require_relative "runner"

N_ROWS     = 100_000
NULL_RATE  = 0.5
ITERATIONS = 5

# Red Arrow native: require 'arrow' inside the subprocess.
RED_ARROW_SCRIPT = <<~RUBY
  require "arrow"
  srand(42)
  N   = #{N_ROWS}
  COL = Arrow::Int32Array.new(Array.new(N) { rand < #{NULL_RATE} ? nil : rand(1000) })
  ITERATIONS = #{ITERATIONS}
  def run
    sum = 0
    COL.each { |v| sum += v if v }
    sum
  end
RUBY

# string-bits: build validity bitmap from source data (one-time setup outside
# timing), then use each_set_bit for repeated iteration.
# COL[i] provides random access to Arrow values by index.
GEM_SCRIPT = <<~RUBY
  require "arrow"
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  srand(42)
  N    = #{N_ROWS}
  data = Array.new(N) { rand < #{NULL_RATE} ? nil : rand(1000) }
  COL  = Arrow::Int32Array.new(data)
  # Pre-build validity bitmap from source array (amortized over ITERATIONS runs).
  # With Arrow::Array#null_bitmap this would be: BITMAP = col.null_bitmap.data
  BITMAP = (0.chr * ((N + 7) / 8)).b
  data.each_with_index { |v, i| BITMAP.set_bit(i) if v }
  ITERATIONS = #{ITERATIONS}
  def run
    sum = 0
    BITMAP.each_set_bit(order: :lsb) { |i| sum += COL[i] }
    sum
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "Apache Arrow validity bitmap benchmark (Red Arrow)",
  description: "#{N_ROWS / 1_000}K rows | ~#{(NULL_RATE * 100).to_i}% null | sum valid values",
  configs:     { "Pure Ruby" => RED_ARROW_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
