class Profile < Ohm::Model
  attribute :title                      
  attribute :container 
  attribute :encoded_filename_suffix
  attribute :video_command 
  attribute :video_bitrate
  attribute :audio_command
  attribute :audio_bitrate
  attribute :width 
  attribute :height 
  attribute :fps
  attribute :player
  attribute :client_id 
  
  def client
    @client ||= Client[self.client_id]
  end
  
  def video_bitrate_in_bits
    self.video_bitrate.to_i * 1024
  end
  
  def audio_bitrate_in_bits
    self.audio_bitrate.to_i * 1024
  end
  
  def is_flash?
    self.container == "flv"
  end
end