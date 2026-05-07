#!/usr/bin/env ruby

# frozen_string_literal: true
#
# Benchmark: Apache Arrow validity bitmap iteration
#
# Simulates processing non-null elements of an Arrow-style column.
# A validity bitmap marks which of N_ROWS elements are non-null;
# the benchmark sums the value of every valid element.
#
# Arrow validity bitmap layout: element i lives in byte[i/8] at bit i%8 (LSB=0).
# ~50% null rate (random bytes as validity bitmap).
#
# Pure Ruby: manual byte loop with (byte >> bit) & 1
# string-bits gem: each_set_bit(order: :lsb)
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/arrow_validity.rb

require_relative "runner"

N_ROWS       = 1_000_000
BITMAP_BYTES = N_ROWS / 8   # N_ROWS is a multiple of 8
ITERATIONS   = 50

SETUP = <<~RUBY
  srand(42)
  N_ROWS   = #{N_ROWS}
  VALIDITY = Array.new(#{BITMAP_BYTES}) { rand(256) }.pack("C*")
  VALUES   = Array.new(#{N_ROWS}) { rand(1000) }
  ITERATIONS = #{ITERATIONS}
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def run
    sum = 0
    VALIDITY.each_byte.with_index do |byte, bi|
      base = bi * 8
      8.times do |bit|
        sum += VALUES[base + bit] if (byte >> bit) & 1 == 1
      end
    end
    sum
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def run
    sum = 0
    VALIDITY.each_set_bit(order: :lsb) { |i| sum += VALUES[i] }
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
  title:       "Apache Arrow validity bitmap benchmark",
  description: "#{N_ROWS / 1_000}K rows | ~50% valid | sum values of valid elements",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
