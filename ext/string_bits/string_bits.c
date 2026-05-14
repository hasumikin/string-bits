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

static ID id_bracket;
static VALUE sym_scan_order, sym_count_from, sym_field_order, sym_lsb, sym_msb, sym_invert;

enum sb_kw_flag {
    SB_KW_SCAN_ORDER = 1 << 0,
    SB_KW_COUNT_FROM = 1 << 1,
    SB_KW_FIELD_ORDER = 1 << 2,
    SB_KW_INVERT = 1 << 3
};

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

/* Convert a Ruby Integer to a long bit index.
 *
 * Raises ArgumentError for Bignums on all platforms: a Bignum cannot be a
 * valid bit index for any real string, and raising explicitly is clearer than
 * silently mapping to a sentinel value that later triggers a different error.
 * This also avoids the platform-dependent RangeError from NUM2LONG (LP64 vs
 * LLP64/Windows with different sizeof(long)).
 *
 * RBIGNUM_NEGATIVE_P is available via ruby.h -> ruby/internal/core/rbignum.h. */
static long
integer_to_bit_idx(VALUE n)
{
    if (FIXNUM_P(n)) return FIX2LONG(n);
    RUBY_ASSERT(RB_TYPE_P(n, T_BIGNUM));
    rb_raise(rb_eArgError, "bit index out of representable range");
    UNREACHABLE_RETURN(0);
}

static long
check_bit_index(VALUE self, VALUE n, int msb_first)
{
    if (!rb_integer_type_p(n)) {
        rb_raise(rb_eTypeError, "bit index must be an integer");
    }
    long idx = integer_to_bit_idx(n);
    long size = RSTRING_LEN(self) * 8;
    if (idx < 0 || idx >= size) {
        rb_raise(rb_eIndexError, "bit index out of range");
    }
    if (msb_first) idx = size - 1 - idx;
    return idx;
}

static inline long
physical_to_logical(long total_bits, long physical, int msb_first)
{
    return msb_first ? (total_bits - 1 - physical) : physical;
}

static void
validate_option_hash(VALUE opts, unsigned allowed)
{
    if (NIL_P(opts)) return;
    Check_Type(opts, T_HASH);

    VALUE keys = rb_funcall(opts, rb_intern("keys"), 0);
    long len = RARRAY_LEN(keys);

    for (long i = 0; i < len; i++) {
        VALUE key = RARRAY_AREF(keys, i);
        if (((allowed & SB_KW_SCAN_ORDER) && key == sym_scan_order) ||
            ((allowed & SB_KW_COUNT_FROM) && key == sym_count_from) ||
            ((allowed & SB_KW_FIELD_ORDER) && key == sym_field_order) ||
            ((allowed & SB_KW_INVERT) && key == sym_invert)) {
            continue;
        }

        rb_raise(rb_eArgError, "unknown keyword: %"PRIsVALUE, rb_inspect(key));
    }
}

static int
parse_binary_opt(VALUE opts, VALUE key, const char *name)
{
    if (NIL_P(opts)) return 0;
    VALUE order = rb_hash_aref(opts, key);
    if (NIL_P(order) || order == sym_lsb) return 0;
    if (order == sym_msb) return 1;
    rb_raise(rb_eArgError, "%s must be :lsb or :msb", name);
    return 0;
}

static int
parse_scan_order_opt(VALUE opts)
{
    return parse_binary_opt(opts, sym_scan_order, "scan_order");
}

static int
parse_count_from_opt(VALUE opts)
{
    return parse_binary_opt(opts, sym_count_from, "count_from");
}

static int
parse_field_order_opt(VALUE opts)
{
    return parse_binary_opt(opts, sym_field_order, "field_order");
}

static int
parse_scan_order(int argc, VALUE *argv)
{
    VALUE opts = Qnil;
    rb_scan_args(argc, argv, "0:", &opts);
    validate_option_hash(opts, SB_KW_SCAN_ORDER);
    return parse_scan_order_opt(opts);
}

static int
parse_count_from(int argc, VALUE *argv)
{
    VALUE opts = Qnil;
    rb_scan_args(argc, argv, "0:", &opts);
    validate_option_hash(opts, SB_KW_COUNT_FROM);
    return parse_count_from_opt(opts);
}

static inline uint64_t
reverse_low_bits_u64(uint64_t v, long bitlen)
{
    uint64_t out = 0;
    for (long i = 0; i < bitlen; i++) {
        out = (out << 1) | (v & 1);
        v >>= 1;
    }
    return out;
}

/* read -------------------------------------------------------------------- */

