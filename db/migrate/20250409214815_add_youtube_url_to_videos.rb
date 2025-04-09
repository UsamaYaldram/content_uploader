class AddYoutubeUrlToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :youtube_url, :string
  end
end
