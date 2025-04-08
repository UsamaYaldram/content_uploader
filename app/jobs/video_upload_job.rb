class VideoUploadJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    return if video.uploaded?

    begin
      Rails.logger.info "Starting video upload for video #{video.id}"
      video.update!(status: :processing)
      
      case video.platform_type
      when 'youtube'
        Rails.logger.info "Uploading to YouTube: #{video.title}"
        youtube_id = upload_to_youtube(video)
        Rails.logger.info "Successfully uploaded to YouTube. Video ID: #{youtube_id}"
        video.update!(platform_id: youtube_id, status: :uploaded)
      when 'tiktok'
        # Future implementation for TikTok
        raise NotImplementedError, 'TikTok upload not implemented yet'
      end
    rescue StandardError => e
      Rails.logger.error "Failed to upload video #{video.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      video.update!(status: :failed)
    end
  end

  private

  def upload_to_youtube(video)
    begin
      Rails.logger.info "Initializing YouTube service"
      youtube_service = YoutubeService.new
      
      Rails.logger.info "Getting video file path"
      video_path = ActiveStorage::Blob.service.path_for(video.video_file.key)
      Rails.logger.info "Video file path: #{video_path}"
      
      unless File.exist?(video_path)
        Rails.logger.error "Video file not found at path: #{video_path}"
        raise "Video file not found"
      end
      
      Rails.logger.info "Starting YouTube upload"
      youtube_id = youtube_service.upload_video(
        video,
        title: video.title,
        description: video.description
      )
      Rails.logger.info "YouTube upload completed successfully"
      
      youtube_id
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Authorization error: #{e.message}"
      Rails.logger.error "Please authorize the application by visiting the URL shown above"
      raise "Authorization required. Please check the logs for the authorization URL."
    rescue StandardError => e
      Rails.logger.error "YouTube upload failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end
end 