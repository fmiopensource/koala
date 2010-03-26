class Main
  helpers do
    def required_params(params, *params_list)
      params_list.each do |p|
        raise(StandardError, "All required parameters were not supplied: #{params_list.join(', ')}") unless params.has_key?(p.to_s)
      end
    end
    
    def authorized?(client_id, access_key)
      client = Client[client_id]
      raise(StandardError, "Authentication failed, the client id and access key do not match.") unless client.access_key == access_key
      return true
    end
    
    def authenticate_for_api
      begin
        required_params(params, :id, :access_key)
        authorized?(params[:id], params[:access_key])
      rescue Exception => e
        content_type :json
        respond_with_error(100, e.message)
      end
    end
    
    def respond_with_success(resource, options = {})
      options[:status] ||= 200
      
      content_type :json
      status options[:status]
      resource.to_json
    end
    
    def respond_with_error(code, message, options = {})
      options[:status] ||= 400
      
      content_type :json
      throw :halt, [options[:status], {:error => {:code => code, :msg => message}}.to_json]
    end
    
    def ensure_video(stored = :local)
      begin
        if stored == :local
          required_params(params[:video], :filepath)
          raise(StandardError, "Video file does not exist") unless Store.file_exists?(:local, params[:video][:filepath])
        elsif stored == :s3
          required_params(params[:video], :filename)
          # extract the path from the URI and re-assign it to the param
          params[:video][:filename] = URI.parse(params[:video][:filename]).path
          client = Client[params[:id]]
          raise(StandardError, "Video file does not exist") unless Store.file_exists?(:s3, params[:video][:filename], client.s3_bucket_name)
        end
      rescue Exception => e
        content_type :json
        respond_with_error(2, e.message)
      end     
    end
  end
end
