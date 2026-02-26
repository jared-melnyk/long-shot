class CreateGolfers < ActiveRecord::Migration[8.1]
  def change
    create_table :golfers do |t|
      t.string :name
      t.string :external_id

      t.timestamps
    end
  end
end
