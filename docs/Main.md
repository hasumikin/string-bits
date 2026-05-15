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

- bit numbering / traversal keywords (`lsb_first:` and `reverse:`)
- whether those keywords should exist consistently across methods
- naming symmetry such as `bits` / `each_bit`
- behavior for out-of-range bit indices

## Proposed Methods

Full prototype and documentation:
https://github.com/hasumikin/string_bits/blob/master/docs/ProposedMethods.md

**Read-only access**

- `bit_at(n, lsb_first: true) -> true | false | nil` -- read a single bit
- `bit_count -> Integer` -- count of set-bits (popcount)

**Single-bit mutation**

- `set_bit(n, lsb_first: true) -> self` -- set bit at n to 1
- `clear_bit(n, lsb_first: true) -> self` -- set bit at n to 0
- `flip_bit(n, lsb_first: true) -> self` -- toggle bit at n

**Iteration**

- `each_bit(reverse: false) { |bool| ... } -> self` -- yield each bit as true/false  
  `each_bit(reverse: false) -> Enumerator`
- `bits(reverse: false) -> Array` -- Array form of `each_bit`  
  `bits(reverse: false) { |bool| ... } -> self`
- `each_set_bit_offset(lsb_first: true) { |n| ... } -> self` -- yield position of each set-bit    
  `each_set_bit_offset(lsb_first: true) -> Enumerator`
- `set_bit_offsets(lsb_first: true) -> Array` -- Array form of `each_set_bit_offset`  
  `set_bit_offsets(lsb_first: true) { |n| ... } -> self`

**Bit-range I/O**

- `bit_slice(bit_offset, bit_length) -> String | nil` -- extract a sub-sequence of bits (bit-granularity `byteslice`)  
  `bit_slice(range) -> String | nil`
- `bit_splice(bit_index, bit_length, str) -> self`  
  `bit_splice(bit_index, bit_length, str, str_bit_index, str_bit_length) -> self`  
  `bit_splice(range, str) -> self`  
  `bit_splice(range, str, str_range) -> self`  
  -- write a sub-sequence of bits in place (bit-granularity `bytesplice`)

**Run-length**

- `bit_run_count(pos, bit) -> Integer | nil` -- length of the run of `bit` starting at pos
- `each_bit_run(reverse: false) { |bit, len| } -> self` -- yield `(bit, run_length)` pairs  
  `each_bit_run(reverse: false) -> Enumerator`
- `bit_runs(reverse: false) -> Array` -- Array form of `each_bit_run`  
  `bit_runs(reverse: false) { |bit, len| } -> self`

**Bulk bitwise**

- `bit_not -> String` / `bit_not! -> self` -- invert every bit
- `bit_and(other) -> String` / `bit_and!(other) -> self` -- bitwise AND
- `bit_or(other) -> String` / `bit_or!(other) -> self` -- bitwise OR
- `bit_xor(other) -> String` / `bit_xor!(other) -> self` -- bitwise XOR

## Performance

This is not only about convenience.
In a prototype implementation, bulk operations such as `bit_and`, `bit_or`, and `bit_count` are also substantially faster than Ruby-level loops over bytes.
I do not think performance alone is the reason to add the feature, but it is a practical benefit.

## Notes

Detailed benchmarks, discussion, and prior art:

- Proposed methods: https://github.com/hasumikin/string_bits/blob/master/docs/ProposedMethods.md
- Benchmark: https://github.com/hasumikin/string_bits/blob/master/docs/Benchmark.md
- Discussion: https://github.com/hasumikin/string_bits/blob/master/docs/Discussion.md
- Bit numbering and traversal order: https://github.com/hasumikin/string_bits/blob/master/docs/BitNumberingAndTraversalOrder.md
- Prior art: https://github.com/hasumikin/string_bits/blob/master/docs/PriorArt.md
