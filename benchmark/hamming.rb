#!/usr/bin/env ruby

# frozen_string_literal: true
#
# Benchmark: nearest-neighbor search by Hamming distance
#
# Simulates a perceptual hash database lookup: given a query fingerprint,
# find the most similar entry among N_FINGERPRINTS stored fingerprints.
# Hamming distance (number of differing bits) is the similarity metric.
#
# Pure Ruby: a.bytes.zip(b.bytes).sum { |x, y| (x ^ y).to_s(2).count("1") }
# string-bits gem: a.bit_xor(b).popcount
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/hamming.rb

require_relative "runner"

FINGERPRINT_BYTES = 32          # 256-bit fingerprint (e.g. pHash)
N_FINGERPRINTS    = 10_000
ITERATIONS        = 200

SETUP = <<~RUBY
  srand(42)
  FINGERPRINT_BYTES = #{FINGERPRINT_BYTES}
  QUERY             = Random.bytes(#{FINGERPRINT_BYTES})
  FINGERPRINTS      = Array.new(#{N_FINGERPRINTS}) { Random.bytes(#{FINGERPRINT_BYTES}) }
  ITERATIONS        = #{ITERATIONS}
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def hamming(a, b)
    a.bytes.zip(b.bytes).sum { |x, y| (x ^ y).to_s(2).count("1") }
  end
  def run
    FINGERPRINTS.min_by { |fp| hamming(QUERY, fp) }
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def hamming(a, b)
    a.bit_xor(b).popcount
  end
  def run
    FINGERPRINTS.min_by { |fp| hamming(QUERY, fp) }
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "Hamming distance nearest-neighbor benchmark",
  description: "#{N_FINGERPRINTS} fingerprints x #{FINGERPRINT_BYTES * 8}bit | find closest to query",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
