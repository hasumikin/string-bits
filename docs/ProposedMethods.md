## Proposed Methods

### String class

| category | methods | allocates result object | keyword param |
|----------|---------|-------------------------|----------|
| read | `bit_at` | no | `count_from:` |
| read | `bit_count` | no | no |
| iterate bits | `each_bit` | no | `scan_order:` |
| iterate bits | `bits` | yes (`Array`) | `scan_order:` |
| iterate set-bit positions | `each_set_bit_offset` | no | `count_from:` |
| iterate set-bit positions | `set_bit_offsets` | yes (`Array`) | `count_from:` |
| extract | `bit_slice` | yes (`String`) | no |
| multi-bit mutation | `bit_splice` | no | no |
| run-length iteration | `bit_run_count` | no | no |
| run-length iteration | `each_bit_run` | no | `scan_order:` |
| run-length iteration | `bit_runs` | yes (`Array`) | `scan_order:` |
| single-bit mutation | `set_bit`, `clear_bit`, `flip_bit` | no | `count_from:` |
| bulk bitwise (in-place) | `bit_not!`, `bit_and!`, `bit_or!`, `bit_xor!` | no | no |
| bulk bitwise | `bit_not`, `bit_and`, `bit_or`, `bit_xor` | yes (`String`) | no |

### Array class

| category | methods | allocates result object | keyword param |
|----------|---------|-------------------------|----------|
| Array validity mask (in-place) | `Array#mask!` | no | `count_from:` |
| Array validity mask | `Array#mask` | yes (`Array`) | `count_from:` |

### Read-only

---

#### `bit_at(n, count_from: :lsb) -> true | false | nil`

Returns whether bit at flat position `n` is set. Returns `nil` if `n` is out of range.

`count_from: :lsb` (default) counts from the first bit of the first byte. `count_from: :msb` counts from the last bit of the last byte, so it reverses numbering over the entire bit sequence rather than preserving byte order.

```ruby
bitmap = "\xFF\xAA"   # byte[0]=0xFF, byte[1]=0xAA (0b10101010)

bitmap.bit_at(0)                #=> true  (bit 0 of byte[0])
bitmap.bit_at(0, count_from: :msb)   #=> true  (bit 7 of byte[1])
bitmap.bit_at(8, count_from: :msb)   #=> true  (bit 7 of byte[0])
```

Apache Arrow idiom --- check if element `i` is valid:

```ruby
valid = bitmap.bit_at(i)
```

---

#### `bit_count -> Integer`

Returns the total number of set bits across the entire string.

```ruby
"\x00".bit_count     #=> 0
"\xFF".bit_count     #=> 8
"\xAA".bit_count     #=> 4   # 0b10101010
"\xFF\xFF".bit_count #=> 16
```

Apache Arrow idiom --- count valid and null elements:

```ruby
valid_count = bitmap.bit_count
null_count  = bitmap.bytesize * 8 - bitmap.bit_count
```

---

#### `each_bit(scan_order: :lsb) { |bool| ... } -> self`
#### `each_bit(scan_order: :lsb) -> Enumerator`

Yields each bit as `true` or `false`. Without a block, returns an `Enumerator`. With a block, returns `self`.

```
scan_order: :lsb  -- physical position 0 first (byte[0] LSB first)

  byte[0]                   byte[1]
  b0 b1 b2 b3 b4 b5 b6 b7 | b0 b1 b2 b3 b4 b5 b6 b7
  ^--- first yielded              last yielded ---^

scan_order: :msb  -- physical position (total-1) first (last byte MSB first)

  byte[n-1]                 byte[0]
  b7 b6 b5 b4 b3 b2 b1 b0 | b7 b6 b5 b4 b3 b2 b1 b0
  ^--- first yielded              last yielded ---^
```

```ruby
"\xAA".each_bit.to_a
#=> [false, true, false, true, false, true, false, true]
#    pos 0   1     2      3     4      5     6      7

"\xAA".each_bit(scan_order: :msb).to_a
#=> [true, false, true, false, true, false, true, false]
#    pos 7   6     5     4      3     2      1     0
```

---

