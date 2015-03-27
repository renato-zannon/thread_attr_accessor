# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'thread_attr_accessor/version'

Gem::Specification.new do |spec|
  spec.name          = "thread_attr_accessor"
  spec.version       = ThreadAttrAccessor::VERSION
  spec.authors       = ["Renato Zannon"]
  spec.email         = ["zannon@tn.com.br"]

  spec.summary       = %q{A thread-aware module-level attr_accessor}
  spec.homepage      = "https://github.com/tecnologiaenegocios/thread_attr_accessor"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.1.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = []
  spec.require_paths = ["lib"]

  spec.add_dependency "hamster", "~> 1.0"

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
