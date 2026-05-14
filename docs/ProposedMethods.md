## Proposed Methods

| category  | methods                                       | keyword param | allocates result object |
|-----------|-----------------------------------------------|---------------|-------------------------|
| Scan      | `each_bit`                                    | `scan_order:` | no                      |
| Scan      | `bits`                                        | `scan_order:` | yes (`Array`)           |
| Scan      | `each_bit_run`                                | `scan_order:` | no                      |
| Scan      | `bit_runs`                                    | `scan_order:` | yes (`Array`)           |
| Position  | `bit_at`                                      | `count_from:` | no                      |
| Position  | `set_bit`, `clear_bit`, `flip_bit`            | `count_from:` | no                      |
| Position  | `each_set_bit_offset`                         | `count_from:` | no                      |
| Position  | `set_bit_offsets`                             | `count_from:` | yes (`Array`)           |
| Flat      | `bit_slice`                                   | no            | yes (`String`)          |
| Flat      | `bit_splice`                                  | no            | no                      |
| Flat      | `bit_run_count`                               | no            | no                      |
| Aggregate | `bit_count`                                   | no            | no                      |
| Bitwise   | `bit_not!`, `bit_and!`, `bit_or!`, `bit_xor!` | no            | no                      |
| Bitwise   | `bit_not`, `bit_and`, `bit_or`, `bit_xor`     | no            | yes (`String`)          |

The category names above are not just cosmetic. `Scan`, `Position`, and `Flat` reflect three different coordinate models in this proposal:

- `Scan` methods traverse bits in one direction and therefore use `scan_order:`
- `Position` methods accept or return logical bit numbers and therefore use `count_from:`
- `Flat` methods work directly on physical bit offsets and therefore take no ordering keyword

`Aggregate` and `Bitwise` are separated because they are whole-bitmap operations rather than coordinate-based APIs.

For a beginner-oriented explanation of those ideas, see [LogicalAndPhysicalPositions.md](./LogicalAndPhysicalPositions.md).

### Scan

#### `each_bit(scan_order: :lsb) { |bool| ... } -> self`
#### `each_bit(scan_order: :lsb) -> Enumerator`

Yields each bit as `true` or `false`. Without a block, returns an `Enumerator`. With a block, returns `self`.
`scan_order: :lsb` starts from physical position 0. `scan_order: :msb` starts from the last physical bit. See [LogicalAndPhysicalPositions.md](./LogicalAndPhysicalPositions.md) for the conceptual model.

```ruby
"\xAA".each_bit.to_a
#=> [false, true, false, true, false, true, false, true]
#  pos  0     1     2      3     4      5     6      7

"\xAA".each_bit(scan_order: :msb).to_a
#=> [true, false, true, false, true, false, true, false]
#  pos 7     6      5     4      3     2      1     0

data = "Any arbitrary string of bytes can be used as data, not just ASCII text."
data.each_bit.to_a == data.each_bit(scan_order: :msb).to_a.reverse
#=> true
```

---

#### `bits(scan_order: :lsb) -> Array`
#### `bits(scan_order: :lsb) { |bool| ... } -> self`

Without a block, equivalent to `each_bit(scan_order: scan_order).to_a`. With a block, equivalent to `each_bit(scan_order: scan_order) { |b| ... }`.

---

#### `each_bit_run(scan_order: :lsb) { |bit, len| } -> self`
#### `each_bit_run(scan_order: :lsb) -> Enumerator`

Yields `(bit, run_length)` pairs for each consecutive run of identical bits.

RLE encoding --- the primary motivation:

```ruby
data = "\xF0"

# with each_bit
runs = []; current = nil; count = 0
data.each_bit(scan_order: :lsb) do |b|
  if b == current then count += 1
  else runs << [current, count] unless current.nil?; current = b; count = 1
  end
end
runs << [current, count] unless current.nil?

# with each_bit_run
"\xF0".each_bit_run(scan_order: :lsb).to_a
#=> [[false, 4], [true, 4]]
```

---

#### `bit_runs(scan_order: :lsb) -> Array`
#### `bit_runs(scan_order: :lsb) { |bit, len| } -> self`

Without a block, equivalent to `each_bit_run(scan_order: scan_order).to_a`. With a block, equivalent to `each_bit_run(scan_order: scan_order) { |bit, len| ... }`.

---

