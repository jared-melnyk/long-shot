class CreatePickGolfers < ActiveRecord::Migration[8.1]
  def change
    create_table :pick_golfers do |t|
      t.references :pick, null: false, foreign_key: true
      t.references :golfer, null: false, foreign_key: true
      t.integer :slot

      t.timestamps
    end
    add_index :pick_golfers, [ :pick_id, :slot ], unique: true
    add_index :pick_golfers, [ :pick_id, :golfer_id ], unique: true
  end
end
