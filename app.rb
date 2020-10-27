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

if DB.table_exists?(:posts)
  class Post < Sequel::Model
    many_to_one :user

    def self.post_rating(post_id:, rate:)
      post = Post[post_id]
      rating = Rating.new(post_id: post.id, rating: rate)
      if rating.valid?
        rating.save
        post.update(ratings_sum: (post.ratings_sum + rate),
                    ratings_count: (post.ratings_count + 1))
        JSON.dump({
                    "data":
                      { "post_id": post.id.to_s,
                        "rating": post.rating.to_s }
                  })
      end
    end

    def self.post_create(params)
      user_id = User.find_by_login_or_create(params['user_login'])

      post = Post.new(
        user_id: user_id,
        title: params['title'],
        content: params['content'],
        ip: params['user_ip']
      )
      if post.valid?
        post.save
        "{\"data\": #{post.to_json}}"
      end
    end

    def self.posts_by_rating(rating:, limit:)
      query = <<-SQL
        select id, round(ratings_sum * 1.0 / ratings_count, 3) rating, title, content
        from posts 
        where ratings_count > 0 
          and round(ratings_sum * 1.0 / ratings_count, 5)::VARCHAR 
          like '#{rating}%'
      SQL
      query += " limit #{limit}" if limit.positive?
      posts = DB.fetch(query)
      posts_a = posts.map do |post|
        Post.with_rating_to_json(post)
      end.join(",\n")

      "{\"data\": {\"posts\": [\n#{posts_a} ] } }\n"
    end

    def self.with_rating_to_json(post)
      puts post
      JSON.dump({
                  "post": {
                    "id": (post[:id]).to_s,
                    "rating": ("%0.#{RATING_PRECISION}f" % post[:rating]).to_s,
                    "title": (post[:title]).to_s,
                    "content": (post[:content]).to_s
                  }
                })
    end

    def self.ip_authors
      query = <<-SQL
        select ip, array_agg(login) authors, count(*) 
        from (
          select ip, user_id 
          from posts 
          group by ip, user_id
        ) p
        JOIN users ON p.user_id=users.id 
        group by ip 
        HAVING p.count > 1;
      SQL
      ips_array = DB.fetch(query).map { |ip| "{\"ip\": \"#{ip[:ip]}\", \"authors\": #{ip[:authors]}}" }.join(",\n")

      "{\"data\": {\"ips\": [\n#{ips_array} ] }}\n"
    end

    def validate
      super
      validates_presence %i[title content user_id ip]
    end

    def rating
      return 0 unless ratings_count.positive?

      (ratings_sum / ratings_count.to_f).round(RATING_PRECISION)
    end

    def to_json(*_args)
      JSON.dump({
                  "post": {
                    "id": id.to_s,
                    "title": title.to_s,
                    "content": content.to_s,
                    "rating": rating.to_s,
                    "ip": ip.to_s,
                    "user": user.to_json
                  }
                })
    end
  end
end

if DB.table_exists?(:users)
  class User < Sequel::Model
    one_to_many :posts

    def validate
      super
      validates_presence [:login]
      validates_unique(:login)
    end

    def self.find_by_login_or_create(login)
      user = User.where(login: login).first
      return user.id unless user.nil?

      user = User.new(login: login)
      return nil unless user.valid?

      user.save
      user.id
    end

    def to_json(*_args)
      JSON.dump({ "id": id.to_s, "login": login.to_s })
    end
  end
end

if DB.table_exists?(:ratings)
  class Rating < Sequel::Model
    one_to_many :posts

    def validate
      super
      validates_presence %i[post_id rating]
      validates_includes RATING_RANGE, :rating
    end
  end
end

class App < Roda
  plugin :all_verbs
  plugin :json_parser
  Sequel::Model.plugin :validation_helpers

  route do |r|
    response['Content-Type'] = 'application/json'

    # puts r.inspect
    # puts r.params

    r.root do
      '{ data: OK }'
    end

    r.on 'api' do # /api branch
      r.on 'v1' do # /api/v1 branch
        r.on 'posts' do # /api/v1/posts branch
          r.on Integer do |post_id|
            r.put do # PUT /api/v1/posts/:id/ -d {"rate":":rate"}
              Post.post_rating(rate: r.params['rate'].to_i, post_id: post_id)
            end
          end

          r.post 'create' do # POST /api/vi/posts/create
            Post.post_create(r.params)
          end

          r.get 'ip_authors' do # GET /api/v1/posts/ip_authors
            Post.ip_authors
          end

          r.get do # GET /api/v1/posts?rating=4.5&limit=10
            Post.posts_by_rating(rating: r.params['rating'], limit: r.params['limit'].to_i)
          end
        end
      end
    end
  end
end
