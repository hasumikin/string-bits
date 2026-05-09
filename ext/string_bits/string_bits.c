#include "ruby.h"
#include "ruby/encoding.h"

/* popcount ----------------------------------------------------------------- */
/*
 * Porting to Ruby Core:
 *   1. Remove sb_popcount64 and the #include block below.
 *      Use rb_popcount64 from internal/bits.h instead.
 *   2. Add #include "internal/bits.h" at the top of string.c (or wherever
 *      String#popcount is implemented).
 *   3. Replace all sb_popcount64 calls with rb_popcount64.
 *   4. Move rb_str_popcount into string.c and register it in Init_String().
 */

#if defined(HAVE_X86INTRIN_H)
#  include <x86intrin.h>
#elif defined(_MSC_VER)
#  include <intrin.h>
#endif

static inline unsigned int
sb_popcount64(uint64_t x)
{
#if defined(_MSC_VER) && defined(__AVX__)
    return (unsigned int)__popcnt64(x);
#elif __has_builtin(__builtin_popcount)
    if (sizeof(long) * CHAR_BIT == 64) {
        return (unsigned int)__builtin_popcountl((unsigned long)x);
    }
    else {
        return (unsigned int)__builtin_popcountll((unsigned long long)x);
    }
#else
    x = (x & 0x5555555555555555) + (x >> 1 & 0x5555555555555555);
    x = (x & 0x3333333333333333) + (x >> 2 & 0x3333333333333333);
    x = (x & 0x0707070707070707) + (x >> 4 & 0x0707070707070707);
    x = (x & 0x000f000f000f000f) + (x >> 8 & 0x000f000f000f000f);
    x = (x & 0x0000001f0000001f) + (x >>16 & 0x0000001f0000001f);
    x = (x & 0x000000000000003f) + (x >>32 & 0x000000000000003f);
    return (unsigned int)x;
#endif
}

/* ctz / clz helpers for set-bit iteration ---------------------------------- */

static inline int
sb_ctz8(unsigned int x)
{
    /* position of lowest set bit; x must be non-zero */
#if __has_builtin(__builtin_ctz)
    return __builtin_ctz(x);
#elif defined(_MSC_VER)
    unsigned long index;
    _BitScanForward(&index, x);
    return (int)index;
#else
    int n = 0;
    if (!(x & 0x0F)) { n += 4; x >>= 4; }
    if (!(x & 0x03)) { n += 2; x >>= 2; }
    if (!(x & 0x01))   n += 1;
    return n;
#endif
}

static inline int
sb_highest_bit8(unsigned int x)
{
    /* position of highest set bit; x must be non-zero */
#if __has_builtin(__builtin_clz)
    return 31 - __builtin_clz(x);
#elif defined(_MSC_VER)
    unsigned long index;
    _BitScanReverse(&index, x);
    return (int)index;
#else
    int n = 0;
    if (x >= 16) { n += 4; x >>= 4; }
    if (x >= 4)  { n += 2; x >>= 2; }
    if (x >= 2)    n += 1;
    return n;
#endif
}

static inline int
sb_ctzll(uint64_t x)
{
    /* position of lowest set bit in a non-zero 64-bit word */
#if __has_builtin(__builtin_ctzll)
    return __builtin_ctzll(x);
#elif defined(_MSC_VER)
    unsigned long index;
    _BitScanForward64(&index, x);
    return (int)index;
#else
    int n = 0;
    if (!(x & 0x00000000FFFFFFFFull)) { n += 32; x >>= 32; }
    if (!(x & 0x0000FFFFull))         { n += 16; x >>= 16; }
    if (!(x & 0x00FFull))             { n +=  8; x >>=  8; }
    if (!(x & 0x0Full))               { n +=  4; x >>=  4; }
    if (!(x & 0x03ull))               { n +=  2; x >>=  2; }
    if (!(x & 0x01ull))                 n +=  1;
    return n;
#endif
}

/* common functions --------------------------------------------------------- */

/*
 * rb_str_get_bit: read one bit from a raw byte sequence.
 *
 * Porting to Ruby Core:
 *   1. Move this declaration to include/ruby/internal/string.h (or
 *      internal/string.h for a non-public internal API).
 *   2. Remove the `static inline` storage class; declare as:
 *        static inline int rb_str_get_bit(const char *ptr, long bit_index, int msb_first);
 *      in the header so both string.c and array.c can include it.
 *   3. Replace all call sites in string.c and array.c accordingly.
 *
 * Parameters:
 *   ptr        - pointer to the first byte of the bitmap
 *   bit_index  - flat zero-based position; byte = bit_index/8 from ptr
 *   msb_first  - non-zero: bit 0 of each byte is the MSB (leftmost);
 *                zero:     bit 0 of each byte is the LSB (Arrow/hardware convention)
 *
 * Returns 0 or 1.
 */
static inline int
rb_str_get_bit(const char *ptr, long bit_index, int msb_first)
{
    long byte_index = bit_index / 8;
    int bit_offset = msb_first ? (7 - bit_index % 8) : (bit_index % 8);
    return (ptr[byte_index] >> bit_offset) & 1;
}

static inline int
test_bit(const char *ptr, long bit_index)
{
    return rb_str_get_bit(ptr, bit_index, 0);
}

