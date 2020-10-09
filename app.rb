# frozen_string_literal: true

class App < Roda
  plugin :all_verbs
  plugin :json

  route do |r|
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
          r.post 'new' do # POST /api/vi/posts/new
            r.params.to_s
            r.body.to_s
            'new post created'
          end
        end
      end
    end
  end
end
