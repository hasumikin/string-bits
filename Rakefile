# frozen_string_literal: true

require "rake/extensiontask"
require "rake/testtask"

spec = Gem::Specification.load("string-bits.gemspec")

Rake::ExtensionTask.new("string_bits", spec) do |t|
  t.ext_dir = "ext/string_bits"
  t.lib_dir = "lib/string_bits"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/test_*.rb"]
end

desc "Run benchmarks (baseline vs string_bits, with and without YJIT). Optionally specify a name: rake benchmark[bitmap_font]"
task :benchmark, [:name] => :compile do |_, args|
  yjit_ok = system(RbConfig.ruby, "--yjit", "-e", "exit 0",
                   out: IO::NULL, err: IO::NULL)

  arrow_ok = system(RbConfig.ruby, "-e", "require 'arrow'",
                    out: IO::NULL, err: IO::NULL)

  runs = [["ruby", RbConfig.ruby]]
  runs << ["yjit", "#{RbConfig.ruby} --yjit"] if yjit_ok

  yamls = if args[:name]
    ["benchmark/#{args[:name]}.yaml"]
  else
    Dir["benchmark/*.yaml"].sort
  end

  runs.each do |label, cmd|
    puts "\n=== #{label.upcase} ==="
    yamls.each do |yaml|
      next if File.basename(yaml).start_with?("arrow_red_arrow") && !arrow_ok
      sh "RUBYLIB=#{File.expand_path('lib')} bundle exec benchmark-driver #{yaml} " \
         "--executables '#{label}::#{cmd}' --output faster"
    end
  end

  puts
  sh "#{RbConfig.ruby} benchmark/allocation.rb" unless args[:name]
end

task default: [:compile, :test]
