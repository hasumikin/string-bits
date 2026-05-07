# frozen_string_literal: true
#
# Shared runner for string-bits benchmarks.
# Each benchmark file calls BenchmarkRunner.run(...) with its own scripts.

module BenchmarkRunner
  LIB_PATH = File.expand_path("../lib", __dir__)

  def self.system_info
    info = IO.popen(["uname", "-srm"], err: IO::NULL, &:read).strip
    info.empty? ? RUBY_PLATFORM : info
  rescue
    RUBY_PLATFORM
  end

  def self.yjit_available?
    IO.popen([RbConfig.ruby, "--yjit", "-e", "exit 0"], err: IO::NULL, &:read)
    $?.success?
  rescue
    false
  end

  def self.measure(impl_script, runner_script, yjit:)
    args = [RbConfig.ruby]
    args << "--yjit" if yjit
    args << "-e" << (impl_script + runner_script)
    ms = IO.popen(args, err: IO::NULL, &:read).strip.to_f
    ms.positive? ? ms : nil
  end

  # Run a 2x2 benchmark matrix: (Pure Ruby | gem) x (YJIT off | YJIT on).
  #
  # configs:  { "Pure Ruby" => impl_script, "string-bits gem" => impl_script }
  # runner:   script appended to each impl_script inside the subprocess
  # iterations: integer used only for the header label (timing is in runner)
  def self.run(title:, description:, configs:, runner:, iterations:)
    yjit_ok    = yjit_available?
    yjit_modes = { "YJIT off" => false }.tap { |h| h["YJIT on"] = true if yjit_ok }

    puts title
    puts "#{description} | #{iterations} iterations"
    puts "Ruby #{RUBY_VERSION} | YJIT: #{yjit_ok ? "available" : "not available"} | #{system_info}"
    puts

    results = {}
    configs.each do |name, script|
      results[name] = {}
      yjit_modes.each do |label, flag|
        printf "  %-18s / %-8s  ... ", name, label
        $stdout.flush
        ms = measure(script, runner, yjit: flag)
        results[name][label] = ms
        ms ? printf("%8.1f ms\n", ms) : puts("failed")
      end
    end

    print_matrix(results, yjit_modes, iterations)
  end

  def self.print_matrix(results, yjit_modes, iterations)
    col = 12
    sep = "  " + "-" * (20 + (col + 2) * yjit_modes.size)
    puts
    puts "  Results: total ms for #{iterations} iterations"
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
  end
end
