require 'digest/md5'

require 'cacheable/middleware'
require 'cacheable/railtie'

module Cacheable

  def self.log(message)
    Rails.logger.info "[Cacheable] #{message}"
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
  
  # Only get? and head? requests should be cacheable 
  # 
  def cacheable_request?
    request.get? or request.head? and not request.params[:cache] == 'false'
  end
  
  # Override this method with additonal namespace information
  # which should modifiy the lookup key
  def cache_namespace_data
    {}
  end
  
  def cache_key_data
    {'request' => {'env' => request.env.slice('PATH_INFO', 'QUERY_STRING')}}
  end

  def try_to_serve_from_client_cache(cache_key_hash, message = "Cache hit: client")
    # Can we save bandwidth by ignoring instructing the 
    # client to simply re-display its local cache?
    if request.env["HTTP_IF_NONE_MATCH"] == cache_key_hash
      request.env['cacheable.miss']  = false
      request.env['cacheable.store'] = 'client'
      head :not_modified
      
      Cacheable.log message
      return true
    end
    false
  end

  def try_to_serve_from_server_cache(cache_key_hash, message = "Cache hit: server")
   if hit = cache_store.read(cache_key_hash)    
      request.env['cacheable.miss']  = false
      request.env['cacheable.store'] = 'server'
    
      status, content_type, body = hit      

      Cacheable.log message
      
      response.headers['Content-Type'] = content_type
      render :text => body, :status => status
      return true
    end
    false
  end
  
  def response_cache(key_data = cache_key_data, namespace_data = cache_namespace_data, options = nil)
    return yield unless cache_configured? && cacheable_request?
    namespaced_key = Cacheable.cache_key_for(:namespace => namespace_data, :key => key_data)
    
    request.env['cacheable.cache'] = true
    request.env['cacheable.key']   = cache_key_hash = %("#{Digest::MD5.hexdigest(namespaced_key)}")
    
    Cacheable.log "Raw cacheable.key: #{namespaced_key}, cacheable.key: #{cache_key_hash}, If-None-Match: #{request.env["HTTP_IF_NONE_MATCH"]}"
        
    return if try_to_serve_from_client_cache(cache_key_hash)
    return if try_to_serve_from_server_cache(cache_key_hash)

    request.env['cacheable.miss'] = true
    yield # Yield to the block, this request cannot be handled from cache
  end
end