## Discussion: Use Cases and Design Considerations

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

### Error behavior for out-of-range bit indices

Two distinct categories of "out of range" are handled differently.

**Index outside the string's bit length** --- read methods return `nil`; mutation methods raise `IndexError`. The asymmetry is intentional: a missed read is a logic question ("is this bit set?"), while a missed write risks silent data corruption. This mirrors Ruby's own `String#[]` (returns `nil` for out-of-bounds reads) and `String#setbyte` (raises `IndexError` for out-of-bounds writes).

**Index outside the implementation's supported integer range** --- all methods raise `ArgumentError`. The goal is deterministic behavior for clearly invalid input, rather than leaking platform-dependent conversion details into the public API.

```ruby
s = "\xFF"
s.bit_at(100)       #=> nil
s.bit_at(2**100)    #=> ArgumentError
s.set_bit(100)      #=> IndexError
s.set_bit(2**100)   #=> ArgumentError
```

### The `order:` parameter (LSB or MSB)

The `order:` keyword controls **interpretation and traversal direction**. It defines which bit is considered "first" (index 0).

| `order:` | interpretation | position sequence / indexing |
|----------|-----------|-------------------|
| `:lsb` (default) | low -> high | 0, 1, 2, ... , total-1 |
| `:msb`   | high -> low | total-1, ..., 2, 1, 0 |

For iterative methods (`each_bit`, `each_set_bit_offset`, `each_bit_run`), it controls yield order. For index-based methods (`bit_at`, `set_bit`, `clear_bit`, `flip_bit`) and for `Array#mask`, it defines the mapping of logical index `n` to physical bit position. `bit_slice`, `bit_splice`, and `bit_run_count` operate exclusively in flat LSB-first numbering and do not accept `order:` --- their range/scan semantics have no well-defined dual under reverse indexing.

Important: `order: :msb` does **not** mean "keep byte order and only flip the bit numbering inside each byte". It means reverse indexing over the entire bit sequence: logical position 0 is the last physical bit of the string, logical position 1 is the second-last physical bit, and so on.

The default is `:lsb` for consistency with `Array#mask` and the Apache Arrow convention (element `i` = byte `i/8` bit `i%8`). It keeps `bit_at(i)`, `values.mask(bitmap)`, and `bitmap.each_set_bit_offset { |i| values[i] }` aligned without extra conversion. `order: :msb` is useful when reverse traversal of the whole bit sequence is desired, but it is not a "network bit order" mode.

The symbol values `:lsb` and `:msb` leave room for future extensions (e.g. `:native`, `:network`) without breaking changes. As a consequence, `each_bit(order: :msb).to_a` is always the reverse of `each_bit.to_a`, and the same holds for `each_set_bit_offset`.

### Naming convention: symmetry with `bytes` / `each_byte`

The method names follow the same pattern as Ruby's built-in `String#bytes` and `String#each_byte`.

`bytes` and `each_byte` are not independent operations: `bytes` returns `each_byte.to_a` without a block, and forwards the block to `each_byte` with a block. The bit methods follow the same convention:

```ruby
# each_bit: Enumerator or self
s.each_bit               #=> Enumerator
s.each_bit { |b| ... }  #=> self (s)

# bits: Array or self
s.bits                   #=> Array of true/false (same as each_bit.to_a)
s.bits { |b| ... }       #=> self (s), same as each_bit { |b| ... }

# each_set_bit_offset: Enumerator or self
s.each_set_bit_offset               #=> Enumerator
s.each_set_bit_offset { |n| ... }  #=> self (s)

# set_bit_offsets: Array or self
s.set_bit_offsets                   #=> Array of set-bit positions (same as each_set_bit_offset.to_a)
s.set_bit_offsets { |n| ... }       #=> self (s), same as each_set_bit_offset { |n| ... }
```

The word "set" is ambiguous in English (verb: mutate; adjective: already-set bits). `each_set_bit_offset` makes the iterative meaning explicit, while `set_bit_offsets` names the returned positions.

| analogy | byte methods | bit methods |
|---------|-------------|-------------|
| iterate with block or Enumerator | `each_byte` | `each_bit` |
| Array or block shorthand | `bytes` | `bits` |
| iterate set-bit *positions* | --- | `each_set_bit_offset` |
| Array or block shorthand for set-bit positions | --- | `set_bit_offsets` |

### Why extend `String` rather than introduce a new class?

The obvious alternative is a dedicated `BitSet` class (analogous to Java's `java.util.BitSet` or C++'s `std::bitset`). Two arguments favour extending `String` instead.

