# db/migrate/002_create_posts.rb
Sequel.migration do
  change do
    create_table(:posts) do
      primary_key :id, unique: true
      String :title, text: true, null: false
      String :content, text: true, null: false
      Inet :ip, null: false
      foreign_key :user_id, :users
    end
  end
end
