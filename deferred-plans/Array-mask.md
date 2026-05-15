# Bitmask Operation into Array

## Methods for Array

| category             | methods       | keyword param | allocates result object |
|----------------------|---------------|---------------|-------------------------|
| Intra-Byte Numbering | `Array#mask!` | `lsb_first:`  | no                      |
| Intra-Byte Numbering | `Array#mask`  | `lsb_first:`  | yes (`Array`)           |

- `mask(bitmap, lsb_first: true, invert: false) -> Array`
- `mask!(bitmap, lsb_first: true, invert: false) -> self`

### Intra-Byte Numbering

`Array#mask` applies a bitmap to an array, returning a new array of the same length where each element is either kept or replaced with `nil` according to the corresponding bit. `Array#mask!` performs the same operation in place.

No block is involved; the operation applies the bitmap directly to the array.

#### `mask(bitmap, lsb_first: true, invert: false) -> Array`

Returns a new `Array`. Elements whose corresponding bit is 1 (for `invert: false`) or 0 (for `invert: true`) are kept; all others become `nil`.

```ruby
data   = [1, 2, 3, 4]

# LSB-first (default, Apache Arrow convention): 0b00001101 -> bits 0,2,3 set = elements 0,2,3 valid
bitmap = "\x0D".b   # 0b00001101
data.mask(bitmap)                        #=> [1, nil, 3, 4]

# MSB-first: 0b11010000 -> bits 7,6,4 set = elements 0,1,3 valid
bitmap = "\xD0".b   # 0b11010000
data.mask(bitmap, lsb_first: false)      #=> [1, 2, nil, 4]

# invert: true --- keep where bit is 0, nil where bit is 1
bitmap = "\x0D".b
data.mask(bitmap, invert: true)          #=> [nil, 2, nil, nil]
```

Apache Arrow idiom --- materialize an Arrow column with nulls applied:

```ruby
# One-time setup: build validity bitmap from source data.
bitmap = ("\x00" * ((n + 7) / 8)).b
source_data.each_with_index { |v, i| bitmap.set_bit(i) if v }

# Apply bitmap to a pre-fetched values array (no per-element rb_yield):
result = values.mask(bitmap)
```

#### `mask!(bitmap, lsb_first: true, invert: false) -> self`

Same as `mask` but modifies the array in place and returns `self`. Elements that would become `nil` are overwritten; valid elements are untouched.

```ruby
ary = [1, 2, 3, 4]
ary.mask!("\x0D".b)   #=> [1, nil, 3, 4]  (LSB-first default)
ary                      #=> [1, nil, 3, 4]  (modified in place)
```
