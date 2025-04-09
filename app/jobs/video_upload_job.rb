class VideoUploadJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)
    Rails.logger.info "Starting video upload for video #{video.id}"
    
    begin
      # Update status to processing
      video.update!(status: :processing)
      
      # Get the video file content
      Rails.logger.info "Downloading video file"
      video_file = video.video_file.download
      Rails.logger.info "Video file downloaded successfully"
      
      # Create a temporary file for upload
      temp_file = Tempfile.new(['video', '.mp4'])
      begin
        temp_file.binmode
        temp_file.write(video_file)
        temp_file.close
        
        Rails.logger.info "Created temporary file at: #{temp_file.path}"
        
        # Upload to YouTube
        Rails.logger.info "Uploading to YouTube: #{video.title}"
        youtube_service = YoutubeService.new(
          video_path: temp_file.path,
          title: video.title,
          description: video.description
        )
        
        result = youtube_service.upload
        youtube_id = result.id
        Rails.logger.info "Successfully uploaded to YouTube. Video ID: #{youtube_id}"
        
        # Update video with YouTube ID and URL
        video.update!(
          status: :completed,
          platform_id: youtube_id,
          youtube_url: "https://youtube.com/watch?v=#{youtube_id}"
        )
      ensure
        # Clean up the temporary file
        temp_file.close
        temp_file.unlink
      end
      
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Authorization error: #{e.message}"
      video.update!(status: :failed)
      raise
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Client error: #{e.message}"
      video.update!(status: :failed)
      raise
    rescue StandardError => e
      Rails.logger.error "Error uploading video: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      video.update!(status: :failed)
      raise "Failed to upload video: #{e.message}"
    end
  end
end