### Position

#### `bit_at(n, count_from: :lsb) -> true | false | nil`

Returns whether bit at flat position `n` is set. Returns `nil` if `n` is out of range.

`count_from: :lsb` (default) uses LSB-first numbering within each byte. `count_from: :msb` preserves byte order but uses MSB-first numbering within each byte. See [LogicalAndPhysicalPositions.md](./LogicalAndPhysicalPositions.md) for the distinction between physical and logical positions.

```ruby
bitmap = "\xFF\xAA"                 # byte[0]=0xFF, byte[1]=0xAA (0b10101010)

bitmap.bit_at(0)                    #=> true  (bit 0 of byte[0])
bitmap.bit_at(0, count_from: :msb)  #=> true  (bit 7 of byte[0])
bitmap.bit_at(8, count_from: :msb)  #=> true  (bit 7 of byte[1])
bitmap.bit_at(100)                  #=> nil
```

Apache Arrow idiom --- check if element `i` is valid:

```ruby
valid = bitmap.bit_at(i)
```

RFC / wire-format idiom --- read by the RFC diagram "bit 0" convention (leftmost bit of the first byte):

```ruby
header = "\xC0\x00\x00\x00"             # IPv4 header byte 0 = 0b11000000
header.bit_at(0, count_from: :msb)      #=> true   (version field, leading bit)
header.bit_at(1, count_from: :msb)      #=> true   (version field, second bit)
header.bit_at(2, count_from: :msb)      #=> false
```

---

#### `set_bit(n, count_from: :lsb) -> self`

Sets bit at logical position `n` to 1.

```ruby
bitmap = +"\x00\x00"
bitmap.set_bit(0)   #=> bit 0 of byte[0] becomes 1  =>  "\x01\x00"
bitmap.set_bit(9)   #=> bit 1 of byte[1] becomes 1  =>  "\x01\x02"
bitmap.set_bit(100) #=> IndexError
```

Apache Arrow idiom --- build a validity bitmap incrementally:

```ruby
bitmap = +"\x00" * ((row_count + 7) / 8)
rows.each_with_index { |row, i| bitmap.set_bit(i) unless row[:value].nil? }
```

---

#### `clear_bit(n, count_from: :lsb) -> self`

Sets bit at logical position `n` to 0.

```ruby
bitmap = +"\xFF\xFF"
bitmap.clear_bit(0)   #=> "\xFE\xFF"
bitmap.clear_bit(8)   #=> "\xFE\xFE"
bitmap.clear_bit(100) #=> IndexError
```

---

#### `flip_bit(n, count_from: :lsb) -> self`

Toggles bit at logical position `n`.

```ruby
bitmap = +"\x00"
bitmap.flip_bit(3)   #=> "\x08"
bitmap.flip_bit(3)   #=> "\x00"  (back to original)
bitmap.flip_bit(100) #=> IndexError
```

---

#### `each_set_bit_offset(count_from: :lsb) { |n| ... } -> self`
#### `each_set_bit_offset(count_from: :lsb) -> Enumerator`

Yields the logical position of each **set-bit** (bit value == 1). Without a block, returns an `Enumerator`. With a block, returns `self`.

```
data = "\xAA\xCC"  (byte[0]=0b10101010, byte[1]=0b11001100)

Flat positions of all set-bits:

  byte[0]: b1 b3 b5 b7  =>  positions  1,  3,  5,  7
  byte[1]: b2 b3 b6 b7  =>  positions 10, 11, 14, 15

count_from: :lsb yields:  1,  3,  5,  7, 10, 11, 14, 15
count_from: :msb yields:  0,  2,  4,  6,  8,  9, 12, 13
```

The returned positions use the same numbering convention as `bit_at`:

```ruby
data.each_set_bit_offset(count_from: :msb).all? do |n|
  data.bit_at(n, count_from: :msb)
end
#=> true
```

---

#### `set_bit_offsets(count_from: :lsb) -> Array`
#### `set_bit_offsets(count_from: :lsb) { |n| ... } -> self`

Without a block, equivalent to `each_set_bit_offset(count_from: count_from).to_a`. With a block, equivalent to `each_set_bit_offset(count_from: count_from) { |n| ... }`.

---

### Flat

#### `bit_slice(bit_offset, bit_length) -> String | nil`
#### `bit_slice(range) -> String | nil`

