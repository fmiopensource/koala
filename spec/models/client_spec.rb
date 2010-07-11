require 'spec_helper'

describe Client do
  describe "validation" do
    before(:each) do
      Client.any_instance.stubs(:create_s3_bucket)
    end
    
    it "should require a name to be present" do
      client = Client.create :s3_bucket_name => "test_bucket"
      client.errors.first.should == [:name, :not_present]
    end
    
    it "should require an s3 bucket name to be present" do
      client = Client.create :name => "Test Client"
      client.errors.first.should == [:s3_bucket_name, :not_present]
    end
    
    it "should require an s3 bucket name to be unique" do
      Client.create :name => "Existing Client", :s3_bucket_name => "existing_s3_bucket"
      client = Client.create :name => "New Client", :s3_bucket_name => "existing_s3_bucket"
      client.errors.first.should == [:s3_bucket_name, :not_unique]
    end
    
    it "should require the s3 bucket name to contain only letters, numbers, and underscores" do
      client = Client.create :name => "Test Client", :s3_bucket_name => "not a valid bucket"
      client.errors.first.should == [:s3_bucket_name, :format]
    end
  end
  
  describe "callbacks" do
    describe "before validation" do
      it "should generate an access_key before validation" do
        client = Client.new :name => "Test Client", :s3_bucket_name => "test_bucket"
        client.access_key.should be_nil
        client.valid?
        client.access_key.should_not be_nil
      end
    end
    
    describe "after creation" do
      it "should create an s3 bucket" do
        client = Client.new :name => "Test Client", :s3_bucket_name => "bucket_to_be_created"
        client.expects(:create_s3_bucket)
        client.save
      end
      
      it "should add default profiles" do
        client = Client.new :name => "Test Client", :s3_bucket_name => "test_bucket"
        client.stubs(:create_s3_bucket)
        client.save
        client.profiles.count.should == 2
      end
    end
  end
end