/* Convert a Ruby Integer to a long bit index without calling NUM2LONG on Bignums.
 *
 * NUM2LONG raises a platform-dependent RangeError: on Windows (LLP64) sizeof(long)==4
 * so any Bignum > INT32_MAX raises, while on Linux/macOS (LP64) sizeof(long)==8 so
 * Bignums up to INT64_MAX succeed. This inconsistency breaks cross-platform tests.
 *
 * Instead, map Bignums to sentinel longs that let the caller's existing range/sign
 * checks handle them uniformly on every platform:
 *   Fixnum          -> FIX2LONG(n)   (normal fast path)
 *   negative Bignum -> -1L           (non-negative guard will fire)
 *   positive Bignum -> LONG_MAX      (always out of range for any real string)
 *
 * RBIGNUM_NEGATIVE_P is available via ruby.h -> ruby/internal/core/rbignum.h. */
static long
integer_to_bit_idx(VALUE n)
{
    if (FIXNUM_P(n)) return FIX2LONG(n);
    RUBY_ASSERT(RB_TYPE_P(n, T_BIGNUM));
    if (RBIGNUM_NEGATIVE_P(n)) return -1L;
    return LONG_MAX;
}

static long
check_bit_index(VALUE self, VALUE n)
{
    if (!rb_integer_type_p(n)) {
        rb_raise(rb_eTypeError, "bit index must be an integer");
    }
    long idx = integer_to_bit_idx(n);
    long size = RSTRING_LEN(self) * 8;
    if (idx < 0 || idx >= size) {
        rb_raise(rb_eIndexError, "bit index out of range");
    }
    return idx;
}

static int
parse_order(int argc, VALUE *argv)
{
    VALUE opts = Qnil;
    rb_scan_args(argc, argv, "0:", &opts);
    if (NIL_P(opts)) return 0;
    VALUE order = rb_hash_aref(opts, ID2SYM(rb_intern("order")));
    if (NIL_P(order) || order == ID2SYM(rb_intern("lsb"))) return 0;
    if (order == ID2SYM(rb_intern("msb"))) return 1;
    rb_raise(rb_eArgError, "order must be :lsb or :msb");
    return 0;
}

/* read -------------------------------------------------------------------- */

/* String#bit_at(n) -> true or false
 *
 * bit_at uses flat/Arrow convention: byte_index = n/8 from start, bit = n%8 from LSB
 * e.g. "\xAA\xCC": bit 0..7 live in byte[0]=0xAA, bit 8..15 live in byte[1]=0xCC
 *
 *   str = "\xFF\xAA" # 11111111 10101010
 *   str.bit_at(0) # => true (1st bit is set)
 *   str.bit_at(7) # => true (8th bit is set)
 *   str.bit_at(8) # => false (9th bit is clear)
 *   str.bit_at(9) # => true (10th bit is set)
 *   str.bit_at(16) # => nil
 */
static VALUE
rb_str_bit_at(VALUE self, VALUE n)
{
    if (!rb_integer_type_p(n)) {
        rb_raise(rb_eTypeError, "bit index must be an integer");
    }
    long idx = integer_to_bit_idx(n);
    if (idx < 0) {
        rb_raise(rb_eArgError, "bit index must be non-negative");
    }
    long size = RSTRING_LEN(self) * 8;
    if (size <= idx) {
        return Qnil;
    }
    if (test_bit(RSTRING_PTR(self), idx)) {
        return Qtrue;
    } else {
        return Qfalse;
    }
}

static VALUE
rb_str_popcount(VALUE self)
{
    long count = 0;
    long len = RSTRING_LEN(self);
    const char *str = RSTRING_PTR(self);
    const uint64_t *aligned_end = (const uint64_t *)(str + (len & ~7));

    for (const uint64_t *ptr = (const uint64_t *)str; ptr < aligned_end; ptr++) {
        count += sb_popcount64(*ptr);
    }

    long remainder = len & 7;
    if (remainder > 0) {
        uint64_t last = 0;
        const unsigned char *tail = (const unsigned char *)aligned_end;
        for (long i = 0; i < remainder; i++) {
            last |= (uint64_t)tail[i] << (i * 8);
        }
        count += sb_popcount64(last);
    }

    return LONG2FIX(count);
}

/* iterate bits ------------------------------------------------------------ */

static VALUE
rb_str_each_bit(int argc, VALUE *argv, VALUE self)
{
    RETURN_ENUMERATOR(self, argc, argv);

    int msb_first = parse_order(argc, argv);
    long len = RSTRING_LEN(self);
    const char *str = RSTRING_PTR(self);
    long total_bits = len * 8;

    if (msb_first) {
        for (long i = total_bits - 1; i >= 0; i--) {
            rb_yield(rb_str_get_bit(str, i, 0) ? Qtrue : Qfalse);
        }
    }
    else {
        for (long i = 0; i < total_bits; i++) {
            rb_yield(rb_str_get_bit(str, i, 0) ? Qtrue : Qfalse);
        }
    }

    return self;
}

