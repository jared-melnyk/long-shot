class CreatePools < ActiveRecord::Migration[8.1]
  def change
    create_table :pools do |t|
      t.string :name

      t.timestamps
    end
  end
end
