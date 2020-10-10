# frozen_string_literal: true

require 'roda'
require 'sequel'
require 'dotenv/load'
require 'json'

DB = Sequel.connect(adapter: 'postgres',
                    database: ENV['PGDATABASE'],
                    host: '127.0.0.1',
                    user: ENV['PGUSER'],
                    password: ENV['PGPASSWORD'])

class Post < Sequel::Model
  plugin :json_serializer

  many_to_one :user

  def to_json
    "{
      id: #{id},
      title: #{title},
      content: #{content},
      ip: #{ip.to_s},
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

  def to_json
    "{ id: #{id}, login: #{login} }"
  end
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
              next unless rate.positive?

              puts r.params
              "post_id=#{post_id}   rate=#{rate}"
            end
          end
          r.get do # GET /api/v1/posts?rating=4.5&limit=10
            'api/v1/posts?rating=4.5&limit=10'
            request.params.to_s
          end
          r.post 'create' do # POST /api/vi/posts/create
            user_id = User.find_by_login_or_create(r.params['user_login'])
            
            @post = Post.create(
              user_id: user_id,
              title: r.params['title'],
              content: r.params['content'],
              ip: r.params['user_ip'])
            "{ message: 'Post created successfully', data: { post: #{@post.to_json} } }\n"
          end
        end
      end
    end
  end
end