#### `bits(scan_order: :lsb) -> Array`
#### `bits(scan_order: :lsb) { |bool| ... } -> self`

Without a block, returns an `Array` of `true`/`false` values --- equivalent to `each_bit(scan_order: scan_order).to_a`. With a block, forwards each bit to the block and returns `self` --- equivalent to `each_bit(scan_order: scan_order) { |b| ... }`.

Follows the same pattern as `String#bytes` vs `String#each_byte`.

```ruby
"\xAA".bits
#=> [false, true, false, true, false, true, false, true]

"\xAA".bits(scan_order: :msb)
#=> [true, false, true, false, true, false, true, false]

"\xAA".bits { |b| print b ? "1" : "0" }
# prints: 01010101
# returns: "\xAA"
```

---

#### `each_set_bit_offset(count_from: :lsb) { |n| ... } -> self`
#### `each_set_bit_offset(count_from: :lsb) -> Enumerator`

Yields the logical position of each **set bit** (bit value == 1). Without a block, returns an `Enumerator`. With a block, returns `self`.

```
data = "\xAA\xCC"  (byte[0]=0b10101010, byte[1]=0b11001100)

Flat positions of all set bits:

  byte[0]: b1 b3 b5 b7  =>  positions  1,  3,  5,  7
  byte[1]: b2 b3 b6 b7  =>  positions 10, 11, 14, 15

count_from: :lsb yields:  1,  3,  5,  7, 10, 11, 14, 15
count_from: :msb yields:  0,  1,  4,  5,  8, 10, 12, 14
```

Positions from `each_set_bit_offset` can be passed directly to `bit_at` under the same numbering convention:

```ruby
data.each_set_bit_offset(count_from: :msb) do |n|
  data.bit_at(n, count_from: :msb)  #=> always true
end
```

For `count_from: :msb`, logical positions are still yielded in ascending order. Internally, the iteration walks physical positions in reverse to preserve that property.

---

#### `set_bit_offsets(count_from: :lsb) -> Array`
#### `set_bit_offsets(count_from: :lsb) { |n| ... } -> self`

Without a block, returns an `Array` of set-bit positions --- equivalent to `each_set_bit_offset(count_from: count_from).to_a`. With a block, forwards each position to the block and returns `self` --- equivalent to `each_set_bit_offset(count_from: count_from) { |n| ... }`.

Follows the same pattern as `String#bytes` vs `String#each_byte`.

```ruby
"\xAA".set_bit_offsets           #=> [1, 3, 5, 7]
"\xAA".set_bit_offsets(count_from: :msb)   #=> [0, 2, 4, 6]

"\xAA\xCC".set_bit_offsets
#=> [1, 3, 5, 7, 10, 11, 14, 15]
```

---

### Extract

---

#### `bit_slice(bit_offset, bit_length) -> String | nil`

The bit-granularity analog of `String#byteslice`. Extracts `bit_length` bits starting at flat bit position `bit_offset` (counted from the first bit, LSB-first).

The result length is `ceil(bit_length / 8)` bytes. If `bit_length` is not a multiple of 8, the unused high bits of the last byte are cleared to zero.

Returns `nil` if `bit_offset` or `bit_length` is not an `Integer`, if either is negative, or if `bit_offset` is beyond the end of the string.

```ruby
data = "\xFF\xAA"   # byte[0]=0xFF, byte[1]=0xAA (0b10101010)

data.bit_slice(0, 8)   #=> "\xFF"
data.bit_slice(8, 8)   #=> "\xAA"
data.bit_slice(4, 8)   #=> "\xAF"   # bits 4-11 packed LSB-first
```

The result String uses the same flat numbering scheme as the source, so `bit_at` and all iteration methods work directly on it:

```ruby
result = data.bit_slice(4, 8)
result.bit_at(0)                #=> same as data.bit_at(4)
result.each_set_bit_offset      # yields set-bit positions within the extracted range
```

Apache Arrow idiom --- normalize a non-byte-aligned validity bitmap for IPC serialization:

```ruby
# Arrow in-memory slice has bit offset 5; IPC requires offset 0
ipc_validity = validity_bitmap.bit_slice(slice_offset, slice_length)
```

