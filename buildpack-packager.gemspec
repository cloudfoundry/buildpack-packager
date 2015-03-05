# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'buildpack/packager/version'

Gem::Specification.new do |spec|
  spec.name          = 'buildpack-packager'
  spec.version       = Buildpack::Packager::VERSION
  spec.authors       = ['Rasheed Abdul-Aziz and Sai To Yeung']
  spec.email         = ['pair+squeedee+syeung@pivotal.io']
  spec.summary       = %q{Tool that packages your buildpacks based on a manifest}
  spec.description   = %q{Tool that packages your buildpacks based on a manifest}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '~> 4.1.8'
  spec.add_dependency 'rspec'
  spec.add_dependency 'kwalify'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubyzip'
end
