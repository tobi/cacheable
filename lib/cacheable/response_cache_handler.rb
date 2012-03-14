module Cacheable
  class CacheableResponseHandler
    attr_accessor :key_data, :namespace_data, :version_data, :block
    def initialize(controller)
      @controller = controller
      @env = controller.request.env
      @cache_store = controller.send :cache_store
      @cache_age_tolerance = controller.cache_age_tolerance

      yield self
    end

    def run!
      @env['cacheable.cache']           = true
      @env['cacheable.key']             = versioned_key_hash
      @env['cacheable.unversioned-key'] = unversioned_key_hash

      Cacheable.log cacheable_info_dump

      # We'll throw cache_hit when we've served the request. 
      # if cache_hit isn't thrown, we will execute the whole block, 
      # and get to run_controller_action! on the last line.
      catch :cache_hit do
        try_to_serve_from_cache unless @controller.force_refill_cache?
        
        @env['cacheable.miss'] = true
        run_controller_action! # Yield to the block; this request cannot be handled from cache
      end
    end

    private

    def run_controller_action!
      @controller.instance_eval(&@block)
    end

    def versioned_key_hash
      @versioned_key_hash ||= key_hash(versioned_key)
    end

    def unversioned_key_hash
      @unversioned_key_hash ||= key_hash(unversioned_key)
    end

    def key_hash(key)
      %("#{Digest::MD5.hexdigest(key)}") 
    end

    def versioned_key
      @versioned_key ||= Cacheable.cache_key_for(namespace: namespace_data, key: key_data, version: version_data)
    end

    def unversioned_key
      @unversioned_key ||= Cacheable.cache_key_for(namespace: namespace_data, key: key_data)
    end

    def cacheable_info_dump
      [
        "Raw cacheable.key: #{versioned_key}",
        "cacheable.key: #{versioned_key_hash}",
        "Raw cacheable.unversioned-key: #{unversioned_key}",
        "cacheable.unversioned-key: #{unversioned_key_hash}",
        "If-None-Match: #{@env['HTTP_IF_NONE_MATCH']}"
      ].join(", ")
    end

    def try_to_serve_from_cache
      try_to_serve_from_current_cache

      if serving_from_noncurrent_but_recent_version_acceptable?
        try_to_serve_from_recent_cache
      end
    end

    def try_to_serve_from_current_cache
      try_to_serve_from_client_cache versioned_key
      try_to_serve_from_server_cache versioned_key
    end

    def try_to_serve_from_recent_cache
      tolerance = @cache_age_tolerance
      try_to_serve_from_server_cache(unversioned_key, tolerance, "Cache hit: server (recent)")
    end

    def serving_from_noncurrent_but_recent_version_acceptable?
      @controller.cache_age_tolerance > 0
    end

    def try_to_serve_from_client_cache(cache_key_hash, message = "Cache hit: client")
      if @env["HTTP_IF_NONE_MATCH"] == cache_key_hash
        @env['cacheable.miss']  = false
        @env['cacheable.store'] = 'client'
        head :not_modified
        
        Cacheable.log message
        throw :cache_hit
      end
    end

    def try_to_serve_from_server_cache(cache_key_hash, cache_age_tolerance=nil, message = "Cache hit: server")
      if hit = @cache_store.read(cache_key_hash)
        @env['cacheable.miss']  = false
        @env['cacheable.store'] = 'server'
      
        status, content_type, body, timestamp = hit

        if cache_age_tolerance && timestamp < (Time.now.to_i - cache_age_tolerance)
          Cacheable.log "Found an unversioned cache entry, but it was too old (#{timestamp})"
        else
          Cacheable.log message
          
          response.headers['Content-Type'] = content_type
          render text: body, status: status
          throw :cache_hit
        end
      end
    end

  end
end