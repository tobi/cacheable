require 'minitest/autorun'
require 'active_support'
require 'active_support/cache'
require 'active_support/cache/memory_store'
require 'active_support/core_ext/module/deprecation'
require 'action_controller'
require 'mocha'

module Rails
  class Railtie  
    def self.initializer(*) ; end
  end
end

$: << File.expand_path('../lib', __FILE__)
require 'cacheable'

