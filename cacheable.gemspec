# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "cacheable"
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tobias L\u{fc}tke", "Burke Libbey"]
  s.date = "2013-09-13"
  s.description = "Simple rails request caching"
  s.email = ["tobi@shopify.com", "burke@burkelibbey.org"]
  s.files = [".travis.yml", "Gemfile", "Gemfile.lock", "README.md", "Rakefile", "cacheable.gemspec", "lib/cacheable.rb", "lib/cacheable/controller.rb", "lib/cacheable/middleware.rb", "lib/cacheable/railtie.rb", "lib/cacheable/response_cache_handler.rb", "lib/cacheable/version.rb", "test/cacheable_test.rb", "test/middleware_test.rb", "test/response_cache_handler_test.rb", "test/test_helper.rb"]
  s.homepage = ""
  s.require_paths = ["lib"]
  s.rubyforge_project = "cacheable"
  s.rubygems_version = "1.8.23"
  s.summary = "Simple rails request caching"
  s.test_files = ["test/cacheable_test.rb", "test/middleware_test.rb", "test/response_cache_handler_test.rb", "test/test_helper.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<minitest>, [">= 0"])
      s.add_development_dependency(%q<mocha>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_runtime_dependency(%q<activesupport>, [">= 0"])
      s.add_runtime_dependency(%q<actionpack>, [">= 0"])
      s.add_runtime_dependency(%q<cityhash>, ["= 0.6.0"])
      s.add_runtime_dependency(%q<useragent>, [">= 0"])
    else
      s.add_dependency(%q<minitest>, [">= 0"])
      s.add_dependency(%q<mocha>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<activesupport>, [">= 0"])
      s.add_dependency(%q<actionpack>, [">= 0"])
      s.add_dependency(%q<cityhash>, ["= 0.6.0"])
      s.add_dependency(%q<useragent>, [">= 0"])
    end
  else
    s.add_dependency(%q<minitest>, [">= 0"])
    s.add_dependency(%q<mocha>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<activesupport>, [">= 0"])
    s.add_dependency(%q<actionpack>, [">= 0"])
    s.add_dependency(%q<cityhash>, ["== 0.6.0"])
    s.add_dependency(%q<useragent>, [">= 0"])
  end
    s.add_dependency(%q<msgpack>, [">= 0"])
end
