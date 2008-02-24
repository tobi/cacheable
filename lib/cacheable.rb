require 'digest/md5'
require File.dirname(__FILE__) + '/gzip'

module Cacheable
  
  def self.included(base)
    base.after_filter :update_cache
  end
  
  # Override cacheable with extra logic which decides 
  # weather or not we should cache the current action
  def cacheable?
    ActionController::Base.perform_caching
  end
  
  # Only get? and head? requests should be cacheable 
  # 
  def cacheable_request?
    request.get? or request.head?
  end
  
  
  # By default we only cache requests which are answered by
  # a OK header and which weren't cached in first place.
  # TODO: Should be also cache 404s and such things? may reduce more database load yet...
  def cacheable_response?    
    # We only cache successful requests...
    headers['Status'].to_i == 200 
  end
  
  # Override this method with additonal namespace information
  # which should modifiy the lookup key
  def cache_namespace
    ''    
  end
  
  def cache_key
    request.env['REQUEST_URI']
  end
  
  def cache(key = cache_key, namespace = cache_namespace, options = {})
    return yield unless cacheable? && cacheable_request?
    
    @cache_key = "#{namespace}#{key}" 
    @cache_key_hash = Digest::MD5.hexdigest(@cache_key)
    
    
    # Can we save bandwidth by ignoring instructing the 
    # client to simply re-display its local cache?
    if request.env["HTTP_IF_NONE_MATCH"] == @cache_key_hash
      response.headers["X-Cache"] = "hit: client"
      head :not_modified
      return
    end
        
    if hit = Cache.get(@cache_key_hash)
      status, content_type, body = *hit
      
      response.headers['X-Cache'] = 'hit: server'
      response.headers['Content-Type'] = content_type

      if accepts = accept_encoding    
        response.headers['Content-Encoding'] = accepts
        render :text => body, :status => status
      else
        render :text => GZip.decompress(body), :status => status
      end      
    else
      response.headers['X-Cache'] = 'miss'
      @cache_miss = true         
      @cache_expiry = options[:expire] || 0
      
      # Yield to the block, this request cannot be handled from cache
      yield
    end
    
    logger.info "Cache: #{headers['X-Cache']}"
  end
    
  def update_cache
    return unless cacheable? and cacheable_request? and cacheable_response?
    
    headers["ETag"] = @cache_key_hash
    
    # Store a compressed representation of the content in memcached.
    if @cache_miss
      logger.info 'Cache: store'            
      Cache.set @cache_key_hash, [headers['Status'].to_i, headers['Content-Type'], compressed_response], @cache_expiry
    end

    # If the client accepts gzip compressed content thats what it will get
    if accepts = accept_encoding and !response_compressed?
      response.body = compressed_response
      response.headers['Content-Encoding'] = accepts
    end
  end  
  
  private
  
  def response_compressed?
    !response.headers['Content-Encoding'].blank?
  end
  
  def accept_encoding
    request.env['HTTP_ACCEPT_ENCODING'].to_s =~ /(x-gzip|gzip)/  ? $1 : nil
  end    
  
  def compressed_response
    @compressed_response ||= GZip.compress(response.body)
  end
  
end