---

### Multi-bit mutation

---

#### `bit_splice(bit_index, bit_length, str) -> self`
#### `bit_splice(bit_index, bit_length, str, str_bit_index, str_bit_length) -> self`
#### `bit_splice(range, str) -> self`
#### `bit_splice(range, str, str_range) -> self`

The bit-granularity analog of `String#bytesplice`. Writes `bit_length` bits from `str` into `self` starting at flat bit position `bit_index` (counted from the first bit, LSB-first).

The inverse of `bit_slice`: where `bit_slice` reads a sub-sequence of bits into a new String, `bit_splice` writes one back. Returns `self`.

Unlike `bytesplice`, `bit_splice` does not resize `self` --- the destination and source bit regions must have the same length. Attempting to splice a different number of bits raises `ArgumentError`. If the destination range or source range falls outside the available bits, it raises `IndexError`. This is the only sensible choice at sub-byte granularity: partial bytes cannot be shifted to make room.

Negative indices count backward from the end, exactly as in `bytesplice` and `[]`. In the 3-arg form, `bit_length` bits are read from the beginning of `str`. In the 2-arg range form, the source is likewise read from the beginning of `str`, with the destination length determined by the destination range. In the 5-arg form and the 3-arg range form, the exact source sub-range is given explicitly.

```ruby
buf = +"\x00\x00"

# 3-arg form: write bits 0-7 of "\xFF" into bits 0-7 of buf
buf.bit_splice(0, 8, "\xFF")      #=> buf is "\xFF\x00"

# write 4 bits starting at a non-byte-aligned position
buf.bit_splice(4, 4, "\x0A")     # 0x0A = 0b00001010; bits 0-3 = 1010
# bits 4-7 of buf[0] become 1010 => 0b10101111 = 0xAF
# buf is "\xAF\x00"

# 5-arg form: copy bits 4-7 of src into bits 0-3 of buf
src = "\xAA"   # 0b10101010
buf.bit_splice(0, 4, src, 4, 4)
# src bits 4-7 = 1010; written into buf bits 0-3

# range form
buf.bit_splice(0..7, "\x00")     # same as bit_splice(0, 8, "\x00")
buf.bit_splice(0..7, src, 0..7)  # copy first byte of src into first byte of buf
```

Roundtrip symmetry with `bit_slice`:

```ruby
src = Random.bytes(8)
# Extract 12 bits from a non-byte-aligned position
slice = src.bit_slice(4, 12)

# Write them back into a zero buffer at the same position
buf = ("\x00" * src.bytesize).b
buf.bit_splice(4, 12, slice)

buf.bit_slice(4, 12) == slice   #=> true
```

Apache Arrow idiom --- overwrite a sub-range of a validity bitmap in place:

```ruby
# Replace elements 40..79 of the bitmap with a new validity mask
bitmap.bit_splice(40, 40, new_mask)
```

---

### Iteration and Search

---

#### `bit_run_count(pos, bit) -> Integer`

Returns the length of the consecutive run of `bit` starting at flat position `pos`, counting forward toward higher bit indices. Returns 0 when `pos` is out of range or the bit at `pos` does not equal `bit`.

`bit` accepts `0`, `1`, `false`, or `true` (`false`/`true` are aliases for `0`/`1`, matching the values yielded by `each_bit_run`).

Inspired by Gauche Scheme's `bitvector-count-run`.

```ruby
data = "\xF0"   # 11110000 (LSB-first: bits 0-3 are 0, bits 4-7 are 1)

data.bit_run_count(0, 0)  #=> 4  (4 zeros forward from bit 0)
data.bit_run_count(4, 1)  #=> 4  (4 ones forward from bit 4)
data.bit_run_count(0, 1)  #=> 0  (bit 0 is not 1)

data = "\xFF\xFF\x00"
data.bit_run_count(0,  1) #=> 16 (16 ones forward from bit 0)
data.bit_run_count(16, 0) #=> 8  (8 zeros forward from bit 16)
data.bit_run_count(24, 0) #=> 0  (out of range)
```