static VALUE
rb_str_bits(int argc, VALUE *argv, VALUE self)
{
    int msb_first = parse_order(argc, argv);
    long len = RSTRING_LEN(self);
    const char *str = RSTRING_PTR(self);
    long total_bits = len * 8;
    int have_block = rb_block_given_p();

    VALUE ary = have_block ? Qnil : rb_ary_new_capa(total_bits);

    if (msb_first) {
        for (long i = total_bits - 1; i >= 0; i--) {
            VALUE bit = rb_str_get_bit(str, i, 0) ? Qtrue : Qfalse;
            have_block ? rb_yield(bit) : rb_ary_push(ary, bit);
        }
    }
    else {
        for (long i = 0; i < total_bits; i++) {
            VALUE bit = rb_str_get_bit(str, i, 0) ? Qtrue : Qfalse;
            have_block ? rb_yield(bit) : rb_ary_push(ary, bit);
        }
    }

    return have_block ? self : ary;
}

/* iterate set-bit positions ----------------------------------------------- */

static VALUE
rb_str_each_set_bit(int argc, VALUE *argv, VALUE self)
{
    RETURN_ENUMERATOR(self, argc, argv);

    int msb_first = parse_order(argc, argv);
    long len = RSTRING_LEN(self);
    const unsigned char *str = (const unsigned char *)RSTRING_PTR(self);

    if (!msb_first) {
        /* LSB-first: ascending positions 0, 1, 2, ...
         * On little-endian, loading 8 bytes as uint64_t preserves the flat
         * LSB-first bit numbering: word bit 0 == position 0, bit 63 == 63. */
#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        long n_words = len >> 3;
        const uint64_t *words = (const uint64_t *)str;
        for (long wi = 0; wi < n_words; wi++) {
            uint64_t w = words[wi];
            while (w != 0) {
                int bit = sb_ctzll(w);
                rb_yield(LONG2FIX(wi * 64 + bit));
                w &= w - 1;
            }
        }
        for (long bi = n_words << 3; bi < len; bi++) {
            unsigned int b = str[bi];
            while (b != 0) {
                int bit = sb_ctz8(b);
                rb_yield(LONG2FIX(bi * 8 + bit));
                b &= b - 1;
            }
        }
#else
        for (long bi = 0; bi < len; bi++) {
            unsigned int b = str[bi];
            while (b != 0) {
                int bit = sb_ctz8(b);
                rb_yield(LONG2FIX(bi * 8 + bit));
                b &= b - 1;
            }
        }
#endif
    }
    else {
        /* MSB-first: descending positions (total-1), ..., 1, 0 */
        for (long bi = len - 1; bi >= 0; bi--) {
            unsigned int b = str[bi];
            while (b != 0) {
                int bit = sb_highest_bit8(b);
                rb_yield(LONG2FIX(bi * 8 + bit));
                b ^= (1u << bit);  /* clear highest set bit */
            }
        }
    }

    return self;
}

static VALUE
rb_str_set_bit_positions(int argc, VALUE *argv, VALUE self)
{
    int msb_first = parse_order(argc, argv);
    long len = RSTRING_LEN(self);
    const unsigned char *str = (const unsigned char *)RSTRING_PTR(self);
    int have_block = rb_block_given_p();

    VALUE ary;
    if (have_block) {
        ary = Qnil;
    }
    else {
        /* Pre-size the Array with popcount to avoid repeated reallocation. */
        long count = 0;
        long nw = len >> 3;
        const uint64_t *wp = (const uint64_t *)str;
        for (long wi = 0; wi < nw; wi++)
            count += sb_popcount64(wp[wi]);
        for (long bi = nw << 3; bi < len; bi++)
            count += sb_popcount64((uint64_t)str[bi]);
        ary = rb_ary_new_capa(count);
    }

    if (!msb_first) {
#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        long n_words = len >> 3;
        const uint64_t *words = (const uint64_t *)str;
        for (long wi = 0; wi < n_words; wi++) {
            uint64_t w = words[wi];
            while (w != 0) {
                int bit = sb_ctzll(w);
                VALUE pos = LONG2FIX(wi * 64 + bit);
                have_block ? rb_yield(pos) : rb_ary_push(ary, pos);
                w &= w - 1;
            }
        }
        for (long bi = n_words << 3; bi < len; bi++) {
            unsigned int b = str[bi];
            while (b != 0) {
                int bit = sb_ctz8(b);
                VALUE pos = LONG2FIX(bi * 8 + bit);
                have_block ? rb_yield(pos) : rb_ary_push(ary, pos);
                b &= b - 1;
            }
        }
#else
        for (long bi = 0; bi < len; bi++) {
            unsigned int b = str[bi];
            while (b != 0) {
                int bit = sb_ctz8(b);
                VALUE pos = LONG2FIX(bi * 8 + bit);
                have_block ? rb_yield(pos) : rb_ary_push(ary, pos);
                b &= b - 1;
            }
        }
#endif
    }
    else {
        for (long bi = len - 1; bi >= 0; bi--) {
            unsigned int b = str[bi];
            while (b != 0) {
                int bit = sb_highest_bit8(b);
                VALUE pos = LONG2FIX(bi * 8 + bit);
                have_block ? rb_yield(pos) : rb_ary_push(ary, pos);
                b ^= (1u << bit);
            }
        }
    }

    return have_block ? self : ary;
}

/* extract ----------------------------------------------------------------- */

/* String#bit_slice(bit_offset, bit_length) -> String
 *
 *   str = "\xFF\x00" # 11111111 00000000
 *   str.bit_slice(4, 8) # => "\xF0" (11110000)
 */
