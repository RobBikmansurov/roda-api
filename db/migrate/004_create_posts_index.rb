# frozen_string_literal: true

# db/migrate/004_create_posts_index.rb
Sequel.migration do
  change do
    alter_table(:posts) do
      add_index :ip, opts: {using: :gist}
    end
  end
end
