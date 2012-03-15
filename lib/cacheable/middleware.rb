module Cacheable
  class Middleware
                   
    def initialize(app, cache_store = nil)
      @app = app
      @cache_store = cache_store
    end  

    def call(env)
      env['cacheable.cache'] = false
      
      status, headers, body = resp = @app.call(env)

      if env['cacheable.cache']
        
        if status == 200 && env['cacheable.miss']
          
          # Flatten down the result so that it can be stored to memcached.              
          if body.is_a?(String)
            body_string = body
          else
            body_string = ""
            body.each { |part| body_string << part }
          end

          # Store result
          cache_data = [status, headers['Content-Type'], body_string, timestamp]
          Cacheable.write_to_cache(env['cacheable.key']) do
            cache.write(env['cacheable.key'], cache_data)
            cache.write(env['cacheable.unversioned-key'], cache_data) if env['cacheable.unversioned-key']
          end
        end

        if status == 200 || status == 304
          headers['ETag'] = env['cacheable.key'] 
        end
        
        # Add X-Cache header 
        miss = env['cacheable.miss']
        x_cache = miss ? 'miss' : 'hit'
        x_cache << ", #{env['cacheable.store']}" if !miss
        headers['X-Cache'] = x_cache
      end
      
      resp    
    end

    def timestamp
      Time.now.to_i
    end
    
    def cache
      @cache_store ||= Rails.cache
    end
      
  end

end