static VALUE
rb_str_bit_slice(VALUE self, VALUE bit_offset, VALUE bit_length)
{
    if (!rb_integer_type_p(bit_offset) || !rb_integer_type_p(bit_length)) {
        return Qnil;
    }
    /* Bignum values exceed any practical string length, treat as out-of-range */
    if (!RB_FIXNUM_P(bit_offset) || !RB_FIXNUM_P(bit_length)) {
        return Qnil;
    }

    long offset = FIX2LONG(bit_offset);
    long length = FIX2LONG(bit_length);

    if (offset < 0 || length < 0) return Qnil;

    long src_len = RSTRING_LEN(self);
    long total_bits = src_len * 8;
    if (offset > total_bits) return Qnil;

    long available = total_bits - offset;
    if (length > available) length = available;
    if (length == 0) return rb_str_new("", 0);

    long out_bytes = (length + 7) / 8;
    VALUE result = rb_str_buf_new(out_bytes);
    rb_str_resize(result, out_bytes);
    rb_enc_associate(result, rb_enc_get(self));
    unsigned char *dst = (unsigned char *)RSTRING_PTR(result);

    const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
    long byte_off = offset >> 3;
    int shift = (int)(offset & 7);

    if (shift == 0) {
        memcpy(dst, src + byte_off, out_bytes);
    }
    else {
        int anti_shift = 8 - shift;
        for (long i = 0; i < out_bytes; i++) {
            unsigned char lo = src[byte_off + i];
            unsigned char hi = (byte_off + i + 1 < src_len) ? src[byte_off + i + 1] : 0;
            dst[i] = (unsigned char)((lo >> shift) | (hi << anti_shift));
        }
    }

    int tail_bits = (int)(length & 7);
    if (tail_bits) {
        dst[out_bytes - 1] &= (unsigned char)((1u << tail_bits) - 1);
    }

    return result;
}

/* single-bit mutation ----------------------------------------------------- */

static VALUE
rb_str_set_bit(VALUE self, VALUE n)
{
    long idx = check_bit_index(self, n);
    rb_str_modify(self);
    RSTRING_PTR(self)[idx / 8] |= (unsigned char)(1 << (idx % 8));
    return self;
}

static VALUE
rb_str_clear_bit(VALUE self, VALUE n)
{
    long idx = check_bit_index(self, n);
    rb_str_modify(self);
    RSTRING_PTR(self)[idx / 8] &= (unsigned char)~(1 << (idx % 8));
    return self;
}

static VALUE
rb_str_flip_bit(VALUE self, VALUE n)
{
    long idx = check_bit_index(self, n);
    rb_str_modify(self);
    RSTRING_PTR(self)[idx / 8] ^= (unsigned char)(1 << (idx % 8));
    return self;
}

/* bulk bitwise ------------------------------------------------------------ */

static void
check_binary_op_lengths(VALUE self, VALUE other)
{
    if (RSTRING_LEN(self) != RSTRING_LEN(other)) {
        rb_raise(rb_eArgError, "operands must have the same length (%ld vs %ld)",
                 RSTRING_LEN(self), RSTRING_LEN(other));
    }
}

static VALUE
alloc_result(VALUE self)
{
    long len = RSTRING_LEN(self);
    VALUE result = rb_str_buf_new(len);
    rb_str_resize(result, len);
    rb_enc_associate(result, rb_enc_get(self));
    return result;
}

static VALUE
rb_str_bit_not(VALUE self)
{
    long len = RSTRING_LEN(self);
    VALUE result = alloc_result(self);
    const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
    unsigned char *dst = (unsigned char *)RSTRING_PTR(result);
    for (long i = 0; i < len; i++) dst[i] = ~src[i];
    return result;
}

static VALUE
rb_str_bit_not_bang(VALUE self)
{
    rb_str_modify(self);
    long len = RSTRING_LEN(self);
    unsigned char *ptr = (unsigned char *)RSTRING_PTR(self);
    for (long i = 0; i < len; i++) ptr[i] = ~ptr[i];
    return self;
}

static VALUE
rb_str_bit_and(VALUE self, VALUE other)
{
    check_binary_op_lengths(self, other);
    long len = RSTRING_LEN(self);
    VALUE result = alloc_result(self);
    const unsigned char *a = (const unsigned char *)RSTRING_PTR(self);
    const unsigned char *b = (const unsigned char *)RSTRING_PTR(other);
    unsigned char *dst = (unsigned char *)RSTRING_PTR(result);
    for (long i = 0; i < len; i++) dst[i] = a[i] & b[i];
    return result;
}

static VALUE
rb_str_bit_and_bang(VALUE self, VALUE other)
{
    check_binary_op_lengths(self, other);
    rb_str_modify(self);
    long len = RSTRING_LEN(self);
    unsigned char *a = (unsigned char *)RSTRING_PTR(self);
    const unsigned char *b = (const unsigned char *)RSTRING_PTR(other);
    for (long i = 0; i < len; i++) a[i] &= b[i];
    return self;
}

static VALUE
rb_str_bit_or(VALUE self, VALUE other)
{
    check_binary_op_lengths(self, other);
    long len = RSTRING_LEN(self);
    VALUE result = alloc_result(self);
    const unsigned char *a = (const unsigned char *)RSTRING_PTR(self);
    const unsigned char *b = (const unsigned char *)RSTRING_PTR(other);
    unsigned char *dst = (unsigned char *)RSTRING_PTR(result);
    for (long i = 0; i < len; i++) dst[i] = a[i] | b[i];
    return result;
}

