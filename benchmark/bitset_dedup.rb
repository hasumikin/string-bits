#!/usr/bin/env ruby

# frozen_string_literal: true
#
# Benchmark: streaming deduplication with a bitset
#
# Marks each integer ID seen in a stream using a compact bitset (1 bit per ID),
# then counts distinct values with popcount.
#
# Typical use cases: deduplication of user IDs, URL fingerprints,
# counting distinct elements in a data pipeline.
#
# Pure Ruby: getbyte/setbyte + manual bit arithmetic; count with to_s(2).count("1")
# string-bits gem: set_bit per item; popcount for distinct count
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/bitset_dedup.rb

require_relative "runner"

ID_RANGE     = 2_000_000        # IDs in [0, ID_RANGE)
BITMAP_BYTES = ID_RANGE / 8     # 250 KB
N_ITEMS      = 1_000_000        # stream length (50% expected distinct)
ITERATIONS   = 20

SETUP = <<~RUBY
  srand(42)
  ID_RANGE     = #{ID_RANGE}
  BITMAP_BYTES = #{BITMAP_BYTES}
  ITEMS        = Array.new(#{N_ITEMS}) { rand(#{ID_RANGE}) }
  ITERATIONS   = #{ITERATIONS}
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def run
    bitmap = (0.chr * BITMAP_BYTES).b
    ITEMS.each do |id|
      byte_idx = id >> 3
      bit_mask = 1 << (id & 7)
      bitmap.setbyte(byte_idx, bitmap.getbyte(byte_idx) | bit_mask)
    end
    bitmap.each_byte.sum { |b| b.to_s(2).count("1") }
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def run
    bitmap = (0.chr * BITMAP_BYTES).b
    ITEMS.each { |id| bitmap.set_bit(id) }
    bitmap.popcount
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "Bitset deduplication benchmark",
  description: "#{N_ITEMS / 1_000}K items | IDs in [0, #{ID_RANGE / 1_000}K) | count distinct",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
