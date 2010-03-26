require "test_helper"

class VideoTest < Test::Unit::TestCase
  def tmp_video(attrs={})
    Video.create({
      :state => 'created'
    })
  end
  
  def client
    @client ||= Client.create(:name => 'Video Client', :s3_bucket_name => 'some_bucket', :access_key => 'abcd1234')
  end
  
  
  # describes validations
  # =====================
  must "require state to be present" do
    video = Video.create
    assert_equal false, video.valid?
    assert_equal [[:state, :not_present]], video.errors
  end
  
  
  
    
  # describes create_on
  # ------------------------------
  must "have initial state 'queued' if the action is 'upload'" do
    video = Video.create_on(:upload, {}, client)
    assert_equal "queued", video.state
  end
  
  must "have initial state 'created' if the action is 'encode'" do
    video = Video.create_on(:encode, {}, client)
    assert_equal "created", video.state
  end
  
  must "belong to client passed in the argument list" do
    video = Video.create_on(:encode, {}, client)
    assert_equal client, video.client
  end
  
  must "add itself to clients videos set" do
    video = Video.create_on(:encode, {}, client)
    assert_equal true, client.videos.to_a.include?(video)
  end
  
  must "handle filenames with spaces and non-alphanumeric characters" do
    describes_create_on
    assert_equal 'some_video_circa_99.mov', @video.filename
  end
  
  must "assign the video a complete and valid filepath" do
    describes_create_on
    assert_equal '/videos/1344324_some_video_circa_99.mov', @video.filepath
  end
  
  must "queue itself onto Resque video queue" do
    video = Video.create_on(:encode, {}, client)
    queued_video = Resque.peek(:videos)
    assert_equal "Video", queued_video['class']
    assert_equal [video.id], queued_video['args']
  end
  
  
  # describes file checkout
  # =======================
  must "update the filepath" do
    settings_tmp_filepath = settings(:temp_video_filepath)
    FileUtils.stubs(:mv)
    Resque.stubs(:enqueue)
    video = Video.create_on(:encode, {:filename => '/some_s3_bucket/my_movie.mov'}, client)
    Store.stubs(:get_from_s3)
    video.perform_file_checkout
    assert_equal "#{settings_tmp_filepath}/#{video.id}/my_movie.mov", video.filepath
  end
  
  
  # describes video processing
  # ==========================
  must "generate a thumbnail filename" do
    FileUtils.stubs(:mkdir)
    inspector = get_inspector()
    RVideo::Inspector.stubs(:new).returns(inspector)
    inspector.stubs(:capture_frame)
    video = Video.create_on(:encode, {:filename => 'koala_test.mov'}, client)
    video.perform_processing
    assert_equal 'koala_test_thumb.jpg', video.thumbnail_filename
  end
  
  
  # describes encoding videos
  # =========================
  must "create a video encoding for each profile associated with client" do
    FileUtils.stubs(:mv)
    Resque.stubs(:enqueue)
    Client.any_instance.stubs(:create_s3_bucket)
    tmp_client = Client.create_with_default_profiles(:name => "Client", :s3_bucket_name => "some_bucket")
    video = Video.create_on(:encode, {:filename => '/some_s3_bucket/my_movie.mov'}, tmp_client)
    video.perform_encoding
    assert_equal tmp_client.profiles.count, video.video_encodings.count
  end
  
  
  # describes cleanup and notification
  # ==================================
  must "delete any local files" do
    FileUtils.stubs(:mv)
    Resque.stubs(:enqueue)
    Client.any_instance.stubs(:create_s3_bucket)
    tmp_client = Client.create_with_default_profiles(:name => "Client", :s3_bucket_name => "some_bucket")
    video = Video.create_on(:encode, {:filename => '/some_s3_bucket/my_movie.mov'}, tmp_client)
    # why twice? once for the file, once for the thumbnail
    Store.expects(:delete_from_local).twice
    video.perform_cleanup_and_notification
  end
  
  must "update its filepath and thumbnail path to point to s3" do
    FileUtils.stubs(:mv)
    Resque.stubs(:enqueue)
    Client.any_instance.stubs(:create_s3_bucket)
    tmp_client = Client.create_with_default_profiles(:name => "Client", :s3_bucket_name => "some_bucket")
    video = Video.create_on(:encode, {:filename => '/some_s3_bucket/my_movie.mov'}, tmp_client)
    video.stubs(:thumbnail_filename).returns('my_movie_thumb.jpg')
    Store.stubs(:delete_from_local)
    Video.any_instance.stubs(:create_and_queue_notifications)
    
    video.perform_cleanup_and_notification
    assert_equal [settings(:s3_base_url), "some_bucket", "koala_videos/#{video.id}/my_movie.mov"].join("/"), video.filepath
    assert_equal [settings(:s3_base_url), "some_bucket", "koala_videos/#{video.id}/my_movie_thumb.jpg"].join("/"), video.thumbnail_filepath
  end
  
  must "queue notifications if the client has a notification url" do
    FileUtils.stubs(:mv)
    Client.any_instance.stubs(:create_s3_bucket)
    tmp_client = Client.create_with_default_profiles(:name => "Client", :s3_bucket_name => "some_bucket", :notification_url => "http://localhost:3000")
    video = Video.create_on(:encode, {:filename => '/some_s3_bucket/my_movie.mov'}, tmp_client)
    video.stubs(:thumbnail_filename).returns('my_movie_thumb.jpg')
    Store.stubs(:delete_from_local)
    
    video.perform_cleanup_and_notification
    queued_notification = Resque.peek(:notifications)
    assert_equal 1, video.notifications.count
    assert_equal "Notification", queued_notification['class']
  end
  
  must "not queue notifications if the client has a notification url" do
    FileUtils.stubs(:mv)
    Client.any_instance.stubs(:create_s3_bucket)
    tmp_client = Client.create_with_default_profiles(:name => "Client", :s3_bucket_name => "some_bucket")
    video = Video.create_on(:encode, {:filename => '/some_s3_bucket/my_movie.mov'}, tmp_client)
    video.stubs(:thumbnail_filename).returns('my_movie_thumb.jpg')
    Store.stubs(:delete_from_local)
    
    video.perform_cleanup_and_notification
    queued_notification = Resque.peek(:notification)
    assert_equal 0, video.notifications.count
    assert_nil queued_notification
  end
  
  
  # describes guards
  # ================
  must "return false if there are encodings in process for video" do
    video = tmp_video
    ve = VideoEncoding.create(:state => 'created', :video_id => video.id)
    video.video_encodings.add(ve)
    
    assert_equal false, video.videos_finished_encoding?
  end
  
  must "return true if there are no more encodings in process" do
    video = tmp_video
    ve = VideoEncoding.create(:state => 'completed', :video_id => video.id)
    video.video_encodings.add(ve)
    
    assert_equal true, video.videos_finished_encoding?
  end
  
  
  # describes convenience methods
  # =============================
  must "return proper s3_filename" do
    video = tmp_video
    video.stubs(:basename).returns('my_awesome_movie.mov')
    assert_equal video.s3_filename, "koala_videos/#{video.id}/my_awesome_movie.mov"
  end
  
  must "return proper s3_thumbnail_filename" do
    video = tmp_video
    video.stubs(:thumbnail_filename).returns("awesome_movie_thumb.jpg")
    assert_equal video.s3_thumbnail_filename, "koala_videos/#{video.id}/awesome_movie_thumb.jpg"
  end
  
  must "return proper s3_dirname" do
    video = tmp_video
    assert_equal video.s3_dirname, "koala_videos/#{video.id}"
  end

private
  def get_inspector
    # creates an inspector for the koala_test video
    inspector = RVideo::Inspector.new(:file => root_path('test','fixtures','koala_test.mov'))
  end
  
  def describes_create_on
    FileUtils.stubs(:mv)
    Resque.stubs(:enqueue)
    vid_params = {:filename => "some video circa '99.mov", :filepath => '/videos/1344324'}
    @video = Video.create_on(:upload, vid_params, client)
  end
end