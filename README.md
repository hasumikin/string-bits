# String Bit Operations

Ruby's `String` is already a byte sequence. This proposal extends it one level lower: **a bit sequence** — making packed binary buffers first-class values without any new class or intermediate allocation.

The methods are designed for real workloads: Apache Arrow validity bitmaps, bitmap font glyph data, and any protocol buffer where bits carry meaning. Most methods operate zero-copy on the existing string bytes; the non-`!` bulk bitwise variants and `bit_slice` return a newly allocated `String`. Because the API relies solely on `String`, the same methods would benefit memory-constrained implementations such as mruby and PicoRuby once adopted into CRuby.

## Proposed Methods

| category | methods | zero-copy |
|----------|---------|-----------|
| read | `bit_at`, `popcount` | yes |
| iterate bits | `each_bit`, `bits` | yes |
| iterate set-bit positions | `each_set_bit`, `set_bit_positions` | yes |
| extract | `bit_slice` | no |
| single-bit mutation | `set_bit`, `clear_bit`, `flip_bit` | yes |
| bulk bitwise (in-place) | `bit_not!`, `bit_and!`, `bit_or!`, `bit_xor!` | yes |
| bulk bitwise | `bit_not`, `bit_and`, `bit_or`, `bit_xor` | no |

---

## Bit Position Numbering

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

The `order:` keyword controls **traversal direction** only; it never changes what position N means.

| `order:` | traversal | position sequence |
|----------|-----------|-------------------|
| `:lsb`   | low -> high | 0, 1, 2, ... , total-1 |
| `:msb`   | high -> low | total-1, ..., 2, 1, 0 |

The default is `:msb` — bits are yielded from the highest-numbered position down to 0, matching the conventional representation of binary data where the most significant bit appears on the left. Apache Arrow and numeric contexts that need ascending element order should pass `order: :lsb` explicitly.

The symbol values `:lsb` and `:msb` were chosen to leave room for future extensions (e.g. `:native`, `:network`) without a breaking change.

As a consequence, `each_bit(order: :msb).to_a` is always exactly the reverse of `each_bit(order: :lsb).to_a`, and the same holds for `each_set_bit`.

---

## Naming Convention: Symmetry with `bytes` / `each_byte`

The method names follow the same pattern as Ruby's built-in `String#bytes` and `String#each_byte`.

### How `bytes` and `each_byte` relate

```ruby
s = "AB"
s.each_byte { |b| ... }   # yields each byte; returns self
s.each_byte               # returns Enumerator
s.bytes { |b| ... }       # same as each_byte with block; returns self
s.bytes                   # returns Array of byte values
```

`bytes` and `each_byte` are not independent operations — `bytes` **delegates** to `each_byte`. When called without a block, `bytes` returns `each_byte.to_a`. When called with a block, `bytes` forwards it to `each_byte` and returns `self`.

### Why "set bits" requires two method names

The word "set" is ambiguous in English:

- As a **verb**: `set_bit(n)` — mutate, set bit n to 1
- As an **adjective**: "set bits" — bits whose value is 1 (already set)

This creates a naming tension: a method named after the adjective form risks being read as a mutating verb. `each_set_bit` resolves this — the `each_` prefix always signals iteration, never mutation. For the array-form shorthand, `set_bit_positions` names the return type explicitly (integer positions, not boolean values), distinguishing it clearly from `bits`.

| analogy | byte methods | bit methods |
|---------|-------------|-------------|
| iterate with block or Enumerator | `each_byte` | `each_bit` |
| Array or block shorthand | `bytes` | `bits` |
| iterate set-bit *positions* | — | `each_set_bit` |
| Array or block shorthand for set-bit positions | — | `set_bit_positions` |

The mutation methods `set_bit(n)`, `clear_bit(n)`, and `flip_bit(n)` use unambiguous verb phrases and are not affected by this convention.

### Block and no-block behavior

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

When `bits` or `set_bit_positions` is called with a block, it returns `self` rather than an `Array`. This matches `String#bytes` exactly. Callers that need a transformed collection should chain via `each_bit` or `each_set_bit`:

```ruby
flags = s.each_bit(order: :lsb).map { |b| b ? :set : :clear }
```

---

## mruby / PicoRuby: Bitmap Font Rendering

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

### Memory efficiency

