require_relative "test_helper"

class TestBits < Minitest::Test
  def test_returns_array_without_block
    assert_instance_of Array, "\xAA".bits
    assert_instance_of Array, "\xAA".bits(order: :lsb)
  end

  def test_array_content_msb
    assert_equal [true, false, true, false, true, false, true, false], "\xAA".bits
  end

  def test_array_content_lsb
    assert_equal [false, true, false, true, false, true, false, true], "\xAA".bits(order: :lsb)
  end

  def test_with_block_yields_same_as_each_bit
    collected_bits = []
    collected_each = []
    "\xAA\xCC".bits     { |b| collected_bits << b }
    "\xAA\xCC".each_bit { |b| collected_each << b }
    assert_equal collected_each, collected_bits
  end

  def test_with_block_returns_self
    s = "\xAA"
    assert_same s, s.bits {}
    assert_same s, s.bits(order: :lsb) {}
  end

  def test_bits_equals_each_bit_to_a
    data = [0b10101010, 0b11001100].pack('C*')
    assert_equal data.each_bit.to_a,              data.bits
    assert_equal data.each_bit(order: :lsb).to_a, data.bits(order: :lsb)
  end

  def test_empty_string
    assert_equal [], "".bits
  end
end
