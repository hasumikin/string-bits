require_relative "test_helper"

class TestEachBitSlice < Minitest::Test
  # --- Enumerator / return value ---

  def test_returns_enumerator_without_block
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_slice(8)
  end

  def test_returns_enumerator_with_options
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_slice(8, planes: 2)
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_slice(8, order: :msb)
  end

  def test_returns_self_with_block
    s = "\xAA\xCC"
    assert_same s, s.each_bit_slice(8) { |_| }
  end

  # --- Basic single-plane, byte-aligned ---

  def test_byte_aligned_single_plane
    result = "\xAA\xCC".each_bit_slice(8).to_a
    assert_equal ["\xAA", "\xCC"], result
  end

  def test_four_byte_string
    data = "\x01\x02\x03\x04"
    result = data.each_bit_slice(8).to_a
    assert_equal ["\x01", "\x02", "\x03", "\x04"], result
  end

  # --- Non-byte-aligned bitlen ---

  def test_12bit_slices
    # 3 bytes = 24 bits = exactly two 12-bit slices
    data = "\xAA\xCC\xFF"
    result = data.each_bit_slice(12).to_a
    assert_equal 2, result.length
    # Each extracted slice must match bit_at of the source
    result.each_with_index do |s, iter|
      12.times do |j|
        assert_equal data.bit_at(iter * 12 + j), s.bit_at(j),
                     "iteration #{iter}, bit #{j} mismatch"
      end
    end
  end

  def test_4bit_slices
    # 0xAB = 10101011; first nibble bits 0-3 = 1,1,0,1 => 0x0B; second nibble bits 4-7 = 0,1,0,1 => 0x0A
    data = "\xAB"
    result = data.each_bit_slice(4).to_a
    assert_equal 2, result.length
    assert_equal "\x0B", result[0]  # bits 0-3 of 0xAB: 1,1,0,1 => b3b2b1b0=0b1011=0x0B
    assert_equal "\x0A", result[1]  # bits 4-7 of 0xAB: 0,1,0,1 => b3b2b1b0=0b1010=0x0A
  end

  def test_extracted_bits_match_bit_at
    data = "\xAA\xCC\xFF\x00"
    bitlen = 6
    data.each_bit_slice(bitlen).each_with_index do |s, iter|
      bitlen.times do |j|
        assert_equal data.bit_at(iter * bitlen + j), s.bit_at(j),
                     "iteration #{iter}, bit #{j}"
      end
    end
  end

  # --- Trailing bits dropped ---

  def test_trailing_bits_dropped
    # 3 bytes = 24 bits; 24 / 10 = 2 complete slices (4 bits remain, dropped)
    result = "\xAA\xCC\xFF".each_bit_slice(10).to_a
    assert_equal 2, result.length
  end

  def test_string_shorter_than_bitlen_yields_nothing
    assert_empty "\xAA".each_bit_slice(16).to_a
  end

  def test_empty_string_yields_nothing
    assert_empty "".each_bit_slice(8).to_a
  end

  # --- Multiple planes ---

  def test_two_planes_byte_aligned
    data = "\xAA\xCC"
    pairs = []
    data.each_bit_slice(8, planes: 2) { |p0, p1| pairs << [p0, p1] }
    assert_equal 1, pairs.length
    assert_equal "\xAA", pairs[0][0]
    assert_equal "\xCC", pairs[0][1]
  end

  def test_two_planes_bits_match_source
    data = "\xAA\xCC"
    data.each_bit_slice(8, planes: 2) do |p0, p1|
      8.times do |j|
        assert_equal data.bit_at(j),     p0.bit_at(j), "plane0 bit #{j}"
        assert_equal data.bit_at(8 + j), p1.bit_at(j), "plane1 bit #{j}"
      end
    end
  end

  def test_three_planes
    # 3 bytes = 24 bits = exactly one group of 3 x 8-bit planes
    data = "\xAA\xBB\xCC"
    groups = []
    data.each_bit_slice(8, planes: 3) { |p0, p1, p2| groups << [p0, p1, p2] }
    assert_equal 1, groups.length
    assert_equal ["\xAA", "\xBB", "\xCC"], groups[0]
  end

  def test_two_planes_12bit_adc
    # Two-channel 12-bit ADC packed format: ch0 sample followed by ch1 sample
    data = "\xAA\xCC\xFF"  # 24 bits = one pair of 12-bit samples
    count = 0
    data.each_bit_slice(12, planes: 2) do |ch0, ch1|
      count += 1
      assert_equal 2, ch0.bytesize
      assert_equal 2, ch1.bytesize
      12.times do |j|
        assert_equal data.bit_at(j),      ch0.bit_at(j), "ch0 bit #{j}"
        assert_equal data.bit_at(12 + j), ch1.bit_at(j), "ch1 bit #{j}"
      end
    end
    assert_equal 1, count
  end

  def test_two_planes_multiple_iterations
    # 4 bytes = 32 bits = two groups of 2 x 8-bit planes
    data = "\xAA\xBB\xCC\xDD"
    groups = []
    data.each_bit_slice(8, planes: 2) { |p0, p1| groups << [p0, p1] }
    assert_equal 2, groups.length
    assert_equal ["\xAA", "\xBB"], groups[0]
    assert_equal ["\xCC", "\xDD"], groups[1]
  end

  # --- order: :msb ---

  def test_msb_reverses_iteration_order
    data = "\xAA\xBB\xCC\xDD"
    lsb = data.each_bit_slice(8).to_a
    msb = data.each_bit_slice(8, order: :msb).to_a
    assert_equal lsb.reverse, msb
  end

  def test_msb_with_two_planes
    data = "\xAA\xBB\xCC\xDD"
    lsb_groups = []
    msb_groups = []
    data.each_bit_slice(8, planes: 2) { |p0, p1| lsb_groups << [p0, p1] }
    data.each_bit_slice(8, planes: 2, order: :msb) { |p0, p1| msb_groups << [p0, p1] }
    assert_equal lsb_groups.reverse, msb_groups
  end

  # --- Error handling ---

  def test_type_error_for_non_integer_bitlen
    assert_raises(TypeError) { "\xAA".each_bit_slice("8") {} }
    assert_raises(TypeError) { "\xAA".each_bit_slice(nil) {} }
  end

  def test_argument_error_for_zero_bitlen
    assert_raises(ArgumentError) { "\xAA".each_bit_slice(0) {} }
  end

  def test_argument_error_for_negative_bitlen
    assert_raises(ArgumentError) { "\xAA".each_bit_slice(-1) {} }
  end

  def test_type_error_for_non_integer_planes
    assert_raises(TypeError) { "\xAA".each_bit_slice(4, planes: "2") {} }
  end

  def test_argument_error_for_non_positive_planes
    assert_raises(ArgumentError) { "\xAA".each_bit_slice(4, planes: 0) {} }
    assert_raises(ArgumentError) { "\xAA".each_bit_slice(4, planes: -1) {} }
  end

  def test_argument_error_for_invalid_order
    assert_raises(ArgumentError) { "\xAA".each_bit_slice(4, order: :foo) {} }
  end

  # --- Enumerator behavior ---

  def test_enumerator_to_a_single_plane
    e = "\xAA\xCC".each_bit_slice(8)
    assert_equal ["\xAA", "\xCC"], e.to_a
  end

  def test_enumerator_to_a_two_planes
    e = "\xAA\xCC".each_bit_slice(8, planes: 2)
    # Two-plane enumerator wraps each yield in an array
    assert_equal [["\xAA", "\xCC"]], e.to_a
  end

  def test_enumerator_count
    e = "\xAA\xCC\xFF\x00".each_bit_slice(8)
    assert_equal 4, e.count
  end
end