Packed binary storage is already possible in Ruby today — the 8x reduction over character strings is not new. What is missing is ergonomic access. Without bit-level methods, reading a single pixel requires the shift-and-mask idiom shown above, and building a bitmap incrementally requires hand-written byte arithmetic. The friction is high enough that tools often choose the simpler `"0"`/`"1"` character format instead, paying the memory cost to avoid the code complexity.

```
"01001111 01100001" (character string, 18 bytes for 16 pixels)
 vs
"\x4F\x61"         (packed binary,     2 bytes for 16 pixels)
```

On a microcontroller with tens of kilobytes of RAM, this trade-off is real. The proposed methods remove the ergonomic barrier: `set_bit` builds packed bitmaps incrementally with no byte arithmetic, and `bit_at` / `each_bit` read them back without intermediate allocation. Packed binary becomes as natural to work with as any other format, making the memory saving achievable in practice.

### Glyph mask operations

Applying a clipping mask or combining two bitmap layers (e.g. a glyph over a background pattern) becomes a single `bit_and` call instead of a byte-by-byte loop:

```ruby
clipped = glyph_bitmap.bit_and(clip_mask)
```

---

## Apache Arrow Compatibility

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

`bit_at(i)` maps directly to Arrow element index `i`. `each_set_bit(order: :lsb)` yields valid element indices in ascending order.

### Arrow IPC serialization

Arrow IPC (Inter-Process Communication) is the binary wire format used to transfer Arrow data between processes, language runtimes, and storage systems such as Parquet and Feather.

Arrow supports zero-copy slicing in memory: slicing an array produces a lightweight object that references the original buffer with a non-zero `offset`. For a validity bitmap, this offset is measured in **bits** — the bitmap for a sliced column may start at an arbitrary bit position within a byte.

The IPC format, however, requires every buffer to be byte-aligned: element 0 of the serialized column must map to bit 0 of the first byte. Serializing a sliced array therefore requires re-packing the validity bitmap to eliminate the in-memory bit offset. `IO::Buffer#slice` operates at byte granularity and cannot perform this re-packing. `bit_slice` fills this gap:

```ruby
# column slice: validity bitmap starts at in-memory bit offset 5, covering 100 elements
# IPC requires the bitmap to start at bit 0
ipc_validity = validity_bitmap.bit_slice(5, 100)
```

This is the operation that bridges the non-byte-aligned in-memory representation that Arrow uses for zero-copy slicing to the byte-aligned form required by the IPC format.

### Why no byte-offset parameter?

Apache Arrow IPC messages pack multiple column buffers into a single contiguous allocation:

```
[metadata][pad][validity bitmap A][pad][data buffer A]
               [validity bitmap B][pad][data buffer B] ...
```

One might expect each method to accept a `byte_offset:` keyword so that a bitmap living inside a larger String can be accessed without first extracting it. The methods deliberately omit this parameter for the following reasons:

| operation | alternative |
|-----------|-------------|
| `bit_at(n)` on a sub-range | encode the offset in `n`: `bit_at(byte_offset * 8 + n)` |
| `popcount`, `each_bit`, `each_set_bit` | extract once with `byteslice(offset, length)`, then call the method |
| `bit_and!`, `bit_or!`, `bit_xor!` on a sub-range | use `IO::Buffer` (see below) |

For single-bit access the byte offset is already expressible through `n`. For bulk read-only operations, `byteslice` produces a one-time copy whose cost is negligible compared with the operation itself (a bitmap for one million rows is only 123 KB).

**In-place bulk operations on a sub-range are the one case that cannot be handled by adjusting `n` or calling `byteslice`**, because `byteslice` returns a copy and writing back is not possible. This is intentional: that use case belongs to `IO::Buffer`.

### IO::Buffer as the zero-copy complement

CRuby's `IO::Buffer` is designed for exactly this scenario. `IO::Buffer#slice` returns a *view* into the original buffer — a new `IO::Buffer` object that shares the underlying memory without any copy. Operations on the slice write directly into the parent buffer:

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

---

## Use Cases and Design Considerations

The methods in this proposal share a single flat bit-numbering scheme: position N lives in
`byte[N/8]` at bit `N % 8` counted from the LSB (LSB = 0 within each byte). This convention
is a natural fit for array-indexed structures, but it conflicts with some domain conventions.
The following table summarises known use cases and their alignment with the current design.

### Bit ordering across domains

