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
end