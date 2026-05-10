# String Bit Operations

Ruby's `String` is already a byte sequence. This proposal extends it one level lower: **a bit sequence** --- making packed binary buffers first-class values without any new class or intermediate allocation. A companion extension to `Array` applies validity bitmaps directly to Ruby arrays, covering the Apache Arrow use case without per-element `rb_yield` overhead.

The methods are designed for real workloads: Apache Arrow validity bitmaps, bitmap font glyph data, and any protocol buffer where bits carry meaning. Most methods operate zero-copy on the existing string bytes; the non-`!` bulk bitwise variants and `bit_slice` return a newly allocated `String`. Because the API relies solely on `String`, the same methods would benefit memory-constrained implementations such as mruby and PicoRuby once adopted into CRuby.

## Proposed Methods

### String class

| category | methods | zero-copy | `order:` keyword param |
|----------|---------|-----------|----------|
| read | `bit_at`, `bit_count` | yes | `bit_at` only |
| iterate bits | `each_bit`, `bits` | yes | yes |
| iterate set-bit positions | `each_set_bit`, `set_bit_positions` | yes | yes |
|  extract | `bit_slice` | no | yes |
| multi-bit mutation | `bit_splice` | yes | yes |
| packed bit-field iteration | `each_bit_slice` | no | yes |
| run-length iteration | `each_bit_run`, `bit_run_count` | yes | yes |
| single-bit mutation | `set_bit`, `clear_bit`, `flip_bit` | yes | yes |
| bulk bitwise (in-place) | `bit_not!`, `bit_and!`, `bit_or!`, `bit_xor!` | yes | no |
| bulk bitwise | `bit_not`, `bit_and`, `bit_or`, `bit_xor` | no | no |

### Array class

| category | methods | zero-copy | `order:` keyword param |
|----------|---------|-----------|----------|
| Array validity mask (in-place) | `Array#mask!` | yes | yes |
| Array validity mask | `Array#mask` |  no | yes |

<details>

<summary>Proposed Methods</summary>

### Read-only

---

#### `bit_at(n, order: :lsb) -> true | false | nil`

Returns whether bit at flat position `n` is set. Returns `nil` if `n` is out of range.

`order: :lsb` (default) counts from the first bit of the first byte. `order: :msb` counts from the last bit of the last byte (mirroring `each_bit(order: :msb)`).

```ruby
bitmap = "\xFF\xAA"   # byte[0]=0xFF, byte[1]=0xAA (0b10101010)

bitmap.bit_at(0)                #=> true  (bit 0 of byte[0])
bitmap.bit_at(0, order: :msb)   #=> true  (bit 7 of byte[1])
bitmap.bit_at(8, order: :msb)   #=> true  (bit 7 of byte[0])
```

Apache Arrow idiom --- check if element `i` is valid:

```ruby
valid = bitmap.bit_at(i)
```

---

#### `bit_count -> Integer`

Returns the total number of set bits across the entire string. O(bytesize) --- no per-bit branching. The C implementation will use `__builtin_popcount` (GCC/Clang) to map directly to the hardware `POPCNT` instruction where available.

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

#### `each_bit(order: :lsb) { |bool| ... } -> self`
#### `each_bit(order: :lsb) -> Enumerator`

Yields each bit as `true` or `false`. Without a block, returns an `Enumerator`. With a block, returns `self`.

```
order: :lsb  -- position 0 first (byte[0] LSB first)

  byte[0]                   byte[1]
  b0 b1 b2 b3 b4 b5 b6 b7 | b0 b1 b2 b3 b4 b5 b6 b7
  ^--- first yielded              last yielded ---^

order: :msb  -- position (total-1) first (last byte MSB first)

  byte[n-1]                 byte[0]
  b7 b6 b5 b4 b3 b2 b1 b0 | b7 b6 b5 b4 b3 b2 b1 b0
  ^--- first yielded              last yielded ---^
```

```ruby
"\xAA".each_bit.to_a
#=> [false, true, false, true, false, true, false, true]
#    pos 0   1     2      3     4      5     6      7

"\xAA".each_bit(order: :msb).to_a
#=> [true, false, true, false, true, false, true, false]
#    pos 7   6     5     4      3     2      1     0
```

---

#### `bits(order: :lsb) -> Array`
#### `bits(order: :lsb) { |bool| ... } -> self`

Without a block, returns an `Array` of `true`/`false` values --- equivalent to `each_bit(order: order).to_a`. With a block, forwards each bit to the block and returns `self` --- equivalent to `each_bit(order: order) { |b| ... }`.

Follows the same pattern as `String#bytes` vs `String#each_byte`.

