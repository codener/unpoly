# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'unpoly/rails/version'

Gem::Specification.new do |spec|
  spec.name          = "unpoly-rails"
  spec.version       = Unpoly::Rails::VERSION
  spec.authors       = ["Henning Koch"]
  spec.email         = ["henning.koch@makandra.de"]
  spec.description   = 'Rails bindings for Unpoly, the progressive enhancement Javascript framework'
  spec.summary       = spec.description
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'rails', '>= 3'
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
