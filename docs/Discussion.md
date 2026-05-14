## Discussion: Use Cases and Design Considerations

### Bit position numbering

All methods share one flat physical numbering scheme: position `N` lives in `byte[N / 8]` at bit `N % 8` (LSB-first within each byte).

The distinction between physical positions, logical positions, `scan_order:`, and `count_from:` is described in [LogicalAndPhysicalPositions.md](./LogicalAndPhysicalPositions.md). This section focuses only on the design consequences.

### Error behavior for out-of-range bit indices

Two distinct categories of "out of range" are handled differently.

**Index outside the string's bit length** --- read methods return `nil`; mutation methods raise `IndexError`. The asymmetry is intentional: a missed read is a logic question ("is this bit set?"), while a missed write risks silent data corruption. This mirrors Ruby's own `String#[]` (returns `nil` for out-of-bounds reads) and `String#setbyte` (raises `IndexError` for out-of-bounds writes).

**Index outside the implementation's supported integer range** --- all methods raise `ArgumentError`. The goal is deterministic behavior for clearly invalid input, rather than leaking platform-dependent conversion details into the public API. Bit indices are held internally in a pointer-width signed integer (`ssize_t`), so the supported range is the same across LP64 and LLP64 (64-bit Windows) systems.

```ruby
s = "\xFF"
s.bit_at(100)            #=> nil
s.bit_at(2**100)         #=> ArgumentError
s.bit_run_count(100, 0)  #=> nil
s.set_bit(100)           #=> IndexError
s.set_bit(2**100)        #=> ArgumentError
```

### Naming convention: symmetry with `bytes` / `each_byte`

The method pairs `each_bit` / `bits` and `each_set_bit_offset` / `set_bit_offsets` follow the same basic Ruby idiom as `each_byte` / `bytes`: iterator form plus collected form.

The word "set" is ambiguous in English (verb: mutate; adjective: already-set bits). `each_set_bit_offset` makes the iterative meaning explicit, while `set_bit_offsets` names the returned positions.

### Why extend `String` rather than introduce a new class?

The obvious alternative is a dedicated `BitSet` class (analogous to Java's `java.util.BitSet` or C++'s `std::bitset`). Two arguments favour extending `String` instead.

**Adding a new top-level constant is a high bar for Ruby core.** Introducing `BitSet` would permanently reserve a widely plausible name and force conversion at boundaries where Ruby code already uses `String`.

**`String` is already Ruby's binary buffer type.** Socket reads, file reads, `pack`/`unpack`, and similar APIs already hand raw bytes to Ruby as `String`. Since `String` already exposes byte-level operations such as `bytesize`, `getbyte`, `setbyte`, `byteslice`, and `bytesplice`, bit-level methods are a depth extension of an existing role rather than a new category.

This proposal is intentionally limited to bit-level operations on an already materialized `String`; concerns such as zero-copy slicing or mapped I/O belong to abstractions like `IO::Buffer`, not to this proposal.

### Bit ordering across domains

| domain | native bit ordering | native via |
|--------|---------------------|------------|
| Apache Arrow validity bitmap | LSB-first (element i = byte[i/8] bit i%8) | `count_from: :lsb` |
| ext4 block bitmap | LSB-first | `count_from: :lsb` |
| RFC-style network headers (IPv4, TCP, DNS) | bit 0 = MSB of first byte (RFC diagram convention) | `count_from: :msb` |
| PNG 1/2/4-bit scanlines | MSB = leftmost pixel | `count_from: :msb` |

The table is limited to cases where bit numbering is directly relevant to a byte buffer held in memory. Both LSB-first and intra-byte MSB-first layouts are directly addressable through `count_from: :lsb` and `count_from: :msb`.

### Apache Arrow Compatibility

Apache Arrow validity bitmaps use the same flat LSB-first layout: element `i` is stored in `byte[i / 8]` at bit `i % 8`.

`bit_at(i)` maps directly to Arrow element index `i`. `each_set_bit_offset(count_from: :lsb)` yields valid element indices in ascending order.

#### Arrow IPC serialization

Arrow supports zero-copy slicing in memory, so a sliced validity bitmap may start at a non-zero bit offset. The IPC format, however, requires the serialized bitmap to start at bit 0 of the first byte. `bit_slice` fills that gap:

```ruby
# column slice: validity bitmap starts at in-memory bit offset 5, covering 100 elements
# IPC requires the bitmap to start at bit 0
ipc_validity = validity_bitmap.bit_slice(5, 100)
```
