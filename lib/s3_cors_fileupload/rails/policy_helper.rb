require 'base64'
require 'openssl'
require 'digest/sha1'
require 'multi_json'

module S3CorsFileupload
  class PolicyHelper
    attr_reader :options

    def initialize(_options = {})
      # default max_file_size to 500 MB if nothing is received
      @options = {
        acl: Config.acl || 'public-read',
        max_file_size: Config.max_file_size || 524_288_000,
        bucket: Config.bucket
      }.merge(_options).merge(secret_access_key: Config.secret_access_key)

      validate_presence_of_options(:bucket, :secret_access_key)
    end

    # generate the policy document that amazon is expecting.
    def policy_document
      @policy_document ||=
        Base64.encode64(
          MultiJson.dump(
            {
              expiration: 10.hours.from_now.utc.iso8601(3),
              conditions: [
                { bucket: options[:bucket] },
                { acl: options[:acl] },
                { success_action_status: '201' },
                ['content-length-range', 0, options[:max_file_size]],
                # ["starts-with", "$utf8", ""],
                ['starts-with', '$key', ''],
                ['starts-with', '$Content-Type', '']
              ]
            }
          )
        ).gsub(/\n/, '')
    end

    # sign our request by Base64 encoding the policy document.
    def upload_signature
      @upload_signature ||=
        Base64.encode64(
          OpenSSL::HMAC.digest(
            OpenSSL::Digest.new('SHA1'),
            options[:secret_access_key],
            policy_document
          )
        ).gsub(/\n/, '')
    end

    private

    def validate_presence_of_options(*options)
      options.each do |option|
        if @options[option].blank?
          raise S3CorsFileupload::Config::MissingOptionError,
                "'#{option}' is a required option in #{S3CorsFileupload::Config.file_path}"
        end
      end
    end
  end
end
