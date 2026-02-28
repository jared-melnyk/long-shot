# frozen_string_literal: true

class CreateTournamentFields < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_fields do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :golfer, null: false, foreign_key: true

      t.timestamps
    end

    add_index :tournament_fields, [ :tournament_id, :golfer_id ], unique: true, name: "index_tournament_fields_on_tournament_and_golfer"
  end
end
