# Future Proposal: Packed Bit-Field Iteration

This file documents `each_bit_field` and `bit_fields`, which are implemented and tested
but intentionally excluded from the main proposal in README.md.

## Reason for deferral

These methods yield plain `Integer` values, which is a different yield type from all other
iteration methods in the proposal (which yield `true`/`false` or flat `Integer` positions).
Introducing a method that yields typed field values decoded from a packed binary layout is
expected to prolong discussion on the core-ruby-dev mailing list. The rest of the proposal
is kept clean to reduce that risk.

---

## `each_bit_field(*bitlens, with: nil, order: :lsb) { |*fields[, extra]| } -> self`
## `each_bit_field(*bitlens, with: nil, order: :lsb) -> Enumerator`

Iterates over the string as a sequence of packed bit-field records. Each positional argument
specifies the width (in bits) of one field in the record. On each iteration, one value per
field is yielded as an `Integer` (LSB-first). Each bitlen must be between 1 and 64. Without
a block, returns an `Enumerator`.

**Integer width and portability.** The 64-bit limit reflects the `uint64_t` extraction used
in this CRuby implementation. On mruby, `mrb_int` is either 32-bit (`MRB_INT32`, common on
microcontrollers) or 64-bit (`MRB_INT64`). mruby does have a BigInt, but it is an optional
gem rather than a core type. For core compatibility --- i.e., without assuming
`MRB_USE_BIGINT=1` is defined --- a portable implementation should enforce
`bitlen <= MRB_INT_BIT - 1`, yielding at most 31 or 63 bits depending on the build. Whether
CRuby should adopt the same `SIZEOF_LONG * 8 - 1` cap (63 on 64-bit systems) for
cross-implementation consistency is an open question: it would sacrifice the ability to yield
a full 64-bit unsigned field, which CRuby can always represent via Bignum.

Incomplete trailing bits --- when `bytesize * 8` is not a multiple of `sum(bitlens)` --- are
silently dropped, matching the behavior of `Enumerable#each_slice`.

```
order: :lsb (default)  -- records yielded left-to-right (ascending bit position)
order: :msb            -- records yielded right-to-left (descending bit position)
with: :offset          -- appends the bit offset of the current record to the block args
with: :index           -- appends the 0-based yield-order index to the block args
```

```ruby
data = "\xAA\xCC"   # 16 bits

data.each_bit_field(8).to_a
#=> [0xAA, 0xCC]           # two single-field records

data.each_bit_field(8, 8).to_a
#=> [[0xAA, 0xCC]]         # one record with two fields
```

**RGB565 pixel manipulation**

`with: :offset` provides the bit offset of the current record so you can write back into the
source with `bit_splice`. `with: :index` provides the 0-based iteration count for addressing
an output buffer.

```ruby
# eg1: Swap R and B channels in an RGB565 buffer
# RGB565 LSB-first layout: bits 0-4 = blue (5), bits 5-10 = green (6), bits 11-15 = red (5)
rgb565data.each_bit_field(5, 6, 5, with: :offset, order: :lsb) do |b, _g, r, offset|
  # b, r are Integers; offset is the bit position of the start of this pixel
  rgb565data.bit_splice(offset,      5, r)  # write red into the blue field
  rgb565data.bit_splice(offset + 11, 5, b)  # write blue into the red field
end

# eg2: Convert RGB565 to 4-bit grayscale
gray4data = "\x00" * (rgb565data.bytesize / 4)
rgb565data.each_bit_field(5, 6, 5, with: :index, order: :lsb) do |b, g, r, index|
  gray8 = ((r * 255 / 31) + (g * 255 / 63) + (b * 255 / 31)) / 3
  gray4data.bit_splice(index * 4, 4, gray8 >> 4)
end
```

The half-block rendering pattern used in bitmap fonts and braille displays also benefits: two
scan-lines are delivered simultaneously so the vertical combination can be computed without
maintaining external state between calls:

