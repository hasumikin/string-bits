# frozen_string_literal: true
#
# Benchmark: Bloom filter build and query
#
# Inserts N_ELEMENTS into a Bloom filter (K hash functions, M-bit bitmap),
# then queries N_QUERIES items. Hash computation is identical in both
# implementations; only the bit-set (set_bit) and bit-test (bit_at) calls differ.
#
# Pure Ruby: bitmap[pos/8] |= 1<<(pos%8) for insert; (bitmap.getbyte >> bit)&1 for query
# string-bits gem: bitmap.set_bit(pos); bitmap.bit_at(pos)
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/bloom_filter.rb

require_relative "runner"

M_BITS     = 1_000_000   # bitmap size (1M bits, ~125 KB)
K_HASHES   = 3           # hash functions
N_ELEMENTS = 100_000     # items to insert
N_QUERIES  = 100_000     # lookup queries
ITERATIONS = 50

# Three independent multiplicative hash seeds.
SEEDS = [0x9e3779b9, 0x517cc1b7, 0x6c622730].freeze

SETUP = <<~RUBY
  srand(42)
  M_BITS     = #{M_BITS}
  K_HASHES   = #{K_HASHES}
  SEEDS      = #{SEEDS.inspect}
  ELEMENTS   = Array.new(#{N_ELEMENTS}) { rand(2**32) }
  QUERIES    = Array.new(#{N_QUERIES})  { rand(2**32) }
  BITMAP_BYTES = M_BITS / 8
  ITERATIONS = #{ITERATIONS}
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def bloom_positions(item)
    SEEDS.map { |seed| (item * seed) % M_BITS }
  end
  def run
    bitmap = "\x00".b * BITMAP_BYTES
    ELEMENTS.each do |item|
      bloom_positions(item).each do |pos|
        byte_idx = pos >> 3
        bitmap.setbyte(byte_idx, bitmap.getbyte(byte_idx) | (1 << (pos & 7)))
      end
    end
    hits = 0
    QUERIES.each do |item|
      hits += 1 if bloom_positions(item).all? { |pos|
        (bitmap.getbyte(pos >> 3) >> (pos & 7)) & 1 == 1
      }
    end
    hits
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def bloom_positions(item)
    SEEDS.map { |seed| (item * seed) % M_BITS }
  end
  def run
    bitmap = (0.chr * BITMAP_BYTES).b
    ELEMENTS.each do |item|
      bloom_positions(item).each { |pos| bitmap.set_bit(pos) }
    end
    hits = 0
    QUERIES.each do |item|
      hits += 1 if bloom_positions(item).all? { |pos| bitmap.bit_at(pos) }
    end
    hits
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "Bloom filter benchmark",
  description: "M=#{M_BITS / 1000}K bits | K=#{K_HASHES} hashes | #{N_ELEMENTS / 1000}K inserts + #{N_QUERIES / 1000}K queries",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
