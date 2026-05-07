# frozen_string_literal: true
#
# Benchmark: bitmap font rendering (shift & mask)
#
# Simulates reading glyph bitmaps from a packed 1bpp font table and
# counting lit pixels -- the shift-and-mask inner loop typical in
# PicoRuby / mruby display drivers.
#
# Layout: 256 glyphs * 8px wide * 16px tall = 4096 bytes of font data.
# For each character in TEXT, extract the 128-bit glyph and count set pixels.
#
# Pure Ruby: getbyte per row, then (byte >> col) & 1 per column.
# string-bits gem: bit_slice per glyph, each_set_bit to walk lit pixels.
#
# (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Usage: ruby docs/benchmark/bitmap_font.rb

LIB_PATH = File.expand_path("../../lib", __dir__)

GLYPH_W    = 8
GLYPH_H    = 16
GLYPH_BITS = GLYPH_W * GLYPH_H  # 128 bits per glyph
CHARS      = 256
FONT_BYTES = CHARS * GLYPH_H    # 4096 bytes

TEXT_LEN   = 2_000
ITERATIONS = 100

font_bytes = Random.bytes(FONT_BYTES).bytes
text_bytes = Random.bytes(TEXT_LEN).bytes

SETUP = <<~RUBY
  GLYPH_W    = #{GLYPH_W}
  GLYPH_H    = #{GLYPH_H}
  GLYPH_BITS = #{GLYPH_BITS}
  FONT = #{font_bytes.inspect}.pack("C*")
  TEXT = #{text_bytes.inspect}.pack("C*")
  ITERATIONS = #{ITERATIONS}
RUBY

PURE_RUBY_SCRIPT = SETUP + <<~'RUBY'
  def run
    count = 0
    TEXT.each_byte do |code|
      base = code * GLYPH_H
      GLYPH_H.times do |row|
        byte = FONT.getbyte(base + row)
        GLYPH_W.times do |col|
          count += (byte >> col) & 1
        end
      end
    end
    count
  end
RUBY

GEM_SCRIPT = SETUP + <<~RUBY
  $LOAD_PATH.unshift #{LIB_PATH.inspect}
  require "string_bits"
  def run
    count = 0
    TEXT.each_byte do |code|
      glyph = FONT.bit_slice(code * GLYPH_BITS, GLYPH_BITS)
      glyph.each_set_bit(order: :lsb) { count += 1 }
    end
    count
  end
RUBY

RUNNER_SCRIPT = <<~'RUBY'
  3.times { run }  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ITERATIONS.times { run }
  puts((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000)
RUBY

def yjit_available?
  IO.popen([RbConfig.ruby, "--yjit", "-e", "exit 0"], err: IO::NULL, &:read)
  $?.success?
rescue
  false
end

def measure(impl_script, yjit:)
  args = [RbConfig.ruby]
  args << "--yjit" if yjit
  args << "-e" << (impl_script + RUNNER_SCRIPT)
  ms = IO.popen(args, err: IO::NULL, &:read).strip.to_f
  ms.positive? ? ms : nil
end

yjit_ok = yjit_available?

puts "Bitmap font rendering benchmark (shift & mask)"
puts "Font: #{CHARS} glyphs x #{GLYPH_W}x#{GLYPH_H}px (#{FONT_BYTES}B) | " \
     "Text: #{TEXT_LEN} chars | #{ITERATIONS} iterations"
puts "Ruby #{RUBY_VERSION} | YJIT: #{yjit_ok ? "available" : "not available"}"
puts

configs   = { "Pure Ruby"       => PURE_RUBY_SCRIPT,
              "string-bits gem" => GEM_SCRIPT }
yjit_modes = { "YJIT off" => false }.tap { |h| h["YJIT on"] = true if yjit_ok }
results   = {}

configs.each do |name, script|
  results[name] = {}
  yjit_modes.each do |label, flag|
    printf "  %-18s / %-8s  ... ", name, label
    $stdout.flush
    ms = measure(script, yjit: flag)
    results[name][label] = ms
    ms ? printf("%8.1f ms\n", ms) : puts("failed")
  end
end

col = 12
sep = "  " + "-" * (20 + (col + 2) * yjit_modes.size)
puts
puts "  Results: total ms for #{ITERATIONS} iterations"
puts
printf "  %-20s", ""
yjit_modes.each_key { |k| printf "  %#{col}s", k }
puts
puts sep
results.each do |name, row|
  printf "  %-20s", name
  yjit_modes.each_key { |k| v = row[k]; v ? printf("  %#{col}.1f", v) : printf("  %#{col}s", "N/A") }
  puts
end
puts sep
printf "  %-20s", "Speedup (x)"
yjit_modes.each_key do |k|
  pr = results["Pure Ruby"][k]
  gm = results["string-bits gem"][k]
  (pr && gm) ? printf("  %#{col}.1f", pr / gm) : printf("  %#{col}s", "N/A")
end
puts
puts
