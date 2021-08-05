# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "unicode/data/version"

Gem::Specification.new do |spec|
  spec.name          = "unicode-data"
  spec.version       = Unicode::Data::VERSION
  spec.authors       = ["Kevin Newton"]
  spec.email         = ["kddnewton@gmail.com"]

  spec.summary       = "A Ruby port of the unicode character data"
  spec.homepage      = "https://github.com/kddnewton/unicode-data"
  spec.license       = "MIT"

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
