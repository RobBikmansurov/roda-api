# frozen_string_literal: true

require 'benchmark/ips'
require 'sequel'
require 'faker'
require 'dotenv/load'
require 'net/http'
require 'json'

USERS_COUNT = 100
POSTS_COUNT = 100
RATINGS_COUNT = POSTS_COUNT / 3
IPS_COUNT = 50

DB = Sequel.connect(adapter: 'postgres',
                    database: ENV['PGDATABASE'],
                    host: '127.0.0.1',
                    user: ENV['PGUSER'],
                    password: ENV['PGPASSWORD'])

user_logins = DB.fetch("select login from users limit #{USERS_COUNT}").map { |r| r[:login] }
ip_addresses = DB.fetch("select ip from posts group by ip limit #{IPS_COUNT}").map { |r| r[:ip] }
posts_ids = DB.fetch("select id from posts limit #{POSTS_COUNT}").map { |r| r[:id] }

Benchmark.ips do |x|
  # Configure the number of seconds used during
  # the warmup phase (default 2) and calculation phase (default 5)
  x.config(time: 5, warmup: 2)

  x.report('post create') do
    uri = URI.parse('http://localhost:9292/api/v1/posts/create')
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = JSON.dump({
                               'title' => Faker::Lorem.words(number: rand(3..7)).join(' '),
                               'content' => Faker::Lorem.paragraph(sentence_count: rand(2..5)),
                               'user_login' => user_logins.sample,
                               'user_ip' => ip_addresses.sample
                             })
    Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  end

  x.report('post rating') do
    uri = URI.parse('http://localhost:9292/api/v1/posts/' + posts_ids.sample.to_s)
    request = Net::HTTP::Put.new(uri)
    request.content_type = 'application/json'
    request.body = JSON.dump({ 'rate' => rand(1..5) })
    Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  end

  x.report('posts by rating') do
    uri = URI.parse('http://localhost:9292/api/v1/posts?rating=' + rand(1..5).to_s)
    Net::HTTP.get_response(uri)
  end

  x.report('ip with authors') do
    uri = URI.parse('http://localhost:9292/api/v1/posts/ip_authors')
    request = Net::HTTP::Get.new(uri)
    request.content_type = 'application/json'
    Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
  end

  # Compare the iterations per second of the various reports!
  x.compare!
end
