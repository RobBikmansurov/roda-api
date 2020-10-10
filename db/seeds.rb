# frozen_string_literal: true

require 'sequel'
require 'faker'

USERS_COUNT = 5
POSTS_COUNT = 20
RATINGS_COUNT = 20

DB = Sequel.connect(adapter: 'postgres', database: 'api', host: '127.0.0.1', user: 'api', password: 'api_pwd')

users = DB[:users]
users_ids = []
USERS_COUNT.times { users_ids << users.insert(login: Faker::Internet.unique.username) }
puts "Created #{USERS_COUNT} users."

posts = DB[:posts]
posts_ids = []
POSTS_COUNT.times do
  id = posts.insert(
    user_id: users_ids.sample,
    title: Faker::Lorem.words(number: rand(3..7)).join(' '),
    content: Faker::Lorem.paragraph(sentence_count: rand(2..5)),
    ip: Faker::Internet.ip_v4_address
  )
  posts_ids << id if rand(10).zero? # 10% posts will have ratings
end
puts "Created #{POSTS_COUNT} posts."

ratings = DB[:ratings]
RATINGS_COUNT.times do
 ratings.insert(
  post_id: posts_ids.sample,
  rating: rand(1..5))
end
puts "Created #{RATINGS_COUNT} ratings."
