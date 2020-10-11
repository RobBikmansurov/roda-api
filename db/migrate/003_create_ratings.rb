# frozen_string_literal: true

# db/migrate/003_create_ratings.rb
Sequel.migration do
  change do
    create_table(:ratings) do
      primary_key :id, unique: true
      Smallint :rating, null: false
      DateTime :created_at, default: Time.now
      foreign_key :post_id, :posts
    end
  end
end
