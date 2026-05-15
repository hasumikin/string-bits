# Bit Numbering and Traversal Order

This note explains how the String bit API addresses individual bits and traverses them.
It covers the two keywords used for ordering choices: `lsb_first:` (intra-byte numbering) and `reverse:` (traversal order).

## 1. Physical layout of bits

A `String` is a sequence of bytes; each byte holds 8 bits. For example, `"\xFF\xAA"` is laid out as:

```text
  byte[0] = 0xFF (0b11111111)                   byte[1] = 0xAA (0b10101010)
  +----+----+----+----+----+----+----+----+     +----+----+----+----+----+----+----+----+
  |  1 |  1 |  1 |  1 |  1 |  1 |  1 |  1 |     |  1 |  0 |  1 |  0 |  1 |  0 |  1 |  0 |
  | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |     | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |
  +----+----+----+----+----+----+----+----+     +----+----+----+----+----+----+----+----+
```

This layout is fixed by memory; nothing the API does can change which bit lives where.
The keywords below decide only how the API exchanges *positions* with the caller and which end traversal starts from.

## 2. Intra-byte numbering --- `lsb_first:`

Methods that take an integer position (`bit_at`, `set_bit`, etc.) need a rule that maps each integer `n` to a specific bit in the layout above.
The `lsb_first:` keyword chooses between two such rules.

### `lsb_first: true` (default)

Within each byte, `n = 0` is the LSB. Numbering proceeds upward through byte[0] and then continues at the LSB of byte[1]:

```text
n :   7  6  5  4  3  2  1  0     15 14 13 12 11 10 9  8
bit:  b7 b6 b5 b4 b3 b2 b1 b0    b7 b6 b5 b4 b3 b2 b1 b0
      byte[0]              ^     byte[1]              ^
                           LSB                        LSB
```

Formula: `n = byte_index * 8 + bit_in_byte`.

This convention is used by Apache Arrow validity bitmaps, ext4 block bitmaps, and most hardware register documentation.
It is the default because it matches plain byte arithmetic.

### `lsb_first: false`

Byte order is preserved (`byte[0]` is still first), but within each byte numbering starts at the MSB:

```text
n :   0  1  2  3  4  5  6  7     8  9 10 11 12 13 14 15
bit:  b7 b6 b5 b4 b3 b2 b1 b0    b7 b6 b5 b4 b3 b2 b1 b0
      ^                          ^
      MSB                        MSB
```

Formula: `n = byte_index * 8 + (7 - bit_in_byte)`.

This convention is used by RFC network header diagrams (IPv4, TCP, DNS), PNG 1/2/4-bit scanlines, and the BitTorrent bitfield message.
In all of those, "bit 0" is the leftmost (most significant) bit of the first byte.

### Same `n`, different bit

The two conventions disagree on what each integer refers to:

```ruby
data = "\xFF\xAA"   # byte[0] = 0xFF (0b11111111), byte[1] = 0xAA (0b10101010)

data.bit_at(0)                    #=> true   (byte[0] bit 0 is set)
data.bit_at(0, lsb_first: false)  #=> true   (byte[0] bit 7 is set)
data.bit_at(8, lsb_first: false)  #=> true   (byte[1] bit 7 is set)
data.bit_at(15, lsb_first: false) #=> false  (byte[1] bit 0 is null)
```

## 3. Traversal Order --- `reverse:`

Methods like `each_bit` and `each_bit_run` walk through every bit. The caller does not supply a position; the method itself walks the sequence.
`reverse:` chooses which end the walk starts from. Within each byte the walk direction follows the byte-stepping direction, so the two are always symmetric.

### `reverse: false` (default)

Starts at byte[0] bit 0 (LSB). Within each byte the walk goes LSB to MSB; across bytes byte[0] comes first.

The yield order under each cell (1 = yielded first, 16 = yielded last):

```text
     byte[0]                                     byte[1]
     +----+----+----+----+----+----+----+----+   +----+----+----+----+----+----+----+----+
     | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |   | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |
     +----+----+----+----+----+----+----+----+   +----+----+----+----+----+----+----+----+
order:  8    7    6    5    4    3    2    1       16   15   14   13   12   11   10    9
```

Equivalently, by byte:

