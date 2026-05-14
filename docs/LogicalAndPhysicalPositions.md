# Logical Position vs Physical Position

This note is for readers who are new to the bit API. It explains the difference between:

- physical positions
- logical positions
- `scan_order:`
- `count_from:`

## 1. Physical Positions

A `String` is a sequence of bytes in memory.

For example, `"\xFF\xAA"` is 2 bytes:

```text
byte[0] = 0xFF
byte[1] = 0xAA
```

Each byte contains 8 bits:

```text
  byte[0]                                      byte[1]
  +----+----+----+----+----+----+----+----+    +----+----+----+----+----+----+----+----+
  | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |    | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |
  +----+----+----+----+----+----+----+----+    +----+----+----+----+----+----+----+----+
phys 7    6    5    4    3    2    1    0   phys 15   14   13   12   11   10    9    8
     ^                                  ^         ^                                  ^
     b                                  a         d                                  c
```

In this document, those numbers are called **physical positions**.

- a: `phys 0` is the LSB of `byte[0]`
- b: `phys 7` is the MSB of `byte[0]`
- c: `phys 8` is the LSB of `byte[1]`
- d: `phys 15` is the MSB of `byte[1]`

In other words:

```text
physical position N = bit (N % 8) of byte[N / 8]
```

Physical position is about where the bit actually lives inside the string.

## 2. Logical positions

We do not always count bits in the same direction.

The Bit-APIs of `String` supports two numbering conventions.

### 2-1. `count_from: :lsb`

This counts from the beginning in the ordinary low-to-high direction.

```text
physical:  15 14 13 12 11 10  9  8   7  6  5  4  3  2  1  0
logical :  15 14 13 12 11 10  9  8   7  6  5  4  3  2  1  0
                                              ...
count_from: :lsb means logical == physical
```

This is the simple case:

- logical position 0 = physical position 0
- logical position 1 = physical position 1
- ...

### 2-2. `count_from: :msb`

This preserves byte order, but counts bits inside each byte from MSB to LSB.

```text
physical:   7  6  5  4  3  2  1  0    15 14 13 12 11 10  9  8
logical :   0  1  2  3  4  5  6  7     8  9 10 11 12 13 14 15
           byte[0]                   byte[1]
```

In this convention:

- logical position 0 = physical position 7
- logical position 1 = physical position 6
- ...
- logical position 7 = physical position 0
- logical position 8 = physical position 15
- ...
- logical position 15 = physical position 8

In formula form:

```text
physical = (logical & ~7) | (7 - (logical & 7))
```

Logical position is not the bit's storage location. It is the number the caller uses under a chosen numbering convention.

## 3. `bit_at` reads a logical position

The `n` in `bit_at(n, count_from: ...)` is a logical position, not a physical one.

### `count_from: :lsb`

```ruby
data = "\xFF\xAA"
data.bit_at(0, count_from: :lsb)
```

This reads:

```text
logical 0 -> physical 0
```

### `count_from: :msb`

```ruby
data = "\xFF\xAA"
data.bit_at(0, count_from: :msb)
```

This reads:

```text
logical 0 -> physical 7
```

So the same number `0` can mean a different bit depending on `count_from:`.

## 4. `scan_order:` means traversal direction

`count_from:` was about numbering.

`scan_order:` is about which side iteration starts from.

For example, `each_bit(scan_order: :lsb)` visits physical positions 0, 1, 2, ... in that order:

```text
scan_order: :lsb

phys 0 -> 1 -> 2 -> 3 -> ... -> 15
```

By contrast, `each_bit(scan_order: :msb)` goes the other way:

```text
scan_order: :msb

phys 15 -> 14 -> 13 -> 12 -> ... -> 0
```

The key point is:

- `scan_order:` means traversal order
- `count_from:` means numbering convention

Those are not the same thing.

## 5. What `each_set_bit_offset` should return

This is the place where you are most likely to get confused.

You can also ask, "Why do you have to use two different numbering conventions?"

The values returned by `each_set_bit_offset` should be usable as input to `bit_at`.

In other words:

```ruby
data.each_set_bit_offset(count_from: X).all? do |n|
  data.bit_at(n, count_from: X)
end
#=> true
```

