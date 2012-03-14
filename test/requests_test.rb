require File.dirname(__FILE__) + "/test_helper"

ActionController::Base.cache_store = :memory_store

class RequestsTest < MiniTest::Unit::TestCase

  def controller
    @controller ||= MockController.new
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

  def test_force_refill_cache
    skip
  end

end
