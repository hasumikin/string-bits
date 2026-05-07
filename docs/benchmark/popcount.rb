# frozen_string_literal: true
#
# Benchmark: String#popcount
#
# Measures 4 configurations:
#   (YJIT off | YJIT on) x (Pure Ruby | string-bits gem)
#
# Pure Ruby baseline: str.bytes.sum { |b| b.to_s(2).count("1") }
#   - allocates a binary string per byte -> O(n) GC pressure
#
# string-bits gem: str.popcount
#   - processes 8 bytes per POPCNT instruction
#
# Usage: ruby docs/benchmark_popcount.rb

LIB_PATH   = File.expand_path("../../lib", __dir__)
ITERATIONS = 200
DATA_SIZE  = 1_000_000  # 1 MB

PURE_RUBY_SCRIPT = <<~'RUBY'
  def run(data, n)
    n.times { data.bytes.sum { |b| b.to_s(2).count("1") } }
  end
RUBY

GEM_SCRIPT = <<~RUBY
  $LOAD_PATH.unshift #{LIB_PATH.inspect}
  require "string_bits"
  def run(data, n)
    n.times { data.popcount }
  end
RUBY

RUNNER_SCRIPT = <<~RUBY
  data = Random.bytes(#{DATA_SIZE})
  run(data, 5)  # warmup
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  run(data, #{ITERATIONS})
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

puts "String#popcount benchmark"
puts "Ruby #{RUBY_VERSION} | #{DATA_SIZE / 1000}KB random data | #{ITERATIONS} iterations"
puts "YJIT: #{yjit_ok ? "available" : "not available"}"
puts

configs = {
  "Pure Ruby"       => PURE_RUBY_SCRIPT,
  "string-bits gem" => GEM_SCRIPT,
}
yjit_modes = { "YJIT off" => false }.tap { |h| h["YJIT on"] = true if yjit_ok }
results = {}

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

# Matrix
col  = 12
sep  = "  " + "-" * (20 + (col + 2) * yjit_modes.size)
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
