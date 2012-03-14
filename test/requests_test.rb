require File.dirname(__FILE__) + "/test_helper"

ActionController::Base.cache_store = :memory_store

class MockController < ActionController::Base
  def self.after_filter(*args); end 
  
  def headers; response.headers; end

  def params
    @params ||= {fill_cache: false}
  end
    
  def request
    @request ||= Class.new do 
      def get?; true; end
      def env; @env ||= {'REQUEST_URI' => '/'}; end
      def params; {}; end
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

  include Cacheable::Controller
  
  def cacheable?; true; end
end

class RequestsTest < MiniTest::Unit::TestCase
  
  def setup
    @controller = MockController.new
  end
  
  def test_cache_miss
    @controller.instance_eval do
      response_cache do 
        response.body = 'miss'
      end    
    end
    assert_equal 'miss', @controller.response.body
  end

  def test_client_cache_hit
    skip
  end

  def test_server_cache_hit
    skip
  end

  def test_server_recent_cache_hit
    skip
  end

  def test_server_recent_cache_acceptable_but_failed
    skip
  end

  def test_recent_cache_available_but_not_acceptable
    skip
  end

end
