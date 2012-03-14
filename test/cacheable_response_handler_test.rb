require File.dirname(__FILE__) + "/test_helper"

ActionController::Base.cache_store = :memory_store

class CacheableResponseHandlerTest < MiniTest::Unit::TestCase

  def setup
    @cache_store = stub.tap { |s| s.stubs(read: nil)}
    controller.request.env['HTTP_IF_NONE_MATCH'] = 'deadbeefdeadbeef'
  end

  def controller
    @controller ||= MockController.new
  end

  def handler
    @handler ||= Cacheable::CacheableResponseHandler.new(controller) do |h|
      h.key_data       = controller.cache_key_data
      h.namespace_data = controller.cache_namespace_data
      h.version_data   = controller.cache_version_data
      h.block          = proc { response.body = 'some text' }
      h.cache_store    = @cache_store
    end
  end

  def page
    [200, "text/html", "<body>hi.</body>", 1331765506]
  end

  def assert_env(expected, key)
    assert_equal expected, controller.request.env[key]
  end

  def test_cache_miss
    handler.run!
    assert_equal 'some text', controller.response.body
    assert_env true, 'cacheable.miss'
  end

  def test_client_cache_hit
    controller.request.env['HTTP_IF_NONE_MATCH'] = handler.versioned_key_hash
    controller.expects(:head).with(:not_modified) 
    handler.run!
    assert_env false, 'cacheable.miss'
    assert_env 'client', 'cacheable.store'
  end

  def test_server_cache_hit
    @cache_store.expects(:read).with(handler.versioned_key_hash).returns(page)
    expect_page_rendered(page)
    handler.run!
    assert_env false,    'cacheable.miss'
    assert_env 'server', 'cacheable.store'
  end

  def test_server_recent_cache_hit
    @controller.stubs(:cache_age_tolerance).returns(999999999999)
    @cache_store.expects(:read).with(handler.unversioned_key_hash).returns(page)
    expect_page_rendered(page)
    Cacheable.expects(:enqueue_cache_rebuild_job).with("http://example.com/")
    handler.run!
    assert_env false,    'cacheable.miss'
    assert_env 'server', 'cacheable.store'
  end

  def test_server_recent_cache_acceptable_but_none_found
    @controller.stubs(:cache_age_tolerance).returns(999999999999)
    handler.run!
    assert_env true, 'cacheable.miss'
    assert_equal 'some text', controller.response.body
  end

  def test_recent_cache_available_but_not_acceptable
    @controller.stubs(:cache_age_tolerance).returns(15)
    @cache_store.expects(:read).with(handler.unversioned_key_hash).returns(page)
    handler.run!
    assert_env true, 'cacheable.miss'
    assert_equal 'some text', controller.response.body
  end

  def test_force_refill_cache
    controller.request.env['HTTP_IF_NONE_MATCH'] = handler.versioned_key_hash
    @cache_store.stubs(:read).with(handler.versioned_key_hash).returns(page)
    @controller.stubs(force_refill_cache?: true)

    handler.run!
    assert_env true, 'cacheable.miss'
    assert_equal 'some text', controller.response.body
  end

  def expect_page_rendered(page)
    status, content_type, body, timestamp = page
    @controller.expects(:render).with(text: body, status: status)
    @controller.response.headers.expects(:[]=).with('Content-Type', content_type)
  end

end
