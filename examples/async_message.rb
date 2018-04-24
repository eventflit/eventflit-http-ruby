require 'rubygems'
require 'eventflit'
require 'eventmachine'
require 'em-http-request'

# To get these values:
# - Go to https://panel.eventflit.com/
# - Click on Choose App.
# - Click on one of your apps
# - Click API Access
Eventflit.app_id = 'your_app_id'
Eventflit.key = 'your_key'
Eventflit.secret = 'your_secret'


EM.run {
  deferrable = Eventflit['test_channel'].trigger_async('my_event', 'hi')

  deferrable.callback { # called on success
    puts "Message sent successfully."
    EM.stop
  }
  deferrable.errback { |error| # called on error
    puts "Message could not be sent."
    puts error
    EM.stop
  }
}
