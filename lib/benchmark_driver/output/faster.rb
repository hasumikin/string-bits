# Like BenchmarkDriver::Output::Compare but shows results relative to the baseline (first in YAML).
require "benchmark_driver/output/compare"

class BenchmarkDriver::Output::Faster < BenchmarkDriver::Output::Compare
  private

  def show_results(results, show_context:)
    # Preserve YAML order so baseline is always the reference (first entry)
    reference = results.first
    results.each do |result|
      label = comparison_label(reference, result) if result != reference
      name = show_context ? result.context.name : result.job
      $stdout.printf("%*s: %11.1f %s %s\n", @name_length, name, result.value, @metrics.first.unit, label)
    end
    $stdout.puts
  end

  def comparison_label(reference, result)
    ref_val = reference.value
    res_val = result.value
    return if BenchmarkDriver::Result::ERROR.equal?(ref_val) || BenchmarkDriver::Result::ERROR.equal?(res_val)

    if @metrics.first.larger_better
      if res_val >= ref_val
        sprintf("- %.2fx  faster", res_val / ref_val)
      else
        sprintf("- %.2fx  slower", ref_val / res_val)
      end
    else
      if res_val <= ref_val
        sprintf("- %.2fx  faster", ref_val / res_val)
      else
        sprintf("- %.2fx  slower", res_val / ref_val)
      end
    end
  end
end
