module Eventflit
  module NativeNotification
    class Client
      attr_reader :app_id, :host

      API_PREFIX = "publisher/app/"

      def initialize(app_id, host, scheme, eventflit_client)
        @app_id = app_id
        @host = host
        @scheme = scheme
        @eventflit_client = eventflit_client
      end

      # Send a notification via the native notifications API
      def notify(interests, data = {})
        Request.new(
          @eventflit_client,
          :post,
          url("/publishes"),
          {},
          payload(interests, data)
        ).send_sync
      end

      private

      # {
      #   interests: [Array of interests],
      #   apns: {
      #     See https://docs.eventflit.com/push_notifications/ios/server
      #   },
      #   gcm: {
      #     See https://docs.eventflit.com/push_notifications/android/server
      #   }
      # }
      #
      # @raise [Eventflit::Error] if the interests array is empty
      # @return [String]
      def payload(interests, data)
        interests = Array(interests).map(&:to_s)

        raise Eventflit::Error, "Interests array must not be empty" if interests.length == 0

        data = deep_symbolize_keys!(data)

        data.merge!(interests: interests)

        MultiJson.encode(data)
      end

      def url(path = nil)
        URI.parse("#{@scheme}://#{@host}/#{API_PREFIX}/#{@app_id}#{path}")
      end

      # Symbolize all keys in the hash recursively
      def deep_symbolize_keys!(hash)
        hash.keys.each do |k|
          ks = k.respond_to?(:to_sym) ? k.to_sym : k
          hash[ks] = hash.delete(k)
          deep_symbolize_keys!(hash[ks]) if hash[ks].kind_of?(Hash)
        end

        hash
      end
    end
  end
end
