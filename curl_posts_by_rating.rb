# frozen_string_literal: true

require 'net/http'
require 'uri'

uri = URI.parse('http://localhost:9292/api/v1/posts?rating=3.75')
response = Net::HTTP.get_response(uri)

puts response.code
puts response.body
