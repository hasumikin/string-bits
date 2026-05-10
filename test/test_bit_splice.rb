# frozen_string_literal: true

require_relative "test_helper"

class TestBitSplice < Minitest::Test
  # --- return value ---

  def test_returns_self
    s = +"\xFF\x00"
    assert_same s, s.bit_splice(0, 8, "\x00")
  end

  # --- 3-arg integer form: bit_splice(bit_index, bit_length, str) ---

  def test_write_full_byte_aligned
    s = +"\xFF\xFF"
    s.bit_splice(0, 8, "\x00")
    assert_equal "\x00\xFF", s
  end

  def test_write_full_second_byte
    s = +"\xFF\xFF"
    s.bit_splice(8, 8, "\x00")
    assert_equal "\xFF\x00", s
  end

  def test_write_partial_low_nibble
    # 0xF0 = 11110000; bits 0-3 are already 0; write 4 zero bits from "\x00"
    s = +"\xF0"
    s.bit_splice(0, 4, "\x00")
    assert_equal "\xF0", s
  end

  def test_write_partial_high_nibble
    # Write 4 ones (bits 0-3 of "\xFF") into bits 4-7 of s
    s = +"\x00"
    s.bit_splice(4, 4, "\xFF")
    assert_equal "\xF0", s
  end

  def test_write_unaligned_middle
    # Take bits 0-3 of "\xFF" (=1111) and place them at bits 3-6 of s
    s = +"\x00\x00"
    s.bit_splice(3, 4, "\xFF")
    # bits 3-6 of byte 0 become 1 => 0b01111000 = 0x78
    assert_equal "\x78\x00", s
  end

  def test_write_cross_byte_unaligned
    # Write 8 bits starting at bit 4 (spans two bytes)
    s = +"\x00\x00"
    s.bit_splice(4, 8, "\xFF")
    # bits 4-7 of byte 0 = 1111, bits 0-3 of byte 1 = 1111
    assert_equal "\xF0\x0F", s
  end

  # --- 5-arg integer form: bit_splice(bit_index, bit_length, str, src_bit_index, src_bit_length) ---

  def test_five_arg_basic
    s = +"\x00\x00"
    src = "\xFF\x00"
    # Copy bits 8-15 of src (which are 0x00) into bits 0-7 of s
    s.bit_splice(0, 8, src, 8, 8)
    assert_equal "\x00\x00", s
  end

  def test_five_arg_partial_source
    s = +"\x00"
    src = "\xAA"  # 10101010: bits 0,2,4,6 = 0; bits 1,3,5,7 = 1
    # Copy bits 4-7 of src (value = 0b1010 >> 4 = 0x0A low nibble) into bits 0-3 of s
    s.bit_splice(0, 4, src, 4, 4)
    # src bits 4-7 of 0xAA = 1010 -> stored in bits 0-3 of s -> s = 0x0A
    assert_equal "\x0A", s
  end

  def test_five_arg_unaligned_source_and_dest
    s = +"\x00\x00"
    src = "\xFF\xFF"
    # Copy 4 bits from src bit 2 into s bit 3
    s.bit_splice(3, 4, src, 2, 4)
    # src bits 2-5 of 0xFF = 1111; placed at bits 3-6 of s[0]
    assert_equal "\x78\x00", s
  end

  # --- 2-arg range form: bit_splice(range, str) ---

  def test_range_form_full_byte
    s = +"\xFF\xFF"
    s.bit_splice(0..7, "\x00")
    assert_equal "\x00\xFF", s
  end

  def test_range_form_exclusive
    s = +"\xFF\xFF"
    s.bit_splice(0...8, "\x00")
    assert_equal "\x00\xFF", s
  end

  def test_range_form_partial
    # bits 0-3 of 0xF0 are already 0; range form reads 4 bits from "\x00"
    s = +"\xF0"
    s.bit_splice(0..3, "\x00")
    assert_equal "\xF0", s
  end

  def test_range_form_negative_index
    s = +"\xFF\xFF"
    s.bit_splice(-8..-1, "\x00")
    assert_equal "\xFF\x00", s
  end

  # --- 3-arg range form: bit_splice(range, str, str_range) ---

  def test_range_range_form
    s = +"\x00\x00"
    src = "\xAA\xFF"
    # Copy bits 8..15 of src (0xFF) into bits 0..7 of s
    s.bit_splice(0..7, src, 8..15)
    assert_equal "\xFF\x00", s
  end

  # --- negative index ---

  def test_negative_bit_index
    s = +"\xFF\xFF"
    s.bit_splice(-8, 8, "\x00")
    assert_equal "\xFF\x00", s
  end

  # --- zero-length is a no-op ---

  def test_zero_length_noop
    s = +"\xFF\xFF"
    s.bit_splice(0, 0, "")
    assert_equal "\xFF\xFF", s
  end

  # --- roundtrip with bit_slice ---

  def test_roundtrip_aligned
    original = "\xAA\xCC\xFF\x00"
    slice    = original.bit_slice(8, 8)  # second byte: 0xCC
    target   = "\x00" * 4
    target.bit_splice(8, 8, slice)
    assert_equal slice, target.bit_slice(8, 8)
  end

  def test_roundtrip_unaligned
    data = "\xAB\xCD\xEF"
    # Extract 12 bits starting at bit 4
    slice = data.bit_slice(4, 12)
    # Write them back into a zero buffer at bit 4
    buf = "\x00" * 3
    buf.bit_splice(4, 12, slice)
    assert_equal slice, buf.bit_slice(4, 12)
  end

  def test_roundtrip_randomized
    srand(0)
    data = Random.bytes(16)
    [0, 1, 3, 7, 8, 13].each do |off|
      [1, 4, 7, 8, 12, 16, 32].each do |len|
        next if off + len > data.bytesize * 8
        slice = data.bit_slice(off, len)
        buf = ("\x00" * data.bytesize).b
        buf.bit_splice(off, len, slice)
        assert_equal slice, buf.bit_slice(off, len),
                     "roundtrip failed for off=#{off} len=#{len}"
      end
    end
  end

  # --- self-splice (aliasing) ---

  def test_self_splice_non_overlapping
    s = +"\xAA\x00"
    # Copy first byte into second byte position
    s.bit_splice(8, 8, s, 0, 8)
    assert_equal "\xAA\xAA", s
  end

  def test_self_splice_overlapping
    s = +"\xAA\xFF"
    # Copy bits 0-7 over bits 4-11 (overlapping)
    s.bit_splice(4, 8, s, 0, 8)
    # src (copy of s before modify) = 0xAA 0xFF; src bits 0-7 = 0xAA = 10101010
    # dst bit 4..11:
    #   bits 4-7 of dst[0]: src bits 0-3 = 1010 -> high nibble becomes 0xA
    #   dst[0] was 0xAA; low nibble 1010 stays, high nibble becomes 1010 -> 0xAA
    #   bits 0-3 of dst[1]: src bits 4-7 = 1010 -> low nibble becomes 0xA
    #   dst[1] was 0xFF; high nibble 1111 stays, low nibble becomes 1010 -> 0xFA
    assert_equal "\xAA\xFA", s
  end

  # --- error cases ---

  def test_wrong_argc
    s = +"\xFF"
    assert_raises(ArgumentError) { s.bit_splice(0, 8) }
    assert_raises(ArgumentError) { s.bit_splice(0, 8, "\x00", 0) }
    assert_raises(ArgumentError) { s.bit_splice(0, 8, "\x00", 0, 4, :extra) }
  end

  def test_type_error_non_integer_index
    s = +"\xFF"
    assert_raises(TypeError) { s.bit_splice("0", 8, "\x00") }
    assert_raises(TypeError) { s.bit_splice(0, "8", "\x00") }
  end

  def test_type_error_non_string_src
    s = +"\xFF"
    assert_raises(TypeError) { s.bit_splice(0, 8, 42) }
  end

  def test_length_mismatch_raises
    s = +"\xFF\xFF"
    # 5-arg form: src and dst bit lengths must match
    assert_raises(ArgumentError) { s.bit_splice(0, 8, "\xFF\xFF", 0, 4) }
    # 3-arg range form with explicit str_range of different length
    assert_raises(ArgumentError) { s.bit_splice(0..7, "\xFF\xFF", 8..11) }
  end

  def test_dst_out_of_range_raises
    s = +"\xFF"
    assert_raises(IndexError) { s.bit_splice(0, 16, "\xFF\xFF") }
    assert_raises(IndexError) { s.bit_splice(9, 1, "\x00") }
  end

  def test_src_out_of_range_raises
    s = +"\xFF"
    assert_raises(IndexError) { s.bit_splice(0, 8, "\xFF", 1, 8) }
  end

  def test_frozen_string_raises
    assert_raises(FrozenError) { "x".freeze.bit_splice(0, 8, "y") }
  end

  def test_order
    # LSB order (default)
    s = +"\x00\x00"
    s.bit_splice(0, 8, "\xFF", order: :lsb)
    assert_equal "\xFF\x00", s

    # MSB order: 0 is the last bit (15 in LSB)
    s = +"\x00\x00"
    s.bit_splice(0, 8, "\xFF", order: :msb)
    assert_equal "\x00\xFF", s

    # 5-arg form with order: :msb
    # Copy 4 bits from src (Logical 0..3 in MSB of src) to s (Logical 0..3 in MSB of s)
    # src = "\xAA\x00" (0b10101010 0x00) -> Logical 0..3 in MSB are bits 15,14,13,12 which are 0.
    # src = "\x00\xAA" (0x00 0b10101010) -> Logical 0..3 in MSB are bits 15,14,13,12 which are bits 7,6,5,4 of byte[1] = 1010.
    s = +"\x00\x00"
    src = "\x00\xAA"
    s.bit_splice(0, 4, src, 0, 4, order: :msb)
    # Logical 0..3 in MSB of s -> Physical 15, 14, 13, 12 (bits 7,6,5,4 of s[1])
    # Should become 1010 -> 0b10100000 = 0xA0
    assert_equal "\x00\xA0", s
  end

  def test_order_range
    s = +"\x00\x00"
    # MSB 0..7 is physical 15..8 (byte[1])
    s.bit_splice(0..7, "\xFF", order: :msb)
    assert_equal "\x00\xFF", s
  end

  def test_order_range_source
    s = +"\x00\x00"
    src = "\x00\xFF"
    # Copy MSB 0..7 of src (byte[1]=0xFF) to MSB 8..15 of s (byte[0])
    s.bit_splice(8..15, src, 0..7, order: :msb)
    assert_equal "\xFF\x00", s
  end

  def test_order_negative_index
    s = +"\x00\x00"
    # -1 in MSB order is logical 15 (last bit), which is physical 0 (byte[0] bit 0)
    s.bit_splice(-1, 1, "\xFF", order: :msb)
    assert_equal "\x01\x00", s

    s = +"\x00\x00"
    # -8 in MSB order is logical 8, which is physical 7 (byte[0] bit 7)
    s.bit_splice(-8, 1, "\xFF", order: :msb)
    assert_equal "\x80\x00", s
  end
end
