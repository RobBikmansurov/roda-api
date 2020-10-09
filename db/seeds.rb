# frozen_string_literal: true

require 'sequel'
require 'faker'

DB = Sequel.connect(adapter: 'postgres', database: 'api', host: '127.0.0.1', user: 'api', password: 'api_pwd')
users = DB[:users]
100.times { users.insert(login: Faker::Internet.unique.username) }
puts "Created #{users.count} users."

