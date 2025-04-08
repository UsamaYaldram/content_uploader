class OauthController < ApplicationController
  def callback
    code = params[:code]
    if code.present?
      begin
        YoutubeService.handle_auth_callback(code)
        redirect_to videos_path, notice: 'Successfully authorized with YouTube!'
      rescue StandardError => e
        Rails.logger.error "Failed to handle YouTube authorization: #{e.message}"
        redirect_to videos_path, alert: "Authorization failed: #{e.message}"
      end
    else
      redirect_to videos_path, alert: 'Authorization failed: No authorization code received'
    end
  end
end 