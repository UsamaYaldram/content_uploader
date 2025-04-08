require 'google/apis/youtube_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

class YoutubeService
  OOB_URI = 'http://localhost:3000/oauth2callback'
  APPLICATION_NAME = 'Content Uploader'
  SCOPE = [
    'https://www.googleapis.com/auth/youtube.upload',
    'https://www.googleapis.com/auth/youtube'
  ].freeze

  def initialize
    Rails.logger.info "Initializing YouTube service"
    @service = Google::Apis::YoutubeV3::YouTubeService.new
    @service.client_options.application_name = APPLICATION_NAME
    Rails.logger.info "Setting up authorization"
    @service.authorization = authorize
  end

  def upload_video(video, title:, description:)
    Rails.logger.info "Starting video upload process"
    check_credentials!

    begin
      Rails.logger.info "Creating video snippet"
      # Create the video snippet
      video_snippet = Google::Apis::YoutubeV3::VideoSnippet.new(
        title: title,
        description: description
      )

      Rails.logger.info "Creating video status"
      # Create the video status
      video_status = Google::Apis::YoutubeV3::VideoStatus.new(
        privacy_status: 'private' # You can change this to 'public' or 'unlisted'
      )

      Rails.logger.info "Creating YouTube video object"
      # Create the video object
      youtube_video = Google::Apis::YoutubeV3::Video.new(
        snippet: video_snippet,
        status: video_status
      )

      Rails.logger.info "Getting video file path"
      # Get the video file path
      video_path = ActiveStorage::Blob.service.path_for(video.video_file.key)
      Rails.logger.info "Video file path: #{video_path}"

      unless File.exist?(video_path)
        Rails.logger.error "Video file not found at path: #{video_path}"
        raise "Video file not found"
      end

      Rails.logger.info "Starting YouTube upload"
      # Upload the video
      result = @service.insert_video(
        'snippet,status',
        youtube_video,
        upload_source: video_path,
        content_type: 'video/*'
      )

      Rails.logger.info "Upload completed successfully. Video ID: #{result.id}"
      result.id
    rescue Google::Apis::ClientError => e
      Rails.logger.error "YouTube API client error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise "YouTube API error: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Unexpected error during YouTube upload: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise "Upload failed: #{e.message}"
    end
  end

  def self.authorization_url
    credentials = Rails.application.credentials.youtube
    client_id = Google::Auth::ClientId.new(
      credentials[:client_id],
      credentials[:client_secret]
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: File.join(Rails.root, 'tmp', 'youtube-tokens.yaml')
    )

    authorizer = Google::Auth::UserAuthorizer.new(
      client_id,
      SCOPE,
      token_store,
      OOB_URI
    )

    authorizer.get_authorization_url(
      base_url: OOB_URI,
      access_type: 'offline',
      prompt: 'consent',
      include_granted_scopes: true
    )
  end

  def self.handle_auth_callback(code, user_id = 'default')
    credentials = Rails.application.credentials.youtube
    client_id = Google::Auth::ClientId.new(
      credentials[:client_id],
      credentials[:client_secret]
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: File.join(Rails.root, 'tmp', 'youtube-tokens.yaml')
    )

    authorizer = Google::Auth::UserAuthorizer.new(
      client_id,
      SCOPE,
      token_store,
      OOB_URI
    )

    authorizer.get_and_store_credentials_from_code(
      user_id: user_id,
      code: code,
      base_url: OOB_URI
    )
  end

  private

  def check_credentials!
    Rails.logger.info "Checking YouTube credentials"
    credentials = Rails.application.credentials.youtube
    unless credentials && credentials[:client_id] && credentials[:client_secret]
      Rails.logger.error "YouTube credentials not found"
      raise "YouTube credentials not found in Rails credentials"
    end
    Rails.logger.info "YouTube credentials found"
  end

  def authorize
    Rails.logger.info "Setting up authorization"
    check_credentials!
    
    credentials = Rails.application.credentials.youtube
    client_id = Google::Auth::ClientId.new(
      credentials[:client_id],
      credentials[:client_secret]
    )
    Rails.logger.info "Creating client ID"

    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: File.join(Rails.root, 'tmp', 'youtube-tokens.yaml')
    )
    Rails.logger.info "Setting up token store"

    authorizer = Google::Auth::UserAuthorizer.new(
      client_id,
      SCOPE,
      token_store,
      OOB_URI
    )
    Rails.logger.info "Creating authorizer"

    user_id = 'default'
    Rails.logger.info "Getting credentials for user: #{user_id}"
    credentials = authorizer.get_credentials(user_id)
    
    if credentials.nil?
      Rails.logger.info "No existing credentials found, requesting new authorization"
      raise Google::Apis::AuthorizationError, "Authorization required"
    end

    credentials
  rescue StandardError => e
    Rails.logger.error "Authorization failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end 