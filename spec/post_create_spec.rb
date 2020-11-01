# frozen_string_literal: true

require_relative './test_spec.rb'

class PostCreateTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    APP
  end

  def test_create_ok
    user = DB[:users].order(:id).last
    login = user[:login]

    post '/api/v1/posts/create', title: 'NEW_POST', content: 'CREATE_CONTENT', user_login: login, user_ip: '8.8.8.8'

    assert last_response.ok?
    assert last_response.body.include? 'NEW_POST'
    assert last_response.body.include? 'CREATE_CONTENT'
    assert last_response.body.include? '8.8.8.8'
    assert last_response.body.include? login

    post '/api/v1/posts/create', title: 'NEW_POST', content: 'NEW_CONTENT', user_login: 'new_user', user_ip: '8.8.8.8'
    assert last_response.ok?
    assert last_response.body.include? 'new_user'
  end

  def test_wrong_parameters
    post '/api/v1/posts/create', title: 'CREATE_POST', content: 'CREATE_CONTENT', user_login: '', user_ip: '8.8.8.8'

    assert last_response.status == 422

    post '/api/v1/posts/create', title: '', content: 'CREATE_CONTENT', user_login: 'new_user', user_ip: '8.8.8.8'

    assert last_response.status == 422

    post '/api/v1/posts/create', title: 'CREATE_POST', content: '', user_login: 'new_user', user_ip: '8.8.8.8'

    assert last_response.status == 422
  end
end
