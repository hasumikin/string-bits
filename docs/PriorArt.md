## Prior Art: Bit Operations in Other Languages

Bit-level operations are common across languages, but they are typically exposed either as low-level primitives on integers or through dedicated container types. This proposal instead attaches bit-oriented operations to Ruby's existing byte container, `String`.

### Python

Python provides limited standard bit-level functionality:

* `int.bit_count()` --- population count (popcount)
* `int.to_bytes()` / `int.from_bytes()` --- conversion between integers and byte sequences

The standard library keeps bit operations on numeric values rather than on byte-sequence containers.

### Java

Java provides `BitSet`, a dedicated mutable bit container:

* `get(int index)` --- read bit
* `set(int index)` / `clear(int index)` / `flip(int index)` --- mutate
* `nextSetBit(int fromIndex)` --- iterate set bits
* `cardinality()` --- population count

Iteration over set bits is positional:

```java
for (int i = bs.nextSetBit(0); i >= 0; i = bs.nextSetBit(i + 1)) {
    // ...
}
```

Java uses a separate container type (`BitSet`) and iteration mainly through positional queries such as `nextSetBit`.

### Rust

Rust exposes bit operations at both the primitive and library level:

* Integer methods: `count_ones()` (popcount), `trailing_zeros()` (ctz)
* External crates such as `bitvec`: `get(index) -> Option<bool>`, `set(index, bool)`, `iter()`

Rust offers both primitive integer operations and external container abstractions such as `bitvec`.

### C++

C++ offers `std::bitset` and `std::vector<bool>`:

* `test(pos)` --- read bit
* `set(pos)` / `reset(pos)` / `flip(pos)` --- mutate
* `count()` --- popcount

C++ exposes bit containers and bit operations through dedicated types and technical method names.

### Go

Go provides low-level bit operations via `math/bits`:

* `bits.OnesCount(x)` --- popcount

Go keeps bit manipulation mostly at the primitive level.

### Erlang

Erlang treats binaries as bit-level sequences via its bit syntax, supporting pattern matching and construction at bit granularity:

```erlang
%% Match the first 3 bits as A and the remaining 5 as B
<<A:3, B:5>> = <<255>>.          %% A = 7, B = 31

%% Extract one bit, leaving the rest as a bitstring
<<X:1, Rest/bitstring>> = SomeBits.
```

Among major languages, Erlang's bit syntax is the closest prior art for this proposal. Bits are exposed directly on the same data type that holds byte buffers, with no intermediate container class. The mechanism differs (pattern matching vs. method calls), but the architectural choice --- bit-level access on the existing byte container --- is the same.

### Summary

Across languages, bit operations typically fall into three categories:

| approach | languages | characteristics |
|----------|-----------|-----------------|
| integer-centric | Python, Go | bit operations tied to numeric types |
| dedicated container | Java, C++, Rust (bitvec) | separate types, explicit APIs |
| in-buffer bit access | Erlang (bit syntax) | bit operations on the existing byte container |

This proposal is closest in spirit to Erlang: **integrate bit-level operations directly into `String`, the existing byte container**, but adapted to Ruby's method-call style.

Compared with the above:

* No new container type in the public API
* Operations on existing byte buffers held in `String`
* Iteration methods aligned with Ruby's `each_*` style
* Naming intended to parallel `String#bytes` / `each_byte`
