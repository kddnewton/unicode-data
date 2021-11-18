# frozen_string_literal: true

require_relative "lib/unicode/data/version"

version = Unicode::Data::VERSION
repository = "https://github.com/kddnewton/unicode-data"

Gem::Specification.new do |spec|
  spec.name          = "unicode-data"
  spec.version       = version
  spec.authors       = ["Kevin Newton"]
  spec.email         = ["kddnewton@gmail.com"]

  spec.summary       = "A Ruby port of the unicode character data"
  spec.homepage      = repository
  spec.license       = "MIT"

  spec.metadata      = {
    "bug_tracker_uri" => "#{repository}/issues",
    "changelog_uri" => "#{repository}/blob/v#{version}/CHANGELOG.md",
    "source_code_uri" => repository,
    "rubygems_mfa_required" => "true"
  }

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/unicode/data/Rakefile"]

  spec.add_dependency "rubyzip"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
end
