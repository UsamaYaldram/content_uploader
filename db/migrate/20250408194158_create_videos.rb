class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.string :title
      t.text :description
      t.string :status
      t.string :platform_type
      t.string :platform_id

      t.timestamps
    end
  end
end
