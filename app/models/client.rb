class Client < Ohm::Model
  include Ohm::Callbacks
  
  attribute :name
  attribute :access_key
  attribute :s3_bucket_name
  attribute :notification_url
  
  collection :profiles, Profile
  
  index :access_key
  index :s3_bucket_name
  
  
  # Callbacks
  # ======================
  before  :validate, :generate_access_key
  after   :create, :create_bucket_and_add_default_profiles
  
  
  # Validations
  # ======================
  def validate
    super # required for before_validate callbacks to work
    assert_present    :name
    assert_present    :access_key
    assert_unique     :access_key
    assert_present    :s3_bucket_name
    assert_unique     :s3_bucket_name
    assert_format     :s3_bucket_name, /^\S*$/
  end
  
  
protected

  def generate_access_key
    begin
      key = generate_random_key
    end while access_key_exists?(key)
    self.access_key = key
  end
  
  def create_bucket_and_add_default_profiles
    create_s3_bucket 
    add_default_profiles
  end
  
  def create_s3_bucket
    # Store.create_bucket(self.s3_bucket_name)
  end
  
  def add_default_profiles
    default_profiles = YAML.load_file(root_path("config", "profiles.yml")).values
    default_profiles.each do |default_profile|
      Profile.create default_profile.merge(:client_id => self.id)
    end
  end
 
  def access_key_exists?(key)
    Client.find(:access_key => key).count > 0
  end
  
  # From http://stackoverflow.com/questions/88311/how-best-to-generate-a-random-string-in-ruby
  def generate_random_key(length=15)
    character_set =  [('a'..'z'),(0..9)].map{|i| i.to_a}.flatten
    (0..length).map{ character_set[rand(character_set.length)]  }.join
  end
end