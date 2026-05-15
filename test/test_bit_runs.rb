require_relative "test_helper"

class TestBitRuns < Minitest::Test
  # --- return value ---

  def test_returns_array_without_block
    assert_instance_of Array, "\xFF".bit_runs
  end

  def test_returns_self_with_block
    s = "\xFF"
    assert_same s, s.bit_runs { |_, _| }
  end

  def test_empty_string_returns_empty_array
    assert_empty "".bit_runs
  end

  def test_empty_string_with_block_returns_self
    s = ""
    assert_same s, s.bit_runs { |_, _| }
  end

  # --- matches each_bit_run.to_a ---

  def test_matches_each_bit_run_to_a
    data = "\xAA\xCC\xFF\x00\xF0"
    assert_equal data.each_bit_run.to_a, data.bit_runs
  end

  def test_matches_each_bit_run_to_a_msb
    data = "\xAA\xCC\xFF\x00\xF0"
    assert_equal data.each_bit_run(reverse: true).to_a, data.bit_runs(reverse: true)
  end

  # --- content ---

  def test_all_ones
    assert_equal [[true, 8]], "\xFF".bit_runs
  end

  def test_all_zeros
    assert_equal [[false, 8]], "\x00".bit_runs
  end

  def test_two_runs
    assert_equal [[false, 4], [true, 4]], "\xF0".bit_runs
  end

  def test_cross_byte_run
    assert_equal [[true, 8], [false, 8]], "\xFF\x00".bit_runs
  end

  # --- msb order ---

  def test_msb_reverses_for_symmetric_data
    data = "\xFF\x00"
    assert_equal data.bit_runs.reverse, data.bit_runs(reverse: true)
  end

  def test_msb_two_runs
    assert_equal [[true, 4], [false, 4]], "\xF0".bit_runs(reverse: true)
  end

  # --- block form ---

  def test_block_yields_bit_and_length
    pairs = []
    "\xFF\x00".bit_runs { |bit, len| pairs << [bit, len] }
    assert_equal [[true, 8], [false, 8]], pairs
  end

  def test_block_msb_order
    pairs = []
    "\xF0".bit_runs(reverse: true) { |bit, len| pairs << [bit, len] }
    assert_equal [[true, 4], [false, 4]], pairs
  end

  # --- run lengths sum to total bits ---

  def test_run_lengths_cover_all_bits
    data = "\xAA\xCC\xFF\x00\xF0\x0F"
    total = data.bit_runs.sum { |_, len| len }
    assert_equal data.bytesize * 8, total
  end

  # --- error handling ---

  def test_invalid_order
    assert_raises(ArgumentError) { "\xFF".bit_runs(reverse: :foo) }
  end
end
