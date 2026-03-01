class AddCreatorIdToPools < ActiveRecord::Migration[8.1]
  def change
    add_reference :pools, :creator, foreign_key: { to_table: :users }, index: true

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE pools p
          SET creator_id = (
            SELECT user_id FROM pool_users WHERE pool_id = p.id ORDER BY id ASC LIMIT 1
          )
        SQL
      end
    end
  end
end
