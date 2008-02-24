require File.dirname(__FILE__) + '/lib/cache'
require File.dirname(__FILE__) + '/lib/cacheable'

# Include the cacheable model in action controller so that the cache method is available.
ActionController::Base.send(:include, Cacheable)

# Load cache configuration from database.yml
if config = ActiveRecord::Base.configurations[RAILS_ENV]['cache']
  Cache.establish_connection(config)
else
  fail "Could not find cache: section in your database.yml" 
end