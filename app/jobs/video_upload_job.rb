class VideoUploadJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    @video = Video.find_by(id: video_id)
    return log_error("Video not found with ID: #{video_id}") unless @video

    begin
      log_info("Starting video upload for video #{@video.id}")
      update_video_status(:processing)
      upload_to_platform
    rescue StandardError => e
      handle_error(e)
    end
  end

  private

  def upload_to_platform
    case @video.platform_type
    when 'youtube'
      upload_to_youtube
    else
      raise "Unsupported platform: #{@video.platform_type}"
    end
  end

  def upload_to_youtube
    log_info("Uploading to YouTube: #{@video.title}")
    
    # Create a temporary file for upload
    temp_file = create_temp_file
    begin
      youtube_service = YoutubeService.new
      youtube_id = youtube_service.upload_video(
        @video.title,
        @video.description,
        temp_file.path
      )

      handle_successful_upload(youtube_id)
    ensure
      # Clean up the temporary file
      temp_file.close
      temp_file.unlink
    end
  rescue Google::Apis::AuthorizationError => e
    handle_authorization_error(e)
  rescue Google::Apis::ClientError => e
    handle_client_error(e)
  rescue StandardError => e
    handle_upload_error(e)
  end

  def create_temp_file
    log_info("Creating temporary file for upload")
    temp_file = Tempfile.new(['video', '.mp4'])
    temp_file.binmode
    
    # Download the video file content
    log_info("Downloading video file content")
    video_content = @video.video_file.download
    temp_file.write(video_content)
    temp_file.close
    
    log_info("Temporary file created at: #{temp_file.path}")
    temp_file
  end

  def handle_successful_upload(youtube_id)
    log_info("Successfully uploaded to YouTube. Video ID: #{youtube_id}")
    
    @video.update!(
      status: :uploaded,
      platform_id: youtube_id,
      youtube_url: "https://www.youtube.com/watch?v=#{youtube_id}"
    )
    
    log_info("Video #{@video.id} status updated to uploaded")
  end

  def handle_authorization_error(error)
    log_error("Authorization error: #{error.message}")
    update_video_status(:failed)
    raise error
  end

  def handle_client_error(error)
    log_error("YouTube API error: #{error.message}")
    update_video_status(:failed)
    raise error
  end

  def handle_upload_error(error)
    log_error("Upload error: #{error.message}")
    log_error(error.backtrace.join("\n"))
    update_video_status(:failed)
    raise error
  end

  def update_video_status(status)
    @video.update!(status: status)
    log_info("Video #{@video.id} status updated to #{status}")
  end

  def log_info(message)
    Rails.logger.info("[VideoUploadJob] #{message}")
  end

  def log_error(message)
    Rails.logger.error("[VideoUploadJob] #{message}")
  end
end
