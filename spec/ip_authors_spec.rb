# frozen_string_literal: true

class IpAuthorsTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    APP
  end

  def test_ip_authors_ok
    get 'api/v1/posts/ip_authors'

    assert last_response.ok?
  end
end
