require 'test/unit'
require 'rubygems'
require 'active_support'
require 'mocha'
require File.dirname(__FILE__) + '/../lib/cache'
require File.dirname(__FILE__) + '/../lib/cacheable'

class MockController  
  def self.after_filter(*args); end 
  
  def headers; response.headers; end
  
  def request
    @request ||= Class.new do 
      def get?; true; end
      def env; @env ||= {'REQUEST_URI' => '/'}; end
    end.new
  end
  
  def response
    @response ||= Class.new do 
      attr_accessor :body
      def headers; @headers ||= { 'Status' => 200, 'Content-Type' => 'text/html' }; end
    end.new    
  end
  
  def logger
    Class.new { def info(a); end }.new
  end
  
  include Cacheable
  
  def cacheable?; true; end
end

class RequestsTest < Test::Unit::TestCase
  
  def setup
    @controller = MockController.new
  end
  
  def test_cache_miss
    @controller.cache do 
      @controller.response.body = 'miss'
    end    
    assert_equal 'miss', @controller.response.body
  end

  def test_etag_cache_hit
    @controller.expects(:head).with(:not_modified)    
    @controller.request.env['HTTP_IF_NONE_MATCH'] = computed_hash_key
    
    @controller.cache do 
      @controller.response.body = 'miss'
    end
    
    assert_equal 'hit: client', @controller.response.headers['X-Cache']
  end

  def test_memory_cache_hit
    Cache.stubs(:get).with(computed_hash_key).returns(cache_entry('hit'))
    @controller.expects(:render_text).with('hit', 200)    
        
    @controller.cache do 
      @controller.response.body = 'miss'
    end
    
    assert_equal 'text/html',   @controller.response.headers['Content-Type']
    assert_equal 'hit: server', @controller.response.headers['X-Cache']
  end

  def test_memory_cache_hit_with_gzip_support
    GZip.expects(:decompress).times(0)
    Cache.stubs(:get).with(computed_hash_key).returns(cache_entry('hit'))        
    @controller.expects(:render_text).with(GZip.compress('hit'), 200)    
    
    @controller.request.env['HTTP_ACCEPT_ENCODING'] = 'deflate, gzip'
        
    @controller.cache do 
      @controller.response.body = 'miss'
    end
    
    assert_equal 'gzip',        @controller.response.headers['Content-Encoding']
    assert_equal 'text/html',   @controller.response.headers['Content-Type']
    assert_equal 'hit: server', @controller.response.headers['X-Cache']
  end

  def test_store_on_cache_miss
    Cache.expects(:set)
    @controller.response.body = 'hit'
    @controller.instance_variable_set('@cache_miss', true)
    @controller.instance_variable_set('@cache_key_hash', computed_hash_key)    
    @controller.update_cache    
    assert_equal 'hit', @controller.response.body
  end

  def test_store_on_cache_miss_on_gzip_request
    Cache.expects(:set)
    @controller.request.env['HTTP_ACCEPT_ENCODING'] = 'deflate, gzip'
    @controller.response.body = 'hit'
    @controller.instance_variable_set('@cache_miss', true)
    @controller.instance_variable_set('@cache_key_hash', computed_hash_key)    
    @controller.update_cache    

    assert_equal 'gzip', @controller.response.headers['Content-Encoding']
    assert_equal GZip.compress('hit'), @controller.response.body
  end

  def test_no_store_of_failed_requests
    Cache.expects(:set).times(0)
    @controller.response.headers['Status'] = 500
    @controller.update_cache        
  end

  def test_no_store_of_unmodified_requests
    Cache.expects(:set).times(0)
    @controller.response.headers['Status'] = 304
    @controller.update_cache        
  end
    
  
  private
  
  def computed_hash_key
    '6666cd76f96956469e7be39d750cc7d9'
  end
  
  def cache_entry(html)
    [200, 'text/html', GZip.compress(html)]
  end

end
