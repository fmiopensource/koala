class Main
  
  # Root
  # ====================================
  
  get "/" do
    @clients = Client.all.sort
    haml :clients, :layout => !request.xhr?
  end
  
  
  # Clients
  # ====================================
  
  get "/clients/new" do
    haml :new_client, :layout => !request.xhr?
  end
  
  get "/clients/:id/edit" do
    @client = Client[params[:id]]
    haml :edit_client, :layout => !request.xhr?
  end
  
  post "/clients" do
    @client = Client.create_with_default_profiles(params[:client])
    @client.to_json
  end
  
  put "/clients/:id" do
    @client = Client[params[:id]]
    @client.update(params[:client])
    @client.to_json
  end
  
  delete "/clients/:id" do
    @client = Client[params[:id]]
    @client.delete
    @client.to_json
  end
  
  
  # Client Profiles
  # ====================================
  
  get "/clients/:id/profiles" do
    @client = Client[params[:id]]
    @profiles = @client.profiles
    haml :profiles, :layout => !request.xhr?
  end
  
  
  # Client Videos
  # ====================================
  
  get "/clients/:id/videos" do
    @client = Client[params[:id]]
    @videos = @client.videos.sort(:order => 'DESC')
    haml :videos, :layout => !request.xhr?
  end
end
