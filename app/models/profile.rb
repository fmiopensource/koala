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
  
  reference :client, Client
end