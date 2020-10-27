# frozen_string_literal: true

require 'net/http'
# require 'uri'

uri = URI.parse('http://localhost:9292/api/v1/posts/ip_authors')
request = Net::HTTP::Get.new(uri)
request.content_type = 'application/json'

req_options = {
  use_ssl: uri.scheme == 'https'
}

response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end

puts response.body
