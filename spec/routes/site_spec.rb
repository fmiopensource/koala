require 'spec_helper'

describe "Site" do
  describe "creating clients" do
    before(:each) do
      Client.any_instance.stubs(:create_s3_bucket)
    end
    
    describe "with valid params" do
      it "should respond with success" do
        post '/clients', :client => { :name => "Test Client", :s3_bucket_name => "another_test_bucket" }
        last_response.should be_ok
      end
    end
    
    describe "with invalid params" do
      it "should respond with error" do
        post '/clients', :client => { :name => '', :s3_bucket_name => 'invalid bucket' }
        last_response.should_not be_ok
      end
      
      it "should send back a 400 bad request" do
        post '/clients', :client => { :name => '', :s3_bucket_name => 'invalid bucket' }
        last_response.status.should == 400
      end
    end
  end
  
  describe "updating clients" do
    before(:each) do
      Client.any_instance.stubs(:create_s3_bucket)
    end
    
    describe "with valid params" do
      it "should respond with succcess" do
        client = Client.create :name => "Test Client", :s3_bucket_name => "update_bucket_1"
        put "/clients/#{client.id}", :client => { :name => 'Updated Test Client' }
        last_response.should be_ok
      end
    end
    
    describe "with invalid params" do
      it "should respond with error" do
        client = Client.create :name => "Test Client", :s3_bucket_name => "update_bucket_2"
        put "/clients/#{client.id}", :client => { :name => '' }
        last_response.should_not be_ok
      end
      
      it "should send a 400 bad request" do
        client = Client.create :name => "Test Client", :s3_bucket_name => "update_bucket_3"
        put "/clients/#{client.id}", :client => { :name => '' }
        last_response.status.should == 400
      end
    end
  end
end