**Adding a new top-level constant is a high bar for Ruby core.** Introducing `BitSet` would permanently reserve a widely plausible name and force conversion at boundaries where Ruby code already uses `String`.

**`String` is already Ruby's binary buffer type.** Socket reads, file reads, `pack`/`unpack`, and similar APIs already hand raw bytes to Ruby as `String`. Since `String` already exposes byte-level operations such as `bytesize`, `getbyte`, `setbyte`, `byteslice`, and `bytesplice`, bit-level methods are a depth extension of an existing role rather than a new category.

### Bit ordering across domains

| domain | native bit ordering | compatibility with current design |
|--------|---------------------|------------------------------------|
| Apache Arrow validity bitmap | LSB-first (element i = byte[i/8] bit i%8) | native |
| ARM / STM32 register fields | register convention: bit 0 = LSB | analogous |
| ext4 block bitmap | LSB-first | native |
| RFC-style network headers (IPv4, TCP, DNS) | bit 0 = MSB of first byte (RFC diagram convention) | not native; explicit offset conversion needed |
| BitTorrent bitfield message | piece 0 = MSB of byte 0 | not native; explicit offset conversion needed |
| PNG 1/2/4-bit scanlines | MSB = leftmost pixel | not native; explicit offset conversion needed |

The table is limited to cases where bit numbering is directly relevant to a byte buffer held in memory. LSB-first layouts align directly with this API. MSB-first layouts inside each byte are still addressable, but require explicit offset conversion because `order: :msb` reverses the whole bit sequence rather than preserving byte order.

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

`bit_at(i)` maps directly to Arrow element index `i`. `each_set_bit_offset(order: :lsb)` yields valid element indices in ascending order. `Array#mask(bitmap, order: :lsb)` materializes an Arrow column as a Ruby array with `nil` in place of null values.

#### Arrow IPC serialization

Arrow supports zero-copy slicing in memory: slicing an array produces a lightweight object that references the original buffer with a non-zero `offset`. For a validity bitmap, this offset is measured in **bits** --- the bitmap for a sliced column may start at an arbitrary bit position within a byte.

The IPC format, however, requires every buffer to be byte-aligned: element 0 of the serialized column must map to bit 0 of the first byte. Serializing a sliced array therefore requires re-packing the validity bitmap to eliminate the in-memory bit offset. `IO::Buffer#slice` operates at byte granularity and cannot perform this re-packing. `bit_slice` fills this gap:

```ruby
# column slice: validity bitmap starts at in-memory bit offset 5, covering 100 elements
# IPC requires the bitmap to start at bit 0
ipc_validity = validity_bitmap.bit_slice(5, 100)
```

#### Why no byte-offset parameter?

Apache Arrow IPC messages pack multiple column buffers into a single contiguous allocation:

```
[metadata][pad][validity bitmap A][pad][data buffer A]
               [validity bitmap B][pad][data buffer B] ...
```

One might expect each method to accept a `byte_offset:` keyword so that a bitmap living inside a larger String can be accessed without first extracting it. The methods deliberately omit this parameter for the following reasons:

| operation | alternative |
|-----------|-------------|
| `bit_at(n)` on a sub-range | encode the offset in `n`: `bit_at(byte_offset * 8 + n)` |
| `bit_count`, `each_bit`, `each_set_bit_offset` | extract once with `byteslice(offset, length)`, then call the method |
| `bit_and!`, `bit_or!`, `bit_xor!` on a sub-range | use `IO::Buffer` (see below) |

For single-bit access the byte offset is already expressible through `n`. For bulk read-only operations, a caller can extract the relevant byte range once with `byteslice(offset, length)` and then operate on that smaller string.

**In-place bulk operations on a sub-range are the one case that cannot be handled by adjusting `n` or calling `byteslice`**, because `byteslice` returns a copy and writing back is not possible. This is intentional: that use case belongs to `IO::Buffer`.

#### IO::Buffer as the zero-copy complement

`IO::Buffer` is the zero-copy complement for this scenario. `IO::Buffer#slice` returns a view into the original buffer that shares the underlying memory:

```ruby
buf    = IO::Buffer.map(File.open("data.arrow"))
bitmap = buf.slice(validity_offset, bitmap_bytes)  # no copy
```

The proposed `String` methods cover the common case where a column buffer has already been materialized as a `String` (for example via socket reads, MessagePack, or `byteslice`). `IO::Buffer` is not a replacement for this proposal; the two serve different layers:

* `IO::Buffer`: memory ownership, zero-copy slicing, I/O operations
* `String` (proposed): bit-level iteration and manipulation of materialized byte data

</details>
