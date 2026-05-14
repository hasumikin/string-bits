#!/usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "string_bits"

COL_LABEL = 65
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
puts "Ruby #{RUBY_VERSION} | string_bits #{StringBits::VERSION rescue "dev"}"
printf "  %-#{COL_LABEL}s  %#{COL_COUNT}s\n", "", "allocs"
puts  "  " + "=" * (COL_LABEL + COL_COUNT + 4)

# --- each_bit_field vs .each_slice chain ---
section "each_bit_field grouping -- 30KB, 12-bit fields, 10_000 pairs (2 fields)"
ebs_data = Random.bytes(30_000)
measure("baseline:    each_bit_field(12).each_slice(2) { |arr| }") {
  ebs_data.each_bit_field(12).each_slice(2) { |_pair| }  # one Array alloc per group
}
measure("baseline:    each_bit_field(12).each_slice(2).to_a  (materialise)") {
  ebs_data.each_bit_field(12).each_slice(2).to_a
}
measure("string_bits: each_bit_field(12, 12) { |a,b| }") {
  ebs_data.each_bit_field(12, 12) { |_a, _b| }  # yields Integers, zero allocs
}

section "each_bit_field grouping -- 30KB, 12-bit fields, 6_666 RGB triplets (3 fields)"
measure("Ruby:      each_bit_field(12).each_slice(3) { |arr| }") {
  ebs_data.each_bit_field(12).each_slice(3) { |_arr| }
}
measure("string_bits: each_bit_field(12, 12, 12) { |r,g,b| }") {
  ebs_data.each_bit_field(12, 12, 12) { |_r, _g, _b| }  # yields Integers, zero allocs
}

