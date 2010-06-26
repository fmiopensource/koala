class Main
  
  # Client Videos
  # ====================================
  
  get "/api/clients/:id/videos" do
    authenticate_for_api
    
    client = Client[params[:id]]
    videos = client.videos
    respond_with_success(:videos => videos.to_json)
  end
  
  get "/api/clients/:id/videos/:video_id" do
    authenticate_for_api
    
    client = Client[params[:id]]
    video = client.videos.find_by_id(params[:video_id])
    respond_with_success(:video => video.to_json(true))
  end
  
  post "/api/clients/:id/videos/upload" do
    authenticate_for_api
    ensure_video(:local)
    
    client = Client[params[:id]]
    video = Video.create_on(:upload, params[:video], client)
    respond_with_success(:video => video.to_json)
  end
  
  post "/api/clients/:id/videos/encode" do
    authenticate_for_api
    ensure_video(:s3)
    
    client = Client[params[:id]]
    params[:video][:filename] = URI.parse(params[:video][:filename]).path
    video = Video.create_on(:encode, params[:video], client)
    respond_with_success(:video => video.to_json)
  end
  
  
  # Client Encodings
  # ====================================
  
  get "/api/clients/:id/encodings/:encoding_id" do
    authenticate_for_api
    
    client = Client[params[:id]]
    encoding = client.video_encodings.find_by_id(params[:encoding_id])
    respond_with_success(:encoding => encoding.to_json)
  end
end