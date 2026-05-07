#! /usr/bin/env ruby
# frozen_string_literal: true

# This implementation just shows how the methods work.
# Actual implementation for CRuby is supposed to be written in C.

# Ref
# - IO::Buffer#bit_count -> https://github.com/ruby/ruby/pull/16784
# - Integer#popcount -> https://bugs.ruby-lang.org/issues/8748

class String
  def each_bit(order: :msb)
    return enum_for(__method__, order: order) unless block_given?
    if order == :lsb
      i = 0
      while byte = getbyte(i)
        8.times do |j|
          yield (byte >> j) & 1 == 1
        end
        i += 1
      end
    else
      i = bytesize - 1
      while i >= 0
        byte = getbyte(i)
        7.downto(0) do |j|
          yield (byte >> j) & 1 == 1
        end
        i -= 1
      end
    end
    self
  end

  def bits(order: :msb)
    if block_given?
      each_bit(order: order) { |b| yield b }
      self
    else
      each_bit(order: order).to_a
    end
  end
end

class String
  POPCOUNT_TABLE = Array.new(256) { |i| i.to_s(2).count('1') }

  def bit_at(n)
    byte = getbyte(n >> 3)
    return nil if byte.nil?
    (byte >> (n & 7)) & 1 == 1
  end

  def popcount
    each_byte.sum { |b| POPCOUNT_TABLE[b] }
  end

  def bit_slice(bit_offset, bit_length)
    return nil if bit_offset < 0 || bit_length < 0
    total_bits = bytesize * 8
    return nil if bit_offset > total_bits
    actual_length = [bit_length, total_bits - bit_offset].min
    result = "\x00" * ((actual_length + 7) / 8)
    actual_length.times do |i|
      src_pos = bit_offset + i
      src_byte = getbyte(src_pos >> 3)
      next unless (src_byte >> (src_pos & 7)) & 1 == 1
      dst_idx = i >> 3
      result.setbyte(dst_idx, result.getbyte(dst_idx) | (1 << (i & 7)))
    end
    result
  end
end

class String
  BIT_POS_TABLE_MSB = Array.new(256) do |i|
    pos = []
    8.times do |j|
      pos << (7 - j) if (i & (1 << (7 - j))) != 0
    end
    pos
  end
  BIT_POS_TABLE_LSB = Array.new(256) do |i|
    pos = []
    8.times do |j|
      pos << j if (i & (1 << j)) != 0
    end
    pos
  end

  def set_bit(n)
    raise IndexError, "bit position #{n} out of range" if n < 0
    idx = n >> 3
    byte = getbyte(idx)
    raise IndexError, "bit position #{n} out of range" if byte.nil?
    setbyte(idx, byte | (1 << (n & 7)))
    self
  end

  def clear_bit(n)
    raise IndexError, "bit position #{n} out of range" if n < 0
    idx = n >> 3
    byte = getbyte(idx)
    raise IndexError, "bit position #{n} out of range" if byte.nil?
    setbyte(idx, byte & ~(1 << (n & 7)))
    self
  end

  def flip_bit(n)
    raise IndexError, "bit position #{n} out of range" if n < 0
    idx = n >> 3
    byte = getbyte(idx)
    raise IndexError, "bit position #{n} out of range" if byte.nil?
    setbyte(idx, byte ^ (1 << (n & 7)))
    self
  end

  def bit_not!
    bytesize.times { |i| setbyte(i, ~getbyte(i) & 0xFF) }
    self
  end

  def bit_not
    dup.bit_not!
  end

  def bit_and!(other)
    raise ArgumentError, "size mismatch: #{bytesize} != #{other.bytesize}" unless bytesize == other.bytesize
    bytesize.times { |i| setbyte(i, getbyte(i) & other.getbyte(i)) }
    self
  end

  def bit_and(other)
    dup.bit_and!(other)
  end

  def bit_or!(other)
    raise ArgumentError, "size mismatch: #{bytesize} != #{other.bytesize}" unless bytesize == other.bytesize
    bytesize.times { |i| setbyte(i, getbyte(i) | other.getbyte(i)) }
    self
  end

  def bit_or(other)
    dup.bit_or!(other)
  end

  def bit_xor!(other)
    raise ArgumentError, "size mismatch: #{bytesize} != #{other.bytesize}" unless bytesize == other.bytesize
    bytesize.times { |i| setbyte(i, getbyte(i) ^ other.getbyte(i)) }
    self
  end

  def bit_xor(other)
    dup.bit_xor!(other)
  end

  def each_set_bit(order: :msb)
    return enum_for(__method__, order: order) unless block_given?
    len = bytesize
    if order == :lsb
      i = 0
      while i < len
        byte = getbyte(i)
        BIT_POS_TABLE_LSB[byte].each do |pos|
          yield pos + i * 8
        end
        i += 1
      end
    else
      i = len - 1
      while i >= 0
        byte = getbyte(i)
        BIT_POS_TABLE_MSB[byte].each do |pos|
          yield pos + i * 8
        end
        i -= 1
      end
    end
    self
  end

  def set_bit_positions(order: :msb)
    if block_given?
      each_set_bit(order: order) { |n| yield n }
      self
    else
      each_set_bit(order: order).to_a
    end
  end

end
