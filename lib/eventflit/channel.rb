require 'openssl'
require 'multi_json'

module Eventflit
  # Delegates operations for a specific channel from a client
  class Channel
    attr_reader :name
    INVALID_CHANNEL_REGEX = /[^A-Za-z0-9_\-=@,.;]/

    def initialize(_, name, client = Eventflit)
      if Eventflit::Channel::INVALID_CHANNEL_REGEX.match(name)
        raise Eventflit::Error, "Illegal channel name '#{name}'"
      elsif name.length > 200
        raise Eventflit::Error, "Channel name too long (limit 164 characters) '#{name}'"
      end
      @name = name
      @client = client
    end

    # Trigger event asynchronously using EventMachine::HttpRequest
    #
    # [Deprecated] This method will be removed in a future gem version. Please
    # switch to Eventflit.trigger_async or Eventflit::Client#trigger_async instead
    #
    # @param (see #trigger!)
    # @return [EM::DefaultDeferrable]
    #   Attach a callback to be notified of success (with no parameters).
    #   Attach an errback to be notified of failure (with an error parameter
    #   which includes the HTTP status code returned)
    # @raise [LoadError] unless em-http-request gem is available
    # @raise [Eventflit::Error] unless the eventmachine reactor is running. You
    #   probably want to run your application inside a server such as thin
    #
    def trigger_async(event_name, data, socket_id = nil)
      params = {}
      if socket_id
        validate_socket_id(socket_id)
        params[:socket_id] = socket_id
      end
      @client.trigger_async(name, event_name, data, params)
    end

    # Trigger event
    #
    # [Deprecated] This method will be removed in a future gem version. Please
    # switch to Eventflit.trigger or Eventflit::Client#trigger instead
    #
    # @example
    #   begin
    #     Eventflit['my-channel'].trigger!('an_event', {:some => 'data'})
    #   rescue Eventflit::Error => e
    #     # Do something on error
    #   end
    #
    # @param data [Object] Event data to be triggered in javascript.
    #   Objects other than strings will be converted to JSON
    # @param socket_id Allows excluding a given socket_id from receiving the
    #   event - see http://eventflit.com/docs/publisher_api_guide/publisher_excluding_recipients for more info
    #
    # @raise [Eventflit::Error] on invalid Eventflit response - see the error message for more details
    # @raise [Eventflit::HTTPError] on any error raised inside http client - the original error is available in the original_error attribute
    #
    def trigger!(event_name, data, socket_id = nil)
      params = {}
      if socket_id
        validate_socket_id(socket_id)
        params[:socket_id] = socket_id
      end
      @client.trigger(name, event_name, data, params)
    end

    # Trigger event, catching and logging any errors.
    #
    # [Deprecated] This method will be removed in a future gem version. Please
    # switch to Eventflit.trigger or Eventflit::Client#trigger instead
    #
    # @note CAUTION! No exceptions will be raised on failure
    # @param (see #trigger!)
    #
    def trigger(event_name, data, socket_id = nil)
      trigger!(event_name, data, socket_id)
    rescue Eventflit::Error => e
      Eventflit.logger.error("#{e.message} (#{e.class})")
      Eventflit.logger.debug(e.backtrace.join("\n"))
    end

    # Request info for a channel
    #
    # @example Response
    #   [{:occupied=>true, :subscription_count => 12}]
    #
    # @param info [Array] Array of attributes required (as lowercase strings)
    # @return [Hash] Hash of requested attributes for this channel
    # @raise [Eventflit::Error] on invalid Eventflit response - see the error message for more details
    # @raise [Eventflit::HTTPError] on any error raised inside http client - the original error is available in the original_error attribute
    #
    def info(attributes = [])
      @client.channel_info(name, :info => attributes.join(','))
    end

    # Request users for a presence channel
    # Only works on presence channels (see: http://docs.eventflit.com/client_api_guide/client_presence_channels and https://eventflit.com/docs/rest_api)
    #
    # @example Response
    #   [{:id=>"4"}]
    #
    # @param params [Hash] Hash of parameters for the API - see REST API docs
    # @return [Hash] Array of user hashes for this channel
    # @raise [Eventflit::Error] on invalid Eventflit response - see the error message for more details
    # @raise [Eventflit::HTTPError] on any error raised inside Net::HTTP - the original error is available in the original_error attribute
    #
    def users(params = {})
      @client.channel_users(name, params)[:users]
    end

    # Compute authentication string required as part of the authentication
    # endpoint response. Generally the authenticate method should be used in
    # preference to this one
    #
    # @param socket_id [String] Each Eventflit socket connection receives a
    #   unique socket_id. This is sent from eventflit.js to your server when
    #   channel authentication is required.
    # @param custom_string [String] Allows signing additional data
    # @return [String]
    #
    # @raise [Eventflit::Error] if socket_id or custom_string invalid
    #
    def authentication_string(socket_id, custom_string = nil)
      validate_socket_id(socket_id)

      unless custom_string.nil? || custom_string.kind_of?(String)
        raise Error, 'Custom argument must be a string'
      end

      string_to_sign = [socket_id, name, custom_string].
        compact.map(&:to_s).join(':')
      Eventflit.logger.debug "Signing #{string_to_sign}"
      token = @client.authentication_token
      digest = OpenSSL::Digest::SHA256.new
      signature = OpenSSL::HMAC.hexdigest(digest, token.secret, string_to_sign)

      return "#{token.key}:#{signature}"
    end

    # Generate the expected response for an authentication endpoint.
    # See http://docs.eventflit.com/authenticating_users for details.
    #
    # @example Private channels
    #   render :json => Eventflit['private-my_channel'].authenticate(params[:socket_id])
    #
    # @example Presence channels
    #   render :json => Eventflit['presence-my_channel'].authenticate(params[:socket_id], {
    #     :user_id => current_user.id, # => required
    #     :user_info => { # => optional - for example
    #       :name => current_user.name,
    #       :email => current_user.email
    #     }
    #   })
    #
    # @param socket_id [String]
    # @param custom_data [Hash] used for example by private channels
    #
    # @return [Hash]
    #
    # @raise [Eventflit::Error] if socket_id or custom_data is invalid
    #
    # @private Custom data is sent to server as JSON-encoded string
    #
    def authenticate(socket_id, custom_data = nil)
      custom_data = MultiJson.encode(custom_data) if custom_data
      auth = authentication_string(socket_id, custom_data)
      r = {:auth => auth}
      r[:channel_data] = custom_data if custom_data
      r
    end

    private

    def validate_socket_id(socket_id)
      unless socket_id && /\A\d+\.\d+\z/.match(socket_id)
        raise Eventflit::Error, "Invalid socket ID #{socket_id.inspect}"
      end
    end
  end
end
