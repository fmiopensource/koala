class Video < Ohm::Model
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
  attribute :client_id
  
  attr_accessor :size, :content_type, :md5
  
  
  # AASM 
  # ===================
  
  aasm_column :state
  
  # States
  aasm_state  :created
  aasm_state  :queued, :enter => :perform_file_checkout
  aasm_state  :processed, :enter  => :perform_processing
  aasm_state  :uploaded, :enter => :perform_upload
  aasm_state  :encoded, :enter => :perform_encoding
  aasm_state  :completed, :enter => :perform_cleanup_and_notification
  aasm_state  :failed, :enter => :perform_error_notification
  
  aasm_initial_state  :created
  
  # State Event Definitions
  aasm_event :queue do
    transitions :to => :queued, :from => [:created]
  end
  
  aasm_event :process do
    transitions :to => :processed, :from => [:queued]
  end
  
  aasm_event :upload do
    transitions :to => :uploaded, :from => [:processed]
  end
  
  aasm_event :encode do
    transitions :to => :encoded, :from => [:uploaded]
  end
  
  aasm_event :complete do
    transitions :to => :completed, :from => [:encoded], :guard => :videos_finished_encoding?
  end
  
  aasm_event :fail do
    transitions :to => :failed, :from => [:created, :queued, :processed, :uploaded, :encoded, :complete]
  end
  
  
  # Associations
  # ====================
  
  set :video_encodings, VideoEncoding
  set :notifications, Notification
  
  def client
    @client ||= Client[self.client_id]
  end
  
  
  # Validations
  # ====================
  
  def validate
    assert_present  :state
  end
  
  
  # Sets the Resque Queue
  @queue = :videos
  
  
  # Class Methods
  # ====================
  
  # Video.create_on(action, params, client)
  # A wrapper for the create method, this will set the initial state of the video object based
  # on the action specified. It will also associate itself with the client.
  # On action :upload, the method performs file manipulation in order to prepare the video file for
  # further processing.
  # Finally, it places the video into the Resque queue.
  def self.create_on(action, params, client)
    params ||= {}
    params.symbolize_keys!
    video = case action.to_sym
    when :upload
      begin
        # TODO: Move to a state transition event so that it can run in the background
        new_filename = params[:filename].strip.gsub(/[^A-Za-z\d\.\-_]+/, '_')
        new_filepath = [params[:filepath], new_filename].join('_')
        FileUtils.mv(params[:filepath], new_filepath)
        params.merge!(:filename => new_filename, :filepath => new_filepath)
      rescue Exception => e
        logger.debug("Preparing files failed: #{e}")
      end
      create params.merge(:state => "queued", :client_id => client.id)
    when :encode
      create params.merge(:state => "created", :client_id => client.id)
    end

    client.videos.add video
    Resque.enqueue(Video, video.id)
    return video
  end
    
  def self.perform(video_id)
    video = self[video_id]
    case video.state
      when "created"
        video.queue!
        video.process!
        video.upload!
        video.encode!
      when "queued"
        video.process!
        video.upload!
        video.encode!
    end
  end
  
  # State Events
  # ====================
  
  def perform_file_checkout
    self.update(:filepath => temp_video_filepath)
    Store.get_from_s3(self.filename, self.filepath, client_s3_bucket)
  end
  
  def perform_processing
    inspector = RVideo::Inspector.new(:file => self.filepath)
    raise "Format Not Recognized" unless inspector.valid? and inspector.video?
    
    self.update( 
      :video_codec => (inspector.video_codec rescue nil),
      :video_bitrate => (inspector.bitrate rescue nil),
      :audio_codec => (inspector.audio_codec rescue nil),
      :audio_sample_rate => (inspector.audio_sample_rate rescue nil),
      :duration => (inspector.duration rescue nil),
      :container => (inspector.container rescue nil),
      :width => (inspector.width rescue nil),
      :height => (inspector.height rescue nil),
      :fps => (inspector.fps rescue nil),
      :thumbnail_filename => generate_thumbnail_filename
    )
    
    inspector.capture_frame("5%", temp_thumbnail_filepath)
    self.update(:thumbnail_filepath => temp_thumbnail_filepath)
  end
  
  def perform_upload
    # upload the file to S3 unless it already exists on s3
    # upload the generated thumbnail to S3
    Store.set_to_s3(s3_filename, self.filepath, client_s3_bucket) unless Store.file_exists?(:s3, self.filename, client_s3_bucket)
    Store.set_to_s3(s3_thumbnail_filename, self.thumbnail_filepath, client_s3_bucket)
  end
  
  def perform_encoding
    create_encodings
    encode_videos
  end
  
  def perform_cleanup_and_notification
    Store.delete_from_local(self.filepath)
    Store.delete_from_local(self.thumbnail_filepath)
    self.update(:filepath => s3_video_path, :thumbnail_filepath => s3_thumbnail_path)
    create_and_queue_notifications unless self.client_notification_url.blank?
  end
  
  def perform_error_notification
    create_and_queue_notifications unless self.client_notification_url.blank?
  end
  
  def create_and_queue_notifications
    notification = Notification.create :state => 'created', :video_id => self.id
    self.notifications.add notification
    Resque.enqueue(Notification, notification.id)
  end
  
  
  # Instance Methods
  # =========================
  
  def error_messages
    self.errors.present do |e|
      e.on [:state, :not_present], "State must be present"
    end
  end
  
  
  # Guards 
  # =========================
  
  def videos_finished_encoding?
    finished_encoding = true
    self.video_encodings.each do |video_encoding|
      finished_encoding = false unless video_encoding.completed?
    end
    return finished_encoding
  end
  
  
  # Convenience Methods
  # =========================
  
  def s3_filename
    [self.s3_dirname, self.basename].join("/")
  end
  
  def s3_thumbnail_filename
    [self.s3_dirname, self.thumbnail_filename].join("/")
  end
  
  def s3_dirname
    ['koala_videos', self.id.to_s].join("/")
  end
      
  def client_s3_bucket
    self.client.s3_bucket_name
  end
  
  def client_notification_url
    self.client.notification_url
  end
      
  def to_json(include_encodings=false)
    unless include_encodings
      return self.attributes_with_values.to_json
    else
      return self.attributes_with_values.merge(:encodings => self.video_encodings.collect { |ve| ve.attributes_with_values }).to_json
    end
  end
  
  def basename
    File.basename(self.filename)
  end
    
  
  # Private Methods
  # =========================
  
