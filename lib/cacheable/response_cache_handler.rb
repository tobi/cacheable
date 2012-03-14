module Cacheable
  class CacheableResponseHandler
    attr_accessor :key_data, :namespace_data, :version_data, :block, :cache_store
    def initialize(controller)
      @controller = controller
      @env = controller.request.env
      @cache_age_tolerance = controller.cache_age_tolerance

      yield self if block_given?
    end

    def run!
      @env['cacheable.cache']           = true
      @env['cacheable.key']             = versioned_key_hash
      @env['cacheable.unversioned-key'] = unversioned_key_hash

      Cacheable.log cacheable_info_dump

      # :cache_hit is thrown as soon as we've sent data to the client.
      catch :cache_hit do
        try_to_serve_from_cache unless @controller.force_refill_cache?

        # Nothing was thrown; this request cannot be handled from cache.
        # Yield to the controller and mark for writing into cache.
        @env['cacheable.miss'] = true
        run_controller_action!
      end
    end

    def versioned_key_hash
      @versioned_key_hash ||= key_hash(versioned_key)
    end

    def unversioned_key_hash
      @unversioned_key_hash ||= key_hash(unversioned_key)
    end

    private

    def run_controller_action!
      @controller.instance_eval(&@block)
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
      try_to_serve_from_client_cache versioned_key_hash
      try_to_serve_from_server_cache versioned_key_hash
    end

    # TODO: This totally destroys the elegance of the catch/throw mechanism here.
    # refactor into something better now.
    def try_to_serve_from_recent_cache
      tolerance = @cache_age_tolerance
      catch :cache_hit do
        try_to_serve_from_server_cache(unversioned_key_hash, tolerance, "Cache hit: server (recent)")
        return
      end
      enqueue_cache_rebuild_job
      throw :cache_hit
    end

    def serving_from_noncurrent_but_recent_version_acceptable?
      @controller.cache_age_tolerance > 0
    end

    def try_to_serve_from_client_cache(cache_key_hash)
      if @env["HTTP_IF_NONE_MATCH"] == cache_key_hash
        @env['cacheable.miss']  = false
        @env['cacheable.store'] = 'client'

        cache_hit!("Cache hit: client") do
          head :not_modified
        end
      end
    end

    def try_to_serve_from_server_cache(cache_key_hash, cache_age_tolerance=nil, message = "Cache hit: server")
      if hit = @cache_store.read(cache_key_hash)
        @env['cacheable.miss']  = false
        @env['cacheable.store'] = 'server'
      
        status, content_type, body, timestamp = hit

        if cache_age_tolerance && page_too_old(timestamp, cache_age_tolerance)
          Cacheable.log "Found an unversioned cache entry, but it was too old (#{timestamp})"
        else
          cache_hit!(message) do
            response.headers['Content-Type'] = content_type
            render text: body, status: status
          end
        end
      end
    end

    def enqueue_cache_rebuild_job
      Cacheable.enqueue_cache_rebuild_job(@controller.request.url)
    end

    def page_too_old(timestamp, cache_age_tolerance)
      !timestamp || timestamp < (Time.now.to_i - cache_age_tolerance)
    end

    def cache_hit!(message, &block)
      Cacheable.log message
      @controller.instance_eval(&block)
      throw :cache_hit
    end

  end
end