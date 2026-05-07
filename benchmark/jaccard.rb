#!/usr/bin/env ruby

# frozen_string_literal: true
#
# Benchmark: Jaccard similarity between two large bitmaps
#
# Computes |A & B| / |A | B| -- the standard Jaccard coefficient -- where
# A and B are sets encoded as 1bpp bitmaps (one bit per possible element).
# Typical use cases: document similarity, collaborative filtering, MinHash.
#
# Pure Ruby: byte-by-byte AND/OR + to_s(2).count("1") for popcount
# string-bits gem: bit_and + bit_or + popcount
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/jaccard.rb

require_relative "runner"

BITMAP_BYTES = 125_000   # 1M-bit bitmap (~125 KB) per set
ITERATIONS   = 200

SETUP = <<~RUBY
  srand(42)
  BITMAP_BYTES = #{BITMAP_BYTES}
  A = Random.bytes(#{BITMAP_BYTES})
  B = Random.bytes(#{BITMAP_BYTES})
  ITERATIONS = #{ITERATIONS}
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def run
    intersection = 0
    union_count  = 0
    A.each_byte.with_index do |a_byte, i|
      b_byte = B.getbyte(i)
      intersection += (a_byte & b_byte).to_s(2).count("1")
      union_count  += (a_byte | b_byte).to_s(2).count("1")
    end
    intersection.to_f / union_count
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def run
    A.bit_and(B).popcount.to_f / A.bit_or(B).popcount
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "Jaccard similarity benchmark",
  description: "#{BITMAP_BYTES / 1000}KB bitmaps (#{BITMAP_BYTES * 8 / 1_000_000}M-bit sets)",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
