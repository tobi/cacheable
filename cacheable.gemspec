# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cacheable/version"

Gem::Specification.new do |s|
  s.name        = "cacheable"
  s.version     = Cacheable::VERSION
  s.license     = "MIT"
  s.authors     = ["Tobias Lütke", "Burke Libbey"]
  s.email       = ["tobi@shopify.com", "burke@burkelibbey.org"]
  s.homepage    = ""
  s.summary     = %q{Simple rails request caching}
  s.description = %q{Simple rails request caching}

  s.files         = Dir["lib/**/*.rb", "README.rdoc", "LICENSE.txt"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 2.4.0"

  s.add_runtime_dependency "useragent"
  s.add_runtime_dependency "msgpack"

  s.add_development_dependency "minitest", ">= 5.13.0"
  s.add_development_dependency "mocha", ">= 1.10.0"
  s.add_development_dependency "rake"
  s.add_development_dependency "rails", ">= 5.0"
  s.add_development_dependency "tzinfo-data", ">= 1.2019.3"
end
