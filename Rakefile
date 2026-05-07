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

task default: [:compile, :test]
