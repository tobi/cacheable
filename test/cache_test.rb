require 'test/unit'
require 'rubygems'
require 'active_support'
require 'mocha'
require File.dirname(__FILE__) + '/../lib/cache'


class CacheTest   < Test::Unit::TestCase
  
  def setup
    Cache.adapter = Cache::Adapters::MemoryCache.new
  end
   
  def test_cache_set
    assert_equal true, Cache.set('data', 'value')
  end                                            
  
  def test_set_get
    assert_equal true, Cache.set('data', 'value')
    assert_equal 'value', Cache.get('data')    
  end                  
  
  def test_get_miss
    assert_equal nil, Cache.get('data')        
  end
  
  def test_get_set_with_block
       
    assert_equal 'value', Cache.get('data') { 'value' } # Miss, will set the cache
    assert_equal 'value', Cache.get('data') { 'value' } # Hit, will return cache directly
    
  end

end