Building block for position-driven iteration (Gauche style):

```ruby
pos = 0
total = data.bytesize * 8
runs = []
while pos < total
  bit = data.bit_at(pos)
  len = data.bit_run_count(pos, bit)
  runs << [bit, len]
  pos += len
end
```

---

#### `bit_runs(scan_order: :lsb) -> Array`
#### `bit_runs(scan_order: :lsb) { |bit, len| } -> self`

Non-iterator complement of `each_bit_run`. Without a block, collects all `(bit, run_length)` pairs into an `Array` and returns it --- equivalent to `each_bit_run(scan_order: scan_order).to_a`. With a block, yields each pair and returns `self`.

```ruby
"\xFF\x00".bit_runs
#=> [[true, 8], [false, 8]]

"\xF0".bit_runs
#=> [[false, 4], [true, 4]]
```

---

#### `each_bit_run(scan_order: :lsb) { |bit, len| } -> self`
#### `each_bit_run(scan_order: :lsb) -> Enumerator`

Yields `(bit, run_length)` pairs for each consecutive run of identical bits.

```ruby
"\xFF\x00".each_bit_run.to_a
#=> [[true, 8], [false, 8]]

"\xAA".each_bit_run.to_a
#=> [[false,1],[true,1],[false,1],[true,1],[false,1],[true,1],[false,1],[true,1]]

"\xFF\xFF\xFF".each_bit_run.to_a
#=> [[true, 24]]
```

RLE encoding --- the primary motivation:

```ruby
# with each_bit
runs = []; current = nil; count = 0
data.each_bit(scan_order: :lsb) do |b|
  if b == current then count += 1
  else runs << [current, count] unless current.nil?; current = b; count = 1
  end
end
runs << [current, count] unless current.nil?

# with each_bit_run
runs = data.each_bit_run(scan_order: :lsb).to_a
```

---

### Single-bit mutation

These methods are always destructive (the name implies mutation, no `!` variant). Each returns `self` for chaining. Raises `IndexError` for out-of-range or negative `n`.

Read methods return `nil` for out-of-range positions; mutation methods raise. This asymmetry is intentional: a missed read is a logic question ("is this bit set?"), while a missed write is data corruption. Strict failure on mutation prevents silent bugs where a caller passes a wrong index and believes the write succeeded.

---

#### `set_bit(n, count_from: :lsb) -> self`

Sets bit at logical position `n` to 1. `count_from: :lsb` (default) counts from the first bit; `count_from: :msb` counts from the last bit.

```ruby
bitmap = +"\x00\x00"
bitmap.set_bit(0)   #=> bit 0 of byte[0] becomes 1  =>  "\x01\x00"
bitmap.set_bit(9)   #=> bit 1 of byte[1] becomes 1  =>  "\x01\x02"
```

Apache Arrow idiom --- build a validity bitmap incrementally:

```ruby
bitmap = +"\x00" * ((row_count + 7) / 8)
rows.each_with_index { |row, i| bitmap.set_bit(i) unless row[:value].nil? }
```

---

#### `clear_bit(n, count_from: :lsb) -> self`

Sets bit at logical position `n` to 0. `count_from: :lsb` (default) counts from the first bit; `count_from: :msb` counts from the last bit.

```ruby
bitmap = +"\xFF\xFF"
bitmap.clear_bit(0)  #=> "\xFE\xFF"
bitmap.clear_bit(8)  #=> "\xFE\xFE"
```

---

#### `flip_bit(n, count_from: :lsb) -> self`

Toggles bit at logical position `n`. `count_from: :lsb` (default) counts from the first bit; `count_from: :msb` counts from the last bit.

```ruby
bitmap = +"\x00"
bitmap.flip_bit(3)  #=> "\x08"
bitmap.flip_bit(3)  #=> "\x00"  (back to original)
```

---

### Bulk bitwise operations

Each operation comes in a non-destructive form (returns a new `String`) and a destructive in-place form (`!`, returns `self`). Both forms raise `ArgumentError` if the two strings differ in `bytesize`.

