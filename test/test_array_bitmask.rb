require_relative "test_helper"

class TestArrayBitmask < Minitest::Test
  # 0b11010000 (MSB-first): elements 0,1,3 valid, element 2 nil
  BITMAP_MSB = "\xD0".b  # 0b11010000
  DATA = [1, 2, 3, 4]

  # 0b00001101 (LSB-first): bit0=1, bit1=0, bit2=1, bit3=1 -> elements 0,2,3 valid
  BITMAP_LSB = "\x0D".b  # 0b00001101

  def test_bitmask_lsb_default
    assert_equal [1, nil, 3, 4], DATA.bitmask(BITMAP_LSB)
  end

  def test_bitmask_msb_explicit
    assert_equal [1, 2, nil, 4], DATA.bitmask(BITMAP_MSB, order: :msb)
  end

  def test_bitmask_lsb_explicit
    assert_equal [1, nil, 3, 4], DATA.bitmask(BITMAP_LSB, order: :lsb)
  end

  def test_bitmask_operation_not
    # :not inverts: where bit=0 -> keep, bit=1 -> nil
    # BITMAP_LSB bits: 0=1,1=0,2=1,3=1 -> inverted: 0=0,1=1,2=0,3=0
    assert_equal [nil, 2, nil, nil], DATA.bitmask(BITMAP_LSB, order: :lsb, invert: true)
  end

  def test_bitmask_returns_new_array
    result = DATA.bitmask(BITMAP_LSB)
    refute_same DATA, result
    assert_equal [1, 2, 3, 4], DATA
  end

  def test_bitmask_bang_modifies_in_place
    ary = [1, 2, 3, 4]
    result = ary.bitmask!(BITMAP_MSB, order: :msb)
    assert_same ary, result
    assert_equal [1, 2, nil, 4], ary
  end

  def test_bitmask_bang_lsb
    ary = [1, 2, 3, 4]
    ary.bitmask!(BITMAP_LSB)
    assert_equal [1, nil, 3, 4], ary
  end

  def test_bitmask_bitmap_too_short
    assert_raises(ArgumentError) { [1, 2, 3, 4, 5, 6, 7, 8, 9].bitmask("\xFF") }
  end

  def test_bitmask_all_valid
    assert_equal [1, 2, 3, 4], DATA.bitmask("\xFF".b)
  end

  def test_bitmask_all_nil
    assert_equal [nil, nil, nil, nil], DATA.bitmask("\x00".b)
  end

  def test_bitmask_multi_byte
    data = (1..16).to_a
    bitmap = "\xFF\x00".b  # first 8 valid, next 8 nil
    result = data.bitmask(bitmap)
    assert_equal((1..8).to_a + [nil] * 8, result)
  end

  # Integer bitmap tests

  # 0b1101 (Integer, always LSB-first): bit0=1, bit1=0, bit2=1, bit3=1 -> elements 0,2,3 valid
  INT_BITMAP = 0b1101

  def test_bitmask_integer_basic
    assert_equal [1, nil, 3, 4], DATA.bitmask(INT_BITMAP)
  end

  def test_bitmask_integer_all_valid
    assert_equal [1, 2, 3, 4], DATA.bitmask(0b1111)
  end

  def test_bitmask_integer_all_nil
    assert_equal [nil, nil, nil, nil], DATA.bitmask(0)
  end

  def test_bitmask_integer_invert
    # bits 0=1,1=0,2=1,3=1 -> inverted: 0=0,1=1,2=0,3=0
    assert_equal [nil, 2, nil, nil], DATA.bitmask(INT_BITMAP, invert: true)
  end

  def test_bitmask_integer_beyond_width_is_zero
    # integer 0b11 has only 2 set bits; elements 2,3 should be nil
    assert_equal [1, 2, nil, nil], DATA.bitmask(0b11)
  end

  def test_bitmask_integer_order_msb_raises
    assert_raises(ArgumentError) { DATA.bitmask(INT_BITMAP, order: :msb) }
  end

  def test_bitmask_integer_negative_raises
    assert_raises(ArgumentError) { DATA.bitmask(-1) }
  end

  def test_bitmask_integer_bignum
    # Bignum: all 16 bits set -> all elements valid
    data = (1..16).to_a
    assert_equal data, data.bitmask((1 << 16) - 1)
  end

  def test_bitmask_bang_integer
    ary = [1, 2, 3, 4]
    ary.bitmask!(INT_BITMAP)
    assert_equal [1, nil, 3, 4], ary
  end

  def test_bitmask_integer_matches_string_bitmap
    # Integer 0b00001101 == "\x0D".b (LSB-first)
    assert_equal DATA.bitmask(BITMAP_LSB), DATA.bitmask(0b00001101)
  end
end