/* String#bit_at(n, count_from: :lsb) -> true or false
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
rb_str_bit_at(int argc, VALUE *argv, VALUE self)
{
    VALUE n, opts;
    rb_scan_args(argc, argv, "1:", &n, &opts);
    validate_option_hash(opts, SB_KW_COUNT_FROM);

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

    int msb_first = parse_count_from_opt(opts);

    if (msb_first) {
        idx = size - 1 - idx;
    }

    if (test_bit(RSTRING_PTR(self), idx)) {
        return Qtrue;
    } else {
        return Qfalse;
    }
}

static VALUE
rb_str_bit_count(VALUE self)
{
    long count = 0;
    long len = RSTRING_LEN(self);
    const char *str = RSTRING_PTR(self);
    const uint64_t *ptr = (const uint64_t *)str;
    const uint64_t *aligned_end = (const uint64_t *)(str + (len & ~7));
    const uint64_t *unrolled_end = (const uint64_t *)(str + (len & ~31));

    for (; ptr < unrolled_end; ptr += 4) {
        count += sb_popcount64(ptr[0]);
        count += sb_popcount64(ptr[1]);
        count += sb_popcount64(ptr[2]);
        count += sb_popcount64(ptr[3]);
    }

    for (; ptr < aligned_end; ptr++) {
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

    int msb_first = parse_scan_order(argc, argv);
    long len = RSTRING_LEN(self);
    const unsigned char *str = (const unsigned char *)RSTRING_PTR(self);

    if (msb_first) {
        for (long i = len - 1; i >= 0; i--) {
            unsigned char b = str[i];
            for (int j = 7; j >= 0; j--) {
                rb_yield((b >> j) & 1 ? Qtrue : Qfalse);
            }
        }
    }
    else {
        for (long i = 0; i < len; i++) {
            unsigned char b = str[i];
            for (int j = 0; j < 8; j++) {
                rb_yield((b >> j) & 1 ? Qtrue : Qfalse);
            }
        }
    }

    return self;
}

static VALUE
rb_str_bits(int argc, VALUE *argv, VALUE self)
{
    int msb_first = parse_scan_order(argc, argv);
    long len = RSTRING_LEN(self);
    const unsigned char *str = (const unsigned char *)RSTRING_PTR(self);
    long total_bits = len * 8;
    int have_block = rb_block_given_p();

    VALUE ary = have_block ? Qnil : rb_ary_new_capa(total_bits);

    if (msb_first) {
        for (long i = len - 1; i >= 0; i--) {
            unsigned char b = str[i];
            for (int j = 7; j >= 0; j--) {
                VALUE bit = (b >> j) & 1 ? Qtrue : Qfalse;
                have_block ? rb_yield(bit) : rb_ary_push(ary, bit);
            }
        }
    }
    else {
        for (long i = 0; i < len; i++) {
            unsigned char b = str[i];
            for (int j = 0; j < 8; j++) {
                VALUE bit = (b >> j) & 1 ? Qtrue : Qfalse;
                have_block ? rb_yield(bit) : rb_ary_push(ary, bit);
            }
        }
    }

    return have_block ? self : ary;
}

/* iterate set-bit positions ----------------------------------------------- */

static VALUE
rb_str_each_set_bit_offset(int argc, VALUE *argv, VALUE self)
{
    RETURN_ENUMERATOR(self, argc, argv);

    int msb_first = parse_count_from(argc, argv);
    long len = RSTRING_LEN(self);
    const unsigned char *str = (const unsigned char *)RSTRING_PTR(self);
    long total_bits = len * 8;

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
        /* count_from: :msb => ascending logical positions 0, 1, 2, ... */
        for (long bi = len - 1; bi >= 0; bi--) {
            unsigned int b = str[bi];
            while (b != 0) {
                int bit = sb_highest_bit8(b);
                long physical = bi * 8 + bit;
                rb_yield(LONG2FIX(physical_to_logical(total_bits, physical, 1)));
                b ^= (1u << bit);  /* clear highest set bit */
            }
        }
    }

    return self;
}

static VALUE
rb_str_set_bit_offsets(int argc, VALUE *argv, VALUE self)
{
    int msb_first = parse_count_from(argc, argv);
    long len = RSTRING_LEN(self);
    const unsigned char *str = (const unsigned char *)RSTRING_PTR(self);
    long total_bits = len * 8;
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
                long physical = bi * 8 + bit;
                VALUE pos = LONG2FIX(physical_to_logical(total_bits, physical, 1));
                have_block ? rb_yield(pos) : rb_ary_push(ary, pos);
                b ^= (1u << bit);
            }
        }
    }

    return have_block ? self : ary;
}

/* extract ----------------------------------------------------------------- */

/*
 * sb_extract_bits: copy bit_length bits from src[src_bit_off] into dst[0..],
 * producing an LSB-first packed byte string with the tail byte masked.
 * dst must be zeroed and sized to (bit_length + 7) / 8 bytes.
 */
static void
sb_extract_bits(unsigned char *dst, long out_bytes,
                const unsigned char *src, long src_len,
                long src_bit_off, long bit_length)
{
    long byte_off = src_bit_off >> 3;
    int shift = (int)(src_bit_off & 7);

    if (shift == 0) {
        memcpy(dst, src + byte_off, out_bytes);
    } else {
        int anti_shift = 8 - shift;
        long i = 0;
#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        long out_bytes64 = out_bytes / 8;
        for (; i < out_bytes64; i++) {
            if (byte_off + i * 8 + 8 < src_len) {
                uint64_t lo;
                memcpy(&lo, src + byte_off + i * 8, 8);
                uint64_t next_byte = src[byte_off + i * 8 + 8];
                uint64_t val = (lo >> shift) | (next_byte << (64 - shift));
                memcpy(dst + i * 8, &val, 8);
            } else {
                break;
            }
        }
        i *= 8;
#endif
        for (; i < out_bytes; i++) {
            unsigned char lo = src[byte_off + i];
            unsigned char hi = (byte_off + i + 1 < src_len) ? src[byte_off + i + 1] : 0;
            dst[i] = (unsigned char)((lo >> shift) | (hi << anti_shift));
        }
    }

    int tail_bits = (int)(bit_length & 7);
    if (tail_bits) {
        dst[out_bytes - 1] &= (unsigned char)((1u << tail_bits) - 1);
    }
}

/* String#bit_slice(bit_offset, bit_length) -> String
 *
 *   str = "\xFF\x00" # 11111111 00000000
 *   str.bit_slice(4, 8) # => "\xF0" (11110000)
 */