| domain | native bit ordering | compatibility with current design |
|--------|---------------------|------------------------------------|
| Apache Arrow validity bitmap | LSB-first (element i = byte[i/8] bit i%8) | native |
| ARM / STM32 hardware registers | bit 0 = LSB (ARM Architecture Reference Manual) | native |
| BLE advertising PDU (air transmission order) | LSB-first | native |
| IEEE 802.15.4 / Zigbee | LSB-first | native |
| PostgreSQL visibility map, ext4 block bitmap | LSB-first | native |
| Roaring Bitmap (analytics databases) | LSB-first | native |
| PicoRuby / mruby bitmap font | MSB = leftmost pixel; LSB numbering within each byte | `order: :msb` traversal covers the render direction |
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

### The `order:` default

The current default for `order:` is `:msb`. Both directions are defensible.

**Case for `:msb` as default:** Binary data is conventionally displayed with the most
significant bit on the left. `each_bit(order: :msb)` over a single byte produces digits in
the familiar left-to-right order. Bitmap font rendering yields pixels left-to-right naturally
without an explicit keyword argument.

**Case for `:lsb` as default:** The majority of identified use cases require ascending
iteration (Arrow, hardware registers, PostgreSQL bitmaps, Roaring Bitmaps, graph traversals).
These callers must write `order: :lsb` explicitly even though ascending iteration is the
common programming idiom. Positions returned by `set_bit_positions(order: :lsb)` are
immediately usable as array indices without any transformation. If Arrow is treated as the
primary production workload, making `:lsb` the default would reduce friction for the most
common path.

There is no universally correct answer. The default affects every caller that omits `order:`,
and changing it after adoption would be a breaking change. The open question is which omission
is more surprising: ascending iteration or MSB-first display?

### Packed integer fields

Several domains store small fixed-width integers in adjacent bit fields: 4-bit nibbles in
packed audio or sensor data, 3-bit or 5-bit fields in network headers, variable-width codes
in compression streams. The current API handles extraction via `bit_slice(offset, width)`
followed by a manual conversion to integer, but there is no single-call method.

A future `read_uint(bit_offset, bit_length) -> Integer` could address this. Its specification
would need to commit to a byte order for multi-byte fields (little-endian vs big-endian within
the extracted field), making it more complex than the methods in this proposal. This is noted
as a potential direction rather than a current commitment.

---

## Methods

### Read-only

---

#### `bit_at(n) -> true | false | nil`

Returns whether bit at flat position `n` is set. Returns `nil` if `n` is out of range (mirrors `String#[]` behaviour). O(1) — no allocation.

Out-of-range returns `nil` rather than raising so that `bit_at` can be used as a predicate in tight loops without exception overhead. This is consistent with `String#[]`, `Array#[]`, and `getbyte`, all of which return `nil` for an out-of-range index. Because `nil` is falsy, `if bitmap.bit_at(i)` works naturally as a boolean check with implicit bounds safety.

```ruby
bitmap = "\xFF\xAA"   # byte[0]=0xFF, byte[1]=0b10101010

bitmap.bit_at(0)   #=> true   (bit 0 of byte[0])
bitmap.bit_at(7)   #=> true   (bit 7 of byte[0])
bitmap.bit_at(8)   #=> false  (bit 0 of byte[1], 0b10101010 & 1 == 0)
bitmap.bit_at(9)   #=> true   (bit 1 of byte[1])
bitmap.bit_at(16)  #=> nil    (out of range)
```

Apache Arrow idiom — check if element `i` is valid:

```ruby
valid = bitmap.bit_at(i)
```

---

#### `popcount -> Integer`

Returns the total number of set bits across the entire string. O(bytesize) — no per-bit branching. The C implementation will use `__builtin_popcount` (GCC/Clang) to map directly to the hardware `POPCNT` instruction where available.

```ruby
"\x00".popcount     #=> 0
"\xFF".popcount     #=> 8
"\xAA".popcount     #=> 4   # 0b10101010
"\xFF\xFF".popcount #=> 16
```

Apache Arrow idiom — count valid and null elements:

```ruby
valid_count = bitmap.popcount
null_count  = bitmap.bytesize * 8 - bitmap.popcount
```

---

#### `each_bit(order: :msb) { |bool| ... } -> self`
#### `each_bit(order: :msb) -> Enumerator`

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
"\xAA".each_bit(order: :lsb).to_a
#=> [false, true, false, true, false, true, false, true]
#    pos 0   1     2      3     4      5     6      7

