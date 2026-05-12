# NOTE: each_bit_field is NOT part of the current core proposal.
# It is deferred pending discussion on yielding Integer field values.
# See FUTURE_PROPOSAL_PLAN.md for the rationale.
require_relative "test_helper"

class TestEachBitField < Minitest::Test
  # --- Enumerator / return value ---

  def test_returns_enumerator_without_block
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_field(8)
  end

  def test_returns_enumerator_with_options
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_field(8, 8)
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_field(8, order: :msb)
    assert_instance_of Enumerator, "\xAA\xCC".each_bit_field(8, with: :index)
  end

  def test_returns_self_with_block
    s = "\xAA\xCC"
    assert_same s, s.each_bit_field(8) { |_| }
  end

  # --- Yields Integer values ---

  def test_yields_integers
    "\xAA\xCC".each_bit_field(8) { |v| assert_instance_of Integer, v }
  end

  def test_yields_integers_multi_field
    "\xAA\xCC".each_bit_field(8, 8) { |a, b| assert_instance_of Integer, a; assert_instance_of Integer, b }
  end

  # --- Single field, byte-aligned ---

  def test_byte_aligned_single_field
    assert_equal [0xAA, 0xCC], "\xAA\xCC".each_bit_field(8).to_a
  end

  def test_four_byte_string
    assert_equal [0x01, 0x02, 0x03, 0x04], "\x01\x02\x03\x04".each_bit_field(8).to_a
  end

  # --- Non-byte-aligned single field ---

  def test_4bit_single_field
    # 0xAB = bits 0-3: 1011 = 0x0B; bits 4-7: 1010 = 0x0A
    assert_equal [0x0B, 0x0A], "\xAB".each_bit_field(4).to_a
  end

  def test_extracted_bits_match_bit_at
    data = "\xAA\xCC\xFF\x00"
    bitlen = 6
    data.each_bit_field(bitlen).each_with_index do |val, iter|
      bitlen.times do |j|
        expected = data.bit_at(iter * bitlen + j) ? 1 : 0
        assert_equal expected, (val >> j) & 1, "iteration #{iter}, bit #{j}"
      end
    end
  end

  def test_12bit_single_field_bits_match
    data = "\xAA\xCC\xFF"
    data.each_bit_field(12).each_with_index do |val, iter|
      12.times do |j|
        expected = data.bit_at(iter * 12 + j) ? 1 : 0
        assert_equal expected, (val >> j) & 1, "iteration #{iter}, bit #{j}"
      end
    end
  end

  # --- Trailing bits dropped ---

  def test_trailing_bits_dropped
    assert_equal 2, "\xAA\xCC\xFF".each_bit_field(10).to_a.length
  end

  def test_string_shorter_than_bitlen_yields_nothing
    assert_empty "\xAA".each_bit_field(16).to_a
  end

  def test_empty_string_yields_nothing
    assert_empty "".each_bit_field(8).to_a
  end

  # --- Multiple fields (equal widths) ---

  def test_two_equal_fields_byte_aligned
    pairs = []
    "\xAA\xCC".each_bit_field(8, 8) { |a, b| pairs << [a, b] }
    assert_equal [[0xAA, 0xCC]], pairs
  end

  def test_three_equal_fields
    groups = []
    "\xAA\xBB\xCC".each_bit_field(8, 8, 8) { |a, b, c| groups << [a, b, c] }
    assert_equal [[0xAA, 0xBB, 0xCC]], groups
  end

  def test_two_equal_fields_multiple_iterations
    groups = []
    "\xAA\xBB\xCC\xDD".each_bit_field(8, 8) { |a, b| groups << [a, b] }
    assert_equal [[0xAA, 0xBB], [0xCC, 0xDD]], groups
  end

  def test_two_12bit_fields_bits_match
    data = "\xAA\xCC\xFF"
    data.each_bit_field(12, 12) do |ch0, ch1|
      12.times do |j|
        assert_equal (data.bit_at(j)      ? 1 : 0), (ch0 >> j) & 1, "ch0 bit #{j}"
        assert_equal (data.bit_at(12 + j) ? 1 : 0), (ch1 >> j) & 1, "ch1 bit #{j}"
      end
    end
  end

  # --- Multiple fields (mixed widths) ---

  def test_mixed_width_fields_565
    # RGB565: blue=21 (5-bit), green=42 (6-bit), red=10 (5-bit)
    pixel = [(21) | (42 << 5) | (10 << 11)].pack("S<")
    fields = []
    pixel.each_bit_field(5, 6, 5) { |b, g, r| fields << [b, g, r] }
    assert_equal [[21, 42, 10]], fields
  end

  def test_mixed_width_fields_bits_match
    data = "\xAA\xCC\xFF"
    data.each_bit_field(5, 6, 5) do |f0, f1, f2|
      5.times { |j| assert_equal (data.bit_at(j)      ? 1 : 0), (f0 >> j) & 1, "f0 bit #{j}" }
      6.times { |j| assert_equal (data.bit_at(5 + j)  ? 1 : 0), (f1 >> j) & 1, "f1 bit #{j}" }
      5.times { |j| assert_equal (data.bit_at(11 + j) ? 1 : 0), (f2 >> j) & 1, "f2 bit #{j}" }
    end
  end

  # --- 64-bit field limit ---

  def test_64bit_field
    data = "\xFF" * 8
    assert_equal [0xFFFFFFFFFFFFFFFF], data.each_bit_field(64).to_a
  end

  def test_argument_error_for_bitlen_over_64
    assert_raises(ArgumentError) { ("\xFF" * 9).each_bit_field(65) {} }
    assert_raises(ArgumentError) { "\xFF".each_bit_field(4, 65) {} }
  end

  # --- with: :offset ---

  def test_with_offset_single_field
    offsets = []
    "\xAA\xBB\xCC\xDD".each_bit_field(8, with: :offset) { |_v, off| offsets << off }
    assert_equal [0, 8, 16, 24], offsets
  end

  def test_with_offset_two_fields
    offsets = []
    "\xAA\xBB\xCC\xDD".each_bit_field(8, 8, with: :offset) { |_a, _b, off| offsets << off }
    assert_equal [0, 16], offsets
  end

  def test_with_offset_mixed_width
    offsets = []
    "\xAA\xBB\xCC\xDD".each_bit_field(5, 6, 5, with: :offset) { |_b, _g, _r, off| offsets << off }
    assert_equal [0, 16], offsets
  end

  def test_with_offset_allows_bit_splice
    data = +"\xAA\xBB"
    data.each_bit_field(8, with: :offset) do |val, off|
      data.bit_splice(off, 8, val ^ 0xFF)
    end
    assert_equal "\x55\x44", data
  end

  # --- with: :index ---

  def test_with_index_single_field
    indices = []
    "\xAA\xBB\xCC\xDD".each_bit_field(8, with: :index) { |_v, idx| indices << idx }
    assert_equal [0, 1, 2, 3], indices
  end

  def test_with_index_two_fields
    indices = []
    "\xAA\xBB\xCC\xDD".each_bit_field(8, 8, with: :index) { |_a, _b, idx| indices << idx }
    assert_equal [0, 1], indices
  end

  def test_with_index_msb
    indices = []
    "\xAA\xBB\xCC\xDD".each_bit_field(8, with: :index, order: :msb) { |_v, idx| indices << idx }
    assert_equal [0, 1, 2, 3], indices
  end

  # --- order: :msb ---

  def test_msb_reverses_iteration_order
    data = "\xAA\xBB\xCC\xDD"
    lsb = data.each_bit_field(8).to_a
    msb = data.each_bit_field(8, order: :msb).to_a
    assert_equal lsb.reverse, msb
  end

  def test_msb_with_two_fields
    data = "\xAA\xBB\xCC\xDD"
    lsb_groups = []
    msb_groups = []
    data.each_bit_field(8, 8) { |a, b| lsb_groups << [a, b] }
    data.each_bit_field(8, 8, order: :msb) { |a, b| msb_groups << [a, b] }
    assert_equal lsb_groups.reverse, msb_groups
  end

  def test_msb_offset_descends
    offsets = []
    "\xAA\xBB\xCC\xDD".each_bit_field(8, with: :offset, order: :msb) { |_v, off| offsets << off }
    assert_equal [24, 16, 8, 0], offsets
  end

  # --- Error handling ---

  def test_argument_error_for_no_fields
    assert_raises(ArgumentError) { "\xAA".each_bit_field {} }
  end

  def test_type_error_for_non_integer_bitlen
    assert_raises(TypeError) { "\xAA".each_bit_field("8") {} }
    assert_raises(TypeError) { "\xAA".each_bit_field(nil) {} }
    assert_raises(TypeError) { "\xAA".each_bit_field(4, "2") {} }
  end

  def test_argument_error_for_zero_bitlen
    assert_raises(ArgumentError) { "\xAA".each_bit_field(0) {} }
    assert_raises(ArgumentError) { "\xAA".each_bit_field(4, 0) {} }
  end

  def test_argument_error_for_negative_bitlen
    assert_raises(ArgumentError) { "\xAA".each_bit_field(-1) {} }
    assert_raises(ArgumentError) { "\xAA".each_bit_field(4, -1) {} }
  end

  def test_argument_error_for_invalid_order
    assert_raises(ArgumentError) { "\xAA".each_bit_field(4, order: :foo) {} }
  end

  def test_argument_error_for_invalid_with
    assert_raises(ArgumentError) { "\xAA".each_bit_field(4, with: :foo) {} }
  end

  # --- Enumerator behavior ---

  def test_enumerator_to_a_single_field
    assert_equal [0xAA, 0xCC], "\xAA\xCC".each_bit_field(8).to_a
  end

  def test_enumerator_to_a_two_fields
    assert_equal [[0xAA, 0xCC]], "\xAA\xCC".each_bit_field(8, 8).to_a
  end

  def test_enumerator_count
    assert_equal 4, "\xAA\xCC\xFF\x00".each_bit_field(8).count
  end
end
