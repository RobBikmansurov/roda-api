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

  def validate
    super
    validates_presence %i[title content user_id ip]
  end

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
    "{ id: #{id}, login: #{login} }"
  end
end

class Rating < Sequel::Model
  one_to_many :posts

  def validate
    super
    validates_presence %i[post_id rating]
    validates_includes RATING_RANGE, :rating
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
              rate = r.params['rate'].to_i
              post = Post[post_id]
              rating = Rating.new(post_id: post.id, rating: rate)
              if rating.valid?
                rating.save
                post.update(ratings_sum: (post.ratings_sum + rate),
                            ratings_count: (post.ratings_count + 1))
                "{ data: { post_id: #{post.id}, rating: #{post.rating} } }\n"
              end
            end
          end

          r.post 'create' do # POST /api/vi/posts/create
            user_id = User.find_by_login_or_create(r.params['user_login'])

            post = Post.new(
              user_id: user_id,
              title: r.params['title'],
              content: r.params['content'],
              ip: r.params['user_ip']
            )

            if post.valid?
              post.save
              "{ data: { post: #{post.to_json} } }\n"
            end
          end

          r.get 'ip_authors' do # GET /api/v1/posts/ip_authors
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
            ips = DB.fetch(query)
            ips_a = ips.map { |ip| "{ ip: #{ip[:ip]}, authors: #{ip[:authors]} }" }.join(",\n")

            "{ data: { ips: [ #{ips_a} ] } }\n"
          end

          r.get do # GET /api/v1/posts?rating=4.5&limit=10
            rating = r.params['rating']
            limit = r.params['limit'].to_i

            puts "#{rating} #{limit}"

            query = <<-SQL
              select id, round(ratings_sum * 1.0 / ratings_count, 3) rating, title, content
              from posts 
              where ratings_count > 0 
                and round(ratings_sum * 1.0 / ratings_count, 5)::VARCHAR 
                like '#{rating}%'
            SQL
            puts query
            query += " limit #{limit}" if limit.positive?

            puts query

            posts = DB.fetch query

            puts posts.inspect
            posts_a = posts.map do |post|
              "{ post_id: #{post[:id]}, rating: %0.#{RATING_PRECISION}f, title: #{post[:title]}, content: #{post[:content]} }" % post[:rating]
            end.join(",\n")

            "{ data: { posts: [ #{posts_a} ] } }\n"
          end
        end
      end
    end
  end
end