```ruby
"\xAA".bits
#=> [false, true, false, true, false, true, false, true]

"\xAA".bits(order: :msb)
#=> [true, false, true, false, true, false, true, false]

"\xAA".bits { |b| print b ? "1" : "0" }
# prints: 01010101
# returns: "\xAA"
```

---

#### `each_set_bit(order: :lsb) { |n| ... } -> self`
#### `each_set_bit(order: :lsb) -> Enumerator`

Yields the flat position of each **set bit** (bit value == 1). Without a block, returns an `Enumerator`. With a block, returns `self`. The C implementation can use `__builtin_ctz` (count trailing zeros) to jump directly to the next set bit within each byte without scanning every bit.

```
data = "\xAA\xCC"  (byte[0]=0b10101010, byte[1]=0b11001100)

Flat positions of all set bits:

  byte[0]: b1 b3 b5 b7  =>  positions  1,  3,  5,  7
  byte[1]: b2 b3 b6 b7  =>  positions 10, 11, 14, 15

order: :lsb yields:  1,  3,  5,  7, 10, 11, 14, 15   (ascending)
order: :msb yields: 15, 14, 11, 10,  7,  5,  3,  1   (descending)
```

Positions from `each_set_bit` can be passed directly to `bit_at`:

```ruby
data.each_set_bit do |n|
  data.bit_at(n)  #=> always true
end
```

---

#### `set_bit_positions(order: :lsb) -> Array`
#### `set_bit_positions(order: :lsb) { |n| ... } -> self`

Without a block, returns an `Array` of set-bit positions --- equivalent to `each_set_bit(order: order).to_a`. With a block, forwards each position to the block and returns `self` --- equivalent to `each_set_bit(order: order) { |n| ... }`.

Follows the same pattern as `String#bytes` vs `String#each_byte`.

```ruby
"\xAA".set_bit_positions           #=> [1, 3, 5, 7]
"\xAA".set_bit_positions(order: :msb)   #=> [7, 5, 3, 1]

"\xAA\xCC".set_bit_positions
#=> [1, 3, 5, 7, 10, 11, 14, 15]
```

---

### Extract

---

#### `bit_slice(bit_offset, bit_length, order: :lsb) -> String | nil`

The bit-granularity analog of `String#byteslice`. Extracts `bit_length` bits starting at flat bit position `bit_offset`.

`order: :lsb` (default) counts `bit_offset` from the first bit. `order: :msb` counts from the last bit. The extracted bits are returned as a new `String` in the standard LSB-first layout.

```ruby
data = "\xFF\xAA"   # byte[0]=0xFF, byte[1]=0xAA (0b10101010)

data.bit_slice(0, 8)                #=> "\xFF"
data.bit_slice(0, 8, order: :msb)   #=> "\xAA"
```

The result String uses the same flat numbering scheme as the source, so `bit_at` and all iteration methods work directly on it:

```ruby
result = data.bit_slice(4, 8)
result.bit_at(0)                    #=> same as data.bit_at(4)
result.each_set_bit(order: :lsb)    # yields set-bit positions within the extracted range
```

Apache Arrow idiom --- normalize a non-byte-aligned validity bitmap for IPC serialization:

```ruby
# Arrow in-memory slice has bit offset 5; IPC requires offset 0
ipc_validity = validity_bitmap.bit_slice(slice_offset, slice_length)
```

---

### Multi-bit mutation

---

#### `bit_splice(bit_index, bit_length, str, order: :lsb) -> self`
#### `bit_splice(bit_index, bit_length, str, str_bit_index, str_bit_length, order: :lsb) -> self`
#### `bit_splice(range, str, order: :lsb) -> self`
#### `bit_splice(range, str, str_range, order: :lsb) -> self`

The bit-granularity analog of `String#bytesplice`. Writes `bit_length` bits from `str` into `self` starting at flat bit position `bit_index`.

`order: :lsb` (default) counts from the first bit. `order: :msb` counts from the last bit.
 The inverse of `bit_slice`: where `bit_slice` reads a sub-sequence of bits into a new String, `bit_splice` writes one back. Returns `self`.

`bit_splice` does not resize `self` --- the destination and source bit regions must have the same length. Attempting to splice a different number of bits raises `ArgumentError`. This mirrors the constraint `bytesplice` imposes on non-resizable strings, and is the only sensible choice at sub-byte granularity (partial bytes cannot be shifted to make room).

Negative indices count backward from the end, exactly as in `bytesplice` and `[]`. In the 3-arg and 2-arg forms, `bit_length` bits are read from the beginning of `str`. In the 5-arg form, the exact source sub-range is given explicitly.

