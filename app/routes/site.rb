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
    @client = Client.new params[:client]
    if @client.save
      partial :client, :locals => { :client => @client }
    else
      status 400
      partial :errors, :locals  => { :entity => @client, :message => "The following errors prevented the Client from being saved" }
    end
  end
  
  put "/clients/:id" do
    @client = Client[params[:id]]
    @client.update_attributes(params[:client])
    if @client.save
      partial :client, :locals => { :client => @client }
    else
      status 400
      partial :errors, :locals  => { :entity => @client, :message => "The following errors prevented the Client from being saved" }
    end
  end
  
  delete "/clients/:id" do
    @client = Client[params[:id]]
    @client.delete
    "Success"
  end
  
  
  # Profiles
  # ====================================
  
  get "/clients/:id/profiles" do
    @client = Client[params[:id]]
    @profiles = @client.profiles
    haml :profiles, :layout => !request.xhr?
  end
  
  get "/profiles/:id/edit" do
    @profile = Profile[params[:id]]
    haml :edit_profile, :layout => !request.xhr?
  end
end
