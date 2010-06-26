require "test_helper"

class ProfileTest < Test::Unit::TestCase
  def profile
    @profile ||= Profile.create :title => "Test Video SD", :container => "flv", :encoded_filename_suffix => "SD", :height => 120, :width => 240, :video_bitrate => 1200, :audio_bitrate => 48, :fps => 24, :video_command => "ffmpeg -i $input_file$ -ar 22050 -f flv -r 24 -y $output_file$"
  end
  
  
  # describes video_bitrate_in_bits
  must "multiply the profiles video bitrate by 1024" do
    assert_equal 1228800, profile.video_bitrate_in_bits
  end
  
  
  # describes audio_bitrate_in_bits
  must "multiply the profiles audio bitrate by 1024" do
    assert_equal 49152, profile.audio_bitrate_in_bits
  end
  
  # describes is_flash?
  must "return true if the profile container is flv" do
    assert_equal true, profile.is_flash? 
  end
  
  must "return false if the profile container is not flv" do
    not_flv_profile = Profile.create :title => "x264 Video", :container => "mp4", :encoded_filename_suffix => "x264", :height => 480, :width => 640, :video_bitrate => 400, :audio_bitrate => 96, :fps => 24, :video_command => "ffmpeg -i $input_file$ -acodec libfaac -ab $audio_bitrate$ -vcodec libx264 -vpre hq -crf 22 -y $output_file$"
    assert_equal false, not_flv_profile.is_flash?
  end
end