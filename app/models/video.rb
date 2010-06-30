class Video < Ohm::Model
  include AASM
  
  attribute :filename
  attribute :filepath
  attribute :video_codec
  attribute :video_bitrate
  attribute :audio_codec
  attribute :audio_sample_rate
  attribute :thumbnail_filename
  attribute :thumbnail_filepath
  attribute :duration
  attribute :container
  attribute :width
  attribute :height
  attribute :fps
  attribute :state
  attribute :error_msg
  
  attr_accessor :size, :content_type, :md5
  
  reference :client, Client
  
  collection :encodings, VideoEncoding
  collection :notifications, Notification
  
  
  # AASM
  # ======================
  aasm_column :state
  
  # States
  # aasm_state  :created
  # aasm_state  :queued, :enter => :perform_file_checkout
  # aasm_state  :processed, :enter  => :perform_processing
  # aasm_state  :uploaded, :enter => :perform_upload
  # aasm_state  :encoded, :enter => :perform_encoding
  # aasm_state  :completed, :enter => :perform_cleanup_and_notification
  # aasm_state  :failed, :enter => :perform_error_notification
  
  
  # Validations
  # ======================
  def validate
    assert_present :state
  end
end