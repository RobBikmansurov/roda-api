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

    class << self
      def post_rating(post_id:, rate:)
        post = Post[post_id]
        rating = Rating.new(post_id: post_id, rating: rate)
        return [422, '{"data": { } }'] unless rating.valid?

        rating.save
        post.update(ratings_sum: (post.ratings_sum + rate),
                    ratings_count: (post.ratings_count + 1))
        [200, JSON.dump({
                          "data":
                            { "post_id": post_id.to_s,
                              "rating": post.rating.to_s }
                        })]
      end

      def post_create(params)
        user_id = User.find_by_login_or_create(params['user_login'])

        post = Post.new(
          user_id: user_id,
          title: params['title'],
          content: params['content'],
          ip: params['user_ip']
        )
        return [422, '{"data": { } }'] unless post.valid?

        post.save
        [200, "{\"data\": #{post.to_json}}"]
      end

      def posts_by_rating(rating:, limit: 11)
        return [422, '{"data": {"posts": [ ] } }'] unless RATING_RANGE.include?(rating)

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
        [200, "{\"data\": {\"posts\": [\n#{posts_a} ] } }\n"]
      end

      def with_rating_to_json(post)
        JSON.dump({
                    "post": {
                      "id": post[:id],
                      "rating": "%0.#{RATING_PRECISION}f" % post[:rating],
                      "title": post[:title],
                      "content": post[:content]
                    }
                  })
      end

      def ip_authors
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
                    "id": id,
                    "title": title,
                    "content": content,
                    "rating": rating,
                    "ip": ip,
                    "user": user.to_json
                  }
                })
    end
  end
end

if DB.table_exists?(:users)
  class User < Sequel::Model
    one_to_many :posts

    def self.find_by_login_or_create(login)
      user = User.where(login: login).first
      return user.id unless user.nil?

      user = User.new(login: login)
      return nil unless user.valid?

      user.save
      user.id
    end

    def validate
      super
      validates_presence [:login]
      validates_unique(:login)
    end

    def to_json(*_args)
      JSON.dump({ "id": id, "login": login })
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

    puts r.inspect
    puts r.params

    r.on 'api' do # /api branch
      r.on 'v1' do # /api/v1 branch
        r.on 'posts' do # /api/v1/posts branch
          r.on Integer do |post_id|
            r.put do # PUT /api/v1/posts/:id/ -d {"rate":":rate"}
              response.status, data = Post.post_rating(rate: r.params['rate'].to_i, post_id: post_id)
              "#{data}\n" if response.status == 200
            end
          end

          r.post 'create' do # POST /api/vi/posts/create
            response.status, data = Post.post_create(r.params)
            data if response.status == 200
          end

          r.get 'ip_authors' do # GET /api/v1/posts/ip_authors
            Post.ip_authors
          end

          r.get do # GET /api/v1/posts?rating=4.5&limit=10
            response.status, data = Post.posts_by_rating(rating: r.params['rating'].to_f, limit: r.params['limit'].to_i)
            data if response.status == 200
          end
        end
      end
    end
    r.root do
      '{ "data": "OK" }'
    end
  end
end
