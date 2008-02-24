require File.dirname(__FILE__) + '/vendor/memcache'

module Cache
  
  module Adapters
    class NoCache
      def set(key, value, expiry)
      end
      def get(key)
      end
      
      def inspect
        'No Cache'
      end      
    end
    
    class MemoryCache      
      def initialize
        $cache = {}
      end
      
      def set(key, value, expiry)
        $cache[key] = Marshal.dump(value)
      end
      
      def get(key)
        Marshal.load($cache[key]) if $cache.has_key?(key)
      end
      
      def inspect
        'Memory Cache'
      end
    end
  end
  
  mattr_accessor :adapter
  self.adapter = Adapters::NoCache.new
  
  def self.establish_connection(config)
    self.adapter = case config['adapter']
    when 'memory'    
      Adapters::MemoryCache.new
    when 'memcached'
      MemCache.new(config['servers'], :namespace => config['namespace'] || 'cacheable')
    else
      Adapters::NoCache.new
    end
    
    RAILS_DEFAULT_LOGGER.info "** Using cache: #{adapter.inspect}"
  end
  
  def self.get(key, expiry = 0)
    if result = adapter.get(key) 
      return result
    end
      
    if block_given?
      block_result = yield          
      set(key, block_result, expiry)
      return block_result
    end 
    
    return nil
  rescue MemCache::MemCacheError 
    nil
  end
  
  def self.set(key, value, expiry = 0)
    adapter.set(key, value, expiry) 
    true
  rescue MemCache::MemCacheError 
    false
  end
  
  def self.stats
    adapter.respond_to?(:stats) ? adapter.stats : {} 
  rescue MemCache::MemCacheError 
    {}
  end 
   
  def self.flush_all
    adapter.respond_to?(:flush_all) ? adapter.flush_all : false
  rescue MemCache::MemCacheError 
    false
  else
    true
  end
  
end