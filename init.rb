require File.dirname(__FILE__) + '/lib/cacheable'
require File.dirname(__FILE__) + '/lib/cacheable_response_middleware'

# Include the cacheable model in action controller so that the cache method is available.
ActionController::Base.send(:include, Cacheable)

# Add this to your environment: 
# config.middleware.use 'CacheableResponseMiddleware', Rails.cache


ActiveRecord::Base.class_eval do  
  def self.cache_store
    ActionController::Base.cache_store
  end  

  def cache_store
    ActionController::Base.cache_store
  end  
end
                                                                           
   
   