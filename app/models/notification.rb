class Notification < Ohm::Model
  attribute :state
  attribute :attempts
  attribute :last_send_at
  attribute :video_id
  
  # AASM
  # ===================
  
  aasm_column :state
  
  # States
  aasm_state :created
  aasm_state :sending, :after_enter => :process_notification
  aasm_state :sent
  aasm_state :failed, :enter => :process_failure
  
  aasm_initial_state :created
  
  # Transitions
  aasm_event :send_notification do
    transitions :to => :sending, :from => [:created, :failed], :guard => :max_attempts_not_reached?
  end
  
  aasm_event :complete do
    transitions :to => :sent, :from => [:sending]
  end
  
  aasm_event :fail do
    transitions :to => :failed, :from => [:created, :sending]
  end
  
  
  # Associations
  
  def video
    @video ||= Video[self.video_id]
  end
  
  
  # Validations
  # ====================
  
  def validate
    assert_present  :state
  end
  
  
  # Sets the Resque Queue
  @queue = :notifications
  
  
  def self.perform(notification_id)
    notification = self[notification_id]
    # set to fail if the guard prevents the state change
    notification.fail! unless notification.send_notification!
  end
  
  def process_notification
    RestClient.post(self.video.client_notification_url, self.to_json, :content_type => :json) { |response|
      number_of_attempts = self.attempts.blank? ? 1 : self.attempts.to_i + 1
      self.update(:attempts => number_of_attempts, :last_send_at => Time.now)
      
      case response.code
      when 200
        # notification has succeded
        logger.info("Notification Success")
        self.complete!
      else
        # notification failed
        logger.info("Notification Fail")
        self.fail!
      end  
    }
  end
  
  def process_failure
    # Keep enqueueing if max attempts not reached
    Resque.enqueue(Notification, self.id) if max_attempts_not_reached?
  end
  
  
  # Convenience methods
  # ======================
  
  def to_json
    video = self.video
    returning attrs = {} do
      attrs[:video_id] = video.id
      attrs[:video_state] = video.state
      attrs[:video_thumbnail] = video.thumbnail_filepath
      attrs[:encodings] = []
      video.video_encodings.each do |ve|
        attrs[:encodings] << {:id => ve.id.to_i, :filename => ve.filename, :filepath => ve.filepath, :state => ve.state}
      end
    end
    attrs.to_json
  end
  
  
private
  def max_attempts_not_reached?
    return true if self.attempts.blank?
    self.attempts.to_i < settings(:max_notification_attempts)
  end
end