```ruby
buf = +"\x00\x00"

# 3-arg integer form: write bits 0-7 of "\xFF" into bits 0-7 of buf
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

#### `bit_run_count(pos, bit, order: :lsb) -> Integer`

Returns the length of the consecutive run of `bit` starting at flat position `pos`. Returns 0 when `pos` is out of range or the bit at `pos` does not equal `bit`.

`bit` accepts `0`, `1`, `false`, or `true` (`false`/`true` are aliases for `0`/`1`, matching the values yielded by `each_bit_run`).

`order: :lsb` (default) counts forward toward higher bit indices. `order: :msb` counts backward toward lower bit indices --- mirrors `each_bit_run(order: :msb)`.

Equivalent to Gauche Scheme's `bitvector-count-run`.

```ruby
data = "\xF0"   # 11110000 (LSB-first: bits 0-3 are 0, bits 4-7 are 1)

data.bit_run_count(0, 0)  #=> 4  (4 zeros forward from bit 0)
data.bit_run_count(4, 1)  #=> 4  (4 ones forward from bit 4)
data.bit_run_count(0, 1)  #=> 0  (bit 0 is not 1)

data.bit_run_count(3, 0, order: :msb)  #=> 4  (4 zeros backward from bit 3)
data.bit_run_count(7, 1, order: :msb)  #=> 4  (4 ones backward from bit 7)

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

#### `each_bit_slice(bitlen, planes: 1, order: :lsb) { |*slices| } -> self`
#### `each_bit_slice(bitlen, planes: 1, order: :lsb) -> Enumerator`

Iterates over the string in consecutive `bitlen`-bit windows, grouping `planes` windows per block call. Each window is passed to the block as a packed `String` using the same LSB-first bit layout as `bit_slice`. Without a block, returns an `Enumerator`.

Incomplete trailing bits --- when `bytesize * 8` is not a multiple of `bitlen * planes` --- are silently dropped, matching the behavior of `Enumerable#each_slice`.

```
order: :lsb (default)  -- windows yielded left-to-right (ascending bit position)
order: :msb            -- windows yielded right-to-left (descending bit position)
```

```ruby
data = "\xAA\xCC"   # 16 bits

data.each_bit_slice(8).to_a
#=> ["\xAA", "\xCC"]   # two 8-bit slices

data.each_bit_slice(8, planes: 2).to_a
#=> [["\xAA", "\xCC"]] # one iteration, two planes per call
```

**12-bit packed ADC / sensor data --- the primary motivation**

Embedded systems, audio codecs, and image sensors routinely pack measurements as 12-bit values into contiguous byte streams. This format is ubiquitous: it appears in ADC raw capture buffers, I2S / PDM audio frames, CAN bus sensor payloads, and MIPI CSI-2 RAW12 image data. Because 12 is not a multiple of 8, there is no single-byte alignment --- two 12-bit samples share a middle byte, and extracting them by hand requires careful shift arithmetic that is both tedious to write and error-prone.

`each_bit_slice` makes 12-bit (and any other fixed-width) packed formats first-class.
For multi-channel data (stereo audio, RGB sensor triplets, dual-ADC boards), the `planes:` keyword groups consecutive samples into a single block call, so the caller receives all channels for one sample point at once without extra bookkeeping.

```ruby
bitlen = 12

# Dual-channel 12-bit ADC: samples packed as ch0|ch1|ch0|ch1|...
adc_buf.each_bit_slice(bitlen, planes: 2, order: :lsb) do |ch0, ch1|
  # ch0 and ch1 are Strings; bit_at(i) reads the i-th bit (LSB-first)
  voltage0 = ch0_to_voltage(ch0)
  voltage1 = ch1_to_voltage(ch1)
  record(voltage0, voltage1)
end
```

The `planes:` keyword also enables efficient half-block rendering, as used in bitmap fonts and braille displays: one iteration delivers two scan-lines simultaneously, so the vertical combination (upper/lower half-block characters) can be computed without maintaining external state between calls:

```ruby
bitlen = 12

data.each_bit_slice(bitlen, planes: 2, order: :lsb) do |plane0, plane1|
  line = ""
  i = 0
  while i < bitlen
    case [plane0.bit_at(i), plane1.bit_at(i)]
    in [true,  true]  then line << "\xE2\x96\x88"  # Full Block U+2588
    in [true,  false] then line << "\xE2\x96\x80"  # Upper Half Block U+2580
    in [false, true]  then line << "\xE2\x96\x84"  # Lower Half Block U+2584
    else                   line << " "
    end
    i += 1
  end
  puts line
end
```

