require 'test_helper'

class ClientTest < Test::Unit::TestCase
  def tmp_client(attrs={})
    Client.create({
      :name => "Test Client", 
      :access_key => "abcd1234", 
      :s3_bucket_name => 's3_bucket_name', 
      :notification_url => 'http://example.com'
    }.merge(attrs))
  end
  
  # describes validations
  # ==============================
  must "require name, access_key, and s3_bucket_name to be present" do
    client = Client.create
    assert_equal false, client.valid?
    assert_equal [[:name, :not_present], [:access_key, :not_present], [:s3_bucket_name, :not_present], [:s3_bucket_name, :format]], client.errors
  end
  
  must "require s3_bucket name to not contain any spaces" do
    client = tmp_client(:s3_bucket_name => "invalid bucket name")
    assert_equal false, client.valid?
    assert_equal [[:s3_bucket_name, :format]], client.errors
  end
  
  must "require access_key to be unique" do
    client_one = tmp_client
    client_two = tmp_client(:s3_bucket_name => 'different_bucket_name')
    assert_equal false, client_two.valid?
    assert_equal [[:access_key, :not_unique]], client_two.errors
  end
  
  must "require s3_bucket_name to be unqie" do
    client_one = tmp_client
    client_two = tmp_client(:access_key => 'efgh5678')
    assert_equal false, client_two.valid?
    assert_equal [[:s3_bucket_name, :not_unique]], client_two.errors
  end
  
  
  # describes creating with default profiles
  # ========================================
  must "generate an access_key" do
    Client.any_instance.stubs(:create_s3_bucket)
    client = Client.create_with_default_profiles(:name => "Client", :s3_bucket_name => "some_bucket")
    assert_equal false, client.access_key.blank?
  end
  
  must "assign default profiles" do
    Client.any_instance.stubs(:create_s3_bucket)
    profiles_count = YAML.load_file(root_path("config", "profiles.yml")).values.count
    client = Client.create_with_default_profiles(:name => "Client", :s3_bucket_name => "some_bucket")
    assert_equal profiles_count, client.profiles.count
  end
  
  # describes post create setup
  # ===========================
  must "assign profiles only if they don't exit" do
    Client.any_instance.stubs(:create_s3_bucket)
    client = Client.create_with_default_profiles(:name => "Client", :s3_bucket_name => "some_bucket")
    profiles_count = client.profiles.count
    client.perform_post_create_setup
    assert_equal profiles_count, client.profiles.count
  end
end