static VALUE
rb_str_bit_or_bang(VALUE self, VALUE other)
{
    check_binary_op_lengths(self, other);
    rb_str_modify(self);
    long len = RSTRING_LEN(self);
    unsigned char *a = (unsigned char *)RSTRING_PTR(self);
    const unsigned char *b = (const unsigned char *)RSTRING_PTR(other);
    for (long i = 0; i < len; i++) a[i] |= b[i];
    return self;
}

static VALUE
rb_str_bit_xor(VALUE self, VALUE other)
{
    check_binary_op_lengths(self, other);
    long len = RSTRING_LEN(self);
    VALUE result = alloc_result(self);
    const unsigned char *a = (const unsigned char *)RSTRING_PTR(self);
    const unsigned char *b = (const unsigned char *)RSTRING_PTR(other);
    unsigned char *dst = (unsigned char *)RSTRING_PTR(result);
    for (long i = 0; i < len; i++) dst[i] = a[i] ^ b[i];
    return result;
}

static VALUE
rb_str_bit_xor_bang(VALUE self, VALUE other)
{
    check_binary_op_lengths(self, other);
    rb_str_modify(self);
    long len = RSTRING_LEN(self);
    unsigned char *a = (unsigned char *)RSTRING_PTR(self);
    const unsigned char *b = (const unsigned char *)RSTRING_PTR(other);
    for (long i = 0; i < len; i++) a[i] ^= b[i];
    return self;
}

/* packed bit-field iteration ---------------------------------------------- */

/*
 * ebs_extract: copy bitlen bits starting at bit_offset from src into a new String.
 * Layout is identical to bit_slice: LSB-first within each byte, zero-padded tail.
 *
 * Porting to Ruby Core:
 *   1. Move this helper into string.c alongside the bit_slice implementation.
 *   2. Share it with rb_str_bit_slice to avoid duplication.
 *   3. Remove the `static` qualifier so it can be called from array.c if needed.
 */
static VALUE
ebs_extract(const unsigned char *src, long src_len, long bit_offset,
            long bitlen, long out_bytes, rb_encoding *enc)
{
    VALUE result = rb_str_buf_new(out_bytes);
    rb_str_resize(result, out_bytes);
    rb_enc_associate(result, enc);
    unsigned char *dst = (unsigned char *)RSTRING_PTR(result);

    long byte_off = bit_offset >> 3;
    int shift = (int)(bit_offset & 7);

    if (shift == 0) {
        memcpy(dst, src + byte_off, out_bytes);
    }
    else {
        int anti_shift = 8 - shift;
        for (long i = 0; i < out_bytes; i++) {
            unsigned char lo = src[byte_off + i];
            unsigned char hi = (byte_off + i + 1 < src_len) ? src[byte_off + i + 1] : 0;
            dst[i] = (unsigned char)((lo >> shift) | (hi << anti_shift));
        }
    }

    int tail_bits = (int)(bitlen & 7);
    if (tail_bits) {
        dst[out_bytes - 1] &= (unsigned char)((1u << tail_bits) - 1);
    }

    return result;
}

/* String#each_bit_slice(bitlen, planes: 1, order: :lsb) { |*planes| } -> self
 * String#each_bit_slice(bitlen, planes: 1, order: :lsb) -> Enumerator
 *
 * Iterates over the string in consecutive bitlen-bit chunks, grouping `planes`
 * chunks per block call. Each chunk is passed to the block as a packed String
 * with the same LSB-first bit layout as bit_slice.
 *
 * order: :lsb (default) iterates from the first chunk forward.
 * order: :msb iterates from the last complete group backward.
 *
 * Incomplete trailing bits (when bytesize*8 is not divisible by bitlen*planes)
 * are silently dropped, matching the behavior of each_slice on Arrays.
 *
 * Porting to Ruby Core:
 *   1. Move ebs_extract and this function into string.c.
 *   2. Register with rb_define_method in Init_String().
 *   3. Replace ALLOCA_N with a stack array for small `planes` and heap otherwise.
 */
