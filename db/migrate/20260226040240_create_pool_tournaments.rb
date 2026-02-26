class CreatePoolTournaments < ActiveRecord::Migration[8.1]
  def change
    create_table :pool_tournaments do |t|
      t.references :pool, null: false, foreign_key: true
      t.references :tournament, null: false, foreign_key: true

      t.timestamps
    end
    add_index :pool_tournaments, [ :pool_id, :tournament_id ], unique: true
  end
end
