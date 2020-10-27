# frozen_string_literal: true

require 'test/unit'
require 'rack/test'

require './app.rb'

class PostRatingsTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    # app = lambda { |env| [200, {'Content-Type' => 'application/json'}, ['All responses are OK']] }
    builder = Rack::Builder.new
    builder.run App
  end

  def empty_ratings_ok
    get '/api/v1/posts'
    #            rating = r.params['rating']
    #        limit = r.params['limit'].to_i'

    assert last_response.ok?
    assert_equal last_response.body, "{ data: { posts: [  ] } }\n"
  end
end
