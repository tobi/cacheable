# ResponseBank [![Build Status](https://secure.travis-ci.org/Shopify/response_bank.png)](http://travis-ci.org/Shopify/response_bank)

### Features

* Serve gzip'd content
* Add ETag and 304 Not Modified headers
* Generational caching
* No explicit expiry

### Support

This gem supports the following versions of Ruby and Rails:

* Ruby 2.4.0+
* Rails 5.0.0+

### Usage

1. include the gem in your Gemfile

```ruby
gem 'response_bank'
```

2. use `#response_cache` method to any desired controller's action

```ruby
class PostsController < ApplicationController
  def show
    response_cache do
      @post = @shop.posts.find(params[:id])
      respond_with(@post)
    end
  end
end
```

3. **(optional)** override custom cache key data. For default, cache key is defined by URL and query string

```ruby
class PostsController < ApplicationController
  before_action :set_shop

  def index
    response_cache do
      @post = @shop.posts
      respond_with(@post)
    end
  end

  def show
    response_cache do
      @post = @shop.posts.find(params[:id])
      respond_with(@post)
    end
  end

  def another_action
    # custom cache key data
    cache_key = {
      action: action_name,
      format: request.format,
      shop_updated_at: @shop.updated_at
      # you may add more keys here
    }
    response_cache cache_key do
      @post = @shop.posts.find(params[:id])
      respond_with(@post)
    end
  end

  # override default cache key data globally per class
  def cache_key_data
    {
      action: action_name,
      format: request.format,
      params: params.slice(:id),
      shop_version: @shop.version
      # you may add more keys here
     }
  end

  def set_shop
    # @shop = ...
  end
end
```

### License

ResponseBank is released under the [MIT License](LICENSE.txt).
