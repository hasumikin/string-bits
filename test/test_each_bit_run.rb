require_relative "test_helper"

class TestBitCountRun < Minitest::Test
  # --- basic ---

  def test_all_ones
    assert_equal 8, "\xFF".bit_run_count(0, 1)
  end

  def test_all_zeros
    assert_equal 8, "\x00".bit_run_count(0, 0)
  end

  def test_low_nibble_zeros
    # 0xF0 = 11110000: bits 0-3 are 0, bits 4-7 are 1
    assert_equal 4, "\xF0".bit_run_count(0, 0)
    assert_equal 4, "\xF0".bit_run_count(4, 1)
  end

  def test_single_set_bit
    # 0x01 = 00000001: bit 0 is 1, bit 1 is 0
    assert_equal 1, "\x01".bit_run_count(0, 1)
  end

  def test_cross_byte_run
    # "\xFF\xFF\x00": 16 ones then 8 zeros
    assert_equal 16, "\xFF\xFF\x00".bit_run_count(0, 1)
    assert_equal 8,  "\xFF\xFF\x00".bit_run_count(16, 0)
  end

  def test_run_starting_mid_byte
    # 0xF0 = 11110000: bit 4 starts a run of 4 ones
    assert_equal 4, "\xF0".bit_run_count(4, 1)
    # bit 2 of 0xF0 = 0, run of 2 zeros (bits 2 and 3) before the ones at 4
    assert_equal 2, "\xF0".bit_run_count(2, 0)
  end

  def test_bit_mismatch_returns_zero
    # bit at 0 of 0xFF is 1; asking for 0-run returns 0
    assert_equal 0, "\xFF".bit_run_count(0, 0)
    # bit at 0 of 0x00 is 0; asking for 1-run returns 0
    assert_equal 0, "\x00".bit_run_count(0, 1)
  end

  def test_out_of_range_returns_zero
    assert_equal 0, "\xFF".bit_run_count(8, 1)
    assert_equal 0, "\xFF".bit_run_count(100, 0)
  end

  def test_negative_returns_zero
    assert_equal 0, "\xFF".bit_run_count(-1, 1)
  end

  def test_bignum_raises_argument_error
    assert_raises(ArgumentError) { "\xFF".bit_run_count(2**62, 1) }
    assert_raises(ArgumentError) { "\xFF".bit_run_count(2**100, 1) }
  end

  def test_negative_bignum_raises_argument_error
    assert_raises(ArgumentError) { "\xFF".bit_run_count(-(2**100), 1) }
  end

  def test_boolean_bit_values
    # true/false are aliases for 1/0, matching each_bit_run yield values
    assert_equal 8, "\xFF".bit_run_count(0, true)
    assert_equal 8, "\x00".bit_run_count(0, false)
    assert_equal 0, "\xFF".bit_run_count(0, false)
  end

  def test_type_error_on_pos
    assert_raises(TypeError) { "\xFF".bit_run_count("0", 1) }
    assert_raises(TypeError) { "\xFF".bit_run_count(nil, 1) }
  end

  def test_arg_error_on_invalid_bit
    assert_raises(ArgumentError) { "\xFF".bit_run_count(0, 2) }
    assert_raises(ArgumentError) { "\xFF".bit_run_count(0, "1") }
    assert_raises(ArgumentError) { "\xFF".bit_run_count(0, nil) }
  end

  # --- cross-byte with long run (exercises the 64-bit word path) ---

  def test_long_run_ones
    data = "\xFF" * 100  # 800 ones
    assert_equal 800, data.bit_run_count(0, 1)
  end

  def test_long_run_zeros
    data = "\x00" * 100  # 800 zeros
    assert_equal 800, data.bit_run_count(0, 0)
  end

  def test_long_run_starting_mid_byte
    # 4 zeros (0xF0 low nibble), then 800 ones, then 4 zeros
    data = "\xF0" + "\xFF" * 99 + "\x0F"
    assert_equal 4,       data.bit_run_count(0, 0)  # initial zeros
    assert_equal 796 + 4, data.bit_run_count(4, 1)  # 796 ones in middle bytes + 4 in last byte
  end

  # --- consistency with bit_at ---

  def test_consistent_with_bit_at
    data = "\xAA\xCC\xFF\x00"
    pos = 0
    while pos < data.bytesize * 8
      target = data.bit_at(pos)
      run = data.bit_run_count(pos, target)
      run.times do |j|
        assert_equal target, data.bit_at(pos + j), "bit #{pos + j} mismatch"
      end
      # First bit after the run must differ (or be out of range)
      next_pos = pos + run
      if next_pos < data.bytesize * 8
        refute_equal target, data.bit_at(next_pos), "run at #{pos} did not end at #{next_pos}"
      end
      pos = next_pos
    end
  end

  # --- interoperability with each_bit_run ---

  def test_count_run_matches_each_bit_run_length
    data = "\xAA\xCC\xFF\x00\xF0"
    pos = 0
    data.each_bit_run do |bit, len|
      assert_equal len, data.bit_run_count(pos, bit),
        "bit_run_count(#{pos}, #{bit}) should be #{len}"
      pos += len
    end
  end
