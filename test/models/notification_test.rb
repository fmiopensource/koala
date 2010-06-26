require "test_helper"

class NotificationTest < Test::Unit::TestCase
  
  def client
    @client ||= Client.create(:name => 'Video Client', :s3_bucket_name => 'some_bucket', :access_key => 'abcd1234')
  end
  
  def video
    @video ||= Video.create :filename => "test_movie.mov", :filepath => "/path/to/movie", :state => 'created', :client_id => client.id, :thumbnail_filepath => "/path/to/thumbnail", :height => 240, :width => 480 
  end
  
  def notification
    @notification ||= Notification.create :state => 'created', :video_id => video.id
  end
  
  def profile
    @profile ||= Profile.create :title => "Test Video SD", :container => "flv", :client_id => client.id, :encoded_filename_suffix => "SD", :height => 120, :width => 240, :video_bitrate => 1200, :audio_bitrate => 48, :fps => 24, :video_command => "ffmpeg -i $input_file$ -ar 22050 -f flv -r 24 -y $output_file$"
  end
  
  def video_encoding
    @ve ||= VideoEncoding.create_for_video_and_profile(video, profile)
  end
  
  
  # describes validation
  # ====================
  must "have state present" do
    notification = Notification.create
    assert_equal false, notification.valid?
    assert_equal [[:state, :not_present]], notification.errors
  end
  
  
  # describes self.perform
  # =======================
  must "enter failed state if max send attempts have been made" do
    notification.stubs(:max_attempts_not_reached?).returns(false)
    Resque.stubs(:enqueue)
    Notification.stubs(:[]).returns(notification)
    
    Notification.perform(notification.id)
    assert_equal 'failed', notification.state
  end
  
  
  # describes process_failire
  # =========================
  must "enqueue the notification if max number of attempts is not reached" do
    notification.stubs(:max_attempts_not_reached?).returns(true)
    
    notification.fail!
    
    queued_notification = Resque.peek(:notifications)
    assert_equal 1, queued_notification['args'].count
    assert_equal "Notification", queued_notification['class']
  end
  
  must "not enqueue the notification if max number of attempts is reached" do
    notification.stubs(:max_attempts_not_reached?).returns(false)
    
    notification.fail!
    
    queued_notification = Resque.peek(:notification)
    assert_equal nil, queued_notification
  end
  
  
  # describes body
  must "return a json object" do
    video.video_encodings.add video_encoding
    body_json = { :video_id => video.id, 
                  :video_state => video.state, 
                  :video_thumbnail => video.thumbnail_filepath,
                  :encodings => [{:id => video_encoding.id.to_i, :filename => video_encoding.filename, :filepath => video_encoding.filepath, :state => video_encoding.state}] }
    assert_equal body_json.to_json, notification.to_json
  end
end