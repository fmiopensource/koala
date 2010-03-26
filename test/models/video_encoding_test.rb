require "test_helper"

class VideoEncodingTest < Test::Unit::TestCase
  
  def client
    @client ||= Client.create(:name => 'Video Client', :s3_bucket_name => 'some_bucket', :access_key => 'abcd1234')
  end
  
  def video
    @video ||= Video.create :filename => "test_movie.mov", :filepath => "/path/to/movie", :state => 'created', :client_id => client.id, :thumbnail_filepath => "/path/to/movie_thumb.jpg", :height => 240, :width => 480 
  end
  
  def profile
    @profile ||= Profile.create :title => "Test Video SD", :container => "flv", :client_id => client.id, :encoded_filename_suffix => "SD", :height => 120, :width => 240, :video_bitrate => 1200, :audio_bitrate => 48, :fps => 24, :video_command => "ffmpeg -i $input_file$ -ar 22050 -f flv -r 24 -y $output_file$"
  end
  
  
  # describes validations
  # =====================
  must "required state to be present" do
    ve = VideoEncoding.create
    assert_equal false, ve.valid?
    assert_equal [[:state, :not_present]], ve.errors
  end
  
  
  # describes create_for_video_and_profile
  # -------------------------------------
  must "have initial state of 'created'" do
    ve = VideoEncoding.create_for_video_and_profile(video, profile)
    assert_equal 'created', ve.state
  end
  
  must "have a properly generated filename with correct suffix" do
    ve = VideoEncoding.create_for_video_and_profile(video, profile)
    assert_equal "test_movie_SD.flv", ve.filename
  end
  
  must "have an assigned client, video, and profile" do
    ve = VideoEncoding.create_for_video_and_profile(video, profile)
    assert_equal client, ve.client
    assert_equal video, ve.video
    assert_equal profile, ve.profile
  end
  
  
  # describes recipe options
  # =============================
  must "generate a proper hash based on the input, output file and the profile" do
    ve = VideoEncoding.create_for_video_and_profile(video, profile)
    recipe_opts = ve.recipe_options("input_file.mov", "output_file.mov", profile)
    assert_equal "input_file.mov", recipe_opts[:input_file]
    assert_equal "output_file.mov", recipe_opts[:output_file]
    assert_equal "flv", recipe_opts[:container]
    assert_equal "1228800", recipe_opts[:video_bitrate_in_bits]
    assert_equal 24, recipe_opts[:fps]
    assert_equal "48", recipe_opts[:audio_bitrate]
    assert_equal "49152", recipe_opts[:audio_bitrate_in_bits]
    assert_equal "-s 240x120 ", recipe_opts[:resolution_and_padding]
  end
  
  must "use the profile width and height if the video does not have a width and height" do
    video = Video.create :filename => "test_movie.mov", :filepath => "/path/to/movie", :state => 'created', :client_id => client.id, :thumbnail_filepath => "/path/to/thumbnail"
    ve = VideoEncoding.create_for_video_and_profile(video, profile)
    recipe_opts = ve.recipe_options("input_file.mov", "output_file.mov", profile)
    assert_equal "-s 240x120 ", recipe_opts[:resolution_and_padding] 
  end
  
  
  # describes client_s3_bucket
  # ==========================
  must "return clients s3 bucket name" do
    ve = VideoEncoding.create_for_video_and_profile(video, profile)
    assert_equal 'some_bucket', ve.client_s3_bucket
  end
  
  
  # describes thumbnail_path
  # ========================
  must "return videos thumbnail filepath" do
    ve = VideoEncoding.create_for_video_and_profile(video, profile)
    assert_equal '/path/to/movie_thumb.jpg', ve.thumbnail_path
  end
  
  
  # descibes s3_filename
  # ====================
  must "return the videos s3 dirname and its filename" do
    ve = VideoEncoding.create_for_video_and_profile(video, profile)
    assert_equal "koala_videos/1/test_movie_SD.flv", ve.s3_filename
  end
end