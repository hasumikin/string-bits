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

/* common functions --------------------------------------------------------- */

static inline int
get_bit(const char *ptr, long bit_index, int msb_first)
{
    long byte_index = bit_index / 8;
    int bit_offset = msb_first ? (7 - bit_index % 8) : (bit_index % 8);
    return (ptr[byte_index] >> bit_offset) & 1;
}

static inline int
test_bit(const char *ptr, long bit_index)
{
    return get_bit(ptr, bit_index, 0);
}

static long
check_bit_index(VALUE self, VALUE n)
{
    if (!RB_TYPE_P(n, T_FIXNUM)) {
        rb_raise(rb_eTypeError, "bit index must be an integer");
    }
    long idx = FIX2LONG(n);
    long size = RSTRING_LEN(self) * 8;
    if (idx < 0 || idx >= size) {
        rb_raise(rb_eIndexError, "bit index %ld out of range for %ld-bit string", idx, size);
    }
    return idx;
}

static int
parse_order(int argc, VALUE *argv)
{
    VALUE opts = Qnil;
    rb_scan_args(argc, argv, "0:", &opts);
    if (NIL_P(opts)) return 1;
    VALUE order = rb_hash_aref(opts, ID2SYM(rb_intern("order")));
    if (NIL_P(order) || order == ID2SYM(rb_intern("msb"))) return 1;
    if (order == ID2SYM(rb_intern("lsb"))) return 0;
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
    long idx, size;
    if (!RB_TYPE_P(n, T_FIXNUM)) {
        rb_raise(rb_eTypeError, "bit index must be an integer");
    }
    idx = FIX2LONG(n);
    if (idx < 0) {
        rb_raise(rb_eArgError, "bit index must be non-negative");
    }
    size = RSTRING_LEN(self) * 8;
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
            rb_yield(get_bit(str, i, 0) ? Qtrue : Qfalse);
        }
    }
    else {
        for (long i = 0; i < total_bits; i++) {
            rb_yield(get_bit(str, i, 0) ? Qtrue : Qfalse);
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
            VALUE bit = get_bit(str, i, 0) ? Qtrue : Qfalse;
            have_block ? rb_yield(bit) : rb_ary_push(ary, bit);
        }
    }
    else {
        for (long i = 0; i < total_bits; i++) {
            VALUE bit = get_bit(str, i, 0) ? Qtrue : Qfalse;
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
    const char *str = RSTRING_PTR(self);
    long total_bits = len * 8;

    if (msb_first) {
        for (long i = total_bits - 1; i >= 0; i--) {
            if (get_bit(str, i, 0)) rb_yield(LONG2FIX(i));
        }
    }
    else {
        for (long i = 0; i < total_bits; i++) {
            if (get_bit(str, i, 0)) rb_yield(LONG2FIX(i));
        }
    }

    return self;
}

static VALUE
rb_str_set_bit_positions(int argc, VALUE *argv, VALUE self)
{
    int msb_first = parse_order(argc, argv);
    long len = RSTRING_LEN(self);
    const char *str = RSTRING_PTR(self);
    long total_bits = len * 8;
    int have_block = rb_block_given_p();

    VALUE ary = have_block ? Qnil : rb_ary_new();

    if (msb_first) {
        for (long i = total_bits - 1; i >= 0; i--) {
            if (get_bit(str, i, 0)) {
                VALUE pos = LONG2FIX(i);
                have_block ? rb_yield(pos) : rb_ary_push(ary, pos);
            }
        }
    }
    else {
        for (long i = 0; i < total_bits; i++) {
            if (get_bit(str, i, 0)) {
                VALUE pos = LONG2FIX(i);
                have_block ? rb_yield(pos) : rb_ary_push(ary, pos);
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
    if (!RB_TYPE_P(bit_offset, T_FIXNUM) || !RB_TYPE_P(bit_length, T_FIXNUM)) {
        return Qnil;
    }

    long offset = FIX2LONG(bit_offset);
    long length = FIX2LONG(bit_length);

    if (offset < 0 || length < 0) return Qnil;

    long total_bits = RSTRING_LEN(self) * 8;
    if (offset > total_bits) return Qnil;

    long available = total_bits - offset;
    if (length > available) length = available;
    if (length == 0) return rb_str_new("", 0);

    long out_bytes = (length + 7) / 8;
    VALUE result = rb_str_buf_new(out_bytes);
    rb_str_resize(result, out_bytes);
    rb_enc_associate(result, rb_enc_get(self));
    char *dst = RSTRING_PTR(result);
    memset(dst, 0, out_bytes);

    const char *src = RSTRING_PTR(self);
    for (long i = 0; i < length; i++) {
        if (get_bit(src, offset + i, 0)) {
            dst[i / 8] |= (unsigned char)(1 << (i % 8));
        }
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
}
