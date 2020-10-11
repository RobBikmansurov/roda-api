# frozen_string_literal: true

# db/migrate/001_create_users.rb
Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id, unique: true
      String :login, unique: true, null: false
    end
  end
end