static VALUE
rb_str_bit_slice(int argc, VALUE *argv, VALUE self)
{
    VALUE bit_offset, bit_length;
    rb_scan_args(argc, argv, "20", &bit_offset, &bit_length);

    if (!rb_integer_type_p(bit_offset) || !rb_integer_type_p(bit_length)) {
        return Qnil;
    }

    long offset = integer_to_bit_idx(bit_offset);
    long length = integer_to_bit_idx(bit_length);

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
    sb_extract_bits(dst, out_bytes, src, src_len, offset, length);
    return result;
}

/* single-bit mutation ----------------------------------------------------- */

static VALUE
rb_str_set_bit(int argc, VALUE *argv, VALUE self)
{
    VALUE n, opts;
    rb_scan_args(argc, argv, "1:", &n, &opts);
    validate_option_hash(opts, SB_KW_COUNT_FROM);
    int msb_first = parse_count_from_opt(opts);

    long idx = check_bit_index(self, n, msb_first);
    rb_str_modify(self);
    RSTRING_PTR(self)[idx / 8] |= (unsigned char)(1 << (idx % 8));
    return self;
}

static VALUE
rb_str_clear_bit(int argc, VALUE *argv, VALUE self)
{
    VALUE n, opts;
    rb_scan_args(argc, argv, "1:", &n, &opts);
    validate_option_hash(opts, SB_KW_COUNT_FROM);
    int msb_first = parse_count_from_opt(opts);

    long idx = check_bit_index(self, n, msb_first);
    rb_str_modify(self);
    RSTRING_PTR(self)[idx / 8] &= (unsigned char)~(1 << (idx % 8));
    return self;
}

