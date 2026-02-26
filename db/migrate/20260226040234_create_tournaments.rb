class CreateTournaments < ActiveRecord::Migration[8.1]
  def change
    create_table :tournaments do |t|
      t.string :name
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :external_id

      t.timestamps
    end
  end
end
