class CreatePoolUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :pool_users do |t|
      t.references :pool, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :pool_users, [ :pool_id, :user_id ], unique: true
  end
end
