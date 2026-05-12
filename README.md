# string-bit gem

Ruby's `String` is already a byte sequence. This gem extends it one level lower: **a bit sequence** --- making packed binary buffers first-class values without any new class or intermediate allocation. A companion extension to `Array` applies validity bitmaps directly to Ruby arrays, covering the Apache Arrow use case without per-element `rb_yield` overhead.

The methods are designed for real workloads: Apache Arrow validity bitmaps, bitmap font glyph data, and any protocol buffer where bits carry meaning. Most methods operate zero-copy on the existing string bytes; the non-`!` bulk bitwise variants and `bit_slice` return a newly allocated `String`. Because the API relies solely on `String`, the same methods would benefit memory-constrained implementations such as mruby and PicoRuby once adopted into CRuby.
