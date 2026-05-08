/*
 * Standalone test for the _MSC_VER + __AVX__ code path in string_bits.c.
 *
 * Compile with MSVC: cl /arch:AVX /O2 /Fe:avx_test.exe test\msvc_avx_test.c
 * /arch:AVX defines __AVX__ which activates the __popcnt64 intrinsic path.
 */
#include <intrin.h>
#include <stdio.h>

#if !defined(_MSC_VER)
#  error This file must be compiled with MSVC (cl.exe)
#endif
#if !defined(__AVX__)
#  error Compile with /arch:AVX to enable __AVX__ and test the target code path
#endif

static const struct {
    unsigned long long input;
    unsigned int expected;
} cases[] = {
    { 0x0000000000000000ULL,  0 },
    { 0xFFFFFFFFFFFFFFFFULL, 64 },
    { 0xAAAAAAAAAAAAAAAAULL, 32 },
    { 0x5555555555555555ULL, 32 },
    { 0x0000000000000001ULL,  1 },
    { 0x8000000000000000ULL,  1 },
    { 0x0F0F0F0F0F0F0F0FULL, 32 },
    { 0x00000000FFFFFFFFULL, 32 },
    { 0x0102040810204080ULL,  8 },
};

int main(void)
{
    int n = (int)(sizeof(cases) / sizeof(cases[0]));
    int failed = 0;
    for (int i = 0; i < n; i++) {
        unsigned int got = (unsigned int)__popcnt64(cases[i].input);
        if (got != cases[i].expected) {
            fprintf(stderr, "FAIL: __popcnt64(0x%016llx) = %u, want %u\n",
                    cases[i].input, got, cases[i].expected);
            failed++;
        }
    }
    if (!failed)
        printf("OK: all %d __popcnt64 cases passed\n", n);
    return failed ? 1 : 0;
}
