# frozen_string_literal: true

require_relative './test_spec.rb'

class PostRatingTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    APP
  end

  def test_correct_ratings
    # create new post with rating = 0
    user = DB[:users].order(:id).last
    post_id = DB[:posts].insert(
      user_id: user[:id],
      title: 'TEST_TITLE',
      content: 'TEST_CONTENT',
      ip: '8.8.8.8'
    )

    put "/api/v1/posts/#{post_id}", rate: 1

    assert last_response.ok?
    assert_equal last_response.body, "{\"data\":{\"post_id\":\"#{post_id}\",\"rating\":\"1.0\"}}\n"

    put "/api/v1/posts/#{post_id}", rate: 5

    assert last_response.ok?
    assert_equal last_response.body, "{\"data\":{\"post_id\":\"#{post_id}\",\"rating\":\"3.0\"}}\n"
  end

  def test_wrong_rating
    # create new post with rating = 0
    user = DB[:users].order(:id).last
    post_id = DB[:posts].insert(
      user_id: user[:id],
      title: 'TEST_TITLE',
      content: 'TEST_CONTENT',
      ip: '8.8.8.8'
    )

    put "/api/v1/posts/#{post_id}", rate: 0

    assert last_response.status = 422

    put "/api/v1/posts/#{post_id}", rate: 6

    assert last_response.status = 422
  end

  def test_wring_pots_id
    put '/api/v1/posts/', rate: 1

    assert last_response.status = 422

    put '/api/v1/posts/abc', rate: 1

    assert last_response.status = 422
  end
end
