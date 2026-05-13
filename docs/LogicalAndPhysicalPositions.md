# Logical Position vs Physical Position

This note is for readers who are new to the bit API. It explains the difference between:

- physical positions
- logical positions
- `scan_order:`
- `count_from:`

using simple ASCII diagrams.

## 1. Physical positions

A `String` is a sequence of bytes in memory.

For example, `"\xFF\xAA"` is 2 bytes:

```text
byte[0] = 0xFF
byte[1] = 0xAA
```

Each byte contains 8 bits:

```text
   byte[0]                                            byte[1]
   +-----+-----+-----+-----+-----+-----+-----+-----+  +-----+-----+-----+-----+-----+-----+-----+-----+
   | b7  | b6  | b5  | b4  | b3  | b2  | b1  | b0  |  | b7  | b6  | b5  | b4  | b3  | b2  | b1  | b0  |
   +-----+-----+-----+-----+-----+-----+-----+-----+  +-----+-----+-----+-----+-----+-----+-----+-----+
  phys 7    6     5     4     3     2     1     0    phys 15   14    13    12    11    10     9     8
```

In this document, those numbers are called **physical positions**.

- `phys 0` is the LSB of `byte[0]`
- `phys 7` is the MSB of `byte[0]`
- `phys 8` is the LSB of `byte[1]`
- `phys 15` is the MSB of `byte[1]`

In other words:

```text
physical position N
  = bit (N % 8) of byte[N / 8]
```

Physical position is about where the bit actually lives inside the string.

## 2. Logical positions

Humans do not always count bits in the same direction.

This API supports two numbering conventions.

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

This counts from the far end of the whole bit sequence.

```text
physical:  15 14 13 12 11 10  9  8   7  6  5  4  3  2  1  0
logical :   0  1  2  3  4  5  6  7   8  9 10 11 12 13 14 15
```

In this convention:

- logical position 0 = physical position 15
- logical position 1 = physical position 14
- ...
- logical position 15 = physical position 0

In formula form:

```text
physical = total_bits - 1 - logical
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
logical 0 -> physical 15
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

This is the place where beginners are most likely to get confused.

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

For example, if a set bit is at physical position 15:

```text
count_from: :lsb => logical 15
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
logical 15 -> physical 0
```

That is a different bit.

## 6. Why `bit_slice` and `bit_splice` are different

`bit_slice` and `bit_splice` are less about logical numbering or traversal direction, and more about:

```text
cutting or writing a physical subsequence of bits
```

Because of that, it is clearer for those methods to use only:

- physical bit offsets counted from the start
- ordinary LSB-first packing

## 7. Summary

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

## 8. Why the names are different

It may seem tempting to make all keyword names follow the same pattern, but `count_from:` and `scan_order:` describe different kinds of things.

`count_from:` is about the meaning of a number supplied by the caller. It answers:

```text
When the caller says "bit 0", which side are we counting from?
```

That is why `count_from:` fits methods such as `bit_at`, `set_bit`, and `each_set_bit_offset`.

By contrast, `scan_order:` is about iteration order.

So the naming is intentionally mixed:

- `count_from:` for logical numbering
- `scan_order:` for traversal order
