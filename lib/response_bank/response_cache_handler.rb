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
      @env['cacheable.key']             = entity_tag_hash
      @env['cacheable.unversioned-key'] = cache_key_hash

      ResponseBank.log(cacheable_info_dump)

      if @force_refill_cache
        refill_cache
      else
        try_to_serve_from_cache
      end
    end

    def entity_tag_hash
      @entity_tag_hash ||= hash(entity_tag)
    end

    def cache_key_hash
      @cache_key_hash ||= hash(cache_key)
    end

    private

    def hash(key)
      "cacheable:#{Digest::MD5.hexdigest(key)}"
    end

    def entity_tag
      @entity_tag ||= ResponseBank.cache_key_for(key: @key_data, version: @version_data)
    end

    def cache_key
      @cache_key ||= ResponseBank.cache_key_for(key: @key_data)
    end

    def cacheable_info_dump
      log_info = [
        "Raw cacheable.key: #{entity_tag}",
        "cacheable.key: #{entity_tag_hash}",
      ]

      if @env['HTTP_IF_NONE_MATCH']
        log_info.push("If-None-Match: #{@env['HTTP_IF_NONE_MATCH']}")
      end

      log_info.join(', ')
    end

    def try_to_serve_from_cache
      # Etag
      response = serve_from_browser_cache(entity_tag_hash, @env['HTTP_IF_NONE_MATCH'])
      return response if response

      response = serve_from_cache(cache_key_hash, entity_tag_hash, @cache_age_tolerance)
      return response if response

      # non cache hits do not yet have the lock
      ResponseBank.acquire_lock(entity_tag_hash) unless @env['cacheable.locked']

      # No cache hit; this request cannot be handled from cache.
      # Yield to the controller and mark for writing into cache.
      refill_cache
    end

    def serving_from_noncurrent_but_recent_version_acceptable?
      @cache_age_tolerance > 0
    end

    def serve_from_browser_cache(entity_tag, if_none_match)
      if etag_matches?(entity_tag, if_none_match)
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

        # to preserve the unversioned/versioned logging messages from past releases we split the match_entity_tag test
        if match_entity_tag == "*"
          ResponseBank.log("Cache hit: server (unversioned)")
          # page tolerance only applies for versioned + etag mismatch
        elsif etag_matches?(headers['ETag'], match_entity_tag)
          ResponseBank.log("Cache hit: server")
        else
          # cache miss; check to see if any parallel requests already are regenerating the cache
          if ResponseBank.acquire_lock(match_entity_tag)
            # execute if we can get the lock
            @env['cacheable.locked'] = true
            return nil
          elsif stale_while_revalidate?(timestamp, cache_age_tolerance)
            # cache is being regenerated, can we avoid piling on and use a stale version in the interim?
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

    def etag_matches?(entity_tag, if_none_match)
      # Support for Etag variations including:
      # If-None-Match: abc
      # If-None-Match: "abc"
      # If-None-Match: W/"abc"
      # If-None-Match: "abc", "def"
      # If-None-Match: "*"
      return false unless entity_tag
      return false unless if_none_match
      if_none_match == "*" || if_none_match.include?(entity_tag)
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
