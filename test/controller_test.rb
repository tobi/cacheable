require File.dirname(__FILE__) + "/test_helper"

class CacheableTest < MiniTest::Unit::TestCase

  class MockRequest
    def get?; true ;end
    def params; {}; end
    def env; {}; end
  end

  class MockController
    include Cacheable::Controller

    def cache_configured?; true ;end
    def params; {}; end
    def request
      MockRequest.new
    end
  end

  def test_middleware_and_controller_use_the_same_cache_store
    m = MockController.new
    Cacheable::ResponseCacheHandler.any_instance.expects(:cache_store=).with(Cacheable.cache_store)
    Cacheable::ResponseCacheHandler.any_instance.expects(:run!)
    m.response_cache
  end
end
