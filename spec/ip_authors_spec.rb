require "test/unit"
require "rack/test"

require './app.rb'

class IpAuthorsTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    # app = lambda { |env| [200, {'Content-Type' => 'application/json'}, ['All responses are OK']] }
    builder = Rack::Builder.new
    builder.run App
  end

  def test_response_is_ok
    get '/'
    
    assert last_response.ok?
    assert_equal last_response.body, '{ data: OK }'
  end

  def ip_authors_ok
    get 'api/v1/posts/ip_authors'

    assert last_response.ok?
  end
end
