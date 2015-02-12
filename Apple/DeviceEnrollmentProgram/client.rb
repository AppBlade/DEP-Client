module Apple
  module DeviceEnrollmentProgram

    class Client

      attr_reader :devices

      def initialize(service_url: 'https://mdmenrollment.apple.com', consumer_key:, consumer_secret:, access_token:, access_secret:, access_token_expiry:, cursor: nil)
        @devices = []
        @service_url = URI service_url
        consumer = OAuth::Consumer.new(
          consumer_key, 
          consumer_secret,
          site: @service_url,
        )
        @oauth_params = {
          consumer: consumer,
          realm: 'ADM',
          token: OAuth::AccessToken.new(
            consumer,
            access_token,
            access_secret
          ),
        }
        @cursor = cursor
        raise "Access token expired." if DateTime.now > access_token_expiry
        request_new_session_authorization_token
      end

      def find_device(serial_number:)
        @devices.find do |device|
          device.serial_number == serial_number
        end
      end

      def find_or_create_device(serial_number:, attributes: {})
        find_device(serial_number: serial_number) ||
        create_device(serial_number: serial_number, attributes: attributes)
      end

      def create_device(serial_number:, attributes: {})
        Device.new(serial_number: serial_number, attributes: attributes).tap do |device|
          @devices << device
        end
      end

      def get_account_details
        response = request :get, '/account'
        JSON.parse response.body
      end

      def fetch_devices(options = {})
        response = request :post, '/server/devices', body: options.to_json
        parsed_response = JSON.parse response.body
        parsed_response['devices'].each do |device_attributes|
          find_or_create_device serial_number: device_attributes['serial_number'], attributes: device_attributes
        end
        @most_recent_cursor = parsed_response['cursor']
        fetch_devices(cursor: @most_recent_cursor) if parsed_response['more_to_follow']
        @devices
      end

      def sync_devices
        response = request :post, '/devices/sync', body: {cursor: @most_recent_cursor}.to_json
        parsed_response = JSON.parse response.body
        puts "Sync count (#{parsed_response['devices'].count})"
        parsed_response['devices'].each do |sync_attributes|
          case sync_attributes['op_type']
          when 'added'
            create_device serial_number: sync_attributes['serial_number'], attributes: sync_attributes
          when 'deleted'
            @devices.delete find_device(serial_number: sync_attributes['serial_number'])
          when 'modified'
            find_device(serial_number: sync_attributes['serial_number']).update sync_attributes
          end
        end
        @most_recent_cursor = parsed_response['cursor']
        sync_devices if parsed_response['more_to_follow']
        @devices.count
      end

      def add_profile(profile_settings)
        response = request :post, '/profile', body: profile_settings.to_json
        JSON.parse response.body
      end

      def assign_profile_to_devices(profile_uuid, device_serial_numbers)
        response = request :put, '/profile/devices', body: {profile_uuid: profile_uuid, devices: device_serial_numbers}.to_json
        JSON.parse response.body
      end

      def request(method, path, options = {}, reauthorize_on_failure = true)
        options[:method] = method
        options[:headers] ||= {}
        options[:headers].merge!({
          'X-Server-Protocol-Version' => '2', 
          'Content-Type' => 'application/json;charset=UTF8',
          'User-Agent' => 'AppBlade https://appblade.com',
          'X-ADM-Auth-Session' => @auth_session_token,
        })
        uri = URI.join @service_url, path
        request = Typhoeus::Request.new(uri, options)
        request.options[:headers].merge! 'Authorization' => oauth_header(request)
        request.run
        response = request.response
        if response.success?
          response
        elsif response.code == 401 && reauthorize_on_failure
          request_new_session_authorization_token
          request method, path, options, false
        else
          raise "#{response.code} #{response.body}"
        end
      end

    private

      def oauth_header(request)
        oauth_helper = OAuth::Client::Helper.new request, @oauth_params.merge(:request_uri => request.url)
        oauth_helper.header
      end

      def request_new_session_authorization_token
        response = request :get, '/session', {}, false
        response.success?.tap do |successful|
          if successful
            @auth_session_token = JSON.parse(response.body)['auth_session_token']
          else
            raise "Failure to fetch new authorization token\n#{response.code}\n#{response.body}"
          end
        end
      end

    end
  end
end
