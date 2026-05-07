# frozen_string_literal: true
#
# Benchmark: bitmap font rendering to framebuffer (shift & mask)
#
# Simulates reading glyph bitmaps from a packed 1bpp font table and
# writing lit pixels to a framebuffer -- the inner loop typical in
# PicoRuby / mruby display drivers.
#
# Layout: 256 glyphs * 8px wide * 16px tall = 4096 bytes of font data.
# Screen: TEXT_LEN * GLYPH_W wide, GLYPH_H tall (single text row).
# For each character, extract the glyph and write each lit pixel to FRAMEBUFFER
# at its (row, col) screen position.
# Each iteration uses a different pre-generated text string (varied data).
#
# Pure Ruby: getbyte per row, (byte >> col) & 1 per column, setbyte to FB.
# string-bits gem: bit_slice per glyph, each_set_bit to walk lit pixels, setbyte to FB.
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/bitmap_font.rb

require_relative "runner"

GLYPH_W    = 8
GLYPH_H    = 16
GLYPH_BITS = GLYPH_W * GLYPH_H  # 128 bits per glyph
CHARS      = 256
FONT_BYTES = CHARS * GLYPH_H    # 4096 bytes

TEXT_LEN   = 2_000
SCREEN_W   = TEXT_LEN * GLYPH_W  # 16,000 px wide
ITERATIONS = 100

SETUP = <<~RUBY
  GLYPH_W    = #{GLYPH_W}
  GLYPH_H    = #{GLYPH_H}
  GLYPH_BITS = #{GLYPH_BITS}
  SCREEN_W   = #{SCREEN_W}
  FONT       = Random.bytes(#{FONT_BYTES})
  FRAMEBUFFER = (0.chr * (#{SCREEN_W} * #{GLYPH_H})).b
  TEXTS = Array.new(#{ITERATIONS}) { Random.bytes(#{TEXT_LEN}) }
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def run(text)
    text.each_byte.with_index do |code, char_idx|
      x_base = char_idx * GLYPH_W
      base   = code * GLYPH_H
      GLYPH_H.times do |row|
        byte    = FONT.getbyte(base + row)
        row_off = row * SCREEN_W + x_base
        GLYPH_W.times do |col|
          FRAMEBUFFER.setbyte(row_off + col, 1) if (byte >> col) & 1 == 1
        end
      end
    end
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{BenchmarkRunner::LIB_PATH.inspect}
  require "string_bits"
  def run(text)
    text.each_byte.with_index do |code, char_idx|
      x_base = char_idx * GLYPH_W
      glyph  = FONT.bit_slice(code * GLYPH_BITS, GLYPH_BITS)
      glyph.each_set_bit(order: :lsb) do |n|
        FRAMEBUFFER.setbyte(n / GLYPH_W * SCREEN_W + x_base + n % GLYPH_W, 1)
      end
    end
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { |i| run(TEXTS[i]) }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  TEXTS.each { |text| run(text) }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

BenchmarkRunner.run(
  title:       "Bitmap font rendering to framebuffer (shift & mask, varied data)",
  description: "#{CHARS} glyphs x #{GLYPH_W}x#{GLYPH_H}px | Screen: #{SCREEN_W}x#{GLYPH_H} | #{TEXT_LEN} chars x #{ITERATIONS} iterations",
  configs:     { "Pure Ruby" => PURE_RUBY_SCRIPT, "string-bits gem" => GEM_SCRIPT },
  runner:      RUNNER_SCRIPT,
  iterations:  ITERATIONS
)
