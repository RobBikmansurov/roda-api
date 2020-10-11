# frozen_string_literal: true

require 'sequel'
require 'faker'
require 'dotenv/load'

USERS_COUNT = 100
POSTS_COUNT = 200_000
RATINGS_COUNT = POSTS_COUNT / 3
IPS_COUNT = 50

DB = Sequel.connect(adapter: 'postgres',
                    database: ENV['PGDATABASE'],
                    host: '127.0.0.1',
                    user: ENV['PGUSER'],
                    password: ENV['PGPASSWORD'])

started_at = Time.now
puts Time.now
users = DB[:users]
users_ids = []
USERS_COUNT.times { users_ids << users.insert(login: Faker::Internet.unique.username) }
puts "Created #{USERS_COUNT} users by #{(Time.now - started_at).round} sec."

started_at = Time.now
posts = DB[:posts]
ip_addresses = []
IPS_COUNT.times { ip_addresses << Faker::Internet.ip_v4_address }
posts_ids = []
POSTS_COUNT.times do
  id = posts.insert(
    user_id: users_ids.sample,
    title: Faker::Lorem.words(number: rand(3..7)).join(' '),
    content: Faker::Lorem.paragraph(sentence_count: rand(2..5)),
    ip: ip_addresses.sample
  )
  posts_ids << id if rand(10).zero? # 10% posts will have ratings
end
puts "Created #{POSTS_COUNT} posts #{(Time.now - started_at).round} sec."

started_at = Time.now
ratings = DB[:ratings]
RATINGS_COUNT.times do
  ratings.insert(
    post_id: posts_ids.sample,
    rating: rand(1..5)
  )
end
puts "Created #{RATINGS_COUNT} ratings #{(Time.now - started_at).round} sec."

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