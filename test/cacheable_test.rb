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

  def test_cache_key_for_handles_nested_everything_and_removes_hash_keys_with_nil_values
    data = {:foo => 'bar', :bar => [1,['a','b'], 2, {:baz => 'buzz'}], 'qux' => {:red => ['blue', 'green'], :day => true, :night => nil, :updated_at => Time.at(1309362467).utc, :published_on => Time.at(1309320000).utc.to_date}, :format => Mime::Type.lookup('text/html')}
    expected = %|{:foo=>\"bar\", :bar=>[1, [\"a\", \"b\"], 2, {:baz=>\"buzz\"}], \"qux\"=>{:red=>[\"blue\", \"green\"], :day=>true, :night=>nil, :updated_at=>2011-06-29 15:47:47 UTC, :published_on=>Wed, 29 Jun 2011}, :format=>text/html}|
    assert_equal expected, Cacheable.cache_key_for(data)
  end

  def test_middleware_and_controller_use_the_same_cache_store
    m = MockController.new
    Cacheable::ResponseCacheHandler.any_instance.expects(:cache_store=).with(Cacheable.cache_store)
    Cacheable::ResponseCacheHandler.any_instance.expects(:run!)
    m.response_cache
  end
end