```ruby
bitlen = 12

data.each_bit_field(bitlen, bitlen, order: :lsb) do |plane0, plane1|
  line = ""
  i = 0
  while i < bitlen
    case [(plane0 >> i) & 1, (plane1 >> i) & 1]
    in [1, 1] then line << "\xE2\x96\x88"  # Full Block U+2588
    in [1, 0] then line << "\xE2\x96\x80"  # Upper Half Block U+2580
    in [0, 1] then line << "\xE2\x96\x84"  # Lower Half Block U+2584
    else           line << " "
    end
    i += 1
  end
  puts line
end
```

Each extracted field is a plain `Integer`, so arithmetic on channel values and direct use
with `bit_splice` require no intermediate conversion or packing step.

---

## `bit_fields(*bitlens, order: :lsb) -> Array`
## `bit_fields(*bitlens, order: :lsb) { |*fields| } -> self`

Non-iterator complement of `each_bit_field`. Without a block, collects all records into an
`Array` and returns it. With a block, yields the same values as `each_bit_field` (without
`with:`) and returns `self`.

The returned array mirrors `each_bit_field(*bitlens).to_a`: when exactly one bitlen is given
the array is flat (`Array[Integer]`); when multiple bitlens are given each element is itself
an `Array` (`Array[Array[Integer]]`).

```ruby
data = "\xAA\xCC"

data.bit_fields(8)
#=> [0xAA, 0xCC]          # single field: flat array

data.bit_fields(8, 8)
#=> [[0xAA, 0xCC]]        # multiple fields: array of arrays

pixel = [(21) | (42 << 5) | (10 << 11)].pack("S<")
pixel.bit_fields(5, 6, 5)
#=> [[21, 42, 10]]

data.bit_fields(8, order: :msb)
#=> [0xCC, 0xAA]          # records in reverse order
```

Unlike `each_bit_field`, `bit_fields` has no `with:` keyword because the caller already
holds the returned array and can compute offsets or indices from it directly.

---

## Use Case: IoT Sensor Telemetry (Non-Byte-Aligned Packed Frames)

Compact binary telemetry protocols pack multiple sensor readings into sub-byte-aligned fields
to minimize transmission overhead. A typical environmental sensor might encode three
measurements into a 36-bit frame:

```
bits  0-11 : temperature  (12 bits, 0.1 deg resolution, 0-409.5)
bits 12-21 : humidity     (10 bits, 0.1% resolution, 0-102.3)
bits 22-35 : CO2          (14 bits, ppm, 0-16383)
```

36 bits = 4.5 bytes, so frames are **not byte-aligned**: even frames start at a byte
boundary, odd frames start 4 bits into the preceding byte. Extracting fields with pure Ruby
requires maintaining two separate code paths:

```ruby
# Pure Ruby: two hard-coded extraction paths for the two alignment cases.
N_FRAMES.times do |i|
  b = i * 36 >> 3
  if i.even?
    temp = DATA.getbyte(b)    | ((DATA.getbyte(b+1) & 0x0F) << 8)
    hum  = (DATA.getbyte(b+1) >> 4) | ((DATA.getbyte(b+2) & 0x3F) << 4)
    co2  = (DATA.getbyte(b+2) >> 6)  | (DATA.getbyte(b+3) << 2) | ((DATA.getbyte(b+4) & 0x0F) << 10)
  else
    temp = (DATA.getbyte(b)   >> 4) |  (DATA.getbyte(b+1) << 4)
    hum  =  DATA.getbyte(b+2) | ((DATA.getbyte(b+3) & 0x03) << 8)
    co2  = (DATA.getbyte(b+3) >> 2) |  (DATA.getbyte(b+4) << 6)
  end
  process(temp, hum, co2)
end
```

`each_bit_field` handles both alignment cases uniformly --- the bit offset arithmetic is
done once in C, and the block always receives three typed integers:

```ruby
# each_bit_field: alignment is handled transparently.
DATA.each_bit_field(12, 10, 14) do |temp, hum, co2|
  process(temp, hum, co2)
end
```

The two versions produce identical results. The `each_bit_field` version eliminates the
alignment branch entirely, and the yielded integers can be used directly in arithmetic
without any further unpacking.
