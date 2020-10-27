# frozen_string_literal: true

require 'sequel'
require 'faker'
require 'dotenv/load'
require 'net/http'
require 'json'

#request = Net::HTTP::Get.new(uri)
#response = Net::HTTP.get_response(uri)


def curl_put(url, json)
  uri = URI.parse(url)
  request = Net::HTTP::Put.new(uri)
  request.content_type = "application/json"
  request.body = json

  Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
end

def curl_post(url, json)
  uri = URI.parse(url)
  request = Net::HTTP::Post.new(uri)
  request.content_type = "application/json"
  request.body = json

  Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
end

def post_rate(post_id, rate)
  curl_put("http://localhost:9292/api/v1/posts/#{post_id}",
    JSON.dump({
      "rate" => rate
    })
  )
end

USERS_COUNT = 100
POSTS_COUNT = 10 #200_000
RATINGS_COUNT = POSTS_COUNT / 3
IPS_COUNT = 50

DB = Sequel.connect(adapter: 'postgres',
                    database: ENV['PGDATABASE'],
                    host: '127.0.0.1',
                    user: ENV['PGUSER'],
                    password: ENV['PGPASSWORD'])

started_at = Time.now
puts Time.now
user_logins = Array.new(USERS_COUNT) { Faker::Internet.unique.username }.uniq
puts "Created #{USERS_COUNT} users by #{(Time.now - started_at).round} sec."

started_at = Time.now
posts = DB[:posts]
ip_addresses = []
IPS_COUNT.times { ip_addresses << Faker::Internet.ip_v4_address }
posts_ids = []
POSTS_COUNT.times do
  response = curl_post("http://localhost:9292/api/v1/posts/create",
    JSON.dump({
      "title" => Faker::Lorem.words(number: rand(3..7)).join(' '),
      "content" => Faker::Lorem.paragraph(sentence_count: rand(2..5)),
      "user_login" => user_logins.sample,
      "user_ip" => ip_addresses.sample
    })
  )
  
  # 10% posts will have rating
  post_id = JSON.parse(response.body)["data"]["post"]["id"].to_i
  post_rate(post_id, rand(1..5)) if rand(10).zero?
end
puts "Created #{POSTS_COUNT} posts #{(Time.now - started_at).round} sec."

# recalculate posts rating
DB << <<-SQL
  update posts 
  set 
    ratings_sum=rat.sum, 
    ratings_count=rat.count 
  from (
    select post_id, sum(rating) sum, count(id) count 
    from ratings 
    group by post_id)
  AS rat 
  where rat.post_id = posts.id;
SQL
puts Time.now