```text
byte[0]:   b0 -> b1 -> b2 -> b3 -> b4 -> b5 -> b6 -> b7
byte[1]:   b0 -> b1 -> b2 -> b3 -> b4 -> b5 -> b6 -> b7
...
byte[n-1]: b0 -> b1 -> b2 -> b3 -> b4 -> b5 -> b6 -> b7
```

### `reverse: true`

Starts at byte[n-1] bit 7 (MSB). Within each byte the walk goes MSB to LSB; across bytes byte[n-1] comes first.

```text
     byte[0]                                     byte[1]
     +----+----+----+----+----+----+----+----+   +----+----+----+----+----+----+----+----+
     | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |   | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |
     +----+----+----+----+----+----+----+----+   +----+----+----+----+----+----+----+----+
order:  9   10   11   12   13   14   15   16        1    2    3    4    5    6    7    8
```

Equivalently, by byte:

```text
byte[n-1]: b7 -> b6 -> b5 -> b4 -> b3 -> b2 -> b1 -> b0
byte[n-2]: b7 -> b6 -> b5 -> b4 -> b3 -> b2 -> b1 -> b0
...
byte[0]:   b7 -> b6 -> b5 -> b4 -> b3 -> b2 -> b1 -> b0
```

The yielded values are unchanged (`true` / `false` or `(bit, run_length)` pairs); only the order is reversed.
`each_bit(reverse: true).to_a` always equals `each_bit.to_a.reverse`.

## 4. The two keywords address different concepts

`lsb_first:` and `reverse:` are independent. They answer different questions:

- `lsb_first:` answers **"which bit does this integer mean?"** --- the keyword applies wherever the API exchanges an integer position with the caller.
- `reverse:` answers **"which end of the buffer does traversal start from?"** --- the keyword applies wherever the API walks the sequence internally.

Because the two are orthogonal, each method takes whichever fits its role:

| methods                                                  | `lsb_first:` | `reverse:` |
|----------------------------------------------------------|--------------|------------|
| `bit_at`, `set_bit`, `clear_bit`, `flip_bit`             | yes          | no         |
| `each_set_bit_offset`, `set_bit_offsets`                 | yes          | no         |
| `each_bit`, `bits`                                       | no           | yes        |
| `each_bit_run`, `bit_runs`                               | no           | yes        |
| `bit_slice`, `bit_splice`, `bit_run_count`               | no           | no         |
| `bit_count`, `bit_not(!)`, `bit_and(!)`, `bit_or(!)`, `bit_xor(!)` | no | no         |

## 5. Why `each_set_bit_offset` uses `lsb_first:`, not `reverse:`

`each_set_bit_offset` walks the bits and yields **integer positions** for the set bits.
Because it yields integers, the keyword question is "what convention do those integers follow?", not "which end does the walk start from?".

The yielded integers must be reusable as input to `bit_at` under the same convention:

```ruby
data.each_set_bit_offset(lsb_first: X).all? do |n|
  data.bit_at(n, lsb_first: X)
end
#=> true, for any X
```

This round-trip is what makes the offset-yielding methods useful as building blocks: a consumer that holds an offset can pass it to any of `bit_at`, `set_bit`, `clear_bit`, `flip_bit` without tracking which convention applies. The mutation methods may also accept a `Range`, but it is still interpreted as a range of logical positions under the same `lsb_first:` convention.
`reverse:` would not give this guarantee because reversing the walk order changes the order in which integers are yielded but not the integers themselves.

## 6. Why `bit_slice`, `bit_splice`, and `bit_run_count` take neither keyword

These methods work in a single fixed scheme: flat positions counted from the start of the string, LSB-first packed.

`bit_slice` extracts a sub-sequence of bits; the result is itself a `String` with the same packing rule, so the rest of the API operates on the result without further configuration.
An MSB-first variant would need its own packing convention and the result could no longer be passed back into the API uniformly.

`bit_splice` is the inverse of `bit_slice` and uses the same convention for symmetry.

`bit_run_count` scans forward from a single physical position and returns a length; numbering and direction are both irrelevant to a single-bit-value scan.

## 7. Summary

```text
lsb_first:  which bit does an integer position refer to?
reverse:    which end of the buffer does traversal start from?
```

These are independent decisions.
Methods that exchange integer positions with the caller take `lsb_first:`; methods that walk the sequence in a chosen direction take `reverse:`; methods that work in a single fixed scheme take neither.
