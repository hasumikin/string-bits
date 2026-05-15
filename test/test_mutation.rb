require_relative "test_helper"

class TestSetClearFlipBit < Minitest::Test
  def test_set_bit_on_zero_byte
    s = +"\x00"
    s.set_bit(0)
    assert_equal "\x01", s
    s.set_bit(7)
    assert_equal "\x81", s
  end

  def test_set_bit_is_idempotent
    s = +"\xFF"
    s.set_bit(3)
    assert_equal "\xFF", s
  end

  def test_set_bit_only_affects_target_bit
    s = +"\x00\x00"
    s.set_bit(8)  # LSB of byte[1]
    assert_equal "\x00\x01", s
  end

  def test_set_bit_returns_self
    s = +"\x00"
    assert_same s, s.set_bit(0)
  end

  def test_set_bit_range_inclusive
    s = +"\x00\x00"
    s.set_bit(0..7)
    assert_equal "\xFF\x00", s
  end

  def test_set_bit_range_exclusive
    s = +"\x00\x00"
    s.set_bit(0...7)
    assert_equal "\x7F\x00", s
  end

  def test_set_bit_range_endless
    s = +"\x00\x00"
    s.set_bit(8..)
    assert_equal "\x00\xFF", s
  end

  def test_set_bit_range_beginless
    s = +"\x00\x00"
    s.set_bit(..7)
    assert_equal "\xFF\x00", s
  end

  def test_set_bit_range_nil_nil
    s = +"\x00\x00"
    s.set_bit(nil..nil)
    assert_equal "\xFF\xFF", s
  end

  def test_set_bit_out_of_range_raises
    s = +"\x00"
    assert_raises(IndexError) { s.dup.set_bit(8) }
    assert_raises(IndexError) { s.dup.set_bit(-1) }
  end

  def test_clear_bit
    s = +"\xFF"
    s.clear_bit(0)
    assert_equal "\xFE", s
    s.clear_bit(7)
    assert_equal "\x7E", s
  end

  def test_clear_bit_is_idempotent
    s = +"\x00"
    s.clear_bit(3)
    assert_equal "\x00", s
  end

  def test_clear_bit_only_affects_target_bit
    s = +"\xFF\xFF"
    s.clear_bit(8)  # LSB of byte[1]
    assert_equal "\xFF\xFE", s
  end

  def test_clear_bit_returns_self
    s = +"\xFF"
    assert_same s, s.clear_bit(0)
  end

  def test_clear_bit_range
    s = +"\xFF\xFF"
    s.clear_bit(4..11)
    assert_equal "\x0F\xF0", s
  end

  def test_clear_bit_out_of_range_raises
    s = +"\xFF"
    assert_raises(IndexError) { s.dup.clear_bit(8) }
  end

  def test_flip_bit_zero_to_one
    s = +"\x00"
    s.flip_bit(3)
    assert_equal "\x08", s
  end

  def test_flip_bit_one_to_zero
    s = +"\xFF"
    s.flip_bit(3)
    assert_equal "\xF7", s
  end

  def test_flip_bit_twice_is_identity
    s = +"\xAA"
    original = s.dup
    s.flip_bit(0).flip_bit(0)
    assert_equal original, s
  end

  def test_flip_bit_returns_self
    s = +"\x00"
    assert_same s, s.flip_bit(0)
  end

  def test_flip_bit_range
    s = +"\x00\x00"
    s.flip_bit(4..11)
    assert_equal "\xF0\x0F", s
  end

  def test_set_clear_roundtrip_consistent_with_bit_at
    s = "\x00" * 2
    [0, 1, 7, 8, 15].each do |n|
      s.set_bit(n)
      assert_equal true, s.bit_at(n), "bit_at(#{n}) should be true after set_bit"
      s.clear_bit(n)
      assert_equal false, s.bit_at(n), "bit_at(#{n}) should be false after clear_bit"
    end
  end

  def test_build_arrow_bitmap_incrementally
    # Simulate building a validity bitmap: elements 0,2,4 are valid
    bitmap = +"\x00"
    [0, 2, 4].each { |i| bitmap.set_bit(i) }
    assert_equal true,  bitmap.bit_at(0)
    assert_equal false, bitmap.bit_at(1)
    assert_equal true,  bitmap.bit_at(2)
    assert_equal false, bitmap.bit_at(3)
    assert_equal true,  bitmap.bit_at(4)
    assert_equal 3, bitmap.bit_count
  end

  def test_set_bit_non_integer_raises_type_error
    s = +"\xFF"
    assert_raises(TypeError) { s.set_bit("0") }
    assert_raises(TypeError) { s.set_bit(0.5) }
    assert_raises(TypeError) { s.set_bit(nil) }
    assert_raises(TypeError) { s.set_bit(:foo) }
  end

  def test_clear_bit_non_integer_raises_type_error
    s = +"\xFF"
    assert_raises(TypeError) { s.clear_bit("0") }
    assert_raises(TypeError) { s.clear_bit(0.5) }
    assert_raises(TypeError) { s.clear_bit(nil) }
    assert_raises(TypeError) { s.clear_bit(:foo) }
  end

  def test_flip_bit_non_integer_raises_type_error
    s = +"\xFF"
    assert_raises(TypeError) { s.flip_bit("0") }
    assert_raises(TypeError) { s.flip_bit(0.5) }
    assert_raises(TypeError) { s.flip_bit(nil) }
    assert_raises(TypeError) { s.flip_bit(:foo) }
  end

  def test_set_bit_bignum_raises_argument_error
    # Integers outside the supported index range raise ArgumentError.
    assert_raises(ArgumentError) { (+"\xFF").set_bit(2**62) }
    assert_raises(ArgumentError) { (+"\xFF").set_bit(2**63) }
    assert_raises(ArgumentError) { (+"\xFF").set_bit(2**100) }
  end

  def test_clear_bit_bignum_raises_argument_error
    assert_raises(ArgumentError) { (+"\xFF").clear_bit(2**62) }
    assert_raises(ArgumentError) { (+"\xFF").clear_bit(2**63) }
    assert_raises(ArgumentError) { (+"\xFF").clear_bit(2**100) }
  end

  def test_flip_bit_bignum_raises_argument_error
    assert_raises(ArgumentError) { (+"\xFF").flip_bit(2**100) }
  end

  def test_lsb_first
    # "\x00\x00"
    s = +"\x00\x00"

    # set_bit with lsb_first: false (byte order preserved, numbering reversed within each byte)
    s.set_bit(0, lsb_first: false) # Physical 7 (bit 7 of s[0])
    assert_equal "\x80\x00", s

    s.set_bit(8, lsb_first: false) # Physical 15 (bit 7 of s[1])
    assert_equal "\x80\x80", s

    # clear_bit with lsb_first: false
    s.clear_bit(0, lsb_first: false)
    assert_equal "\x00\x80", s

    # flip_bit with lsb_first: false
    s.flip_bit(15, lsb_first: false) # Physical 8 (bit 0 of s[1])
    assert_equal "\x00\x81", s
  end

  def test_lsb_first_false_range_uses_logical_positions
    s = +"\x00\x00"
    s.set_bit(6..9, lsb_first: false)
    assert_equal "\x03\xC0", s
  end

  def test_empty_range_is_noop
    s = +"\x00"
    assert_same s, s.set_bit(8..)
    assert_equal "\x00", s
  end

  def test_out_of_range_range_raises_index_error
    assert_raises(IndexError) { (+"\x00").set_bit(9..) }
    assert_raises(IndexError) { (+"\x00").clear_bit(9..10) }
    assert_raises(IndexError) { (+"\x00").flip_bit(-9..-1) }
  end

  def test_range_with_end_past_total_raises_index_error
    # Explicit end past total must raise (no silent clipping).
    assert_raises(IndexError) { (+"\x00").set_bit(0..100) }
    assert_raises(IndexError) { (+"\x00").set_bit(8..15) }
    assert_raises(IndexError) { (+"\x00").set_bit(8..8) }
    assert_raises(IndexError) { (+"\x00").clear_bit(0..100) }
    assert_raises(IndexError) { (+"\x00").flip_bit(0..100) }
  end

  def test_range_on_empty_string
    # Non-empty range on an empty string is out-of-range.
    assert_raises(IndexError) { (+"").set_bit(0..7) }
    # Empty range on an empty string is a no-op.
    s = +""
    assert_same s, s.set_bit(0...0)
    assert_equal "", s
  end

  def test_range_bignum_raises
    assert_raises(IndexError) { (+"\x00").set_bit((2**62)..(2**62 + 4)) }
  end

  def test_range_exclusive_endless
    s = +"\x00"
    s.set_bit(0...)
    assert_equal "\xFF", s
  end

  def test_range_negative_endpoints
    s = +"\x00"
    s.set_bit(..-1)
    assert_equal "\xFF", s

    s = +"\x00"
    s.set_bit(-1..-1)
    assert_equal "\x80", s
  end

  def test_range_lsb_first_false_end_past_total_raises
    assert_raises(IndexError) { (+"\x00").set_bit(0..100, lsb_first: false) }
  end

  def test_lsb_first_negative_raises_index_error
    assert_raises(IndexError) { (+"\x00").set_bit(-1, lsb_first: false) }
    assert_raises(IndexError) { (+"\xFF").clear_bit(-1, lsb_first: false) }
    assert_raises(IndexError) { (+"\x00").flip_bit(-1, lsb_first: false) }
  end
end
