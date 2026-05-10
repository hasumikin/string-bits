require_relative "test_helper"

class TestBitCount < Minitest::Test
  def test_empty_string
    assert_equal 0, "".bit_count
  end

  def test_all_zeros
    assert_equal 0, "\x00\x00\x00".bit_count
  end

  def test_all_ones
    assert_equal 8,  "\xFF".bit_count
    assert_equal 24, "\xFF\xFF\xFF".bit_count
  end

  def test_single_byte
    assert_equal 4, "\xAA".bit_count  # 0b10101010
    assert_equal 4, "\x0F".bit_count  # 0b00001111
    assert_equal 1, "\x01".bit_count
    assert_equal 1, "\x80".bit_count
  end

  def test_multi_byte
    # 0xAA=4 bits, 0xCC=4 bits
    assert_equal 8, [0xAA, 0xCC].pack('C*').bit_count
  end

  def test_matches_each_bit_count
    data = [0b10110111, 0b00101101, 0b11000001].pack('C*')
    expected = data.each_bit.count { |b| b }
    assert_equal expected, data.bit_count
  end

  def test_bit_count_is_byte_size_times_8_for_all_ones
    data = "\xFF" * 10
    assert_equal 80, data.bit_count
  end
end
