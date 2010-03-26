class Client < Ohm::Model
  attribute :name
  attribute :access_key
  attribute :s3_bucket_name
  attribute :notification_url
  
  # Associations
  set :profiles, Profile
  set :videos, Video
  set :video_encodings, VideoEncoding
  
  # Indexes
  index :access_key
  index :s3_bucket_name
  
  # Validations
  def validate
    assert_present    :name
    assert_present    :access_key
    assert_unique     :access_key
    assert_present    :s3_bucket_name
    assert_unique     :s3_bucket_name
    assert_format     :s3_bucket_name, /^\S*$/
  end

  
  def self.create_with_default_profiles(params)
    client = create params.merge!(:access_key => generate_access_key)
    client.perform_post_create_setup if client.valid?
    return client
  end
  
  def perform_post_create_setup
    create_s3_bucket
    add_default_profiles if self.profiles.blank?
  end
   
  def to_json
    self.attributes_with_values.merge(:errors => error_messages).to_json
  end
  
  # Presents the error messages in a readable format
  def error_messages
    self.errors.present do |e|
      e.on [:name, :not_present], "Name must be present"
      e.on [:access_key, :not_present], "Access key must be present"
      e.on [:access_key, :not_unique], "Access key must be unique"
      e.on [:s3_bucket_name, :not_present], "S3 Bucket must be present"
      e.on [:s3_bucket_name, :not_unique], "S3 Bucket must be unique"
      e.on [:s3_bucket_name, :format], "S3 Bucket name can not contain whitespace"
    end
  end

private
  def create_s3_bucket
    Store.create_bucket(self.s3_bucket_name)
  end

  def add_default_profiles
    default_profiles = YAML.load_file(root_path("config", "profiles.yml")).values
    default_profiles.each do |default_profile|
      profile = Profile.create default_profile.merge(:client_id => self.id)
      self.profiles.add(profile)
    end
  end
  
  def self.generate_access_key
    begin
      key = generate_random_key
    end while access_key_exists?(key)
    return key
  end

  def self.access_key_exists?(key)
    self.find(:access_key => key).count > 0
  end

  # From http://stackoverflow.com/questions/88311/how-best-to-generate-a-random-string-in-ruby
  def self.generate_random_key(length=15)
    character_set =  [('a'..'z'),(0..9)].map{|i| i.to_a}.flatten
    (0..length).map{ character_set[rand(character_set.length)]  }.join
  end
  
  # Protect access to the following class methods
  private_class_method :generate_access_key, :access_key_exists?, :generate_random_key
end