static VALUE
rb_str_each_bit_slice(int argc, VALUE *argv, VALUE self)
{
    RETURN_ENUMERATOR(self, argc, argv);

    VALUE vbitlen, opts;
    rb_scan_args(argc, argv, "1:", &vbitlen, &opts);

    if (!rb_integer_type_p(vbitlen)) {
        rb_raise(rb_eTypeError, "bitlen must be an integer");
    }
    long bitlen = NUM2LONG(vbitlen);
    if (bitlen <= 0) {
        rb_raise(rb_eArgError, "bitlen must be positive");
    }

    long planes = 1;
    int msb_first = 0;

    if (!NIL_P(opts)) {
        VALUE v_planes = rb_hash_aref(opts, ID2SYM(rb_intern("planes")));
        if (!NIL_P(v_planes)) {
            if (!rb_integer_type_p(v_planes)) {
                rb_raise(rb_eTypeError, "planes must be an integer");
            }
            planes = NUM2LONG(v_planes);
            if (planes <= 0) {
                rb_raise(rb_eArgError, "planes must be positive");
            }
        }
        VALUE order = rb_hash_aref(opts, ID2SYM(rb_intern("order")));
        if (!NIL_P(order)) {
            if (order == ID2SYM(rb_intern("lsb")))      msb_first = 0;
            else if (order == ID2SYM(rb_intern("msb"))) msb_first = 1;
            else rb_raise(rb_eArgError, "order must be :lsb or :msb");
        }
    }

    long src_len = RSTRING_LEN(self);
    long total_bits = src_len * 8;
    long step = bitlen * planes;
    long out_bytes = (bitlen + 7) / 8;
    long iterations = total_bits / step;

    rb_encoding *enc = rb_enc_get(self);
    VALUE *plane_vals = ALLOCA_N(VALUE, planes);

    if (!msb_first) {
        for (long iter = 0; iter < iterations; iter++) {
            long base_bit = iter * step;
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            for (long p = 0; p < planes; p++) {
                plane_vals[p] = ebs_extract(src, src_len,
                                            base_bit + p * bitlen,
                                            bitlen, out_bytes, enc);
            }
            rb_yield_values2((int)planes, plane_vals);
        }
    }
    else {
        for (long iter = iterations - 1; iter >= 0; iter--) {
            long base_bit = iter * step;
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            for (long p = 0; p < planes; p++) {
                plane_vals[p] = ebs_extract(src, src_len,
                                            base_bit + p * bitlen,
                                            bitlen, out_bytes, enc);
            }
            rb_yield_values2((int)planes, plane_vals);
        }
    }

    return self;
}

/* run-length iteration ---------------------------------------------------- */

/*
 * count_run_lsb: count consecutive bits equal to `target` starting at flat
 * position `pos` (LSB-first).  Uses ctz / ctzll to skip bits in bulk:
 *   - partial first byte: ctz on the inverted masked nibble
 *   - full 64-bit words (LE): ctzll on the inverted word (64 bits per step)
 *   - remaining bytes: ctz on the inverted byte
 *
 * Porting to Ruby Core:
 *   1. Move to string.c alongside bit_at and each_bit.
 *   2. Share sb_ctz8 / sb_ctzll with the existing set-bit helpers.
 */
static long
count_run_lsb(const unsigned char *src, long src_len, long pos, int target)
{
    long max_run  = src_len * 8 - pos;
    long byte_idx = pos >> 3;
    int  bit_off  = pos & 7;
    long count    = 0;

    /* partial first byte: shift pos to bit 0, mask remaining bits */
    {
        int          remaining = 8 - bit_off;
        unsigned int b         = (unsigned int)src[byte_idx] >> bit_off;
        if (!target) b         = ~b;
        unsigned int mask      = (1u << remaining) - 1;
        b                     &= mask;
        unsigned int inv       = (~b) & mask;
        int run                = (inv == 0) ? remaining : sb_ctz8(inv);
        count                 += run;
        byte_idx++;
        if (run < remaining)
            return count < max_run ? count : max_run;
    }

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    /* full 8-byte words: skip 64 identical bits per iteration */
    while (byte_idx + 8 <= src_len) {
        uint64_t word;
        memcpy(&word, src + byte_idx, 8);
        if (!target) word = ~word;
        if (word == UINT64_MAX) {
            count    += 64;
            byte_idx += 8;
        } else {
            count += sb_ctzll(~word);
            return count < max_run ? count : max_run;
        }
    }
#endif

    /* remaining bytes (< 8) */
    while (byte_idx < src_len) {
        unsigned int b = (unsigned int)src[byte_idx];
        if (!target) b = ~b;
        b &= 0xFF;
        if (b == 0xFF) {
            count += 8;
            byte_idx++;
        } else {
            count += sb_ctz8(~b);
            return count < max_run ? count : max_run;
        }
    }

    return count < max_run ? count : max_run;
}

/*
 * count_run_msb: count consecutive bits equal to `target` from `pos` going
 * downward (toward bit 0).  Uses sb_highest_bit8 (clz-based) per byte.
 */
static long
count_run_msb(const unsigned char *src, long pos, int target)
{
    long max_run  = pos + 1;
    long byte_idx = pos >> 3;
    int  bit_off  = pos & 7;
    long count    = 0;

    /* partial first byte: align pos to bit 7 (MSB), mask upper garbage */
    {
        int          remaining = bit_off + 1;
        unsigned int b         = ((unsigned int)src[byte_idx] << (7 - bit_off)) & 0xFF;
        if (!target) b         = (~b) & 0xFF;
        int run;
        if (b == 0xFF) {
            run = remaining;
        } else {
            /* leading ones from MSB = 7 - position_of_highest_zero */
            run = 7 - sb_highest_bit8((~b) & 0xFF);
        }
        count += run;
        byte_idx--;
        if (run < remaining)
            return count < max_run ? count : max_run;
    }

    /* remaining full bytes, scanning from high to low */
    while (byte_idx >= 0) {
        unsigned int b = (unsigned int)src[byte_idx];
        if (!target) b = (~b) & 0xFF;
        else         b &= 0xFF;
        if (b == 0xFF) {
            count += 8;
            byte_idx--;
        } else {
            /* (~b) & 0xFF is non-zero because b != 0xFF */
            count += 7 - sb_highest_bit8((~b) & 0xFF);
            return count < max_run ? count : max_run;
        }
    }

    return count < max_run ? count : max_run;
}

