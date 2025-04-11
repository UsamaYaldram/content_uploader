require "google/apis/youtube_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"

class YoutubeService
  OOB_URI = "http://localhost:3000/oauth2callback"
  APPLICATION_NAME = "Content Uploader"
  SCOPE = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube"
  ]

  def initialize
    @service = Google::Apis::YoutubeV3::YouTubeService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
  end

  def upload_video(title, description, video_path, category_id: "22", privacy_status: "unlisted", keywords: "")
    Rails.logger.info "Starting video upload process"
    check_credentials!

    begin
      # Verify file exists and is readable
      unless File.exist?(video_path) && File.readable?(video_path)
        Rails.logger.error "Video file not found or not readable: #{video_path}"
        raise "Video file not found or not readable"
      end

      # Create video snippet
      snippet = Google::Apis::YoutubeV3::VideoSnippet.new(
        title: title,
        description: description,
        tags: keywords.split(","),
        category_id: category_id
      )

      # Create video status
      status = Google::Apis::YoutubeV3::VideoStatus.new(
        privacy_status: privacy_status
      )

      # Create video object
      video = Google::Apis::YoutubeV3::Video.new(
        snippet: snippet,
        status: status
      )

      Rails.logger.info "Created video object with title: #{title}"

      # Upload video
      Rails.logger.info "Uploading video file from path: #{video_path}"
      result = @service.insert_video(
        "snippet,status",
        video,
        upload_source: video_path,
        content_type: "video/mp4"
      )

      Rails.logger.info "Upload completed successfully. Video ID: #{result.id}"
      result.id
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Authorization error: #{e.message}"
      raise
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Client error: #{e.message}"
      raise
    rescue StandardError => e
      Rails.logger.error "Error uploading video: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end

  def self.authorization_url
    credentials = Rails.application.credentials.youtube
    client_id = Google::Auth::ClientId.new(
      credentials[:client_id],
      credentials[:client_secret]
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: File.join(Rails.root, "tmp", "youtube-tokens.yaml")
    )

    authorizer = Google::Auth::UserAuthorizer.new(
      client_id,
      SCOPE,
      token_store,
      OOB_URI
    )

    authorizer.get_authorization_url(
      base_url: OOB_URI,
      access_type: "offline",
      prompt: "consent",
      include_granted_scopes: true
    )
  end

  def self.handle_auth_callback(code, user_id = "default")
    credentials = Rails.application.credentials.youtube
    client_id = Google::Auth::ClientId.new(
      credentials[:client_id],
      credentials[:client_secret]
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: File.join(Rails.root, "tmp", "youtube-tokens.yaml")
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
    unless Rails.application.credentials.youtube[:client_id] && Rails.application.credentials.youtube[:client_secret]
      Rails.logger.error "YouTube credentials not found"
      raise "YouTube credentials not found. Please check your Rails credentials."
    end
  end

  def authorize
    Rails.logger.info "Starting authorization process"
    client_id = Google::Auth::ClientId.from_hash(
      {
        "installed" => {
          "client_id" => Rails.application.credentials.youtube[:client_id],
          "client_secret" => Rails.application.credentials.youtube[:client_secret],
          "redirect_uris" => [ OOB_URI ],
          "auth_uri" => "https://accounts.google.com/o/oauth2/auth",
          "token_uri" => "https://oauth2.googleapis.com/token"
        }
      }
    )

    token_store = Google::Auth::Stores::FileTokenStore.new(file: "tmp/youtube-tokens.yaml")
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

    user_id = "default"
    credentials = authorizer.get_credentials(user_id)

    if credentials.nil?
      Rails.logger.info "No credentials found, checking for authorization code"
      auth_code_path = Rails.root.join("tmp", "youtube-auth-code.txt")

      if File.exist?(auth_code_path)
        Rails.logger.info "Found authorization code, exchanging for tokens"
        code = File.read(auth_code_path).strip
        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id,
          code: code,
          base_url: OOB_URI
        )
        File.delete(auth_code_path) # Clean up the code file after use
      else
        Rails.logger.error "No authorization code found"
        raise "No authorization code found. Please authorize the application first."
      end
    end

    credentials
  end
end
