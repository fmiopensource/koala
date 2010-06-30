require "test_helper"

class ClientTest < Test::Unit::TestCase
  
  describe "validations" do
    setup do
      @valid_client = Client.create :name => "Test Client", :s3_bucket_name => "my_s3_bucket"
    end
    
    should "require a name to be present" do
      client = Client.create :s3_bucket_name => "some_bucket_name"
      assert_equal [:name, :not_present], client.errors.first
    end
    
    should "require s3 bucket name to be present" do
      client = Client.create :name => "Bucketless Client"
      assert_equal [:s3_bucket_name, :not_present], client.errors.first
    end
    
    should "require s3 bucket name to be unique" do
      client = Client.create :name => "Bucket name is taken", :s3_bucket_name => @valid_client.s3_bucket_name
      assert_equal [:s3_bucket_name, :not_unique], client.errors.first
    end
    
    should "require s3 bucket name to not contain any spaces" do
      client = Client.create :name => "Bucket name has space", :s3_bucket_name => "invalid bucket name"
      assert_equal [:s3_bucket_name, :format], client.errors.first
    end
  end
  
  describe "callbacks" do
    should "generate an access_key before validation" do
      client = Client.new :name => "Test Client", :s3_bucket_name => "test_bucket"
      assert_equal nil, client.access_key
      client.valid?
      assert_equal false, client.access_key.blank?
    end
    
    should "create an s3 bucket after save" do
      client = Client.new :name => "Test Client", :s3_bucket_name => "test_bucket"
      client.expects(:create_s3_bucket).once
      client.save
    end
    
    should "add default profiles after save" do
      client = Client.create :name => "Test Client", :s3_bucket_name => "test_bucket"
      assert_equal 2, client.profiles.count
    end
  end
end