Thinking of this as a round-trip makes the design easier to understand.

### Good design

Under `count_from: :msb`, the method should return logical positions in MSB numbering.

For example, if a set-bit is at physical position 7:

```text
count_from: :lsb => logical 7
count_from: :msb => logical 0
```

So the returned value should be `0` in `count_from: :msb` mode.

Then this works:

```ruby
n = data.each_set_bit_offset(count_from: :msb).first
data.bit_at(n, count_from: :msb)
#=> true
```

### Bad design

If `count_from: :msb` merely returned physical positions in descending order, round-trip behavior would break.

For example, if it returned `15`, then:

```ruby
data.bit_at(15, count_from: :msb)
```

would mean:

```text
logical 15 -> physical 8
```

That is a different bit.

Another way to say the same thing is this: if `each_set_bit_offset` had been designed to take `scan_order:` instead of `count_from:`, it would have encouraged a broken round-trip model:

```ruby
data.each_set_bit_offset(scan_order: :lsb).all? do |n|
  data.bit_at(n, count_from: :lsb)
end
#=> true
```

```ruby
data.each_set_bit_offset(scan_order: :msb).all? do |n|
  data.bit_at(n, count_from: :msb)
end
#=> false
```

In that hypothetical design, `scan_order: :msb` would naturally mean "walk physical positions from high to low", so the yielded numbers would be physical positions in descending order. But `bit_at(..., count_from: :msb)` interprets its argument using intra-byte MSB-first numbering. The same number would no longer refer to the same bit. For example, `bit_at(15, count_from: :msb)` reads physical position 8 (the LSB of `byte[1]`), not physical position 0.

So `scan_order:` would have been a poor fit for `each_set_bit_offset` and `set_bit_offsets`. The important property of those methods is not traversal direction. It is that the returned numbers must mean the same thing when passed back to position-based APIs such as `bit_at`.

## 6. Why `bit_slice` and `bit_splice` are different

`bit_slice` and `bit_splice` are less about logical numbering or traversal direction, and more about:

```text
cutting or writing a physical subsequence of bits
```

Because of that, it is clearer for those methods to use only:

- physical bit offsets counted from the start
- ordinary LSB-first packing

## 7. Why `ProposedMethods.md` is grouped the way it is

The categories in [ProposedMethods.md](ProposedMethods.md) are not arbitrary. They group methods by which coordinate model they use.

### Scan

These methods walk across the bit sequence and therefore care about traversal direction.

- `each_bit`
- `bits`
- `each_bit_run`
- `bit_runs`

That is why they use `scan_order:`.

### Position

These methods accept or return bit numbers that a caller can use directly.

- `bit_at`
- `set_bit`, `clear_bit`, `flip_bit`
- `each_set_bit_offset`, `set_bit_offsets`

That is why they use `count_from:`. The question is not "which side do we walk from?" but "which bit does this number mean?"

As a naming alternative, `each_setbit_offset` is also plausible. It is only one character shorter, but removing one underscore makes the name read as three chunks (`each` / `setbit` / `offset`) rather than four. The current draft keeps `each_set_bit_offset` because it is the most explicit spelling, but `each_setbit_offset` is a reasonable candidate if the present name is judged too long.

### Flat

These methods operate on physical bit offsets directly.

- `bit_slice`
- `bit_splice`
- `bit_run_count`

They do not need `scan_order:` or `count_from:` because they already work in one fixed flat numbering scheme.

### Aggregate

`bit_count` is separated because it reduces the whole bit sequence to one value.

It does not traverse for the caller, does not accept logical positions, and does not operate on a sub-range.

### Bitwise

The bitwise methods treat the string as a whole bitmap and combine or invert it in bulk.

- `bit_not`
- `bit_and`
- `bit_or`
- `bit_xor`

## 8. Summary

```text
physical position
  which bit actually exists inside the String

logical position
  which number a caller uses under some counting convention

scan_order:
  which side iteration starts from

count_from:
  which bit a logical number refers to
```

In one sentence:

```text
scan_order: which side to walk from
count_from: which bit a number points to
```
