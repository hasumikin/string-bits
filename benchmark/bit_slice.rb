# frozen_string_literal: true
#
# Benchmark: non-byte-aligned bit window extraction (bit_slice)
#
# Extracts N_WINDOWS fixed-width windows from a bitstream at pre-computed
# non-byte-aligned offsets (stride 37: always misaligned).
# Representative use cases: packed bitfield codecs, sprite-sheet tile
# extraction, Arrow IPC bitmap normalization.
#
# Pure Ruby: optimised byte-shift loop (same algorithm as the C code).
#   For each output byte, merge two adjacent source bytes with >> / <<.
#   This is O(output_bytes) per call, avoiding bit-by-bit iteration.
#
# string-bits gem: data.bit_slice(offset, WINDOW_BITS)
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/bit_slice.rb

require_relative "runner"

DATA_BYTES  = 100_000
WINDOW_BITS = 64          # 8 output bytes per window
N_WINDOWS   = 10_000
STRIDE      = 37          # non-byte-aligned stride: all offsets are misaligned
ITERATIONS  = 200

offsets = Array.new(N_WINDOWS) { |i| i * STRIDE }

SETUP = <<~RUBY
  srand(42)
  DATA        = Random.bytes(#{DATA_BYTES})
  WINDOW_BITS = #{WINDOW_BITS}
  OFFSETS     = #{offsets.inspect}
  BYTES_OUT   = (#{WINDOW_BITS} + 7) / 8
  ITERATIONS  = #{ITERATIONS}
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def extract(data, offset)
    byte_start = offset >> 3
    shift      = offset & 7
    anti_shift = 8 - shift
    result     = (0.chr * BYTES_OUT).b
    BYTES_OUT.times do |i|
      lo = data.getbyte(byte_start + i) || 0
      hi = data.getbyte(byte_start + i + 1) || 0
      result.setbyte(i, ((lo >> shift) | (hi << anti_shift)) & 0xFF)
    end
    result
  end
  def run
    OFFSETS.each { |off| extract(DATA, off) }
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def run
    OFFSETS.each { |off| DATA.bit_slice(off, WINDOW_BITS) }
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "bit_slice benchmark (non-byte-aligned window extraction)",
  description: "#{DATA_BYTES / 1000}KB data | #{WINDOW_BITS}-bit windows | stride #{STRIDE} | #{N_WINDOWS} windows",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