private

  def temp_video_filepath
    directory = File.join(settings(:temp_video_filepath), self.id.to_s)
    FileUtils.mkdir(directory, :mode => 0777) unless File.directory?(directory)
    File.join(directory, self.basename)
  end
  
  def temp_thumbnail_filepath
    directory = File.join(settings(:temp_video_filepath), self.id.to_s)
    FileUtils.mkdir(directory, :mode => 0777) unless File.directory?(directory)
    File.join(directory, self.thumbnail_filename)
  end
  
  def s3_video_path
    [settings(:s3_base_url), client_s3_bucket, self.s3_filename].join("/")
  end
  
  def s3_thumbnail_path
    [settings(:s3_base_url), client_s3_bucket, self.s3_thumbnail_filename].join("/")
  end
  
  def create_encodings
    self.client.profiles.each do |profile|
      video_encoding = VideoEncoding.create_for_video_and_profile(self, profile)
      self.client.video_encodings.add video_encoding
      self.video_encodings.add video_encoding
    end
  end
    
  def encode_videos
    self.video_encodings.each do |ve|
      Resque.enqueue(VideoEncoding, ve.id)
    end
  end
  
  def generate_thumbnail_filename(ext = "jpg")
    self.basename.gsub(Regexp.new(File.extname(self.filename)), "") << "_thumb" << ".#{ext}"
  end
end