Each extracted slice is a plain `String`, so `bit_at`, `each_bit`, `bit_count`, and all other bit methods apply directly --- no intermediate conversion or unpacking step required.
This is what makes the API worthwhile: the same tool that reads Arrow validity bitmaps also decodes packed sensor frames, with no new types and no extra allocation beyond the slice strings themselves.

**`planes:` vs `.each_slice` chaining**

The idiomatic alternative, `each_bit_slice(bitlen).each_slice(planes) { |arr| }`, is functionally equivalent but allocates one `Array` per group to hold the slices before yielding them. For a 30 KB buffer with 12-bit slices and `planes: 2` that is 10,000 extra short-lived Arrays. The built-in `planes:` keyword eliminates those entirely by yielding all channels in a single `rb_yield_values2` call. Benchmarks show approximately **1.6x throughput** and **33% fewer heap objects** compared with the chained form.

---

#### `each_bit_run(order: :lsb) { |bit, len| } -> self`
#### `each_bit_run(order: :lsb) -> Enumerator`

Yields `(bit, run_length)` pairs for each consecutive run of identical bits. Run-length boundary detection and counting happen entirely in C --- no Ruby-level `current`/`count` state machine is needed.

The key insight from Gauche's `bitvector-count-run`: instead of visiting every bit, use `__builtin_ctzll` to skip up to 64 identical bits in a single instruction per 8-byte word, making the inner loop O(run\_length / 64) rather than O(run\_length).

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
# with each_bit (Ruby-level state machine, one yield per bit)
runs = []; current = nil; count = 0
data.each_bit(order: :lsb) do |b|
  if b == current then count += 1
  else runs << [current, count] unless current.nil?; current = b; count = 1
  end
end
runs << [current, count] unless current.nil?

# with each_bit_run (boundary detection in C, one yield per run)
runs = data.each_bit_run(order: :lsb).to_a
```

Performance characteristics for random data (~50% density, average run length ≈ 2):

| | Ruby | YJIT |
|---|---|---|
| baseline (byte loop) | 1.0x | 1.0x |
| `each_bit` + Ruby state machine | 1.4x | 0.8x |
| `each_bit_run` | **4.3x** | **1.5x** |

For structured data with longer runs (sparse validity bitmaps, sensor bursts, run-length compressed streams) the speedup is proportional to average run length --- a 64-bit run of zeros is resolved in a single `ctzll` call.

---

### Single-bit mutation

These methods are always destructive (the name implies mutation, no `!` variant). Each returns `self` for chaining. Raises `IndexError` for out-of-range or negative `n`.

Read methods return `nil` for out-of-range positions; mutation methods raise. This asymmetry is intentional: a missed read is a logic question ("is this bit set?"), while a missed write is data corruption. Strict failure on mutation prevents silent bugs where a caller passes a wrong index and believes the write succeeded.

---

#### `set_bit(n, order: :lsb) -> self`

Sets bit at position `n` to 1. `order: :lsb` (default) counts from the first bit; `order: :msb` counts from the last bit.

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

#### `clear_bit(n, order: :lsb) -> self`

Sets bit at position `n` to 0. `order: :lsb` (default) counts from the first bit; `order: :msb` counts from the last bit.

```ruby
bitmap = +"\xFF\xFF"
bitmap.clear_bit(0)  #=> "\xFE\xFF"
bitmap.clear_bit(8)  #=> "\xFE\xFE"
```

---

#### `flip_bit(n, order: :lsb) -> self`

Toggles bit at position `n`. `order: :lsb` (default) counts from the first bit; `order: :msb` counts from the last bit.

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

No Ruby block or `rb_yield` is involved --- the operation is performed entirely in C, making it significantly faster than a Ruby-level `map` loop.

#### `mask(bitmap, order: :lsb, invert: false) -> Array`

Returns a new `Array`. Elements whose corresponding bit is 1 (for `invert: false`) or 0 (for `invert: true`) are kept; all others become `nil`.

```ruby
data   = [1, 2, 3, 4]

# LSB-first (default, Apache Arrow convention): 0b00001101 -> bits 0,2,3 set = elements 0,2,3 valid
bitmap = "\x0D".b   # 0b00001101
data.mask(bitmap)                        #=> [1, nil, 3, 4]

# MSB-first: 0b11010000 -> bits 7,6,4 set = elements 0,1,3 valid
bitmap = "\xD0".b   # 0b11010000
data.mask(bitmap, order: :msb)           #=> [1, 2, nil, 4]

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

#### `mask!(bitmap, order: :lsb, invert: false) -> self`

Same as `mask` but modifies the array in place and returns `self`. Elements that would become `nil` are overwritten; valid elements are untouched.

