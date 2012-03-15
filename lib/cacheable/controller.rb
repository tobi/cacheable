module Cacheable
  module Controller
    # Only get? and head? requests should be cacheable 
    def cacheable_request?
      request.get? or request.head? and not request.params[:cache] == 'false'
    end
    
    # Override this method with additonal namespace information
    # which should modifiy the lookup key
    def cache_namespace_data
      {}
    end

    # Override this method with additional information that changes to invalidate the cache.
    def cache_version_data
      {}
    end
    
    def cache_key_data
      {'request' => {'env' => request.env.slice('PATH_INFO', 'QUERY_STRING')}}
    end

    def force_refill_cache?
      params[:fill_cache] == "true"
    end

    # If you're okay with serving pages that are not at the newest version, bump this up
    # to whatever number of seconds you're comfortable with.
    def cache_age_tolerance
      0
    end

    def response_cache(key_data=nil, namespace_data=nil, version_data=nil, &block)
      return yield unless cache_configured? && cacheable_request?
      
      handler = Cacheable::ResponseCacheHandler.new(self) do |h|
        h.key_data       = key_data       || cache_key_data
        h.namespace_data = namespace_data || cache_namespace_data
        h.version_data   = version_data   || cache_version_data
        h.block          = block
        h.cache_store    = cache_store
      end

      handler.run!
    end
  end
end