/* String#count_run(pos) -> Integer
 *
 * Returns the length of the consecutive run of identical bits that starts at
 * flat position `pos`.  The bit value at `pos` determines what is counted.
 * Returns 0 when `pos` is out of range (mirrors bit_at nil behavior).
 *
 * Equivalent to Gauche Scheme's (bitvector-count-run bit bvec i), where the
 * bit value is inferred from the string rather than passed explicitly.
 *
 * Uses the same flat LSB-first addressing as bit_at: byte[pos/8] bit pos%8.
 *
 * Porting to Ruby Core:
 *   1. Move to string.c; register in Init_String().
 *   2. Reuse integer_to_bit_idx for consistent Bignum handling.
 */
static VALUE
rb_str_count_run(VALUE self, VALUE pos_val)
{
    if (!rb_integer_type_p(pos_val)) {
        rb_raise(rb_eTypeError, "position must be an integer");
    }
    long pos     = integer_to_bit_idx(pos_val);
    long src_len = RSTRING_LEN(self);
    if (pos < 0 || pos >= src_len * 8) return LONG2FIX(0);

    const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
    int target = (src[pos >> 3] >> (pos & 7)) & 1;
    return LONG2FIX(count_run_lsb(src, src_len, pos, target));
}

/* String#each_run(order: :lsb) { |bit, len| } -> self
 * String#each_run(order: :lsb) -> Enumerator
 *
 * Yields (bit, run_length) pairs for each consecutive run of identical bits.
 * Run-length boundary detection and counting happen entirely in C, replacing
 * the Ruby-level current/count state machine required when using each_bit.
 *
 * For random data (~50% density) each_run yields ~half as many times as
 * each_bit.  For structured data (sparse validity bitmaps, sensor bursts) the
 * ratio is proportional to the average run length.
 *
 * order: :lsb (default) iterates from bit 0 forward.
 * order: :msb iterates from the last bit downward.
 *
 * Porting to Ruby Core:
 *   1. Move to string.c; register in Init_String().
 *   2. count_run_lsb / count_run_msb move with it.
 */
static VALUE
rb_str_each_run(int argc, VALUE *argv, VALUE self)
{
    RETURN_ENUMERATOR(self, argc, argv);

    int msb_first = parse_order(argc, argv);
    long src_len  = RSTRING_LEN(self);
    if (src_len == 0) return self;

    long total_bits = src_len * 8;

    if (!msb_first) {
        long pos = 0;
        while (pos < total_bits) {
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            int bit  = (src[pos >> 3] >> (pos & 7)) & 1;
            long run = count_run_lsb(src, src_len, pos, bit);
            rb_yield_values(2, bit ? Qtrue : Qfalse, LONG2FIX(run));
            pos += run;
        }
    }
    else {
        long pos = total_bits - 1;
        while (pos >= 0) {
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            int bit  = (src[pos >> 3] >> (pos & 7)) & 1;
            long run = count_run_msb(src, pos, bit);
            rb_yield_values(2, bit ? Qtrue : Qfalse, LONG2FIX(run));
            pos -= run;
        }
    }

    return self;
}

/* Array#bitmask and Array#bitmask! --------------------------------------- */

/*
 * parse_bitmask_kwargs: extract bitmap, order:, and invert: from method arguments.
 *
 * Porting to Ruby Core:
 *   1. Keep this as a `static` helper in array.c — it is only called by
 *      ary_bitmask and ary_bitmask_bang, so no header declaration is needed.
 *   2. Rename to ary_bitmask_kwargs or similar to follow array.c conventions
 *      (static helpers in array.c use the `ary_` prefix, not `rb_ary_`).
 */
static void
parse_bitmask_kwargs(int argc, VALUE *argv, VALUE *bitmap_out,
                     int *msb_first_out, int *invert_out, int *is_integer_out)
{
    VALUE bitmap, opts;
    rb_scan_args(argc, argv, "1:", &bitmap, &opts);

    int msb_first  = 0; /* default :lsb */
    int invert     = 0; /* default false */
    int is_integer = rb_integer_type_p(bitmap);

    if (!is_integer) Check_Type(bitmap, T_STRING);

    if (!NIL_P(opts)) {
        VALUE order = rb_hash_aref(opts, ID2SYM(rb_intern("order")));
        if (!NIL_P(order)) {
            if (order == ID2SYM(rb_intern("lsb")))       msb_first = 0;
            else if (order == ID2SYM(rb_intern("msb"))) {
                if (is_integer)
                    rb_raise(rb_eArgError,
                             "order: :msb is not supported for Integer bitmap; "
                             "Integer bits are always LSB-first");
                msb_first = 1;
            }
            else rb_raise(rb_eArgError, "order: must be :lsb or :msb");
        }
        VALUE inv = rb_hash_aref(opts, ID2SYM(rb_intern("invert")));
        if (!NIL_P(inv)) {
            invert = RTEST(inv) ? 1 : 0;
        }
    }

    *bitmap_out     = bitmap;
    *msb_first_out  = msb_first;
    *invert_out     = invert;
    *is_integer_out = is_integer;
}

/* Read bit i from an Integer bitmap (always LSB-first).
 * Bits beyond the integer's width are 0 (valid for non-negative integers). */