```ruby
ary = [1, 2, 3, 4]
ary.mask!("\x0D".b)   #=> [1, nil, 3, 4]  (LSB-first default)
ary                      #=> [1, nil, 3, 4]  (modified in place)
```

</details>

---

## Use Cases and Design Considerations

<details>

<summary>Use Cases and Design Considerations</summary>

### Bit position numbering

All methods share a single flat numbering scheme: **position N** lives in `byte[N/8]` at bit `N % 8` (counted from LSB = 0).

```
   byte[0]                                            byte[1]
   +-----+-----+-----+-----+-----+-----+-----+-----+  +-----+-----+-----+-----+-----+-----+-----+-----+
   | b7  | b6  | b5  | b4  | b3  | b2  | b1  | b0  |  | b7  | b6  | b5  | b4  | b3  | b2  | b1  | b0  |
   +-----+-----+-----+-----+-----+-----+-----+-----+  +-----+-----+-----+-----+-----+-----+-----+-----+
  pos 7     6     5     4     3     2     1     0    pos 15    14    13    12    11    10    9     8
    MSB                                        LSB      MSB                                       LSB
```

Within each byte, the **LSB is the lower-numbered position**. Bytes are numbered from the start of the string, so `byte[0]` always holds positions 0-7.

### The `order:` parameter

The `order:` keyword controls **interpretation and traversal direction**. It defines which bit is considered "first" (index 0).

| `order:` | interpretation | position sequence / indexing |
|----------|-----------|-------------------|
| `:lsb` (default) | low -> high | 0, 1, 2, ... , total-1 |
| `:msb`   | high -> low | total-1, ..., 2, 1, 0 |

For iterative methods (`each_bit`, `each_set_bit`), it controls the yield order. For index-based methods (`bit_at`, `bit_slice`, `bit_splice`, `set_bit`, etc.), it defines the mapping of logical index `n` to physical bit position.

The default is `:lsb` for consistency with `Array#mask` and the Apache Arrow convention (element `i` = byte `i/8` bit `i%8`). This ensures `values.mask(bitmap)` and `bitmap.each_set_bit { |i| values[i] }` work correctly without extra arguments. Additionally, `:lsb` yields positions in ascending order, making `set_bit_positions` results immediately usable as array subscripts.

The trade-off is that visual binary display (where the MSB is leftmost) requires `order: :msb` explicitly. This is preferred as columnar analytics and Arrow represent the primary production workload.

The symbol values `:lsb` and `:msb` leave room for future extensions (e.g. `:native`, `:network`) without breaking changes. As a consequence, `each_bit(order: :msb).to_a` is always the reverse of `each_bit.to_a`, and the same holds for `each_set_bit`.

### Naming convention: symmetry with `bytes` / `each_byte`

The method names follow the same pattern as Ruby's built-in `String#bytes` and `String#each_byte`.

`bytes` and `each_byte` are not independent operations --- `bytes` **delegates** to `each_byte`. When called without a block, `bytes` returns `each_byte.to_a`. When called with a block, `bytes` forwards it to `each_byte` and returns `self`. The bit methods follow the same convention:

```ruby
# each_bit: Enumerator or self
s.each_bit               #=> Enumerator
s.each_bit { |b| ... }  #=> self (s)

# bits: Array or self
s.bits                   #=> Array of true/false (same as each_bit.to_a)
s.bits { |b| ... }       #=> self (s), same as each_bit { |b| ... }

# each_set_bit: Enumerator or self
s.each_set_bit               #=> Enumerator
s.each_set_bit { |n| ... }  #=> self (s)

# set_bit_positions: Array or self
s.set_bit_positions                   #=> Array of set-bit positions (same as each_set_bit.to_a)
s.set_bit_positions { |n| ... }       #=> self (s), same as each_set_bit { |n| ... }
```

The word "set" is ambiguous in English (verb: mutate; adjective: already-set bits). `each_set_bit` resolves this --- the `each_` prefix always signals iteration, never mutation. `set_bit_positions` names the return type explicitly, distinguishing it from `bits`.

| analogy | byte methods | bit methods |
|---------|-------------|-------------|
| iterate with block or Enumerator | `each_byte` | `each_bit` |
| Array or block shorthand | `bytes` | `bits` |
| iterate set-bit *positions* | --- | `each_set_bit` |
| Array or block shorthand for set-bit positions | --- | `set_bit_positions` |

The mutation methods `set_bit(n)`, `clear_bit(n)`, and `flip_bit(n)` use unambiguous verb phrases and are not affected by this convention.

### Bit ordering across domains

