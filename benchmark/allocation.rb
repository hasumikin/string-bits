# frozen_string_literal: true
#
# Benchmark: Ruby object allocations per operation
#
# Uses GC.stat[:total_allocated_objects] to count heap objects allocated
# during each operation. YJIT has no effect on allocation counts, so this
# runs in a single process without subprocess isolation.
#
# Note: Ruby Fixnum/Integer values up to a certain size are immediate (tagged
# pointers) and do NOT count as allocations. Only String, Array, etc. do.
#
# Usage: ruby docs/benchmark/memory.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "string_bits"

DATA_1MB  = Random.bytes(1_000_000)
A_1MB     = Random.bytes(1_000_000)
B_1MB     = Random.bytes(1_000_000)
DATA_100K = Random.bytes(100_000)

COL_LABEL = 50
COL_COUNT =  9

def measure(label)
  GC.start(full_mark: true, immediate_sweep: true)
  before = GC.stat[:total_allocated_objects]
  yield
  after = GC.stat[:total_allocated_objects]
  printf "  %-#{COL_LABEL}s  %#{COL_COUNT}d\n", label, after - before
end

def section(title)
  puts
  puts "  #{title}"
  puts "  " + "-" * (COL_LABEL + COL_COUNT + 4)
end

puts "Allocation benchmark"
puts "Ruby #{RUBY_VERSION} | string-bits #{StringBits::VERSION rescue "dev"}"
printf "  %-#{COL_LABEL}s  %#{COL_COUNT}s\n", "", "allocs"
puts  "  " + "=" * (COL_LABEL + COL_COUNT + 4)

# --- popcount ---
section "popcount (1MB data)"
measure("Pure Ruby: each_byte { b.to_s(2).count(\"1\") }") {
  DATA_1MB.each_byte.sum { |b| b.to_s(2).count("1") }
}
measure("Pure Ruby: bytes.sum { ... }  (+ Array alloc)") {
  DATA_1MB.bytes.sum { |b| b.to_s(2).count("1") }
}
measure("gem:       popcount") {
  DATA_1MB.popcount
}

# --- bulk bitwise ---
section "bulk bitwise AND (1MB + 1MB)"
measure("Pure Ruby: bytes/zip/map/pack  (natural)") {
  A_1MB.bytes.zip(B_1MB.bytes).map { |a, b| a & b }.pack("C*")
}
measure("Pure Ruby: dup + setbyte loop  (optimised)") {
  result = A_1MB.dup
  A_1MB.bytesize.times { |i| result.setbyte(i, A_1MB.getbyte(i) & B_1MB.getbyte(i)) }
  result
}
measure("gem:       bit_and  (returns new String)") {
  A_1MB.bit_and(B_1MB)
}
measure("gem:       bit_and! (in-place, needs dup)") {
  A_1MB.dup.bit_and!(B_1MB)
}

# --- bit_slice ---
section "bit_slice x1000 (64-bit unaligned windows, 100KB data)"
measure("Pure Ruby: byte-shift loop x1000") {
  1_000.times do |i|
    offset = i * 37
    shift  = offset & 7
    bstart = offset >> 3
    anti   = 8 - shift
    result = (0.chr * 8).b
    8.times do |j|
      lo = DATA_100K.getbyte(bstart + j) || 0
      hi = DATA_100K.getbyte(bstart + j + 1) || 0
      result.setbyte(j, ((lo >> shift) | (hi << anti)) & 0xFF)
    end
  end
}
measure("gem:       bit_slice x1000") {
  1_000.times { |i| DATA_100K.bit_slice(i * 37, 64) }
}

# --- each_set_bit / set_bit_positions ---
section "set-bit iteration (1M bits, ~50% set)"
validity = Random.bytes(125_000)
measure("gem:       each_set_bit { block }  (yields Fixnum)") {
  validity.each_set_bit(order: :lsb) { |_i| }
}
measure("gem:       set_bit_positions  (-> Array)") {
  validity.set_bit_positions(order: :lsb)
}
measure("Pure Ruby: manual byte loop + conditional push") {
  positions = []
  validity.each_byte.with_index do |byte, bi|
    base = bi * 8
    8.times { |bit| positions << base + bit if (byte >> bit) & 1 == 1 }
  end
  positions
}

# --- RLE (each_bit) ---
section "run-length encoding (100KB = 800K bits)"
measure("Pure Ruby: each_byte + bit loop") {
  runs = []; current = nil; count = 0
  DATA_100K.each_byte do |byte|
    8.times do |bit|
      b = (byte >> bit) & 1 == 1
      if b == current then count += 1
      else runs << [current, count] unless current.nil?; current = b; count = 1
      end
    end
  end
  runs << [current, count] unless current.nil?
  runs
}
measure("gem:       each_bit { block }") {
  runs = []; current = nil; count = 0
  DATA_100K.each_bit(order: :lsb) do |b|
    if b == current then count += 1
    else runs << [current, count] unless current.nil?; current = b; count = 1
    end
  end
  runs << [current, count] unless current.nil?
  runs
}

puts
