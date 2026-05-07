# frozen_string_literal: true
#
# Benchmark: run-length encoding of a bitstream
#
# Scans a binary string bit by bit and collects runs of consecutive 0s and 1s.
# Inner loop body: branch + conditional array push (heavier than plain arithmetic).
#
# Pure Ruby: each_byte + bit-shift per column
# string-bits gem: each_bit(order: :lsb)
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/rle.rb

require_relative "runner"

DATA_BYTES = 100_000   # 800K bits
ITERATIONS = 100

SETUP = <<~RUBY
  srand(42)
  DATA       = Random.bytes(#{DATA_BYTES})
  ITERATIONS = #{ITERATIONS}
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def run
    runs    = []
    current = nil
    count   = 0
    DATA.each_byte do |byte|
      8.times do |bit|
        b = (byte >> bit) & 1 == 1
        if b == current
          count += 1
        else
          runs << [current, count] unless current.nil?
          current = b
          count   = 1
        end
      end
    end
    runs << [current, count] unless current.nil?
    runs
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def run
    runs    = []
    current = nil
    count   = 0
    DATA.each_bit(order: :lsb) do |b|
      if b == current
        count += 1
      else
        runs << [current, count] unless current.nil?
        current = b
        count   = 1
      end
    end
    runs << [current, count] unless current.nil?
    runs
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "Run-length encoding benchmark",
  description: "#{DATA_BYTES / 1000}KB data (#{DATA_BYTES * 8 / 1000}K bits)",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
