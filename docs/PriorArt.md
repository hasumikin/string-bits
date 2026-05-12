## Prior Art: Bit Operations in Other Languages

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

**Implication:** Java requires a separate container type (`BitSet`) and exposes relatively low-level iteration primitives. In contrast, Ruby integrates bit operations into `String` and provides direct iteration via `each_bit` and `each_set_bit_offset`, eliminating boilerplate.

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

**Implication:** C++ emphasizes performance and explicitness, but lacks a high-level, idiomatic iteration model. Ruby's `each_bit` and `each_set_bit_offset` provide a more natural, Enumerable-based interface.

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
* Full integration with Ruby's Enumerable style (`each_bit`, `each_set_bit_offset`)
* Natural method naming consistent with `String#bytes` / `each_byte`

In effect, this design lifts bit manipulation from low-level primitives into a high-level, idiomatic Ruby interface, while preserving the performance characteristics required for real-world workloads such as Apache Arrow and bitmap rendering.
