begin
  require 'bundler/setup'
rescue LoadError
  puts 'although not required, it is recommended that you use bundler when running the tests'
end

ENV['EVENTFLIT_URL']= 'http://some:secret@service.eventflit.com:441/apps/54'

require 'rspec'
require 'em-http' # As of webmock 1.4.0, em-http must be loaded first
require 'webmock/rspec'

require 'eventflit'
require 'eventmachine'

RSpec.configure do |config|
  config.before(:each) do
    WebMock.reset!
    WebMock.disable_net_connect!
  end
end

def hmac(key, data)
  digest = OpenSSL::Digest::SHA256.new
  OpenSSL::HMAC.hexdigest(digest, key, data)
end
