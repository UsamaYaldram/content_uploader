class Video < ApplicationRecord
  has_one_attached :video_file

  validates :title, presence: true
  validates :video_file, presence: true
  validates :video_file, content_type: [ "video/mp4", "video/quicktime", "video/x-msvideo", "video/x-ms-wmv" ]
  validates :video_file, size: { less_than: 100.megabytes }

  after_initialize :set_default_status, if: :new_record?

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    uploaded: 'uploaded',
    failed: 'failed'
  }

  enum :platform_type, {
    youtube: "youtube",
    tiktok: "tiktok"
  }

  private

  def set_default_status
    self.status ||= :pending
  end
end
