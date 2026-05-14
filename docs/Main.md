ref: Integer#popcount https://bugs.ruby-lang.org/issues/20163

----

# Introduce Bit Operations into String

## Abstract

Ruby's `String` is already a byte sequence, but it lacks high-level bit operations.
As a result, packed binary data must be handled with manual byte arithmetic.

For example, checking one bit at offset `10` currently looks like this:

```ruby
data = "\xAA\xAA\xAA\xAA"
byte_offset = 10 / 8
byte = data.getbyte(byte_offset)
bit_offset = 10 % 8
((byte >> bit_offset) & 1) == 1
```

With a dedicated method:

```ruby
"\xAA\xAA\xAA\xAA".bit_at(10)
```

This proposal presents a family of methods for bit-oriented use of `String`, organized into groups below.
The immediate goal is agreement on the overall direction and feedback on which subset should be pursued first.

Presenting the full menu matters because some design questions only become clear at that level:

- bit numbering / traversal keywords (`count_from:` and `scan_order:`)
- whether those keywords should exist consistently across methods
- naming symmetry such as `bits` / `each_bit`
- behavior for out-of-range bit indices

## Proposed Methods

Full prototype and documentation:
https://github.com/hasumikin/string_bits/blob/master/docs/ProposedMethods.md

**Read-only access**

- `bit_at(n, count_from: :lsb) -> true | false | nil`
- `bit_count -> Integer`

**Single-bit mutation**

- `set_bit(n, count_from: :lsb) -> self`
- `clear_bit(n, count_from: :lsb) -> self`
- `flip_bit(n, count_from: :lsb) -> self`

**Iteration**

- `each_bit(scan_order: :lsb) { |bool| ... } -> self`
     `each_bit(scan_order: :lsb) -> Enumerator`
- `bits(scan_order: :lsb) -> Array`
     `bits(scan_order: :lsb) { |bool| ... } -> self`
- `each_set_bit_offset(count_from: :lsb) { |n| ... } -> self`
     `each_set_bit_offset(count_from: :lsb) -> Enumerator`
- `set_bit_offsets(count_from: :lsb) -> Array`
     `set_bit_offsets(count_from: :lsb) { |n| ... } -> self`

**Bit-range I/O**

- `bit_slice(bit_offset, bit_length) -> String | nil`
     `bit_slice(range) -> String | nil`
- `bit_splice(bit_index, bit_length, str) -> self`
     `bit_splice(bit_index, bit_length, str, str_bit_index, str_bit_length) -> self`
     `bit_splice(range, str) -> self`
     `bit_splice(range, str, str_range) -> self`

**Run-length**

- `bit_run_count(pos, bit) -> Integer | nil`
- `each_bit_run(scan_order: :lsb) { |bit, len| } -> self`
     `each_bit_run(scan_order: :lsb) -> Enumerator`
- `bit_runs(scan_order: :lsb) -> Array`
     `bit_runs(scan_order: :lsb) { |bit, len| } -> self`

**Bulk bitwise**

- `bit_not -> String`
- `bit_not! -> self`
- `bit_and(other) -> String`
- `bit_and!(other) -> self`
- `bit_or(other) -> String`
- `bit_or!(other) -> self`
- `bit_xor(other) -> String`
- `bit_xor!(other) -> self`

## Performance

This is not only about convenience.
In a prototype implementation, bulk operations such as `bit_and`, `bit_or`, and `bit_count` are also substantially faster than Ruby-level loops over bytes.
I do not think performance alone is the reason to add the feature, but it is a practical benefit.

## Notes

Detailed benchmarks, discussion, and prior art:

- Proposed methods: https://github.com/hasumikin/string_bits/blob/master/docs/ProposedMethods.md
- Benchmark: https://github.com/hasumikin/string_bits/blob/master/docs/Benchmark.md
- Discussion: https://github.com/hasumikin/string_bits/blob/master/docs/Discussion.md
- Logical vs physical positions: https://github.com/hasumikin/string_bits/blob/master/docs/LogicalAndPhysicalPositions.md
- Prior art: https://github.com/hasumikin/string_bits/blob/master/docs/PriorArt.md
