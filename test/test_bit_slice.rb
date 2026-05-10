require_relative "test_helper"

class TestBitSlice < Minitest::Test
  def test_byte_aligned_full
    assert_equal "\xFF\xAA", "\xFF\xAA".bit_slice(0, 16)
  end

  def test_byte_aligned_first_byte
    assert_equal "\xFF", "\xFF\xAA".bit_slice(0, 8)
  end

  def test_byte_aligned_second_byte
    assert_equal "\xAA", "\xFF\xAA".bit_slice(8, 8)
  end

  def test_crossing_byte_boundary
    # bits 4-11: bits 4-7 from 0xFF, bits 8-11 from 0xAA=0b10101010
    # result bits 0-3 = 1,1,1,1; bits 4-7 = 0,1,0,1 => 0b10101111 = 0xAF
    assert_equal "\xAF", "\xFF\xAA".bit_slice(4, 8)
  end

  def test_length_zero_returns_empty_string
    assert_equal "", "\xFF".bit_slice(0, 0)
  end

  def test_offset_at_total_bits_returns_empty_string
    assert_equal "", "\xFF".bit_slice(8, 0)
  end

  def test_offset_beyond_range_returns_nil
    assert_nil "\xFF".bit_slice(9, 1)
  end

  def test_negative_offset_returns_nil
    assert_nil "\xFF".bit_slice(-1, 4)
  end

  def test_negative_length_returns_nil
    assert_nil "\xFF".bit_slice(0, -1)
  end

  def test_length_clamped_to_available_bits
    # bits 12-15 of "\xFF\xAA": only 4 bits; 0xAA bits 4-7 = 0,1,0,1 => 0b00001010 = 0x0A
    assert_equal "\x0A", "\xFF\xAA".bit_slice(12, 8)
  end

  def test_sub_byte_extraction
    # first 4 bits of "\xAA" (0b10101010): bits 0,1,2,3 = 0,1,0,1 => 0b00001010 = 0x0A
    assert_equal "\x0A", "\xAA".bit_slice(0, 4)
  end

  def test_returns_string_instance
    assert_instance_of String, "\xFF".bit_slice(0, 4)
  end

  def test_roundtrip_bits_match_bit_at
    data = "\xAA\xCC\xFF"
    result = data.bit_slice(4, 12)
    12.times do |i|
      assert_equal data.bit_at(4 + i), result.bit_at(i), "bit #{i} mismatch"
    end
  end

  def test_does_not_modify_original
    data = +"\xFF\xAA"
    data.bit_slice(0, 8)
    assert_equal "\xFF\xAA", data
  end

  def test_empty_string_offset_zero_returns_empty
    assert_equal "", "".bit_slice(0, 0)
  end

  def test_non_integer_offset_returns_nil
    assert_nil "\xFF".bit_slice("0", 4)
    assert_nil "\xFF".bit_slice(0.5, 4)
    assert_nil "\xFF".bit_slice(nil, 4)
    assert_nil "\xFF".bit_slice(:foo, 4)
  end

  def test_non_integer_length_returns_nil
    assert_nil "\xFF".bit_slice(0, "4")
    assert_nil "\xFF".bit_slice(0, 0.5)
    assert_nil "\xFF".bit_slice(0, nil)
    assert_nil "\xFF".bit_slice(0, :foo)
  end

  def test_bignum_offset_returns_nil
    assert_nil "\xFF".bit_slice(2**62, 4)
    assert_nil "\xFF".bit_slice(2**63, 4)
  end

  def test_bignum_length_returns_nil
    assert_nil "\xFF".bit_slice(0, 2**63)
  end

  def test_order
    # "\xFF\xAA": byte[0]=0xFF, byte[1]=0xAA (0b10101010)
    data = "\xFF\xAA"

    # LSB order (default)
    assert_equal "\xFF", data.bit_slice(0, 8, order: :lsb)
    assert_equal "\xAA", data.bit_slice(8, 8, order: :lsb)

    # MSB order: 0 is the last bit (15 in LSB)
    # bit_slice(0, 8, order: :msb) should extract bits from the "end" from a MSB perspective.
    # Logic: Logical 0..7 in MSB -> Physical 15, 14, 13, 12, 11, 10, 9, 8
    # These are bits of byte[1].
    assert_equal "\xAA", data.bit_slice(0, 8, order: :msb)

    # bit_slice(8, 8, order: :msb) -> Logical 8..15 in MSB -> Physical 7..0
    assert_equal "\xFF", data.bit_slice(8, 8, order: :msb)

    # Crossing boundary in MSB
    # bit_slice(4, 8, order: :msb) -> Logical 4..11 in MSB
    # Logical 4 -> Physical 11
    # Logical 11 -> Physical 4
    # Physical bits 4..11: bits 4..7 of byte[0] (0xF) and bits 0..3 of byte[1] (0xA)
    # Result should be 0b10101111 = 0xAF (LSB-first String)
    assert_equal "\xAF", data.bit_slice(4, 8, order: :msb)
  end

  def test_order_zero_length
    assert_equal "", "\xFF".bit_slice(0, 0, order: :msb)
    assert_equal "", "\xFF".bit_slice(8, 0, order: :msb)
  end

  def test_order_negative_offset_returns_nil
    assert_nil "\xFF".bit_slice(-1, 4, order: :msb)
  end
end