```
non-destructive:  result = a.bit_and(b)   -- allocates a new String
destructive:      a.bit_and!(b)           -- modifies a in place, no allocation
```

---

#### `bit_not -> String` / `bit_not! -> self`

Inverts every bit.

```ruby
"\xAA".bit_not   #=> "\x55"   # 0b10101010 -> 0b01010101
"\x00".bit_not   #=> "\xFF"
```

---

#### `bit_and(other) -> String` / `bit_and!(other) -> self`

Bitwise AND. A bit in the result is 1 only if both operands have 1 at that position.

```
  0b11110000   (left)
& 0b11001100   (right)
-----------
  0b11000000   (result: only bits set in both)
```

```ruby
"\xF0".bit_and("\xCC")  #=> "\xC0"
```

Apache Arrow idiom --- null propagation (result valid only where both inputs are valid):

```ruby
result_validity = left_validity.bit_and(right_validity)
```

Apache Arrow idiom --- apply a boolean filter to a column:

```ruby
result_validity = source_validity.bit_and(filter_bitmap)
```

---

#### `bit_or(other) -> String` / `bit_or!(other) -> self`

Bitwise OR. A bit in the result is 1 if either operand has 1 at that position.

```
  0b11110000   (left)
| 0b00001111   (right)
-----------
  0b11111111   (result: union)
```

```ruby
"\xF0".bit_or("\x0F")  #=> "\xFF"
```

Apache Arrow idiom --- union of two validity bitmaps:

```ruby
either_valid = left_validity.bit_or(right_validity)
```

---

#### `bit_xor(other) -> String` / `bit_xor!(other) -> self`

Bitwise XOR. A bit in the result is 1 if the operands differ at that position.

```
  0b11111111   (left)
^ 0b10101010   (right)
-----------
  0b01010101   (result: difference)
```

```ruby
"\xFF".bit_xor("\xAA")  #=> "\x55"
"\xAA".bit_xor("\xAA")  #=> "\x00"   # XOR with self is always zero
"\xAA".bit_xor("\xFF")  #=> "\x55"   # XOR with all-ones is bit_not
```

---

### Array validity mask

`Array#mask` applies a bitmap to an array, returning a new array of the same length where each element is either kept or replaced with `nil` according to the corresponding bit. `Array#mask!` performs the same operation in place.

No block is involved; the operation applies the bitmap directly to the array.

#### `mask(bitmap, count_from: :lsb, invert: false) -> Array`

Returns a new `Array`. Elements whose corresponding bit is 1 (for `invert: false`) or 0 (for `invert: true`) are kept; all others become `nil`.

```ruby
data   = [1, 2, 3, 4]

# LSB-first (default, Apache Arrow convention): 0b00001101 -> bits 0,2,3 set = elements 0,2,3 valid
bitmap = "\x0D".b   # 0b00001101
data.mask(bitmap)                        #=> [1, nil, 3, 4]

# MSB-first: 0b11010000 -> bits 7,6,4 set = elements 0,1,3 valid
bitmap = "\xD0".b   # 0b11010000
data.mask(bitmap, count_from: :msb)      #=> [1, 2, nil, 4]

# invert: true --- keep where bit is 0, nil where bit is 1
bitmap = "\x0D".b
data.mask(bitmap, invert: true)          #=> [nil, 2, nil, nil]
```

Apache Arrow idiom --- materialize an Arrow column with nulls applied:

```ruby
# One-time setup: build validity bitmap from source data.
bitmap = ("\x00" * ((n + 7) / 8)).b
source_data.each_with_index { |v, i| bitmap.set_bit(i) if v }

# Apply bitmap to a pre-fetched values array (no per-element rb_yield):
result = values.mask(bitmap)
```

#### `mask!(bitmap, count_from: :lsb, invert: false) -> self`

Same as `mask` but modifies the array in place and returns `self`. Elements that would become `nil` are overwritten; valid elements are untouched.

```ruby
ary = [1, 2, 3, 4]
ary.mask!("\x0D".b)   #=> [1, nil, 3, 4]  (LSB-first default)
ary                      #=> [1, nil, 3, 4]  (modified in place)
```
