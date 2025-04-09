class VideosController < ApplicationController
  before_action :set_video, only: [:show, :edit, :update, :destroy]

  def index
    @videos = Video.all
  end

  def show
  end

  def new
    @video = Video.new
  end

  def edit
  end

  def create
    @video = Video.new(video_params)
    
    if @video.save
      # Store video ID in session in case we need to restart the upload after authorization
      session[:pending_video_id] = @video.id
      
      # Start the upload job
      VideoUploadJob.perform_later(@video.id)
      
      redirect_to videos_path, notice: 'Video was successfully created and upload has started.'
    else
      render :new
    end
  end

  def update
    if @video.update(video_params)
      Rails.logger.info "Video #{@video.id} status changed to #{@video.status}"
      if video_params[:video_file].present?
        @video.update(status: :pending)
        VideoUploadJob.perform_later(@video.id)
        redirect_to @video, notice: 'Video was successfully updated. Upload started.'
      else
        redirect_to @video, notice: 'Video was successfully updated.'
      end
    else
      render :edit, status: :unprocessable_entity
    end
  rescue Google::Apis::AuthorizationError
    session[:pending_video_id] = @video.id
    redirect_to YoutubeService.authorization_url, allow_other_host: true
  end

  def destroy
    @video.destroy
    redirect_to videos_url, notice: 'Video was successfully deleted.'
  end

  private

  def set_video
    @video = Video.find(params[:id])
  end

  def video_params
    params.require(:video).permit(:title, :description, :platform_type, :video_file)
  end
end
