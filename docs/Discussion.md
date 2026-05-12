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

**String range exceeded (Fixnum beyond the string's bit length)** --- read methods return `nil`; mutation methods raise `IndexError`. The asymmetry is intentional: a missed read is a logic question ("is this bit set?"), while a missed write risks silent data corruption. This mirrors Ruby's own `String#[]` (returns `nil` for out-of-bounds reads) and `String#setbyte` (raises `IndexError` for out-of-bounds writes).

**System-unrepresentable index (Bignum)** --- all methods raise `ArgumentError`. A `Bignum` cannot be converted to a C `long` in a portable way: on LLP64 platforms (Windows), `sizeof(long) == 4`, so any `Bignum > INT32_MAX` would overflow, while on LP64 (Linux/macOS) the limit is `INT64_MAX`. Rather than letting this platform dependency surface as an inconsistent `RangeError`, the implementation detects Bignums explicitly and raises `ArgumentError` uniformly. In practice, no real string can hold enough bytes to make a Bignum a valid index, so the restriction carries no practical cost.

```ruby
s = "\xFF"
s.bit_at(100)       #=> nil         (Fixnum, out of string range)
s.bit_at(2**100)    #=> ArgumentError (Bignum, system-unrepresentable)
s.set_bit(100)      #=> IndexError   (Fixnum, out of string range)
s.set_bit(2**100)   #=> ArgumentError (Bignum, system-unrepresentable)
```

### The `order:` parameter (LSB or MSB)

The `order:` keyword controls **interpretation and traversal direction**. It defines which bit is considered "first" (index 0).

| `order:` | interpretation | position sequence / indexing |
|----------|-----------|-------------------|
| `:lsb` (default) | low -> high | 0, 1, 2, ... , total-1 |
| `:msb`   | high -> low | total-1, ..., 2, 1, 0 |

For iterative methods (`each_bit`, `each_set_bit_offset`), it controls the yield order. For index-based methods (`bit_at`, `bit_slice`, `bit_splice`, `set_bit`, etc.), it defines the mapping of logical index `n` to physical bit position.

The default is `:lsb` for consistency with `Array#mask` and the Apache Arrow convention (element `i` = byte `i/8` bit `i%8`). This ensures `values.mask(bitmap)` and `bitmap.each_set_bit_offset { |i| values[i] }` work correctly without extra arguments. Additionally, `:lsb` yields positions in ascending order, making `set_bit_offsets` results immediately usable as array subscripts.

The trade-off is that visual binary display (where the MSB is leftmost) requires `order: :msb` explicitly. The `:lsb` default is consistent with hardware-level bit numbering (bit 0 = LSB on x86/ARM), ensures `bit_at(i)` aligns with array index `i`, and yields positions in ascending order --- making `setbit_positions` results directly usable as array subscripts. Apache Arrow validity bitmaps follow the same convention (element `i` = byte `i/8` bit `i%8`).

The symbol values `:lsb` and `:msb` leave room for future extensions (e.g. `:native`, `:network`) without breaking changes. As a consequence, `each_bit(order: :msb).to_a` is always the reverse of `each_bit.to_a`, and the same holds for `each_set_bit_offset`.

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

# each_set_bit_offset: Enumerator or self
s.each_set_bit_offset               #=> Enumerator
s.each_set_bit_offset { |n| ... }  #=> self (s)

# set_bit_offsets: Array or self
s.set_bit_offsets                   #=> Array of set-bit positions (same as each_set_bit_offset.to_a)
s.set_bit_offsets { |n| ... }       #=> self (s), same as each_set_bit_offset { |n| ... }
```

The word "set" is ambiguous in English (verb: mutate; adjective: already-set bits). `each_set_bit_offset` resolves this --- the `each_` prefix always signals iteration, never mutation. `set_bit_offsets` names the return type explicitly, distinguishing it from `bits`.

| analogy | byte methods | bit methods |
|---------|-------------|-------------|
| iterate with block or Enumerator | `each_byte` | `each_bit` |
| Array or block shorthand | `bytes` | `bits` |
| iterate set-bit *positions* | --- | `each_set_bit_offset` |
| Array or block shorthand for set-bit positions | --- | `set_bit_offsets` |

The mutation methods `set_bit(n)`, `clear_bit(n)`, and `flip_bit(n)` use unambiguous verb phrases and are not affected by this convention.

### Why extend `String` rather than introduce a new class?

The obvious alternative is a dedicated `BitSet` class (analogous to Java's `java.util.BitSet` or C++'s `std::bitset`). Two arguments favour extending `String` instead.

**Adding a new top-level constant is a high bar for Ruby core.** Ruby's top-level namespace is long-established and shared by every program. Introducing `BitSet` there is a permanent, backwards-incompatible name reservation: any existing codebase that already defines a `BitSet` constant would break silently. The Ruby core team historically applies careful scrutiny to proposals that claim a new top-level name --- a shared reservation that affects every program --- and consistently asks whether the same functionality could fit an existing class instead. Routing the methods through `String` avoids this hurdle entirely.

**`String` is already Ruby's binary buffer type.** Unlike Java (`String` is immutable text), C++ (`std::string` is a text container with a narrow character model), or Python (`bytes` is immutable), Ruby's `String` carries an encoding tag and can be switched to `Encoding::BINARY` (`str.b`), making it the standard container for raw byte sequences. Socket reads, file reads, `pack`/`unpack` output, `IO::Buffer` materializations, and MessagePack payloads all land in `String`. The class already exposes a byte-level API --- `bytesize`, `getbyte`, `setbyte`, `byteslice`, `bytesplice` --- so adding bit-level methods is not a category change but a depth extension of the binary-buffer role `String` already plays. A standalone `BitSet` would require conversion at every boundary between the new type and the `String` that real code already holds, introducing copies and API friction where none need exist.

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

`bit_at(i)` maps directly to Arrow element index `i`. `each_set_bit_offset(order: :lsb)` yields valid element indices in ascending order. `Array#bitwise(bitmap, order: :lsb)` materializes an Arrow column as a Ruby array with `nil` in place of null values --- entirely in C with no per-element callback overhead.

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
