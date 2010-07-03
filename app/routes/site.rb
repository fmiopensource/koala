class Main
  # Root
  # ====================================
  
  get "/" do
    @clients = Client.all.sort
    haml :clients, :layout => !request.xhr?
  end
end
