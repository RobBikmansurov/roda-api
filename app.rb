# frozen_string_literal: true

require 'roda'
require 'sequel'
require 'dotenv/load'
require 'json'

RATING_PRECISION = 5
RATING_RANGE = (1..5).freeze

DB = Sequel.connect(adapter: 'postgres',
                    database: ENV['PGDATABASE'],
                    host: '127.0.0.1',
                    user: ENV['PGUSER'],
                    password: ENV['PGPASSWORD'])

class Post < Sequel::Model
  many_to_one :user

  def rating
    return 0 unless ratings_count.positive?

    (ratings_sum / ratings_count.to_f).round(RATING_PRECISION)
  end

  def to_json(*_args)
    "{
      id: #{id},
      title: #{title},
      content: #{content},
      rating: #{rating},
      ip: #{ip},
      user: #{user.to_json}
    }"
  end
end

class User < Sequel::Model
  one_to_many :posts

  def self.find_by_login_or_create(login)
    user = User.where(login: login).first
    return user.id unless user.nil?

    User.create(login: login).id
  end

  def to_json(*_args)
    "{ id: #{id}, login: #{login} }"
  end
end

class Rating < Sequel::Model
  one_to_many :posts
end

class App < Roda
  plugin :all_verbs
  plugin :json_parser

  route do |r|
    response['Content-Type'] = 'application/json'

    puts r.inspect

    r.on 'api' do # /api branch
      r.on 'v1' do # /api/v1 branch
        r.on 'posts' do # /api/v1/posts branch
          r.on Integer do |post_id|
            r.put do # PUT /api/v1/posts/:id/ -d {"rate":":rate"}
              rate = r.params['rate'].to_i
              next unless RATING_RANGE.include?(rate)

              post = Post[post_id]
              next if post.nil?

              Rating.create(post_id: post.id, rating: rate)
              post.update(ratings_sum: (post.ratings_sum + rate),
                          ratings_count: (post.ratings_count + 1))

              "{ data: { post_id: #{post.id}, rating: #{post.rating} }\n"
            end
          end

          r.get do # GET /api/v1/posts?rating=4.5&limit=10
            rating = r.params['rating']
            limit = r.params['limit'].to_i

            query = <<-SQL
              select id, round(ratings_sum * 1.0 / ratings_count, 3) rating, title, content
              from posts 
              where ratings_count > 0 
                and round(ratings_sum * 1.0 / ratings_count, 5)::VARCHAR 
                like '#{rating}%'
            SQL
            query += " limit #{limit}" if limit.positive?

            posts = DB.fetch query
            posts_a = posts.map do |post|
              "{ post_id: #{post[:id]}, rating: %0.#{RATING_PRECISION}f, title: #{post[:title]}, content: #{post[:content]} }" % post[:rating]
            end.join(",\n")

            "{ data: { posts: [ #{posts_a} ] } }\n"
          end

          r.post 'create' do # POST /api/vi/posts/create
            user_id = User.find_by_login_or_create(r.params['user_login'])

            post = Post.create(
              user_id: user_id,
              title: r.params['title'],
              content: r.params['content'],
              ip: r.params['user_ip']
            )
            "{ data: { post: #{post.to_json} } }\n"
          end
        end
      end
    end
  end
end
