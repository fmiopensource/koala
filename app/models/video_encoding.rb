class VideoEncoding < Ohm::Model
  attribute :filename
  attribute :filepath
  attribute :state
  attribute :started_encoding_at
  attribute :finished_encoding_at
  attribute :client_id
  attribute :profile_id
  attribute :video_id
  
  # AASM 
  # ===================
  aasm_column :state
  
  # States
  aasm_state  :created
  aasm_state  :processed, :enter  => :perform_encoding
  aasm_state  :uploaded, :enter => :perform_upload
  aasm_state  :completed, :after_enter => :perform_cleanup_and_notification
  aasm_state  :failed
  
  aasm_initial_state  :created
  
  # State Event Definitions  
  aasm_event :process do
    transitions :to => :processed, :from => [:created]
  end
  
  aasm_event :upload do
    transitions :to => :uploaded, :from => [:processed]
  end
  
  aasm_event :complete do
    transitions :to => :completed, :from => [:uploaded]
  end
  
  aasm_event :fail do
    transitions :to => :failed, :from => [:created, :queued, :processed, :uploaded, :encoded, :complete]
  end
  
  
  # Associations
  # ====================

  def client
    @client ||= Client[self.client_id]
  end
  
  def profile
    @profile ||= Profile[self.profile_id]
  end
  
  def video
    @video ||= Video[self.video_id]
  end
  
  
  # Validations
  # ====================
  def validate
    assert_present  :state
  end
  
  
  # Sets the Resque Queue
  @queue = :encodings
  
  
  # Class Methods
  # ====================
  
  def self.create_for_video_and_profile(video, profile)
    params = { :state => "created", :filename => self.generate_encoding_filename(video.basename, profile) }
    ve = create params.merge(:client_id => video.client.id, :video_id => video.id, :profile_id => profile.id)
    return ve
  end
  
  def self.perform(vid_encoding_id)
    video_encoding = self[vid_encoding_id]
    video_encoding.process!
    video_encoding.upload!
    video_encoding.complete!
  end
  
  
  # State Events
  # ====================
  
  def perform_encoding
    video, profile = self.video, self.profile
    begin
      transcoder = RVideo::Transcoder.new(video.filepath)
      recipe = profile.video_command.concat(" \nflvtool2 -U $output_file$")
      self.update(:started_encoding_at => Time.now)
      transcoder.execute(recipe, recipe_options(video.filepath, encoding_filepath, profile))
      self.update(:finished_encoding_at => Time.now, :filepath => encoding_filepath)
    rescue
      self.fail!
    end
  end
  
  def perform_upload
    Store.set_to_s3(self.s3_filename, self.filepath, client_s3_bucket)
  end
  
  def perform_cleanup_and_notification
    Store.delete_from_local(self.filepath)
    self.update(:filepath => s3_path) 
    self.video.complete!
  end
  
  
  
  def recipe_options(input_file, output_file, profile)
    {
      :input_file => input_file,
      :output_file => output_file,
      :container => profile.container, 
      :video_bitrate_in_bits => profile.video_bitrate_in_bits.to_s, 
      :fps => profile.fps,
      :audio_bitrate => profile.audio_bitrate.to_s, 
      :audio_bitrate_in_bits => profile.audio_bitrate_in_bits.to_s, 
      :resolution_and_padding => calculate_resolution_padding_and_cropping
    }
  end
  
  def error_messages
    self.errors.present do |e|
      e.on [:state, :not_present], "State must be present"
    end
  end
  
  
  # Convenience methods
  # ======================
  
  def client_s3_bucket
    self.client.s3_bucket_name
  end
  
  def thumbnail_path
    self.video.thumbnail_filepath
  end
  
  def s3_filename
    [self.video.s3_dirname, self.filename].join("/")
  end
  
  def to_json
    self.attributes_with_values.to_json
  end
  
      
private  

  def encoding_filepath
    File.join(settings(:temp_video_filepath), self.video_id, self.filename)
  end
  
  def s3_path
    [settings(:s3_base_url), client_s3_bucket, self.s3_filename].join("/")
  end
  
  # http://github.com/newbamboo/panda/blob/sinatra/lib/db/encoding.rb
  def calculate_resolution_padding_and_cropping
    video, profile = self.video, self.profile
    in_w = video.width.to_f
    in_h = video.height.to_f
    out_w = profile.width.to_f
    out_h = profile.height.to_f
    
    begin
      raise RuntimeError if (in_h.zero? || in_w.zero?)
      aspect = in_w / in_h
      aspect_inv = in_h / in_w
    rescue
      return %(-s #{profile.width}x#{profile.height} )
    end

    height = (out_w / aspect.to_f).to_i
    height -= 1 if height % 2 == 1

    opts_string = %(-s #{profile.width}x#{height} )

    # Keep the video's original width if the video height is greater than profile height
    if height > out_h
      width = (out_h / aspect_inv.to_f).to_i
      width -= 1 if width % 2 == 1

      opts_string = %(-s #{width}x#{profile.height} )
    # Otherwise letterbox it
    elsif height < out_h
      pad = ((out_h - height.to_f) / 2.0).to_i
      pad -= 1 if pad % 2 == 1
      opts_string << %(-padtop #{pad} -padbottom #{pad})
    end

    return opts_string
  end
  
  def self.generate_encoding_filename(original_video_filename, profile_data)
    suffix = profile_data.encoded_filename_suffix
    ext = profile_data.container
    original_video_filename.gsub(Regexp.new(/#{File.extname(original_video_filename)}\Z/), "") + "_#{suffix}.#{ext}"
  end
end