"\xAA".each_bit(order: :msb).to_a
#=> [true, false, true, false, true, false, true, false]
#    pos 7   6     5     4      3     2      1     0
```

---

#### `bits(order: :msb) -> Array`
#### `bits(order: :msb) { |bool| ... } -> self`

Without a block, returns an `Array` of `true`/`false` values — equivalent to `each_bit(order: order).to_a`. With a block, forwards each bit to the block and returns `self` — equivalent to `each_bit(order: order) { |b| ... }`.

Follows the same pattern as `String#bytes` vs `String#each_byte`.

```ruby
"\xAA".bits(order: :lsb)
#=> [false, true, false, true, false, true, false, true]

"\xAA".bits(order: :msb)
#=> [true, false, true, false, true, false, true, false]

"\xAA".bits(order: :lsb) { |b| print b ? "1" : "0" }
# prints: 01010101
# returns: "\xAA"
```

---

#### `each_set_bit(order: :msb) { |n| ... } -> self`
#### `each_set_bit(order: :msb) -> Enumerator`

Yields the flat position of each **set bit** (bit value == 1). Without a block, returns an `Enumerator`. With a block, returns `self`. The C implementation can use `__builtin_ctz` (count trailing zeros) to jump directly to the next set bit within each byte without scanning every bit.

```
data = "\xAA\xCC"  (byte[0]=0b10101010, byte[1]=0b11001100)

Flat positions of all set bits:

  byte[0]: b1 b3 b5 b7  =>  positions  1,  3,  5,  7
  byte[1]: b2 b3 b6 b7  =>  positions 10, 11, 14, 15

order: :lsb yields:  1,  3,  5,  7, 10, 11, 14, 15   (ascending)
order: :msb yields: 15, 14, 11, 10,  7,  5,  3,  1   (descending)
```

Positions from `each_set_bit(order: :lsb)` can be passed directly to `bit_at`:

```ruby
data.each_set_bit(order: :lsb) do |n|
  data.bit_at(n)  #=> always true
end
```

Apache Arrow idiom — iterate over valid element indices:

```ruby
validity_bitmap.each_set_bit(order: :lsb) do |i|
  process(column_data, i)
end
```

---

#### `set_bit_positions(order: :msb) -> Array`
#### `set_bit_positions(order: :msb) { |n| ... } -> self`

Without a block, returns an `Array` of set-bit positions — equivalent to `each_set_bit(order: order).to_a`. With a block, forwards each position to the block and returns `self` — equivalent to `each_set_bit(order: order) { |n| ... }`.

Follows the same pattern as `String#bytes` vs `String#each_byte`.

```ruby
"\xAA".set_bit_positions(order: :lsb)   #=> [1, 3, 5, 7]
"\xAA".set_bit_positions(order: :msb)   #=> [7, 5, 3, 1]

"\xAA\xCC".set_bit_positions(order: :lsb)
#=> [1, 3, 5, 7, 10, 11, 14, 15]
```

---

### Extract

---

#### `bit_slice(bit_offset, bit_length) -> String | nil`

The bit-granularity analog of `String#byteslice`. Extracts `bit_length` bits starting at flat bit position `bit_offset` and returns them packed into a new `String`. Bit `bit_offset` of the source becomes bit 0 of the result; bit `bit_offset + 1` becomes bit 1, and so on, preserving the LSB-first layout within each byte. When `bit_length` is not a multiple of 8, the remaining bits of the last byte in the result are zero-padded.

Out-of-range and clamping behaviour mirrors `String#byteslice`: returns `nil` if `bit_offset` is negative or strictly greater than the total number of bits; silently clamps `bit_length` if `bit_offset + bit_length` exceeds the total.

```ruby
data = "\xFF\xAA"   # byte[0]=0xFF, byte[1]=0b10101010

data.bit_slice(0, 8)   #=> "\xFF"      (bits 0-7: all of byte[0])
data.bit_slice(8, 8)   #=> "\xAA"      (bits 8-15: all of byte[1])
data.bit_slice(0, 16)  #=> "\xFF\xAA"  (all bits)
data.bit_slice(4, 8)   #=> "\xAF"      (bits 4-11, crosses byte boundary)
data.bit_slice(12, 8)  #=> "\x0A"      (bits 12-15 clamped to 4, zero-padded)
data.bit_slice(16, 1)  #=> nil         (out of range)
```