| domain | native bit ordering | compatibility with current design |
|--------|---------------------|------------------------------------|
| Apache Arrow validity bitmap | LSB-first (element i = byte[i/8] bit i%8) | native |
| ARM / STM32 hardware registers | bit 0 = LSB (ARM Architecture Reference Manual) | native |
| BLE advertising PDU (air transmission order) | LSB-first | native |
| IEEE 802.15.4 / Zigbee | LSB-first | native |
| PostgreSQL visibility map, ext4 block bitmap | LSB-first | native |
| Roaring Bitmap (analytics databases) | LSB-first | native |
| RFC-style network headers (IPv4, TCP, DNS) | bit 0 = MSB of first byte (RFC diagram convention) | position offset conversion needed: `7 - (n % 8) + (n / 8) * 8` |
| BitTorrent bitfield message | piece 0 = MSB of byte 0 | same offset conversion as RFC |
| PNG 1/2/4-bit scanlines | MSB = leftmost pixel | same offset conversion as RFC |
| Huffman / LZ compressed bit streams | MSB written first into each byte | same offset conversion as RFC |

Domains using LSB-first numbering represent the majority of high-performance in-process
workloads (columnar analytics, embedded hardware, filesystem bitmaps). Domains using
MSB-first numbering (RFC headers, BitTorrent, PNG sub-byte images) are real but tend to
appear in Ruby code that already uses `unpack` with format strings and integer bit shifts,
where a flat-bitmap API is less directly useful.

For the MSB-first domains, the relationship between their document-level bit index d and the
flat position n used by this API is `n = 7 - (d % 8) + (d / 8) * 8`. This is mechanical but
not obvious; if any of these domains become primary use cases, the naming and default
choices should be revisited.

### Packed integer fields

Several domains store small fixed-width integers in adjacent bit fields: 4-bit nibbles in
packed audio or sensor data, 3-bit or 5-bit fields in network headers, variable-width codes
in compression streams. The current API handles extraction via `bit_slice(offset, width)`
followed by a manual conversion to integer, but there is no single-call method.

A future `read_uint(bit_offset, bit_length) -> Integer` could address this. Its specification
would need to commit to a byte order for multi-byte fields (little-endian vs big-endian within
the extracted field), making it more complex than the methods in this proposal. This is noted
as a potential direction rather than a current commitment.

### mruby / PicoRuby: Bitmap Font Rendering

<details>

<summary>mruby / PicoRuby: Bitmap Font Rendering</summary>

