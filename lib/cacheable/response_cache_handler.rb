require 'digest/md5'

module Cacheable
  class ResponseCacheHandler
    def initialize(**kwargs, &block)
      @cache_miss_block = block

      @key_data = kwargs.fetch(:key_data)
      @version_data = kwargs.fetch(:version_data)
      @env = kwargs.fetch(:env)
      @cache_age_tolerance = kwargs.fetch(:cache_age_tolerance)

      @serve_unversioned = kwargs[:serve_unversioned]
      @force_refill_cache = kwargs[:force_refill_cache]
      @cache_store = kwargs[:cache_store] || Cacheable.cache_store
      @headers = kwargs[:headers] || {}
    end

    def run!
      @env['cacheable.cache']           = true
      @env['cacheable.key']             = versioned_key_hash
      @env['cacheable.unversioned-key'] = unversioned_key_hash

      Cacheable.log cacheable_info_dump

      try_to_serve_from_cache unless @force_refill_cache
      return @response if defined?(@response)

      # No cache hit; this request cannot be handled from cache.
      # Yield to the controller and mark for writing into cache.
      @env['cacheable.miss'] = true
      @cache_miss_block.call
    end

    def versioned_key_hash
      @versioned_key_hash ||= key_hash(versioned_key)
    end

    def unversioned_key_hash
      @unversioned_key_hash ||= key_hash(unversioned_key)
    end

    private

    def key_hash(key)
      "cacheable:#{Digest::MD5.hexdigest(key)}"
    end

    def versioned_key
      @versioned_key ||= Cacheable.cache_key_for(key: @key_data, version: @version_data)
    end

    def unversioned_key
      @unversioned_key ||= Cacheable.cache_key_for(key: @key_data)
    end

    def cacheable_info_dump
      log_info = [
        "Raw cacheable.key: #{versioned_key}",
        "cacheable.key: #{versioned_key_hash}",
      ]

      if @env['HTTP_IF_NONE_MATCH']
        log_info.push("If-None-Match: #{@env['HTTP_IF_NONE_MATCH']}")
      end

      log_info.join(', ')
    end

    def try_to_serve_from_cache
      # Etag
      serve_from_browser_cache(versioned_key_hash)

      return if defined?(@response)

      # Memcached
      if @serve_unversioned
        serve_from_cache(unversioned_key_hash, nil, "Cache hit: server (unversioned)")
      else
        serve_from_cache(versioned_key_hash)
      end

      return if defined?(@response)

      # execute if we can get the lock
      execute

      return if defined?(@response)

      # serve a stale version
      if serving_from_noncurrent_but_recent_version_acceptable?
        serve_from_cache(unversioned_key_hash, @cache_age_tolerance, "Cache hit: server (recent)")
      end
    end

    def execute
      @env['cacheable.locked'] ||= false

      if @env['cacheable.locked'] || Cacheable.acquire_lock(versioned_key_hash)
        @env['cacheable.locked'] = true
        @env['cacheable.miss']  = true
        Cacheable.log("Refilling cache")
        @response = @cache_miss_block.call
      end
    end

    def serving_from_noncurrent_but_recent_version_acceptable?
      @cache_age_tolerance > 0
    end

    def serve_from_browser_cache(cache_key_hash)
      if @env["HTTP_IF_NONE_MATCH"] == cache_key_hash
        @env['cacheable.miss']  = false
        @env['cacheable.store'] = 'client'

        @headers.delete('Content-Type')
        @headers.delete('Content-Length')

        Cacheable.log("Cache hit: client")
        @response = [304, @headers, []]
      end
    end

    def serve_from_cache(cache_key_hash, cache_age_tolerance=nil, message = "Cache hit: server")
      if raw = @cache_store.read(cache_key_hash)
        hit = MessagePack.load(raw)

        @env['cacheable.miss']  = false
        @env['cacheable.store'] = 'server'

        status, content_type, body, timestamp, location = hit

        if cache_age_tolerance && page_too_old(timestamp, cache_age_tolerance)
          Cacheable.log "Found an unversioned cache entry, but it was too old (#{timestamp})"
        else
          @headers['Content-Type'] = content_type

          @headers['Location'] = location if location

          if @env["gzip"]
            @headers['Content-Encoding'] = "gzip"
          else
            # we have to uncompress because the client doesn't support gzip
            Cacheable.log "uncompressing for client without gzip"
            body = Cacheable.decompress(body)
          end

          Cacheable.log(message)
          @response = [status, @headers, [body]]
        end
      end
    end

    def page_too_old(timestamp, cache_age_tolerance)
      !timestamp || timestamp < (Time.now.to_i - cache_age_tolerance)
    end
  end
end
