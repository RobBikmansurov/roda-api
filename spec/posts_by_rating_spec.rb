# frozen_string_literal: true

require_relative './test_spec.rb'

class PostsByRatingTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    APP
  end

  def test_ratings_not_in_range
    get '/api/v1/posts?limit=10&rating=0'

    assert last_response.status = 422
    assert_equal last_response.body, ''

    get '/api/v1/posts?limit=10&rating=5.1'

    assert last_response.status = 422
    assert_equal last_response.body, ''
  end

  def test_ratings_ok
    get '/api/v1/posts?limit=10&rating=2'

    assert last_response.ok?
  end

  def test_root
    get '/'
    assert last_response.ok?
    assert_equal last_response.body, '{ "data": "OK" }'
  end
end
