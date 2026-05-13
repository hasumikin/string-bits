# Logical Position vs Physical Position

この文書は、bit API を初めて読む人向けに、

- 物理位置
- 論理位置
- `scan_order:`
- `index_order:`

の違いを、アスキーアートで説明するためのメモです。

## 1. まず「物理位置」

`String` はメモリ上では byte の並びです。

たとえば `"\xFF\xAA"` は 2 byte です。

```text
byte[0] = 0xFF
byte[1] = 0xAA
```

各 byte の中には 8 個の bit があります。

```text
   byte[0]                                            byte[1]
   +-----+-----+-----+-----+-----+-----+-----+-----+  +-----+-----+-----+-----+-----+-----+-----+-----+
   | b7  | b6  | b5  | b4  | b3  | b2  | b1  | b0  |  | b7  | b6  | b5  | b4  | b3  | b2  | b1  | b0  |
   +-----+-----+-----+-----+-----+-----+-----+-----+  +-----+-----+-----+-----+-----+-----+-----+-----+
  phys 7    6     5     4     3     2     1     0    phys 15   14    13    12    11    10     9     8
```

ここでの番号を、この文書では **物理位置** と呼びます。

- `phys 0` は `byte[0]` の LSB
- `phys 7` は `byte[0]` の MSB
- `phys 8` は `byte[1]` の LSB
- `phys 15` は `byte[1]` の MSB

つまり、

```text
physical position N
  = byte[N / 8] の bit (N % 8)
```

です。

## 2. 次に「論理位置」

人間が bit を数えるときは、いつも同じ向きとは限りません。

2 つの考え方があります。

### 2-1. `index_order: :lsb`

先頭から、低い物理位置へ向かって数える考え方です。

```text
physical:  15 14 13 12 11 10  9  8   7  6  5  4  3  2  1  0
logical :  15 14 13 12 11 10  9  8   7  6  5  4  3  2  1  0
                                              ...
index_order: :lsb では logical == physical
```

この場合は単純です。

- 論理位置 0 = 物理位置 0
- 論理位置 1 = 物理位置 1
- ...

### 2-2. `index_order: :msb`

末尾側から逆向きに数える考え方です。

```text
physical:  15 14 13 12 11 10  9  8   7  6  5  4  3  2  1  0
logical :   0  1  2  3  4  5  6  7   8  9 10 11 12 13 14 15
```

この場合は、

- 論理位置 0 = 物理位置 15
- 論理位置 1 = 物理位置 14
- ...
- 論理位置 15 = 物理位置 0

です。

式で書くと:

```text
physical = total_bits - 1 - logical
```

です。

## 3. `bit_at` は「論理位置」を読む

`bit_at(n, index_order: ...)` の `n` は、物理位置ではなく論理位置です。

### `index_order: :lsb`

```ruby
data = "\xFF\xAA"
data.bit_at(0, index_order: :lsb)
```

これは

```text
logical 0 -> physical 0
```

を読みます。

### `index_order: :msb`

```ruby
data = "\xFF\xAA"
data.bit_at(0, index_order: :msb)
```

これは

```text
logical 0 -> physical 15
```

を読みます。

つまり、同じ `0` でも意味が違います。

## 4. `scan_order:` は「どちらから走査するか」

`index_order:` は「数え方」でした。

`scan_order:` は「どちらから先に見るか」です。

たとえば `each_bit(scan_order: :lsb)` は物理位置 0, 1, 2, ... の順で進みます。

```text
scan_order: :lsb

phys 0 -> 1 -> 2 -> 3 -> ... -> 15
```

一方 `each_bit(scan_order: :msb)` は逆です。

```text
scan_order: :msb

phys 15 -> 14 -> 13 -> 12 -> ... -> 0
```

ここで大事なのは:

- `scan_order:` は「走査の順番」
- `index_order:` は「数え方」

であって、同じではないということです。

## 5. `each_set_bit_offset` が返すべきもの

初心者が一番混乱しやすいのはここです。

`each_set_bit_offset` が返す値は、`bit_at` にそのまま渡せるべきです。

つまり:

```ruby
data.each_set_bit_offset(index_order: X).all? do |n|
  data.bit_at(n, index_order: X)
end
#=> true
```

でなければいけません。

この性質を **round-trip できる** と考えると分かりやすいです。

### よい設計

`index_order: :msb` のとき、

```text
返す値も msb 側の論理位置
```

にします。

たとえば `physical 15` に立っている bit は、

```text
index_order: :lsb では logical 15
index_order: :msb では logical 0
```

と返すべきです。

そうすれば:

```ruby
n = data.each_set_bit_offset(index_order: :msb).first
data.bit_at(n, index_order: :msb)
#=> true
```

になります。

### よくない設計

`index_order: :msb` なのに、

```text
物理位置を逆順に返すだけ
```

だと壊れます。

たとえば `15` を返してしまうと、

```ruby
data.bit_at(15, index_order: :msb)
```

は

```text
logical 15 -> physical 0
```

を読むので、別の bit を見に行ってしまいます。

## 6. `bit_slice` と `bit_splice` が別扱いになる理由

`bit_slice` と `bit_splice` は、論理位置や走査順よりも、

```text
「物理的な bit 列の一部をそのまま切る / 書く」
```

という性格が強い API です。

そのため、これらは素直に

- 先頭から数えた物理位置
- LSB-first の packed layout

だけを受け付けるほうが分かりやすいです。

## 7. まとめ

```text
physical position
  実際に String の中のどの bit か

logical position
  人間がどの向きで数えたときの番号か

scan_order:
  どちらから先に走査するか

index_order:
  logical position をどう physical position に変換するか
```

初心者向けに一言で言うと:

```text
scan_order: どちらから見るか
index_order: その番号がどの bit を指すか
```

です。
