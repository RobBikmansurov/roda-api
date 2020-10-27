# frozen_string_literal: true

require 'net/http'
require 'json'

def curl(url, json)
  uri = URI.parse(url)
  request = Net::HTTP::Put.new(uri)
  request.content_type = 'application/json'
  request.body = json

  Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
end

response = curl('http://localhost:9292/api/v1/posts/3',
                JSON.dump({
                            'rate' => '3'
                          }))

puts response.code
puts response.body
