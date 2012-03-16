require 'digest/md5'

require 'cacheable/middleware'
require 'cacheable/railtie'
require 'cacheable/response_cache_handler'
require 'cacheable/controller'

module Cacheable

  def self.log(message)
    Rails.logger.info "[Cacheable] #{message}"
  end

  def self.acquire_lock(cache_key)
    raise NotImplementedError, "Override Cacheable.acquire_lock in an initializer."
  end

  def self.write_to_cache(key)
    yield
  end
  
  def self.cache_key_for(data)
    case data
    when Hash
      components = data.inject([]) do |ary, pair|
        ary << "#{cache_key_for(pair.first)}=>#{cache_key_for(pair.last)}" unless pair.last.nil?
        ary
      end
      "{"+ components.sort.join(',') +"}"
    when Array
      "["+ data.map {|el| cache_key_for(el)}.join(',') +"]"
    when Time, DateTime
      data.to_i
    when Date
      data.to_time.to_i
    when true, false, Fixnum, Symbol, String
      data.inspect
    else
      data.to_s.inspect
    end
  end
  
end