The bit-granularity analog of `String#byteslice`. Extracts `bit_length` bits starting at flat bit position `bit_offset` (counted from the first bit, LSB-first).

The range form is equivalent to the integer form, with the offset and length derived from the given bit range. Negative indices count backward from the end, exactly as in `byteslice` and `[]`.

The result length is `ceil(bit_length / 8)` bytes. If `bit_length` is not a multiple of 8, the unused high bits of the last byte are cleared to zero.

Returns `nil` if `bit_offset` or `bit_length` is not an `Integer`, if either is negative, or if `bit_offset` is beyond the end of the string.

```ruby
data = "\xFF\xAA"   # byte[0]=0xFF, byte[1]=0xAA (0b10101010)

data.bit_slice(0, 8)   #=> "\xFF"
data.bit_slice(8, 8)   #=> "\xAA"
data.bit_slice(4, 8)   #=> "\xAF"   # bits 4-11 packed LSB-first

data.bit_slice(0..7)   #=> "\xFF"
data.bit_slice(0...8)  #=> "\xFF"
data.bit_slice(-8..-1) #=> "\xAA"
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

#### `bit_splice(bit_index, bit_length, str) -> self`
#### `bit_splice(bit_index, bit_length, str, str_bit_index, str_bit_length) -> self`
#### `bit_splice(range, str) -> self`
#### `bit_splice(range, str, str_range) -> self`

The bit-granularity analog of `String#bytesplice`. Writes `bit_length` bits from `str` into `self` starting at flat bit position `bit_index` (counted from the first bit, LSB-first).

The inverse of `bit_slice`: where `bit_slice` reads a sub-sequence of bits into a new String, `bit_splice` writes one back. Returns `self`.

Unlike `bytesplice`, `bit_splice` does not resize `self`. The destination range always has length `bit_length` (or the length implied by the destination range form), and the source side must provide at least that many bits. If the destination range or source range falls outside the available bits, it raises `IndexError`. This is the only sensible choice at sub-byte granularity: partial bytes cannot be shifted to make room.

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

# source range too short
buf.bit_splice(1, 7, "")         #=> IndexError

# destination range too long
"\xAA\xCC".bit_splice(1, 17, "abcalkjsdcfkljaf") #=> IndexError
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

#### `bit_run_count(pos, bit) -> Integer | nil`

Returns the length of the consecutive run of `bit` starting at flat position `pos`, counting forward toward higher bit indices.

If a run of `bit` starts at `pos`, returns its length as an `Integer`.
Otherwise, returns `nil`. This includes both cases where `pos` is out of range and where the bit at `pos` does not equal `bit`.

`bit` accepts `0`, `1`, `false`, or `true` (`false`/`true` are aliases for `0`/`1`, matching the values yielded by `each_bit_run`).

Inspired by Gauche Scheme's `bitvector-count-run`.

```ruby
data = "\xF0"   # 11110000 (LSB-first: bits 0-3 are 0, bits 4-7 are 1)

data.bit_run_count(0, 0)  #=> 4  (4 zeros forward from bit 0)
data.bit_run_count(4, 1)  #=> 4  (4 ones forward from bit 4)
data.bit_run_count(0, 1)  #=> nil  (bit 0 is not 1)

data = "\xFF\xFF\x00"
data.bit_run_count(0,  1) #=> 16 (16 ones forward from bit 0)
data.bit_run_count(16, 0) #=> 8  (8 zeros forward from bit 16)
data.bit_run_count(24, 0) #=> nil  (out of range)
```

Building block for position-driven iteration (Gauche style):

```ruby
pos = 0
runs = []
until (bit = data.bit_at(pos)).nil?
  len = data.bit_run_count(pos, bit)
  runs << [bit, len]
  pos += len
end
```

---

### Aggregate

#### `bit_count -> Integer`

Returns the total number of set-bits across the entire string.

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

### Bitwise

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

### Why no `bit_size`?

This proposal does not add `bit_size`.

For any `String`, the physical number of bits is always `bytesize * 8`.
When a `String` is used as a bitmap, however, the number of semantically meaningful bits is format-dependent and often not equal to the physical capacity of the last byte.

A dedicated `bit_size` method would therefore suggest a level of semantic precision that `String` itself does not carry.
Callers that need the physical bit length can already write `str.bytesize * 8`.
