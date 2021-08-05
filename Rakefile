# frozen_string_literal: true

lib = File.expand_path("../../../lib", __dir__)
$LOAD_PATH.unshift(lib)

require "bundler/gem_tasks"
require "rake/clean"
require "rake/testtask"
require "unicode/data"

# Make sure we clean up after ourselves if the user runs rake clean.
CLEAN.include(File.join(lib, "unicode/data/derived"))

namespace :ext do
  load "ext/unicode/data/Rakefile"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

namespace :"unicode:data" do
  desc "Generate all of the neccesary derived files"
  task :generate do
    Unicode::Data.generate
  end

  desc "Validate all of the necessary derived files"
  task :validate do
    Unicode::Data.validate
  end
end
