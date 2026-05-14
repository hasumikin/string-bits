require_relative "test_helper"

class TestSetBitOffsets < Minitest::Test
  def setup
    @data = [0b10101010, 0b11001100].pack('C*')
  end

  def test_returns_array_without_block
    assert_instance_of Array, @data.set_bit_offsets
    assert_instance_of Array, @data.set_bit_offsets(count_from: :lsb)
  end

  def test_array_content_lsb
    assert_equal [1, 3, 5, 7, 10, 11, 14, 15], @data.set_bit_offsets
  end

  def test_array_content_msb
    assert_equal [0, 2, 4, 6, 8, 9, 12, 13], @data.set_bit_offsets(count_from: :msb)
  end

  def test_with_block_yields_same_as_each_set_bit
    collected_set  = []
    collected_each = []
    @data.set_bit_offsets { |n| collected_set  << n }
    @data.each_set_bit_offset { |n| collected_each << n }
    assert_equal collected_each, collected_set
  end

  def test_with_block_returns_self
    assert_same @data, @data.set_bit_offsets {}
    assert_same @data, @data.set_bit_offsets(count_from: :lsb) {}
  end

  def test_set_bit_offsets_equals_each_set_bit_to_a
    assert_equal @data.each_set_bit_offset.to_a,              @data.set_bit_offsets
    assert_equal @data.each_set_bit_offset(count_from: :msb).to_a, @data.set_bit_offsets(count_from: :msb)
  end

  def test_empty_string
    assert_equal [], "".set_bit_offsets
  end
end
