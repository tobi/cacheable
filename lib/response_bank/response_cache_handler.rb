# frozen_string_literal: true
require 'digest/md5'

module ResponseBank
  class ResponseCacheHandler
    def initialize(
      key_data:,
      version_data:,
      env:,
      cache_age_tolerance:,
      serve_unversioned:,
      headers:,
      force_refill_cache: false,
      cache_store: ResponseBank.cache_store,
      &block
    )
      @cache_miss_block = block

      @key_data = key_data
      @version_data = version_data
      @env = env
      @cache_age_tolerance = cache_age_tolerance

      @serve_unversioned = serve_unversioned
      @force_refill_cache = force_refill_cache
      @cache_store = cache_store
      @headers = headers || {}
    end

    def run!
      @env['cacheable.cache']           = true
      @env['cacheable.key']             = versioned_key_hash
      @env['cacheable.unversioned-key'] = unversioned_key_hash

      ResponseBank.log(cacheable_info_dump)

      if @force_refill_cache
        refill_cache
      else
        try_to_serve_from_cache
      end
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
      @versioned_key ||= ResponseBank.cache_key_for(key: @key_data, version: @version_data)
    end

    def unversioned_key
      @unversioned_key ||= ResponseBank.cache_key_for(key: @key_data)
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
      response = serve_from_browser_cache(versioned_key_hash)
      return response if response

      response = serve_from_cache(unversioned_key_hash, versioned_key_hash, @cache_age_tolerance)
      return response if response

      ResponseBank.acquire_lock(versioned_key_hash) unless @env['cacheable.locked']

      # No cache hit; this request cannot be handled from cache.
      # Yield to the controller and mark for writing into cache.
      refill_cache
    end

    def serving_from_noncurrent_but_recent_version_acceptable?
      @cache_age_tolerance > 0
    end

    def serve_from_browser_cache(cache_key_hash)
      # Support for Etag variations including:
      # If-None-Match: abc
      # If-None-Match: "abc"
      # If-None-Match: W/"abc"
      # If-None-Match: "abc", "def"
      if !@env["HTTP_IF_NONE_MATCH"].nil? && @env["HTTP_IF_NONE_MATCH"].include?(cache_key_hash)
        @env['cacheable.miss']  = false
        @env['cacheable.store'] = 'client'

        @headers.delete('Content-Type')
        @headers.delete('Content-Length')

        ResponseBank.log("Cache hit: client")

        [304, @headers, []]
      end
    end

    def serve_from_cache(cache_key_hash, match_entity_tag = "*", cache_age_tolerance = nil)
      raw = ResponseBank.read_from_backing_cache_store(@env, cache_key_hash, backing_cache_store: @cache_store)

      if raw
        hit = MessagePack.load(raw)

        @env['cacheable.miss']  = false
        @env['cacheable.store'] = 'server'

        status, headers, body, timestamp, location = hit

        # polyfill headers for legacy versions
        headers = { 'Content-Type' => headers.to_s } if headers.is_a? String
        headers['Location'] = location if location

        @env['cacheable.locked'] ||= false
        if match_entity_tag == "*"
          ResponseBank.log("Cache hit: server (unversioned)")
          # page tolerance only applies for versioned + etag mismatch
        elsif headers['ETag'] == match_entity_tag
          ResponseBank.log("Cache hit: server")
        else
          # cache miss
          if ResponseBank.acquire_lock(match_entity_tag)
            # execute if we can get the lock
            @env['cacheable.locked'] = true
            return nil
          elsif stale_while_revalidate?(timestamp, cache_age_tolerance)
            ResponseBank.log("Cache hit: server (recent)")
          else
            ResponseBank.log("Found an unversioned cache entry, but it was too old (#{timestamp})")
            return nil
          end
        end


        # version check
        # unversioned but tolerance threshold
        # regen
        @headers['Content-Type'] = headers['Content-Type']
        @headers['Location'] = headers['Location'] if headers['Location']

        if @env["gzip"]
          @headers['Content-Encoding'] = "gzip"
        else
          # we have to uncompress because the client doesn't support gzip
          ResponseBank.log("uncompressing for client without gzip")
          body = ResponseBank.decompress(body)
        end

        [status, @headers, [body]]
      end
    end

    def stale_while_revalidate?(timestamp, cache_age_tolerance)
      return false if !cache_age_tolerance
      return false if !timestamp

      timestamp >= (Time.now.to_i - cache_age_tolerance)
    end

    def refill_cache
      @env['cacheable.miss'] = true

      ResponseBank.log("Refilling cache")

      @cache_miss_block.call
    end
  end
end
