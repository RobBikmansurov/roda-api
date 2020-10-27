# frozen_string_literal: true

require 'net/http'
require 'json'

uri = URI.parse('http://localhost:9292/api/v1/posts/create')
request = Net::HTTP::Post.new(uri)
request.content_type = 'application/json'
request.body = JSON.dump({
                           'title' => 'post title',
                           'content' => 'post_content',
                           'user_login' => 'robby',
                           'user_ip' => '192.168.1.101'
                         })

req_options = {
  use_ssl: uri.scheme == 'https'
}

response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end

puts response.code
puts response.body