static inline int
integer_get_bit(VALUE n, long i)
{
    if (FIXNUM_P(n)) {
        long v = FIX2LONG(n);
        if (v < 0)
            rb_raise(rb_eArgError, "Integer bitmap must be non-negative");
        if (i >= (long)(sizeof(long) * CHAR_BIT) - 1) return 0;
        return (int)((v >> i) & 1);
    }
    if (RBIGNUM_NEGATIVE_P(n))
        rb_raise(rb_eArgError, "Integer bitmap must be non-negative");
    VALUE bit = rb_funcall(n, rb_intern("[]"), 1, LONG2FIX(i));
    return RB_TEST(bit) ? 1 : 0;
}

static VALUE
rb_ary_bitmask(int argc, VALUE *argv, VALUE self)
{
    VALUE bitmap;
    int msb_first, invert, is_integer;
    parse_bitmask_kwargs(argc, argv, &bitmap, &msb_first, &invert, &is_integer);

    long ary_len = RARRAY_LEN(self);
    const VALUE *src = RARRAY_CONST_PTR(self);
    VALUE result = rb_ary_new_capa(ary_len);

    if (is_integer) {
        for (long i = 0; i < ary_len; i++) {
            int bit = integer_get_bit(bitmap, i);
            if (invert) bit = !bit;
            rb_ary_push(result, bit ? src[i] : Qnil);
        }
    }
    else {
        const char *bmp = RSTRING_PTR(bitmap);
        long bmp_len    = RSTRING_LEN(bitmap);
        long needed     = (ary_len + 7) >> 3;
        if (needed > bmp_len)
            rb_raise(rb_eArgError,
                     "bitmap too short: need %ld bytes for %ld elements, got %ld",
                     needed, ary_len, bmp_len);
        for (long i = 0; i < ary_len; i++) {
            int bit = rb_str_get_bit(bmp, i, msb_first);
            if (invert) bit = !bit;
            rb_ary_push(result, bit ? src[i] : Qnil);
        }
    }

    return result;
}

static VALUE
rb_ary_bitmask_bang(int argc, VALUE *argv, VALUE self)
{
    VALUE bitmap;
    int msb_first, invert, is_integer;
    parse_bitmask_kwargs(argc, argv, &bitmap, &msb_first, &invert, &is_integer);

    long ary_len = RARRAY_LEN(self);
    rb_ary_modify(self);

    if (is_integer) {
        for (long i = 0; i < ary_len; i++) {
            int bit = integer_get_bit(bitmap, i);
            if (invert) bit = !bit;
            if (!bit) rb_ary_store(self, i, Qnil);
        }
    }
    else {
        const char *bmp = RSTRING_PTR(bitmap);
        long bmp_len    = RSTRING_LEN(bitmap);
        long needed     = (ary_len + 7) >> 3;
        if (needed > bmp_len)
            rb_raise(rb_eArgError,
                     "bitmap too short: need %ld bytes for %ld elements, got %ld",
                     needed, ary_len, bmp_len);
        for (long i = 0; i < ary_len; i++) {
            int bit = rb_str_get_bit(bmp, i, msb_first);
            if (invert) bit = !bit;
            if (!bit) rb_ary_store(self, i, Qnil);
        }
    }

    return self;
}

/* Init -------------------------------------------------------------------- */

void
Init_string_bits(void)
{
    rb_define_method(rb_cString, "bit_at",            rb_str_bit_at,            1);
    rb_define_method(rb_cString, "popcount",          rb_str_popcount,          0);
    rb_define_method(rb_cString, "each_bit",          rb_str_each_bit,         -1);
    rb_define_method(rb_cString, "bits",              rb_str_bits,             -1);
    rb_define_method(rb_cString, "each_set_bit",      rb_str_each_set_bit,     -1);
    rb_define_method(rb_cString, "set_bit_positions", rb_str_set_bit_positions,-1);
    rb_define_method(rb_cString, "bit_slice",         rb_str_bit_slice,         2);
    rb_define_method(rb_cString, "each_bit_slice",    rb_str_each_bit_slice,   -1);
    rb_define_method(rb_cString, "count_run",         rb_str_count_run,         1);
    rb_define_method(rb_cString, "each_run",          rb_str_each_run,         -1);
    rb_define_method(rb_cString, "set_bit",           rb_str_set_bit,           1);
    rb_define_method(rb_cString, "clear_bit",         rb_str_clear_bit,         1);
    rb_define_method(rb_cString, "flip_bit",          rb_str_flip_bit,          1);
    rb_define_method(rb_cString, "bit_not",           rb_str_bit_not,           0);
    rb_define_method(rb_cString, "bit_not!",          rb_str_bit_not_bang,      0);
    rb_define_method(rb_cString, "bit_and",           rb_str_bit_and,           1);
    rb_define_method(rb_cString, "bit_and!",          rb_str_bit_and_bang,      1);
    rb_define_method(rb_cString, "bit_or",            rb_str_bit_or,            1);
    rb_define_method(rb_cString, "bit_or!",           rb_str_bit_or_bang,       1);
    rb_define_method(rb_cString, "bit_xor",           rb_str_bit_xor,           1);
    rb_define_method(rb_cString, "bit_xor!",          rb_str_bit_xor_bang,      1);
    rb_define_method(rb_cArray,  "bitmask",            rb_ary_bitmask,          -1);
    rb_define_method(rb_cArray,  "bitmask!",           rb_ary_bitmask_bang,     -1);
}