end

class TestEachBitRun < Minitest::Test
  # --- return value / enumerator ---

  def test_returns_enumerator_without_block
    assert_instance_of Enumerator, "\xFF".each_bit_run
    assert_instance_of Enumerator, "\xFF".each_bit_run(scan_order: :lsb)
    assert_instance_of Enumerator, "\xFF".each_bit_run(scan_order: :msb)
  end

  def test_returns_self_with_block
    s = "\xFF"
    assert_same s, s.each_bit_run { |_, _| }
  end

  def test_empty_string_yields_nothing
    assert_empty "".each_bit_run.to_a
  end

  # --- basic LSB runs ---

  def test_all_ones
    assert_equal [[true, 8]], "\xFF".each_bit_run.to_a
  end

  def test_all_zeros
    assert_equal [[false, 8]], "\x00".each_bit_run.to_a
  end

  def test_two_runs
    # 0xF0 = 11110000: bits 0-3 = 0, bits 4-7 = 1
    assert_equal [[false, 4], [true, 4]], "\xF0".each_bit_run.to_a
  end

  def test_alternating_bits
    # 0xAA = 10101010: bit0=0,bit1=1,...
    expected = [[false,1],[true,1]] * 4
    assert_equal expected, "\xAA".each_bit_run.to_a
  end

  def test_cross_byte_run
    assert_equal [[true, 8], [false, 8]], "\xFF\x00".each_bit_run.to_a
  end

  def test_multi_byte_single_run
    assert_equal [[true, 24]], "\xFF\xFF\xFF".each_bit_run.to_a
  end

  # --- scan_order: :msb ---

  def test_msb_all_ones
    assert_equal [[true, 8]], "\xFF".each_bit_run(scan_order: :msb).to_a
  end

  def test_msb_two_runs
    # 0xF0: bits 7-4 are 1, bits 3-0 are 0 -- MSB yields from bit 7 downward
    assert_equal [[true, 4], [false, 4]], "\xF0".each_bit_run(scan_order: :msb).to_a
  end

  def test_msb_is_reverse_of_lsb_for_consistent_data
    # When all runs have distinct lengths, msb == lsb.reverse
    data = "\xFF\x00"  # two runs of 8
    lsb = data.each_bit_run(scan_order: :lsb).to_a
    msb = data.each_bit_run(scan_order: :msb).to_a
    assert_equal lsb.reverse, msb
  end

  # --- argument errors ---

  def test_invalid_scan_order
    assert_raises(ArgumentError) { "\xFF".each_bit_run(scan_order: :foo) {} }
  end

  # --- run lengths sum to total bits ---

  def test_run_lengths_cover_all_bits
    data = "\xAA\xCC\xFF\x00\xF0\x0F"
    total = data.each_bit_run.sum { |_, len| len }
    assert_equal data.bytesize * 8, total
  end

  # --- roundtrip: reconstruct bits from runs ---

  def test_roundtrip_lsb
    data = "\xAA\xCC\xFF\x00\xF0"
    reconstructed = []
    data.each_bit_run(scan_order: :lsb) { |bit, len| len.times { reconstructed << bit } }
    assert_equal data.each_bit(scan_order: :lsb).to_a, reconstructed
  end

  def test_roundtrip_msb
    data = "\xAA\xCC\xFF\x00\xF0"
    reconstructed = []
    data.each_bit_run(scan_order: :msb) { |bit, len| len.times { reconstructed << bit } }
    assert_equal data.each_bit(scan_order: :msb).to_a, reconstructed
  end

  # --- long runs (exercises 64-bit word path) ---

  def test_long_run_single
    data = "\xFF" * 128  # 1024 ones
    assert_equal [[true, 1024]], data.each_bit_run.to_a
  end

  def test_long_run_roundtrip
    data = "\x00" * 63 + "\xFF" * 63
    reconstructed = []
    data.each_bit_run { |bit, len| len.times { reconstructed << bit } }
    assert_equal data.each_bit.to_a, reconstructed
  end

  # --- enumerator ---

  def test_enumerator_to_a
    e = "\xFF\x00".each_bit_run
    assert_equal [[true, 8], [false, 8]], e.to_a
  end

  def test_each_bit_run_count
    # 0xAA has 8 alternating runs
    assert_equal 8, "\xAA".each_bit_run.count
  end

  # --- RLE equivalence to each_bit-based approach ---

  def test_rle_equivalence
    data = "\xAA\xCC\xFF\x00" * 10

    # each_bit-based RLE (existing approach)
    expected = []
    current = nil; count = 0
    data.each_bit(scan_order: :lsb) do |b|
      if b == current then count += 1
      else expected << [current, count] unless current.nil?; current = b; count = 1
      end
    end
    expected << [current, count] unless current.nil?

    # each_bit_run (new approach)
    actual = data.each_bit_run(scan_order: :lsb).to_a

    assert_equal expected, actual
  end
end