The result String uses the same flat numbering scheme as the source, so `bit_at` and all iteration methods work directly on it:

```ruby
result = data.bit_slice(4, 8)
result.bit_at(0)                    #=> same as data.bit_at(4)
result.each_set_bit(order: :lsb)    # yields set-bit positions within the extracted range
```

Apache Arrow idiom — normalize a non-byte-aligned validity bitmap for IPC serialization:

```ruby
# Arrow in-memory slice has bit offset 5; IPC requires offset 0
ipc_validity = validity_bitmap.bit_slice(slice_offset, slice_length)
```

---

### Single-bit mutation

These methods are always destructive (the name implies mutation, no `!` variant). Each returns `self` for chaining. Raises `IndexError` for out-of-range or negative `n`.

Read methods return `nil` for out-of-range positions; mutation methods raise. This asymmetry is intentional: a missed read is a logic question ("is this bit set?"), while a missed write is data corruption. Strict failure on mutation prevents silent bugs where a caller passes a wrong index and believes the write succeeded.

---

#### `set_bit(n) -> self`

Sets bit at position `n` to 1.

```ruby
bitmap = +"\x00\x00"
bitmap.set_bit(0)   #=> bit 0 of byte[0] becomes 1  =>  "\x01\x00"
bitmap.set_bit(9)   #=> bit 1 of byte[1] becomes 1  =>  "\x01\x02"
```

Apache Arrow idiom — build a validity bitmap incrementally:

```ruby
bitmap = +"\x00" * ((row_count + 7) / 8)
rows.each_with_index { |row, i| bitmap.set_bit(i) unless row[:value].nil? }
```

---

#### `clear_bit(n) -> self`

Sets bit at position `n` to 0.

```ruby
bitmap = +"\xFF\xFF"
bitmap.clear_bit(0)  #=> "\xFE\xFF"
bitmap.clear_bit(8)  #=> "\xFE\xFE"
```

---

#### `flip_bit(n) -> self`

Toggles bit at position `n`.

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

Apache Arrow idiom — null propagation (result valid only where both inputs are valid):

```ruby
result_validity = left_validity.bit_and(right_validity)
```

Apache Arrow idiom — apply a boolean filter to a column:

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

Apache Arrow idiom — union of two validity bitmaps:

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

## Benchmark

<details>

<summary>Benchmark</summary>

Environment:

```
$> uname -a
Linux hasumi-Ubuntu-Desktop 6.17.0-20-generic #20~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Thu Mar 19 01:28:37 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
```

</details>

---

## Prior Art: Bit Operations in Other Languages

<details>

<summary>Prior Art: Bit Operations in Other Languages</summary>

Bit-level operations are common across languages, but they are typically exposed either as low-level primitives on integers or through dedicated container types. This proposal integrates those capabilities directly into Ruby's `String`, preserving zero-copy semantics while raising the abstraction to match Ruby's Enumerable style.

### Python

Python provides limited bit-level functionality:

* `int.bit_count()` — population count (popcount)
* `int.to_bytes()` / `int.from_bytes()` — conversion between integers and byte sequences

There is no standard abstraction for iterating over bits in a byte sequence or treating a bytes object as a bit array.

**Implication:** Bit operations are tied to numeric values, not sequences. This proposal extends Ruby beyond Python by treating byte sequences (`String`) as first-class bit containers.

### Java

Java provides `BitSet`, a dedicated mutable bit container:

* `get(int index)` — read bit
* `set(int index)` / `clear(int index)` / `flip(int index)` — mutate
* `nextSetBit(int fromIndex)` — iterate set bits
* `cardinality()` — population count

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

* `test(pos)` — read bit
* `set(pos)` / `reset(pos)` / `flip(pos)` — mutate
* `count()` — popcount

These APIs are efficient but not integrated with standard iteration patterns, and naming tends toward technical terminology (`test`, `reset`).

**Implication:** C++ emphasizes performance and explicitness, but lacks a high-level, idiomatic iteration model. Ruby's `each_bit` and `each_set_bit` provide a more natural, Enumerable-based interface.

### Go

Go provides low-level bit operations via `math/bits`:

* `bits.OnesCount(x)` — popcount

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
