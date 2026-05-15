# NOTE: bit_fields is NOT part of the current core proposal.
# It is deferred pending discussion on yielding Integer field values.
# See FUTURE_PROPOSAL_PLAN.md for the rationale.
require_relative "test_helper"

class TestBitFields < Minitest::Test
  # --- Return value without block ---

  def test_returns_array_without_block
    assert_instance_of Array, "\xAA\xCC".bit_fields(8)
  end

  def test_returns_self_with_block
    s = "\xAA\xCC"
    assert_same s, s.bit_fields(8) { |_| }
  end

  # --- Single field: flat array ---

  def test_single_field_byte_aligned
    assert_equal [0xAA, 0xCC], "\xAA\xCC".bit_fields(8)
  end

  def test_single_field_4bit
    assert_equal [0x0B, 0x0A], "\xAB".bit_fields(4)
  end

  def test_single_field_matches_each_bit_field_to_a
    data = "\xAA\xCC\xFF\x00"
    assert_equal data.each_bit_field(6).to_a, data.bit_fields(6)
  end

  def test_single_field_64bit
    data = "\xFF" * 8
    assert_equal [0xFFFFFFFFFFFFFFFF], data.bit_fields(64)
  end

  # --- Multiple fields: array of arrays ---

  def test_two_fields_returns_array_of_arrays
    assert_equal [[0xAA, 0xCC]], "\xAA\xCC".bit_fields(8, 8)
  end

  def test_two_fields_multiple_records
    assert_equal [[0xAA, 0xBB], [0xCC, 0xDD]], "\xAA\xBB\xCC\xDD".bit_fields(8, 8)
  end

  def test_three_fields
    assert_equal [[0xAA, 0xBB, 0xCC]], "\xAA\xBB\xCC".bit_fields(8, 8, 8)
  end

  def test_mixed_width_565
    pixel = [(21) | (42 << 5) | (10 << 11)].pack("S<")
    assert_equal [[21, 42, 10]], pixel.bit_fields(5, 6, 5)
  end

  def test_multiple_fields_matches_each_bit_field_to_a
    data = "\xAA\xCC\xFF\x00"
    assert_equal data.each_bit_field(5, 6, 5).to_a, data.bit_fields(5, 6, 5)
  end

  # --- Trailing bits dropped ---

  def test_trailing_bits_dropped_single_field
    assert_equal 2, "\xAA\xCC\xFF".bit_fields(10).length
  end

  def test_trailing_bits_dropped_multi_field
    assert_equal 1, "\xAA\xCC\xFF".bit_fields(12, 12).length
  end

  def test_string_shorter_than_bitlen_yields_nothing
    assert_empty "\xAA".bit_fields(16)
  end

  def test_empty_string
    assert_empty "".bit_fields(8)
  end

  # --- reverse: true ---

  def test_msb_reverses_order_single_field
    data = "\xAA\xBB\xCC\xDD"
    assert_equal data.bit_fields(8).reverse, data.bit_fields(8, reverse: true)
  end

  def test_msb_reverses_order_multi_field
    data = "\xAA\xBB\xCC\xDD"
    assert_equal data.bit_fields(8, 8).reverse, data.bit_fields(8, 8, reverse: true)
  end

  def test_msb_matches_each_bit_field_to_a
    data = "\xAA\xCC\xFF\x00"
    assert_equal data.each_bit_field(8, reverse: true).to_a, data.bit_fields(8, reverse: true)
    assert_equal data.each_bit_field(8, 8, reverse: true).to_a, data.bit_fields(8, 8, reverse: true)
  end

  # --- Block form ---

  def test_block_yields_single_integer_for_one_field
    vals = []
    "\xAA\xCC".bit_fields(8) { |v| vals << v }
    assert_equal [0xAA, 0xCC], vals
  end

  def test_block_yields_multiple_integers_for_multi_field
    records = []
    "\xAA\xBB\xCC\xDD".bit_fields(8, 8) { |a, b| records << [a, b] }
    assert_equal [[0xAA, 0xBB], [0xCC, 0xDD]], records
  end

  def test_block_returns_self
    s = "\xAA\xCC"
    result = s.bit_fields(8) { |_| }
    assert_same s, result
  end

  def test_block_msb_order
    vals = []
    "\xAA\xBB\xCC\xDD".bit_fields(8, reverse: true) { |v| vals << v }
    assert_equal [0xDD, 0xCC, 0xBB, 0xAA], vals
  end

  # --- Error handling ---

  def test_argument_error_for_no_fields
    assert_raises(ArgumentError) { "\xAA".bit_fields }
  end

  def test_type_error_for_non_integer_bitlen
    assert_raises(TypeError) { "\xAA".bit_fields("8") }
    assert_raises(TypeError) { "\xAA".bit_fields(nil) }
    assert_raises(TypeError) { "\xAA".bit_fields(4, "2") }
  end

  def test_argument_error_for_zero_bitlen
    assert_raises(ArgumentError) { "\xAA".bit_fields(0) }
    assert_raises(ArgumentError) { "\xAA".bit_fields(4, 0) }
  end

  def test_argument_error_for_negative_bitlen
    assert_raises(ArgumentError) { "\xAA".bit_fields(-1) }
    assert_raises(ArgumentError) { "\xAA".bit_fields(4, -1) }
  end

  def test_argument_error_for_bitlen_over_64
    assert_raises(ArgumentError) { ("\xFF" * 9).bit_fields(65) }
    assert_raises(ArgumentError) { "\xFF".bit_fields(4, 65) }
  end

  def test_argument_error_for_invalid_reverse
    assert_raises(ArgumentError) { "\xAA".bit_fields(4, reverse: :foo) }
  end

  def test_field_order_is_unknown_keyword
    err = assert_raises(ArgumentError) { "\xAA".bit_fields(4, field_order: :msb) }
    assert_match(/unknown keyword/, err.message)
  end
end
