# string-bit gem

Ruby's `String` is already a byte sequence. This gem extends it one level lower: **a bit sequence** --- making packed binary buffers first-class values without any new class. A companion extension to `Array` applies validity bitmaps directly to Ruby arrays, covering the Apache Arrow use case without per-element `rb_yield` overhead.

The methods are designed for real workloads: Apache Arrow validity bitmaps, bitmap font glyph data, and any protocol buffer where bits carry meaning. Many methods read or modify the existing string bytes directly; methods such as `bit_slice`, `bit_not`, `bit_and`, `bit_or`, `bit_xor`, `bits`, `set_bit_offsets`, `bit_runs`, and `Array#mask` allocate a derived result object. Because the API relies solely on `String`, the same methods would benefit memory-constrained implementations such as mruby and PicoRuby once adopted into CRuby.

Methods that walk a bitmap use `scan_order:`. Methods that accept or return bit numbers use `count_from:`. This keeps traversal direction separate from logical numbering, so `data.each_set_bit_offset(count_from: :msb).all? { |n| data.bit_at(n, count_from: :msb) }` stays true.

## Usage

```
gem install string_bits
```

```ruby
require "string_bits"
puts "\xAA\xAA\xAA\xAA".bit_at(10)
#=> false

puts "\xAA".each_bit(scan_order: :msb).to_a.inspect
#=> [true, false, true, false, true, false, true, false]
```