static VALUE
rb_str_flip_bit(int argc, VALUE *argv, VALUE self)
{
    VALUE n, opts;
    rb_scan_args(argc, argv, "1:", &n, &opts);
    validate_option_hash(opts, SB_KW_COUNT_FROM);
    int msb_first = parse_count_from_opt(opts);

    long idx = check_bit_index(self, n, msb_first);
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
 * NOTE: each_bit_field and bit_fields are implemented here and fully tested,
 * but are NOT part of the current core proposal (see FUTURE_PROPOSAL_PLAN.md).
 * They are deferred because yielding Integer field values is a qualitatively
 * different contract from the rest of the API, and that difference is expected
 * to extend core-ruby-dev discussion. The code is kept so the proposal can be
 * extended later without re-implementation.
 */

/*
 * extract_uint64: extract up to 64 bits starting at bit_offset from src as an
 * unsigned 64-bit integer (LSB-first bit layout, matching bit_slice).
 *
 * Porting to Ruby Core:
 *   1. Move into string.c alongside the bit_slice implementation.
 *   2. Share with rb_str_bit_slice to avoid duplication.
 */
static uint64_t
extract_uint64(const unsigned char *src, long src_len, long bit_offset, long bitlen)
{
    uint64_t val = 0;
    long byte_off = bit_offset >> 3;
    int  shift    = (int)(bit_offset & 7);
    int  n        = (shift + (int)bitlen + 7) / 8;
    for (int i = 0; i < n; i++) {
        if (byte_off + i < src_len)
            val |= (uint64_t)src[byte_off + i] << (i * 8);
    }
    val >>= shift;
    if (bitlen < 64) val &= (UINT64_C(1) << bitlen) - 1;
    return val;
}

/* String#each_bit_field(*bitlens, scan_order: :lsb, field_order: :lsb) -> self
 * String#each_bit_field(*bitlens, scan_order: :lsb, field_order: :lsb) -> Enumerator
 *
 * Iterates over the string as a sequence of packed bit-field records. Each
 * positional argument specifies the width (in bits) of one field in the record.
 * On each iteration, one Integer per field is yielded (LSB-first bit layout).
 * Each bitlen must be in the range 1..64.
 *
 * scan_order:  :lsb (default) -- iterates from the first record forward.
 * scan_order:  :msb           -- iterates from the last complete record backward.
 * field_order: :lsb (default) -- lowest-numbered bit becomes the least significant bit.
 * field_order: :msb           -- lowest-numbered bit becomes the most significant bit.
 *
 * Incomplete trailing bits (when bytesize*8 is not a multiple of sum(bitlens))
 * are silently dropped, matching the behavior of Enumerable#each_slice.
 *
 * Porting to Ruby Core:
 *   1. Move extract_uint64 and this function into string.c.
 *   2. Register with rb_define_method in Init_String().
 *   3. Replace ALLOCA_N with stack arrays for small field counts and heap otherwise.
 */
static VALUE
rb_str_each_bit_field(int argc, VALUE *argv, VALUE self)
{
    RETURN_ENUMERATOR(self, argc, argv);

    VALUE rest, opts;
    rb_scan_args(argc, argv, "*:", &rest, &opts);
    validate_option_hash(opts, SB_KW_SCAN_ORDER | SB_KW_FIELD_ORDER);

    long num_fields = RARRAY_LEN(rest);
    if (num_fields == 0) {
        rb_raise(rb_eArgError, "wrong number of arguments (given 0, expected 1+)");
    }

    long *bitlens = ALLOCA_N(long, num_fields);
    long step = 0;
    for (long f = 0; f < num_fields; f++) {
        VALUE v = RARRAY_AREF(rest, f);
        if (!rb_integer_type_p(v)) {
            rb_raise(rb_eTypeError, "bitlen must be an integer");
        }
        long bl = NUM2LONG(v);
        if (bl <= 0) {
            rb_raise(rb_eArgError, "bitlen must be positive");
        }
        if (bl > 64) {
            rb_raise(rb_eArgError, "bitlen must be <= 64 (got %ld)", bl);
        }
        bitlens[f] = bl;
        step += bl;
    }

    int msb_first = parse_scan_order_opt(opts);
    int field_msb = parse_field_order_opt(opts);

    long src_len = RSTRING_LEN(self);
    long total_bits = src_len * 8;
    long iterations = total_bits / step;

    VALUE *field_vals = ALLOCA_N(VALUE, num_fields);

    if (!msb_first) {
        for (long iter = 0; iter < iterations; iter++) {
            long base_bit = iter * step;
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            long field_bit = base_bit;
            for (long f = 0; f < num_fields; f++) {
                uint64_t val = extract_uint64(src, src_len, field_bit, bitlens[f]);
                if (field_msb) val = reverse_low_bits_u64(val, bitlens[f]);
                field_vals[f] = ULL2NUM(val);
                field_bit += bitlens[f];
            }
            rb_yield_values2((int)num_fields, field_vals);
        }
    } else {
        for (long iter = iterations - 1; iter >= 0; iter--) {
            long base_bit = iter * step;
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            long field_bit = base_bit;
            for (long f = 0; f < num_fields; f++) {
                uint64_t val = extract_uint64(src, src_len, field_bit, bitlens[f]);
                if (field_msb) val = reverse_low_bits_u64(val, bitlens[f]);
                field_vals[f] = ULL2NUM(val);
                field_bit += bitlens[f];
            }
            rb_yield_values2((int)num_fields, field_vals);
        }
    }

    return self;
}

/* String#bit_fields(*bitlens, scan_order: :lsb, field_order: :lsb) -> Array
 * String#bit_fields(*bitlens, scan_order: :lsb, field_order: :lsb) { |*fields| } -> self
 *
 * Non-iterator complement of each_bit_field.  Without a block, returns an
 * Array of all extracted records.  With a single bitlen the array is flat
 * (matching each_bit_field(n).to_a); with multiple bitlens each record is
 * itself an Array (matching each_bit_field(a, b, ...).to_a).
 *
 * With a block, behaves identically to each_bit_field without with: ---
 * yielding one Integer per field and returning self.
 *
 * Porting to Ruby Core:
 *   1. Move alongside each_bit_field in string.c.
 *   2. Share extract_uint64 and the bitlen validation logic.
 *   3. Register with rb_define_method in Init_String().
 */
static VALUE
rb_str_bit_fields(int argc, VALUE *argv, VALUE self)
{
    VALUE rest, opts;
    rb_scan_args(argc, argv, "*:", &rest, &opts);
    validate_option_hash(opts, SB_KW_SCAN_ORDER | SB_KW_FIELD_ORDER);

    long num_fields = RARRAY_LEN(rest);
    if (num_fields == 0) {
        rb_raise(rb_eArgError, "wrong number of arguments (given 0, expected 1+)");
    }

    long *bitlens = ALLOCA_N(long, num_fields);
    long step = 0;
    for (long f = 0; f < num_fields; f++) {
        VALUE v = RARRAY_AREF(rest, f);
        if (!rb_integer_type_p(v)) {
            rb_raise(rb_eTypeError, "bitlen must be an integer");
        }
        long bl = NUM2LONG(v);
        if (bl <= 0) {
            rb_raise(rb_eArgError, "bitlen must be positive");
        }
        if (bl > 64) {
            rb_raise(rb_eArgError, "bitlen must be <= 64 (got %ld)", bl);
        }
        bitlens[f] = bl;
        step += bl;
    }

    int msb_first = parse_scan_order_opt(opts);
    int field_msb = parse_field_order_opt(opts);

    long src_len = RSTRING_LEN(self);
    long total_bits = src_len * 8;
    long iterations = total_bits / step;

    int have_block = rb_block_given_p();
    VALUE result = have_block ? Qnil : rb_ary_new_capa(iterations);

    VALUE *field_vals = ALLOCA_N(VALUE, num_fields);

    if (!msb_first) {
        for (long iter = 0; iter < iterations; iter++) {
            long base_bit = iter * step;
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            long field_bit = base_bit;
            for (long f = 0; f < num_fields; f++) {
                uint64_t val = extract_uint64(src, src_len, field_bit, bitlens[f]);
                if (field_msb) val = reverse_low_bits_u64(val, bitlens[f]);
                field_vals[f] = ULL2NUM(val);
                field_bit += bitlens[f];
            }
            if (have_block) {
                rb_yield_values2((int)num_fields, field_vals);
            } else if (num_fields == 1) {
                rb_ary_push(result, field_vals[0]);
            } else {
                rb_ary_push(result, rb_ary_new_from_values(num_fields, field_vals));
            }
        }
    } else {
        for (long iter = iterations - 1; iter >= 0; iter--) {
            long base_bit = iter * step;
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            long field_bit = base_bit;
            for (long f = 0; f < num_fields; f++) {
                uint64_t val = extract_uint64(src, src_len, field_bit, bitlens[f]);
                if (field_msb) val = reverse_low_bits_u64(val, bitlens[f]);
                field_vals[f] = ULL2NUM(val);
                field_bit += bitlens[f];
            }
            if (have_block) {
                rb_yield_values2((int)num_fields, field_vals);
            } else if (num_fields == 1) {
                rb_ary_push(result, field_vals[0]);
            } else {
                rb_ary_push(result, rb_ary_new_from_values(num_fields, field_vals));
            }
        }
    }

    return have_block ? self : result;
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

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    /* full 8-byte words, scanning backward */
    while (byte_idx >= 7) {
        uint64_t word;
        memcpy(&word, src + byte_idx - 7, 8);
        if (!target) word = ~word;
        if (word == UINT64_MAX) {
            count += 64;
            byte_idx -= 8;
        } else {
            /* highest bit is at the end of the 8-byte block */
#if __has_builtin(__builtin_clzll)
            count += __builtin_clzll(~word);
#elif defined(_MSC_VER)
            unsigned long index;
            _BitScanReverse64(&index, ~word);
            count += 63 - (int)index;
#else
            /* fallback to byte-by-byte if no clzll */
            goto byte_by_byte;
#endif
            return count < max_run ? count : max_run;
        }
    }
#endif

#if !defined(__BYTE_ORDER__) || __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
byte_by_byte:
#endif
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

/* String#bit_run_count(pos, bit) -> Integer
 *
 * Returns the length of the consecutive run of `bit` starting at flat
 * position `pos`.  Returns 0 when `pos` is out of range or the bit at `pos`
 * does not equal `bit`.
 *
 * `bit` accepts 0, 1, false, or true (false/true are aliases for 0/1,
 * matching the values yielded by each_bit_run).
 *
 * Counts forward from `pos` toward higher bit indices.
 *
 * Inspired by Gauche Scheme's (bitvector-count-run bit bvec i).
 *
 * Uses the same flat LSB-first addressing as bit_at: byte[pos/8] bit pos%8.
 *
 * Porting to Ruby Core:
 *   1. Move to string.c; register in Init_String().
 *   2. Reuse integer_to_bit_idx for consistent Bignum handling.
 */
static VALUE
rb_str_bit_run_count(int argc, VALUE *argv, VALUE self)
{
    VALUE pos_val, bit_val;
    rb_scan_args(argc, argv, "20", &pos_val, &bit_val);

    if (!rb_integer_type_p(pos_val)) {
        rb_raise(rb_eTypeError, "position must be an integer");
    }
    int target;
    if (bit_val == Qtrue || bit_val == INT2FIX(1)) {
        target = 1;
    } else if (bit_val == Qfalse || bit_val == INT2FIX(0)) {
        target = 0;
    } else {
        rb_raise(rb_eArgError, "bit must be 0, 1, false, or true");
    }
    long pos     = integer_to_bit_idx(pos_val);
    long src_len = RSTRING_LEN(self);
    if (pos < 0 || pos >= src_len * 8) return LONG2FIX(0);

    const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
    if (((src[pos >> 3] >> (pos & 7)) & 1) != target) return LONG2FIX(0);
    return LONG2FIX(count_run_lsb(src, src_len, pos, target));
}

/* String#each_bit_run(scan_order: :lsb) { |bit, len| } -> self
 * String#each_bit_run(scan_order: :lsb) -> Enumerator
 *
 * Yields (bit, run_length) pairs for each consecutive run of identical bits.
 * Run-length boundary detection and counting happen entirely in C, replacing
 * the Ruby-level current/count state machine required when using each_bit.
 *
 * For random data (~50% density) each_bit_run yields ~half as many times as
 * each_bit.  For structured data (sparse validity bitmaps, sensor bursts) the
 * ratio is proportional to the average run length.
 *
 * scan_order: :lsb (default) iterates from bit 0 forward.
 * scan_order: :msb iterates from the last bit downward.
 *
 * Porting to Ruby Core:
 *   1. Move to string.c; register in Init_String().
 *   2. count_run_lsb / count_run_msb move with it.
 */
static VALUE
rb_str_each_bit_run(int argc, VALUE *argv, VALUE self)
{
    RETURN_ENUMERATOR(self, argc, argv);

    int msb_first = parse_scan_order(argc, argv);
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

/* String#bit_runs(scan_order: :lsb) -> Array
 * String#bit_runs(scan_order: :lsb) { |bit, len| } -> self
 *
 * Non-iterator complement of each_bit_run. Without a block, collects all
 * (bit, run_length) pairs into an Array and returns it. With a block,
 * yields each pair and returns self.
 *
 * Follows the same pattern as String#bytes vs String#each_byte.
 *
 * Porting to Ruby Core:
 *   1. Move to string.c alongside each_bit_run; register in Init_String().
 */
static VALUE
rb_str_bit_runs(int argc, VALUE *argv, VALUE self)
{
    int msb_first  = parse_scan_order(argc, argv);
    long src_len   = RSTRING_LEN(self);
    int have_block = rb_block_given_p();

    if (src_len == 0) return have_block ? self : rb_ary_new();

    long total_bits = src_len * 8;
    VALUE result    = have_block ? Qnil : rb_ary_new();

    if (!msb_first) {
        long pos = 0;
        while (pos < total_bits) {
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            int bit  = (src[pos >> 3] >> (pos & 7)) & 1;
            long run = count_run_lsb(src, src_len, pos, bit);
            VALUE bval = bit ? Qtrue : Qfalse;
            VALUE lval = LONG2FIX(run);
            have_block ? rb_yield_values(2, bval, lval)
                       : rb_ary_push(result, rb_assoc_new(bval, lval));
            pos += run;
        }
    } else {
        long pos = total_bits - 1;
        while (pos >= 0) {
            const unsigned char *src = (const unsigned char *)RSTRING_PTR(self);
            int bit  = (src[pos >> 3] >> (pos & 7)) & 1;
            long run = count_run_msb(src, pos, bit);
            VALUE bval = bit ? Qtrue : Qfalse;
            VALUE lval = LONG2FIX(run);
            have_block ? rb_yield_values(2, bval, lval)
                       : rb_ary_push(result, rb_assoc_new(bval, lval));
            pos -= run;
        }
    }

    return have_block ? self : result;
}

/* multi-bit mutation ------------------------------------------------------ */

/*
 * bit_copy_core: copy `length` bits from src[src_bit_off] to dst[dst_bit_off].
 *
 * Both offsets are in the LSB-first flat bit numbering used throughout
 * string_bits.  The routine does not resize dst; the caller must ensure
 * dst has enough bytes.
 *
 * Algorithm:
 *   1. Extract the src bits into a small aligned tmp buffer (identical to the
 *      bit_slice read path).
 *   2. Write tmp into dst with shift/mask merge (handles the unaligned case).
 *
 * Porting to Ruby Core:
 *   1. Move alongside bit_slice in string.c.
 *   2. Share the extract loop with rb_str_bit_slice via ebs_extract.
 *   3. Remove `static`.
 */
static void
bit_copy_core(unsigned char *dst, long dst_bit_off,
              const unsigned char *src, long src_len_bytes,
              long src_bit_off, long length)
{
    if (length == 0) return;
    long out_bytes = (length + 7) >> 3;

    unsigned char  stack_tmp[256];
    unsigned char *tmp = (out_bytes <= (long)sizeof(stack_tmp))
                         ? stack_tmp
                         : (unsigned char *)ruby_xmalloc(out_bytes);

    /* Step 1: extract src bits into tmp (aligned, zero-padded tail) */
    {
        long src_byte_off = src_bit_off >> 3;
        int  src_shift    = (int)(src_bit_off & 7);
        if (src_shift == 0) {
            memcpy(tmp, src + src_byte_off, out_bytes);
        }
        else {
            int anti = 8 - src_shift;
            for (long i = 0; i < out_bytes; i++) {
                unsigned char lo = src[src_byte_off + i];
                unsigned char hi = (src_byte_off + i + 1 < src_len_bytes)
                                   ? src[src_byte_off + i + 1] : 0;
                tmp[i] = (unsigned char)((lo >> src_shift) | (hi << anti));
            }
        }
        int tail = (int)(length & 7);
        if (tail) tmp[out_bytes - 1] &= (unsigned char)((1u << tail) - 1);
    }

    /* Step 2: write aligned tmp into dst at dst_bit_off */
    {
        long dst_byte_off = dst_bit_off >> 3;
        int  dst_shift    = (int)(dst_bit_off & 7);

        if (dst_shift == 0) {
            long full = length >> 3;
            int  tail = (int)(length & 7);
            memcpy(dst + dst_byte_off, tmp, full);
            if (tail) {
                unsigned char mask = (unsigned char)((1u << tail) - 1);
                dst[dst_byte_off + full] =
                    (dst[dst_byte_off + full] & (unsigned char)~mask)
                    | (tmp[full] & mask);
            }
        }
        else {
            int  anti  = 8 - dst_shift;
            long n_dst = ((dst_bit_off + length - 1) >> 3) - dst_byte_off + 1;

            for (long i = 0; i < n_dst; i++) {
                long byte_base = (dst_byte_off + i) * 8;
                long wstart = dst_bit_off > byte_base ? dst_bit_off - byte_base : 0;
                long wend   = (dst_bit_off + length - 1 < byte_base + 7)
                              ? dst_bit_off + length - 1 - byte_base : 7;
                unsigned char wmask =
                    (unsigned char)(((1u << (wend + 1)) - 1) ^ ((1u << wstart) - 1));

                /* lo_t: high bits of the previous tmp byte spill into this dst byte */
                unsigned char lo_t = (i > 0 && i - 1 < out_bytes) ? tmp[i - 1] : 0;
                /* hi_t: low bits of the current tmp byte fill the upper part */
                unsigned char hi_t = (i < out_bytes) ? tmp[i] : 0;
                unsigned char nv = (unsigned char)((lo_t >> anti) | (hi_t << dst_shift));
                dst[dst_byte_off + i] =
                    (dst[dst_byte_off + i] & (unsigned char)~wmask) | (nv & wmask);
            }
        }
    }

    if (tmp != stack_tmp) ruby_xfree(tmp);
}

/* String#bit_splice(bit_index, bit_length, str) -> self
 * String#bit_splice(bit_index, bit_length, str, str_bit_index, str_bit_length) -> self
 * String#bit_splice(range, str) -> self
 * String#bit_splice(range, str, str_range) -> self
 *
 * Writes bits from str into self at bit-level granularity.  The inverse of
 * bit_slice: where bit_slice reads a sub-sequence of bits, bit_splice writes one.
 *
 * The destination and source bit lengths must be equal; bit_splice does not
 * resize self (sub-byte resize is undefined).  This mirrors the constraint that
 * bytesplice imposes when the replacement has the same byte length.
 *
 * Negative indices count backward from the end, exactly as in bytesplice.
 * Returns self.
 *
 * Porting to Ruby Core:
 *   1. Move to string.c; register in Init_String().
 *   2. Use rb_str_modify_expand if resize support is ever added.
 *   3. bit_copy_core moves with it; share ebs_extract with bit_slice.
 */
static VALUE
rb_str_bit_splice(int argc, VALUE *argv, VALUE self)
{
    long dst_bit_off, dst_bit_len;
    long src_bit_off, src_bit_len;
    VALUE str;
    long dst_total = RSTRING_LEN(self) * 8;
    VALUE v0, v1, v2, v3, v4;

    int n_pos = rb_scan_args(argc, argv, "23", &v0, &v1, &v2, &v3, &v4);

    if (n_pos == 2 && rb_obj_is_kind_of(v0, rb_cRange)) {
        /* bit_splice(range, str) */
        long beg, len;
        rb_range_beg_len(v0, &beg, &len, dst_total, 1);
        dst_bit_off = beg;
        dst_bit_len = len;
        str = v1;
        Check_Type(str, T_STRING);
        src_bit_off = 0;
        src_bit_len = dst_bit_len;
    }
    else if (n_pos == 3 && rb_obj_is_kind_of(v0, rb_cRange)) {
        /* bit_splice(range, str, str_range) */
        long beg, len;
        rb_range_beg_len(v0, &beg, &len, dst_total, 1);
        dst_bit_off = beg;
        dst_bit_len = len;
        str = v1;
        Check_Type(str, T_STRING);
        if (!rb_obj_is_kind_of(v2, rb_cRange)) {
            rb_raise(rb_eTypeError, "third argument must be a Range");
        }
        long src_total = RSTRING_LEN(str) * 8;
        rb_range_beg_len(v2, &beg, &len, src_total, 1);
        src_bit_off = beg;
        src_bit_len = len;
    }
    else if (n_pos == 3) {
        /* bit_splice(bit_index, bit_length, str) */
        if (!rb_integer_type_p(v0) || !rb_integer_type_p(v1)) {
            rb_raise(rb_eTypeError, "bit index and length must be integers");
        }
        dst_bit_off = integer_to_bit_idx(v0);
        dst_bit_len = integer_to_bit_idx(v1);
        if (dst_bit_off < 0) dst_bit_off += dst_total;

        /*
         * Integer source support was prototyped here, but it is intentionally
         * disabled in the current proposal to keep the public API limited to
         * String-to-String splicing.
         */
        if (rb_integer_type_p(v2)) {
            rb_raise(rb_eArgError,
                     "bit_splice source must be a String in the current proposal");
        }

        str = v2;
        Check_Type(str, T_STRING);
        src_bit_off = 0;
        src_bit_len = dst_bit_len;
    }
    else if (n_pos == 5) {
        /* bit_splice(bit_index, bit_length, str, str_bit_index, str_bit_length) */
        if (!rb_integer_type_p(v0) || !rb_integer_type_p(v1) ||
            !rb_integer_type_p(v3) || !rb_integer_type_p(v4)) {
            rb_raise(rb_eTypeError, "bit indices and lengths must be integers");
        }
        dst_bit_off = integer_to_bit_idx(v0);
        dst_bit_len = integer_to_bit_idx(v1);
        if (dst_bit_off < 0) dst_bit_off += dst_total;
        str = v2;
        Check_Type(str, T_STRING);
        long src_total = RSTRING_LEN(str) * 8;
        src_bit_off = integer_to_bit_idx(v3);
        src_bit_len = integer_to_bit_idx(v4);
        if (src_bit_off < 0) src_bit_off += src_total;
    }
    else {
        rb_raise(rb_eArgError,
                 "wrong number of arguments (given %d, expected 2, 3, or 5)", n_pos);
    }

    if (dst_bit_off < 0 || dst_bit_len < 0 || dst_bit_off + dst_bit_len > dst_total) {
        rb_raise(rb_eIndexError,
                 "bit_splice: destination range [%ld, %ld] out of bounds (total %ld bits)",
                 dst_bit_off, dst_bit_len, dst_total);
    }

    long src_total_bits = RSTRING_LEN(str) * 8;
    if (src_bit_off < 0 || src_bit_len < 0 || src_bit_off + src_bit_len > src_total_bits) {
        rb_raise(rb_eIndexError,
                 "bit_splice: source range [%ld, %ld] out of bounds (total %ld bits)",
                 src_bit_off, src_bit_len, src_total_bits);
    }

    if (dst_bit_len != src_bit_len) {
        rb_raise(rb_eArgError,
                 "bit_splice: destination length (%ld) must equal source length (%ld)",
                 dst_bit_len, src_bit_len);
    }

    if (dst_bit_len == 0) return self;

    /* Guard against self-aliasing: duplicate src before modifying self */
    VALUE src_str = (str == self) ? rb_str_dup(str) : str;

    rb_str_modify(self);

    unsigned char       *dst          = (unsigned char *)RSTRING_PTR(self);
    const unsigned char *src          = (const unsigned char *)RSTRING_PTR(src_str);
    long                 src_len_bytes = RSTRING_LEN(src_str);

    bit_copy_core(dst, dst_bit_off, src, src_len_bytes, src_bit_off, dst_bit_len);

    RB_GC_GUARD(src_str);
    return self;
}

/* Array#mask and Array#mask! --------------------------------------- */
/*
 * NOTE: Array#mask and Array#mask! are implemented here and fully tested,
 * but are NOT part of the current core proposal (see FUTURE_PROPOSAL_PLAN.md).
 */
/*
 * parse_mask_kwargs: extract bitmap, count_from:, and invert: from method arguments.
 *
 * Porting to Ruby Core:
 *   1. Keep this as a `static` helper in array.c — it is only called by
 *      ary_mask and ary_mask_bang, so no header declaration is needed.
 *   2. Rename to ary_mask_kwargs or similar to follow array.c conventions
 *      (static helpers in array.c use the `ary_` prefix, not `rb_ary_`.
 */
static void
parse_mask_kwargs(int argc, VALUE *argv, VALUE *bitmap_out,
                     int *msb_first_out, int *invert_out, int *is_integer_out)
{
    VALUE bitmap, opts;
    rb_scan_args(argc, argv, "1:", &bitmap, &opts);
    validate_option_hash(opts, SB_KW_COUNT_FROM | SB_KW_INVERT);

    int is_integer = rb_integer_type_p(bitmap);

    if (!is_integer) Check_Type(bitmap, T_STRING);

    int msb_first  = parse_count_from_opt(opts);
    int invert     = 0; /* default false */

    if (msb_first && is_integer) {
        rb_raise(rb_eArgError,
                 "count_from: :msb is not supported for Integer bitmap; "
                 "Integer bits are always LSB-first");
    }

    if (!NIL_P(opts)) {
        VALUE inv = rb_hash_aref(opts, sym_invert);
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
    VALUE bit = rb_funcall(n, id_bracket, 1, LONG2FIX(i));
    return RB_TEST(bit) ? 1 : 0;
}

static VALUE
rb_ary_mask(int argc, VALUE *argv, VALUE self)
{
    VALUE bitmap;
    int msb_first, invert, is_integer;
    parse_mask_kwargs(argc, argv, &bitmap, &msb_first, &invert, &is_integer);

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
        const unsigned char *bmp = (const unsigned char *)RSTRING_PTR(bitmap);
        long bmp_len    = RSTRING_LEN(bitmap);
        long needed     = (ary_len + 7) >> 3;
        if (needed > bmp_len)
            rb_raise(rb_eArgError,
                     "bitmap too short: need %ld bytes for %ld elements, got %ld",
                     needed, ary_len, bmp_len);

        if (msb_first) {
            for (long i = 0; i < ary_len; i++) {
                int bit = (bmp[i >> 3] >> (7 - (i & 7))) & 1;
                if (invert) bit = !bit;
                rb_ary_push(result, bit ? src[i] : Qnil);
            }
        }
        else {
            for (long i = 0; i < ary_len; i++) {
                int bit = (bmp[i >> 3] >> (i & 7)) & 1;
                if (invert) bit = !bit;
                rb_ary_push(result, bit ? src[i] : Qnil);
            }
        }
    }

    return result;
}

static VALUE
rb_ary_mask_bang(int argc, VALUE *argv, VALUE self)
{
    VALUE bitmap;
    int msb_first, invert, is_integer;
    parse_mask_kwargs(argc, argv, &bitmap, &msb_first, &invert, &is_integer);

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
        const unsigned char *bmp = (const unsigned char *)RSTRING_PTR(bitmap);
        long bmp_len    = RSTRING_LEN(bitmap);
        long needed     = (ary_len + 7) >> 3;
        if (needed > bmp_len)
            rb_raise(rb_eArgError,
                     "bitmap too short: need %ld bytes for %ld elements, got %ld",
                     needed, ary_len, bmp_len);

        if (msb_first) {
            for (long i = 0; i < ary_len; i++) {
                int bit = (bmp[i >> 3] >> (7 - (i & 7))) & 1;
                if (invert) bit = !bit;
                if (!bit) rb_ary_store(self, i, Qnil);
            }
        }
        else {
            for (long i = 0; i < ary_len; i++) {
                int bit = (bmp[i >> 3] >> (i & 7)) & 1;
                if (invert) bit = !bit;
                if (!bit) rb_ary_store(self, i, Qnil);
            }
        }
    }

    return self;
}

/* Init -------------------------------------------------------------------- */

void
Init_string_bits(void)
{
    id_bracket = rb_intern("[]");
    sym_scan_order  = ID2SYM(rb_intern("scan_order"));
    sym_count_from  = ID2SYM(rb_intern("count_from"));
    sym_field_order = ID2SYM(rb_intern("field_order"));
    sym_lsb         = ID2SYM(rb_intern("lsb"));
    sym_msb         = ID2SYM(rb_intern("msb"));
    sym_invert      = ID2SYM(rb_intern("invert"));

    rb_define_method(rb_cString, "bit_at",            rb_str_bit_at,           -1);
    rb_define_method(rb_cString, "bit_count",         rb_str_bit_count,         0);
    rb_define_method(rb_cString, "each_bit",          rb_str_each_bit,         -1);
    rb_define_method(rb_cString, "bits",              rb_str_bits,             -1);
    rb_define_method(rb_cString, "each_set_bit_offset", rb_str_each_set_bit_offset, -1);
    rb_define_method(rb_cString, "set_bit_offsets",   rb_str_set_bit_offsets,  -1);
    rb_define_method(rb_cString, "bit_slice",         rb_str_bit_slice,        -1);
    rb_define_method(rb_cString, "bit_splice",        rb_str_bit_splice,       -1);
    rb_define_method(rb_cString, "bit_run_count",     rb_str_bit_run_count,    -1);
    rb_define_method(rb_cString, "each_bit_run",      rb_str_each_bit_run,     -1);
    rb_define_method(rb_cString, "bit_runs",          rb_str_bit_runs,         -1);
    rb_define_method(rb_cString, "set_bit",           rb_str_set_bit,          -1);
    rb_define_method(rb_cString, "clear_bit",         rb_str_clear_bit,        -1);
    rb_define_method(rb_cString, "flip_bit",          rb_str_flip_bit,         -1);
    rb_define_method(rb_cString, "bit_not",           rb_str_bit_not,           0);
    rb_define_method(rb_cString, "bit_not!",          rb_str_bit_not_bang,      0);
    rb_define_method(rb_cString, "bit_and",           rb_str_bit_and,           1);
    rb_define_method(rb_cString, "bit_and!",          rb_str_bit_and_bang,      1);
    rb_define_method(rb_cString, "bit_or",            rb_str_bit_or,            1);
    rb_define_method(rb_cString, "bit_or!",           rb_str_bit_or_bang,       1);
    rb_define_method(rb_cString, "bit_xor",           rb_str_bit_xor,           1);
    rb_define_method(rb_cString, "bit_xor!",          rb_str_bit_xor_bang,      1);

    // These methods are defined here to avoid cluttering this file, but they are not part of the current core proposal (see FUTURE_PROPOSAL_PLAN.md).
    rb_define_method(rb_cString, "each_bit_field",    rb_str_each_bit_field,   -1);
    rb_define_method(rb_cString, "bit_fields",        rb_str_bit_fields,       -1);
    rb_define_method(rb_cArray,  "mask",              rb_ary_mask,             -1);
    rb_define_method(rb_cArray,  "mask!",             rb_ary_mask_bang,        -1);
}
