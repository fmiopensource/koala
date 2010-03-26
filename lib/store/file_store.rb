class S3VideoObject < AWS::S3::S3Object;end
class S3Bucket < AWS::S3::Bucket;end 

class FileStore
  class FileDoesNotExistError < RuntimeError; end
  
  def initialize
    raise RuntimeError, "Missing S3 Information in settings.yml" unless settings(:s3_access_key_id) && settings(:s3_secret_access_key)
    AWS::S3::Base.establish_connection!(
      :access_key_id     => settings(:s3_access_key_id),
      :secret_access_key => settings(:s3_secret_access_key),
      :persistent => false
    )
  end
  
  def create_bucket(bucket_name)
    begin
      S3Bucket.create(bucket_name)
    rescue AWS::S3::S3Exception => e
      logger.error(e)
      return false
    else
      return true
    end
  end
  
  # Check to see if the video file exists
  def file_exists?(store, key, bucket=nil)
    if store == :local
      return File.exists?(key)
    elsif store == :s3
      return S3VideoObject.exists?(key, bucket)
    end
    return false
  end
  
  # Store the file to S3
  def set_to_s3(key, file, bucket)
    begin
      S3VideoObject.store(key, File.open(file), bucket, :access => :public_read)
    rescue AWS::S3::S3Exception => e
      logger.error(e)
      return false
    else
      return true
    end
  end
  
  # Get the file from S3
  def get_from_s3(key, file, bucket)
    begin
      File.open(file, 'w') do |f|
        S3VideoObject.stream(key, bucket) {|chunk| f.write chunk}
      end
    rescue AWS::S3::S3Exception => e
      logger.error(e)
      return false
    else
      return true
    end
  end
  
# Delete the file from S3
  def delete_from_s3(key, bucket)
    begin
      S3VideoObject.delete(key, bucket)
    rescue AWS::S3::S3Exception => e
      logger.error(e)
      return false
    else
      true
    end
  end
  
  def delete_from_local(key)
    begin
      File.delete(key)
    rescue Exception => e
      logger.error(e)
      return false
    else
      return true
    end
    
  end
end