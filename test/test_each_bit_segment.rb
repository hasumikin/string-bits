require_relative "test_helper"

class TestEachBitSegment < Minitest::Test
  # --- Return value ---

  def test_returns_enumerator_without_block
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_segment(0, 8)
  end

  def test_returns_enumerator_with_options
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_segment(0, 8, order: :msb)
  end

  def test_returns_self_with_block
    s = "\xAA\xCC"
    assert_same s, s.each_bit_segment(0, 8) { |_| }
  end

  # --- Yields String ---

  def test_yields_strings
    "\xAA\xCC".each_bit_segment(0, 8) { |s| assert_instance_of String, s }
  end

  # --- Byte-aligned segments ---

  def test_byte_aligned_single_byte_segments
    segments = []
    "\xAA\xCC".each_bit_segment(0, 8) { |s| segments << s }
    assert_equal ["\xAA", "\xCC"], segments
  end

  def test_byte_aligned_two_byte_segments
    segments = []
    "\xAA\xCC\xFF\x00".each_bit_segment(0, 16) { |s| segments << s }
    assert_equal ["\xAA\xCC", "\xFF\x00"], segments
  end

  # --- Segment content matches bit_slice ---

  def test_segment_content_matches_bit_slice
    data = "\xAA\xCC\xFF\x00"
    data.each_bit_segment(0, 6).each_with_index do |segment, iter|
      assert_equal data.bit_slice(iter * 6, 6), segment
    end
  end

  def test_nonzero_offset_matches_bit_slice
    data = "\xAA\xCC\xFF\x00"
    offset = 4
    bitlen = 8
    data.each_bit_segment(offset, bitlen).each_with_index do |segment, iter|
      assert_equal data.bit_slice(offset + iter * bitlen, bitlen), segment
    end
  end

  def test_4bit_segments
    segments = "\xAB".each_bit_segment(0, 4).to_a
    assert_equal 2, segments.length
    assert_equal "\xAB".bit_slice(0, 4), segments[0]
    assert_equal "\xAB".bit_slice(4, 4), segments[1]
  end

  # --- Non-byte-aligned ---

  def test_12bit_slices_bits_match
    data = "\xAA\xCC\xFF"
    data.each_bit_segment(0, 12).each_with_index do |segment, iter|
      12.times do |j|
        expected = data.bit_at(iter * 12 + j) ? 1 : 0
        actual   = (segment.getbyte(j / 8) >> (j % 8)) & 1
        assert_equal expected, actual, "iter #{iter}, bit #{j}"
      end
    end
  end

  # --- Trailing bits dropped ---

  def test_trailing_bits_dropped
    assert_equal 2, "\xAA\xCC\xFF".each_bit_segment(0, 10).to_a.length
  end

  def test_nonzero_offset_trailing_bits_dropped
    data = "\xAA\xCC\xFF\x00"
    segments = data.each_bit_segment(4, 8).to_a
    available = data.bytesize * 8 - 4
    assert_equal available / 8, segments.length
  end

  def test_string_shorter_than_bit_length_yields_nothing
    assert_empty "\xAA".each_bit_segment(0, 16).to_a
  end

  def test_empty_string_yields_nothing
    assert_empty "".each_bit_segment(0, 8).to_a
  end

  def test_offset_at_end_yields_nothing
    data = "\xAA\xCC"
    assert_empty data.each_bit_segment(16, 8).to_a
  end

  def test_offset_beyond_end_yields_nothing
    data = "\xAA\xCC"
    assert_empty data.each_bit_segment(100, 8).to_a
  end

  # --- order: :msb ---

  def test_msb_reverses_iteration_order
    data = "\xAA\xBB\xCC\xDD"
    lsb = data.each_bit_segment(0, 8).to_a
    msb = data.each_bit_segment(0, 8, order: :msb).to_a
    assert_equal lsb.reverse, msb
  end

  def test_msb_with_nonbyte_aligned_segments
    data = "\xAA\xCC\xFF\x00"
    lsb = data.each_bit_segment(0, 6).to_a
    msb = data.each_bit_segment(0, 6, order: :msb).to_a
    assert_equal lsb.reverse, msb
  end

  def test_msb_with_nonzero_offset
    data = "\xAA\xBB\xCC\xDD"
    lsb = data.each_bit_segment(4, 8).to_a
    msb = data.each_bit_segment(4, 8, order: :msb).to_a
    assert_equal lsb.reverse, msb
  end

  # --- Enumerator behavior ---

  def test_enumerator_to_a
    assert_equal ["\xAA", "\xCC"], "\xAA\xCC".each_bit_segment(0, 8).to_a
  end

  def test_enumerator_count
    assert_equal 4, "\xAA\xCC\xFF\x00".each_bit_segment(0, 8).count
  end

  # --- Error handling ---

  def test_type_error_for_non_integer_offset
    assert_raises(TypeError) { "\xAA".each_bit_segment("0", 8) {} }
  end

  def test_type_error_for_non_integer_length
    assert_raises(TypeError) { "\xAA".each_bit_segment(0, "8") {} }
  end

  def test_argument_error_for_negative_offset
    assert_raises(ArgumentError) { "\xAA".each_bit_segment(-1, 8) {} }
  end

  def test_argument_error_for_zero_length
    assert_raises(ArgumentError) { "\xAA".each_bit_segment(0, 0) {} }
  end

  def test_argument_error_for_negative_length
    assert_raises(ArgumentError) { "\xAA".each_bit_segment(0, -1) {} }
  end

  def test_argument_error_for_invalid_order
    assert_raises(ArgumentError) { "\xAA".each_bit_segment(0, 8, order: :foo) {} }
  end
end
