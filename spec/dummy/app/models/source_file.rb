require 'aws-sdk-s3'

class SourceFile < ActiveRecord::Base
  # This line can be removed for Rails 4 apps that are using Strong Parameters
  attr_accessible :url, :bucket, :key if S3CorsFileupload.active_record_protected_attributes?

  validates_presence_of :file_name, :file_content_type, :file_size, :key, :bucket

  before_validation(:on => :create) do
    self.file_name = key.split('/').last if key
    # for some reason, the response from AWS seems to escape the slashes in the keys, this line will unescape the slash
    self.url = url.gsub(/%2F/, '/') if url
    self.file_size ||= s3_object.content_length rescue nil
    self.file_content_type ||= s3_object.content_type rescue nil
  end
  # make all attributes readonly after creating the record (not sure we need this?)
  after_create { readonly! }
  # cleanup; destroy corresponding file on S3
  after_destroy { s3_object.try(:delete) }

  def to_jq_upload
    { 
      'id' => id.to_s,
      'name' => file_name,
      'size' => file_size,
      'url' => url,
      'image' => self.is_image?,
      'delete_url' => Rails.application.routes.url_helpers.source_file_path(self, :format => :json)
    }
  end

  def is_image?
    !!file_content_type.try(:match, /image/)
  end

  #---- start S3 related methods -----
  def s3_object
    @s3_object ||=
      key && self.class.aws_s3_client.get_object(bucket: bucket, key: key)
  end

  def self.aws_s3_client
    @aws_s3_client ||=
      Aws::S3::Client.new(
        :region            => S3CorsFileupload::Config.region,
        :access_key_id     => S3CorsFileupload::Config.access_key_id,
        :secret_access_key => S3CorsFileupload::Config.secret_access_key
      )
  end
  #---- end S3 related methods -----

end
