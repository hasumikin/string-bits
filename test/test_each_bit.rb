require_relative "test_helper"

class TestEachBit < Minitest::Test
  def test_lsb_single_byte
    bits = []
    "\xAA".each_bit { |b| bits << b }
    assert_equal [false, true, false, true, false, true, false, true], bits
  end

  def test_msb_single_byte
    bits = []
    "\xAA".each_bit(scan_order: :msb) { |b| bits << b }
    assert_equal [true, false, true, false, true, false, true, false], bits
  end

  def test_lsb_multi_byte
    bits = []
    [0b10101010, 0b11001100].pack('C*').each_bit { |b| bits << (b ? 1 : 0) }
    assert_equal [0,1,0,1,0,1,0,1, 0,0,1,1,0,0,1,1], bits
  end

  def test_msb_multi_byte
    bits = []
    [0b10101010, 0b11001100].pack('C*').each_bit(scan_order: :msb) { |b| bits << (b ? 1 : 0) }
    assert_equal [1,1,0,0,1,1,0,0, 1,0,1,0,1,0,1,0], bits
  end

  def test_empty_string
    bits = []
    "".each_bit { |b| bits << b }
    assert_empty bits
  end

  def test_all_zeros
    bits = []
    "\x00\x00".each_bit { |b| bits << b }
    assert_equal [false] * 16, bits
  end

  def test_all_ones
    bits = []
    "\xFF\xFF".each_bit { |b| bits << b }
    assert_equal [true] * 16, bits
  end

  def test_returns_enumerator_without_block
    assert_instance_of Enumerator, "\xAA".each_bit
    assert_instance_of Enumerator, "\xAA".each_bit(scan_order: :lsb)
  end

  def test_returns_self_with_block
    s = "\xAA"
    assert_same s, s.each_bit {}
    assert_same s, s.each_bit(scan_order: :lsb) {}
  end

  def test_enumerator_lsb
    e = "\xAA".each_bit
    assert_equal [false, true, false, true, false, true, false, true], e.to_a
  end

  def test_enumerator_msb
    e = "\xAA".each_bit(scan_order: :msb)
    assert_equal [true, false, true, false, true, false, true, false], e.to_a
  end

  def test_enumerator_map
    result = "\xFF".each_bit.map { |b| b ? 1 : 0 }
    assert_equal [1] * 8, result
  end

  def test_msb_is_reverse_of_lsb
    ["\xAA", [0b10101010, 0b11001100].pack('C*')].each do |data|
      msb = data.each_bit(scan_order: :msb).to_a
      lsb = data.each_bit(scan_order: :lsb).to_a
      assert_equal msb, lsb.reverse
    end
  end

  def test_count_set_bit_positions
    count = "\xAA".each_bit.count { |b| b }
    assert_equal 4, count
  end

  def test_unknown_keyword_raises_argument_error
    err = assert_raises(ArgumentError) { "\xAA".each_bit(count_from: :lsb).to_a }
    assert_match(/unknown keyword/, err.message)
  end
end
