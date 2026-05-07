require_relative "test_helper"

class TestEachSetBit < Minitest::Test
  def setup
    @data = [0b10101010, 0b11001100].pack('C*')
  end

  def test_msb_positions
    positions = []
    @data.each_set_bit { |i| positions << i }
    # descending flat positions: byte[1] MSB-first, then byte[0] MSB-first
    assert_equal [15, 14, 11, 10, 7, 5, 3, 1], positions
  end

  def test_lsb_positions
    positions = []
    @data.each_set_bit(order: :lsb) { |i| positions << i }
    # ascending flat positions: byte[0] LSB-first, then byte[1] LSB-first
    assert_equal [1, 3, 5, 7, 10, 11, 14, 15], positions
  end

  def test_empty_string
    positions = []
    "".each_set_bit { |i| positions << i }
    assert_empty positions
  end

  def test_all_zeros
    positions = []
    "\x00\x00".each_set_bit { |i| positions << i }
    assert_empty positions
  end

  def test_all_ones_single_byte
    positions = []
    "\xFF".each_set_bit { |i| positions << i }
    assert_equal (0..7).to_a, positions.sort
    assert_equal 8, positions.size
  end

  def test_single_bit_msb_high
    positions = []
    "\x80".each_set_bit { |i| positions << i }
    assert_equal [7], positions
  end

  def test_single_bit_msb_low
    positions = []
    "\x01".each_set_bit { |i| positions << i }
    assert_equal [0], positions
  end

  def test_single_bit_lsb_high
    positions = []
    "\x80".each_set_bit(order: :lsb) { |i| positions << i }
    assert_equal [7], positions
  end

  def test_single_bit_lsb_low
    positions = []
    "\x01".each_set_bit(order: :lsb) { |i| positions << i }
    assert_equal [0], positions
  end

  def test_returns_enumerator_without_block
    assert_instance_of Enumerator, @data.each_set_bit
    assert_instance_of Enumerator, @data.each_set_bit(order: :lsb)
  end

  def test_returns_self_with_block
    assert_same @data, @data.each_set_bit {}
    assert_same @data, @data.each_set_bit(order: :lsb) {}
  end

  def test_enumerator_msb
    assert_equal [15, 14, 11, 10, 7, 5, 3, 1], @data.each_set_bit.to_a
  end

  def test_enumerator_lsb
    assert_equal [1, 3, 5, 7, 10, 11, 14, 15], @data.each_set_bit(order: :lsb).to_a
  end

  def test_lsb_positions_match_bit_at
    @data.each_set_bit(order: :lsb) do |n|
      assert_equal true, @data.bit_at(n), "bit_at(#{n}) should be set"
    end
  end

  def test_msb_is_reverse_of_lsb
    msb = @data.each_set_bit.to_a
    lsb = @data.each_set_bit(order: :lsb).to_a
    assert_equal msb, lsb.reverse
  end

  def test_msb_and_lsb_cover_same_positions
    msb = @data.each_set_bit.to_a.sort
    lsb = @data.each_set_bit(order: :lsb).to_a.sort
    assert_equal msb, lsb
  end

  def test_position_count_matches_set_bit_count
    expected = @data.each_bit.count { |b| b }
    actual   = @data.each_set_bit.to_a.size
    assert_equal expected, actual
  end
end
