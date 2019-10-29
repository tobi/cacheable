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

  s.rubyforge_project = "cacheable"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "minitest"
  s.add_development_dependency "mocha"
  s.add_development_dependency "rake"
  s.add_development_dependency "rails", ">= 4.2"
  s.add_development_dependency "activesupport"
  s.add_development_dependency "actionpack", ">= 4.1"
  s.add_development_dependency "tzinfo-data", ">= 1.2019.3"

  s.add_runtime_dependency "useragent"
  s.add_runtime_dependency "msgpack"
end
