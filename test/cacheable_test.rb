require File.dirname(__FILE__) + "/test_helper"

class CacheableTest < MiniTest::Unit::TestCase
  def setup
    @data = {:foo => 'bar', :bar => [1,['a','b'], 2, {:baz => 'buzz'}], 'qux' => {:red => ['blue', 'green'], :day => true, :night => nil, :updated_at => Time.at(1309362467), :published_on => Time.at(1309320000).to_date}, :format => Mime::Type.lookup('text/html')}
  end
  
  def test_cache_key_for_handles_nested_everything_and_removes_hash_keys_with_nil_values
    expected = %|{"qux"=>{:day=>true,:published_on=>1309237200,:red=>["blue","green"],:updated_at=>1309362467},:bar=>[1,["a","b"],2,{:baz=>"buzz"}],:foo=>"bar",:format=>"text/html"}|
    assert_equal expected, Cacheable.cache_key_for(@data)
  end
end
