class OauthController < ApplicationController
  def callback
    Rails.logger.info "Received OAuth callback with code: #{params[:code]}"
    
    # Store the authorization code in a temporary file
    auth_code_path = Rails.root.join('tmp', 'youtube-auth-code.txt')
    File.write(auth_code_path, params[:code])
    
    # Restart the video upload job
    video_id = session[:pending_video_id]
    if video_id
      VideoUploadJob.perform_later(video_id)
      session.delete(:pending_video_id)
      redirect_to videos_path, notice: 'Authorization successful! Video upload has been restarted.'
    else
      redirect_to videos_path, alert: 'Authorization successful but no pending video found.'
    end
  end
end 