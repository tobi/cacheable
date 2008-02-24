require 'test/unit'
require File.dirname(__FILE__) + '/../lib/gzip'

class RequestsTest < Test::Unit::TestCase
  # Replace this with your real tests.

  def test_recompress
    assert_equal 'testing', GZip.decompress(GZip.compress('testing'))
  end
  
  def test_compress_short_string
    assert_equal 'testing', GZip.decompress(short_compressed_string)
  end
  
  def test_compress_long_string
    assert_not_equal long_string, GZip.compress(long_string)
    assert_equal long_string, GZip.decompress(GZip.compress(long_string))
  end
  
  def test_sizes
    assert_equal 1338, long_string.size  
    assert_equal 297, GZip.compress(long_string).size  

    assert_equal 446, medium_string.size  
    assert_equal 282, GZip.compress(medium_string).size      
  end
  
  
  def medium_string
    "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
  end
  
  def long_string
    "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." +
    "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." +
    "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."     
  end
  
  
  def short_compressed_string
    "\037\213\010\000\247Q\220F\000\003+I-.\311\314K\a\000\006Z\363\350\a\000\000\000"
  end
end