Bitmap font libraries such as [picoruby-terminus](https://github.com/picoruby/picoruby-terminus) and [picoruby-rapicco](https://github.com/picoruby/picoruby-rapicco) store glyph data as packed binary strings and render them pixel-by-pixel. The current rendering hot path (e.g. `Rapicco::Slide#render_slide`) tests each bit with a shift-and-mask idiom:

```ruby
# current code in picoruby-rapicco/mrblib/slide.rb
scan_line_upper = glyphs[g][l * 2]
scan_line_lower = glyphs[g][l * 2 + 1]
shift = width - 1
while 0 <= shift
  if (scan_line_upper >> shift) & 1 == 1
    if (scan_line_lower >> shift) & 1 == 1
      print "\xE2\x96\x88"  # Full Block
    else
      print "\xE2\x96\x80"  # Upper Half Block
    end
  else
    if (scan_line_lower >> shift) & 1 == 1
      print "\xE2\x96\x84"  # Lower Half Block
    else
      print " "
    end
  end
  shift -= 1
end
```

Once these methods are available, glyph data stored as a packed binary String can be queried directly. `bit_at` returns a boolean, eliminating the `& 1 == 1` pattern. `each_bit(order: :msb)` yields pixels left-to-right in natural rendering order (MSB = leftmost pixel):

```ruby
# with String bit operations
glyph.each_bit(order: :msb).each_slice(width) do |row|
  upper_row, lower_row = row, next_row
  upper_row.zip(lower_row).each do |upper, lower|
    print case [upper, lower]
          when [true,  true]  then "\xE2\x96\x88"
          when [true,  false] then "\xE2\x96\x80"
          when [false, true]  then "\xE2\x96\x84"
          else                     " "
          end
  end
end
```

#### Memory efficiency

Packed binary storage is already possible in Ruby today --- the 8x reduction over character strings is not new. What is missing is ergonomic access. Without bit-level methods, reading a single pixel requires the shift-and-mask idiom shown above, and building a bitmap incrementally requires hand-written byte arithmetic. The friction is high enough that tools often choose the simpler `"0"`/`"1"` character format instead, paying the memory cost to avoid the code complexity.

```
"01001111 01100001" (character string, 18 bytes for 16 pixels)
 vs
"\x4F\x61"         (packed binary,     2 bytes for 16 pixels)
```

On a microcontroller with tens of kilobytes of RAM, this trade-off is real. The proposed methods remove the ergonomic barrier: `set_bit` builds packed bitmaps incrementally with no byte arithmetic, and `bit_at` / `each_bit` read them back without intermediate allocation. Packed binary becomes as natural to work with as any other format, making the memory saving achievable in practice.

#### Glyph mask operations

Applying a clipping mask or combining two bitmap layers (e.g. a glyph over a background pattern) becomes a single `bit_and` call instead of a byte-by-byte loop:

```ruby
clipped = glyph_bitmap.bit_and(clip_mask)
```

</details>

---

### Apache Arrow Compatibility

<details>

<summary>Apache Arrow Compatibility</summary>

Apache Arrow validity bitmaps use the same flat LSB-first layout: element `i` is stored in `byte[i / 8]` at bit `i % 8`.

```
Arrow validity bitmap for 10 elements (byte[0] = 0b11111111, byte[1] = 0b00000011):

  element:  0    1    2    3    4    5    6    7    8    9
            |    |    |    |    |    |    |    |    |    |
  byte[0]: [b0  |b1  |b2  |b3  |b4  |b5  |b6  |b7 ]
  pos:       0    1    2    3    4    5    6    7
  byte[1]: [b0  |b1  |b2  ...]
  pos:       8    9   10  ...

  validity:  ok   ok   ok   ok   ok   ok   ok   ok   ok   ok
```

`bit_at(i)` maps directly to Arrow element index `i`. `each_set_bit(order: :lsb)` yields valid element indices in ascending order. `Array#bitwise(bitmap, order: :lsb)` materializes an Arrow column as a Ruby array with `nil` in place of null values --- entirely in C with no per-element callback overhead.

#### Arrow IPC serialization

Arrow IPC (Inter-Process Communication) is the binary wire format used to transfer Arrow data between processes, language runtimes, and storage systems such as Parquet and Feather.

Arrow supports zero-copy slicing in memory: slicing an array produces a lightweight object that references the original buffer with a non-zero `offset`. For a validity bitmap, this offset is measured in **bits** --- the bitmap for a sliced column may start at an arbitrary bit position within a byte.

The IPC format, however, requires every buffer to be byte-aligned: element 0 of the serialized column must map to bit 0 of the first byte. Serializing a sliced array therefore requires re-packing the validity bitmap to eliminate the in-memory bit offset. `IO::Buffer#slice` operates at byte granularity and cannot perform this re-packing. `bit_slice` fills this gap:

```ruby
# column slice: validity bitmap starts at in-memory bit offset 5, covering 100 elements
# IPC requires the bitmap to start at bit 0
ipc_validity = validity_bitmap.bit_slice(5, 100)
```

This is the operation that bridges the non-byte-aligned in-memory representation that Arrow uses for zero-copy slicing to the byte-aligned form required by the IPC format.

### #Why no byte-offset parameter?

Apache Arrow IPC messages pack multiple column buffers into a single contiguous allocation:

```
[metadata][pad][validity bitmap A][pad][data buffer A]
               [validity bitmap B][pad][data buffer B] ...
```

One might expect each method to accept a `byte_offset:` keyword so that a bitmap living inside a larger String can be accessed without first extracting it. The methods deliberately omit this parameter for the following reasons:

| operation | alternative |
|-----------|-------------|
| `bit_at(n)` on a sub-range | encode the offset in `n`: `bit_at(byte_offset * 8 + n)` |
| `bit_count`, `each_bit`, `each_set_bit` | extract once with `byteslice(offset, length)`, then call the method |
| `bit_and!`, `bit_or!`, `bit_xor!` on a sub-range | use `IO::Buffer` (see below) |

For single-bit access the byte offset is already expressible through `n`. For bulk read-only operations, `byteslice` produces a one-time copy whose cost is negligible compared with the operation itself (a bitmap for one million rows is only 123 KB).

**In-place bulk operations on a sub-range are the one case that cannot be handled by adjusting `n` or calling `byteslice`**, because `byteslice` returns a copy and writing back is not possible. This is intentional: that use case belongs to `IO::Buffer`.

#### IO::Buffer as the zero-copy complement

CRuby's `IO::Buffer` is designed for exactly this scenario. `IO::Buffer#slice` returns a *view* into the original buffer --- a new `IO::Buffer` object that shares the underlying memory without any copy. Operations on the slice write directly into the parent buffer:

```ruby
buf    = IO::Buffer.map(File.open("data.arrow"))
bitmap = buf.slice(validity_offset, bitmap_bytes)  # no copy
# bitmap is a zero-copy window; future String bit methods
# operating on IO::Buffer would apply here.
```

The String methods proposed here cover the common case where a column buffer has already been materialized as a `String` (e.g. read from a socket, deserialized from MessagePack, or extracted via `byteslice`).

`IO::Buffer` is designed for memory management: zero-copy views, I/O, and low-level typed access. The methods proposed here are designed for semantic access to already-materialized byte sequences: bit-level iteration, mutation, and bulk operations. These concerns are complementary:

* `IO::Buffer`: memory ownership, zero-copy slicing, I/O operations
* `String` (proposed): bit-level iteration and manipulation of materialized byte data

</details>

</details>

---

## Benchmark

<details>

<summary>Benchmark</summary>

Environment:

```
$> uname -a
Linux hasumi-Ubuntu-Desktop 6.17.0-20-generic #20~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Mar 19 01:28:37 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
```

**[TODO]**

</details>

---

## Prior Art: Bit Operations in Other Languages

<details>

<summary>Prior Art: Bit Operations in Other Languages</summary>

Bit-level operations are common across languages, but they are typically exposed either as low-level primitives on integers or through dedicated container types. This proposal integrates those capabilities directly into Ruby's `String`, preserving zero-copy semantics while raising the abstraction to match Ruby's Enumerable style.

### Python

Python provides limited bit-level functionality:

* `int.bit_count()` --- population count (popcount)
* `int.to_bytes()` / `int.from_bytes()` --- conversion between integers and byte sequences

There is no standard abstraction for iterating over bits in a byte sequence or treating a bytes object as a bit array.

**Implication:** Bit operations are tied to numeric values, not sequences. This proposal extends Ruby beyond Python by treating byte sequences (`String`) as first-class bit containers.

### Java

Java provides `BitSet`, a dedicated mutable bit container:

* `get(int index)` --- read bit
* `set(int index)` / `clear(int index)` / `flip(int index)` --- mutate
* `nextSetBit(int fromIndex)` --- iterate set bits
* `cardinality()` --- population count

Iteration over set bits requires explicit looping:

```java
for (int i = bs.nextSetBit(0); i >= 0; i = bs.nextSetBit(i + 1)) {
    // ...
}
```

**Implication:** Java requires a separate container type (`BitSet`) and exposes relatively low-level iteration primitives. In contrast, Ruby integrates bit operations into `String` and provides direct iteration via `each_bit` and `each_set_bit`, eliminating boilerplate.

### Rust

Rust exposes bit operations at both the primitive and library level:

* Integer methods: `count_ones()` (popcount), `trailing_zeros()` (ctz)
* External crates such as `bitvec`: `get(index) -> Option<bool>`, `set(index, bool)`, `iter()`

The use of `Option<bool>` for `get` mirrors Ruby's `nil` return for out-of-range access.

**Implication:** Rust provides efficient primitives and flexible abstractions, but requires either external crates or explicit types. Ruby's proposal achieves similar expressiveness directly on `String` with no additional types.

### C++

C++ offers `std::bitset` and `std::vector<bool>`:

* `test(pos)` --- read bit
* `set(pos)` / `reset(pos)` / `flip(pos)` --- mutate
* `count()` --- popcount

These APIs are efficient but not integrated with standard iteration patterns, and naming tends toward technical terminology (`test`, `reset`).

**Implication:** C++ emphasizes performance and explicitness, but lacks a high-level, idiomatic iteration model. Ruby's `each_bit` and `each_set_bit` provide a more natural, Enumerable-based interface.

### Go

Go provides low-level bit operations via `math/bits`:

* `bits.OnesCount(x)` --- popcount

Bit arrays are typically implemented manually using slices of integers or bytes.

**Implication:** Go keeps bit manipulation minimal and explicit. Higher-level abstractions are left to the user. Ruby instead provides a built-in abstraction directly on `String`.

### Summary

Across languages, bit operations typically fall into two categories:

| approach | languages | characteristics |
|----------|-----------|-----------------|
| integer-centric | Python, Go | bit operations tied to numeric types |
| dedicated container | Java, C++, Rust (bitvec) | separate types, explicit APIs |

This proposal takes a third approach: **integrate bit-level operations directly into `String`, the existing byte container.**

Key differences from the above:

* No new container type (unlike `BitSet`, `bitvec`)
* Zero-copy operation on existing byte buffers
* Full integration with Ruby's Enumerable style (`each_bit`, `each_set_bit`)
* Natural method naming consistent with `String#bytes` / `each_byte`

In effect, this design lifts bit manipulation from low-level primitives into a high-level, idiomatic Ruby interface, while preserving the performance characteristics required for real-world workloads such as Apache Arrow and bitmap rendering.

</details>
