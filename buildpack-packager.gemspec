# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'buildpack/packager/version'

Gem::Specification.new do |spec|
  spec.name          = 'buildpack-packager'
  spec.version       = Buildpack::Packager::VERSION
  spec.authors       = ['Cloud Foundry Buildpacks Team']
  spec.email         = ['cf-buildpacks-eng@pivotal.io']
  spec.summary       = 'Tool that packages your buildpacks based on a manifest'
  spec.description   = 'Tool that packages your buildpacks based on a manifest'
  spec.homepage      = 'https://github.com/cloudfoundry/buildpack-packager'
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.2'

  spec.add_dependency 'activesupport', '~> 4.1.8'
  spec.add_dependency 'kwalify'
  spec.add_dependency 'terminal-table', '~> 1.4.5'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubyzip'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rspec'
end
