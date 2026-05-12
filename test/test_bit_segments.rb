require_relative "test_helper"

class TestBitSegments < Minitest::Test
  # --- Return value without block ---

  def test_returns_array_without_block
    assert_instance_of Array, "\xAA\xCC".bit_segments(0, 8)
  end

  def test_returns_self_with_block
    s = "\xAA\xCC"
    assert_same s, s.bit_segments(0, 8) { |_| }
  end

  # --- Matches each_bit_segment.to_a ---

  def test_matches_each_bit_segment_byte_aligned
    data = "\xAA\xCC\xFF\x00"
    assert_equal data.each_bit_segment(0, 8).to_a, data.bit_segments(0, 8)
  end

  def test_matches_each_bit_segment_nonbyte_aligned
    data = "\xAA\xCC\xFF\x00"
    assert_equal data.each_bit_segment(0, 6).to_a, data.bit_segments(0, 6)
  end

  def test_matches_each_bit_segment_with_offset
    data = "\xAA\xCC\xFF\x00"
    assert_equal data.each_bit_segment(4, 8).to_a, data.bit_segments(4, 8)
  end

  # --- Content ---

  def test_byte_aligned_single_byte_segments
    assert_equal ["\xAA", "\xCC"], "\xAA\xCC".bit_segments(0, 8)
  end

  def test_byte_aligned_two_byte_segments
    assert_equal ["\xAA\xCC", "\xFF\x00"], "\xAA\xCC\xFF\x00".bit_segments(0, 16)
  end

  def test_segments_match_bit_slice
    data = "\xAA\xCC\xFF\x00"
    data.bit_segments(0, 6).each_with_index do |seg, iter|
      assert_equal data.bit_slice(iter * 6, 6), seg
    end
  end

  # --- Trailing bits dropped ---

  def test_trailing_bits_dropped
    assert_equal 2, "\xAA\xCC\xFF".bit_segments(0, 10).length
  end

  def test_empty_string_returns_empty_array
    assert_empty "".bit_segments(0, 8)
  end

  def test_offset_at_end_returns_empty_array
    assert_empty "\xAA\xCC".bit_segments(16, 8)
  end

  # --- order: :msb ---

  def test_msb_reverses_order
    data = "\xAA\xBB\xCC\xDD"
    assert_equal data.bit_segments(0, 8).reverse, data.bit_segments(0, 8, order: :msb)
  end

  def test_msb_matches_each_bit_segment_to_a
    data = "\xAA\xCC\xFF\x00"
    assert_equal data.each_bit_segment(0, 8, order: :msb).to_a,
                 data.bit_segments(0, 8, order: :msb)
  end

  # --- Block form ---

  def test_block_yields_strings
    "\xAA\xCC".bit_segments(0, 8) { |s| assert_instance_of String, s }
  end

  def test_block_yields_segments_in_order
    segs = []
    "\xAA\xCC".bit_segments(0, 8) { |s| segs << s }
    assert_equal ["\xAA", "\xCC"], segs
  end

  def test_block_returns_self
    s = "\xAA\xCC"
    assert_same s, s.bit_segments(0, 8) { |_| }
  end

  def test_block_msb_order
    segs = []
    "\xAA\xBB\xCC\xDD".bit_segments(0, 8, order: :msb) { |s| segs << s }
    assert_equal ["\xDD", "\xCC", "\xBB", "\xAA"], segs
  end

  # --- Error handling ---

  def test_type_error_for_non_integer_offset
    assert_raises(TypeError) { "\xAA".bit_segments("0", 8) }
  end

  def test_type_error_for_non_integer_length
    assert_raises(TypeError) { "\xAA".bit_segments(0, "8") }
  end

  def test_argument_error_for_negative_offset
    assert_raises(ArgumentError) { "\xAA".bit_segments(-1, 8) }
  end

  def test_argument_error_for_zero_length
    assert_raises(ArgumentError) { "\xAA".bit_segments(0, 0) }
  end

  def test_argument_error_for_negative_length
    assert_raises(ArgumentError) { "\xAA".bit_segments(0, -1) }
  end

  def test_argument_error_for_invalid_order
    assert_raises(ArgumentError) { "\xAA".bit_segments(0, 8, order: :foo) }
  end
end
