Eventflit gem
==========

## Installation & Configuration

Add eventflit to your Gemfile, and then run `bundle install`

``` ruby
gem 'eventflit'
```

or install via gem

``` bash
gem install eventflit
```

After registering at <http://eventflit.com> configure your app with the security credentials.

### Instantiating a Eventflit client

Creating a new Eventflit `client` can be done as follows.

``` ruby
require 'eventflit'

eventflit_client = Eventflit::Client.new(
  app_id: 'your-app-id',
  key: 'your-app-key',
  secret: 'your-app-secret',
  cluster: 'your-app-cluster',
)
```
The cluster value will set the `host` to `api-<cluster>.eventflit.com`.

If you want to set a custom `host` value for your client then you can do so when instantiating a Eventflit client like so:

``` ruby
require 'eventflit'

eventflit_client = Eventflit::Client.new(
  app_id: 'your-app-id',
  key: 'your-app-key',
  secret: 'your-app-secret',
  host: 'your-app-host'
)
```

If you pass both `host` and `cluster` options, the `host` will take precendence and `cluster` will be ignored.


Finally, if you have the configuration set in an `EVENTFLIT_URL` environment
variable, you can use:

``` ruby
eventflit_client = Eventflit::Client.from_env
```

### Global

Configuring Eventflit can also be done globally on the Eventflit class.

``` ruby
Eventflit.app_id = 'your-app-id'
Eventflit.key = 'your-app-key'
Eventflit.secret = 'your-app-secret'
Eventflit.cluster = 'your-app-cluster'
```

Global configuration will automatically be set from the `EVENTFLIT_URL` environment variable if it exists. This should be in the form  `http://KEY:SECRET@HOST/apps/APP_ID`. On Heroku this environment variable will already be set.

If you need to make requests via a HTTP proxy then it can be configured

``` ruby
Eventflit.http_proxy = 'http://(user):(password)@(host):(port)'
```

By default API requests are made over HTTP. HTTPS can be used by setting `encrypted` to `true`.
Issuing this command is going to reset `port` value if it was previously specified.

``` ruby
Eventflit.encrypted = true
```

As of version 0.12, SSL certificates are verified when using the synchronous http client. If you need to disable this behaviour for any reason use:

``` ruby
Eventflit.default_client.sync_http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
```

## Interacting with the Eventflit service

The Eventflit gem contains a number of helpers for interacting with the service. As a general rule, the library adheres to a set of conventions that we have aimed to make universal.

### Handling errors

Handle errors by rescuing `Eventflit::Error` (all errors are descendants of this error)

``` ruby
begin
  Eventflit.trigger('a_channel', 'an_event', :some => 'data')
rescue Eventflit::Error => e
  # (Eventflit::AuthenticationError, Eventflit::HTTPError, or Eventflit::Error)
end
```

### Logging

Errors are logged to `Eventflit.logger`. It will by default log at info level to STDOUT using `Logger` from the standard library, however you can assign any logger:

``` ruby
Eventflit.logger = Rails.logger
```

### Publishing events

An event can be published to one or more channels (limited to 10) in one API call:

``` ruby
Eventflit.trigger('channel', 'event', foo: 'bar')
Eventflit.trigger(['channel_1', 'channel_2'], 'event_name', foo: 'bar')
```

An optional fourth argument may be used to send additional parameters to the API, for example to [exclude a single connection from receiving the event](http://docs.eventflit.com/publisher_api_guide/publisher_excluding_recipients).

``` ruby
Eventflit.trigger('channel', 'event', {foo: 'bar'}, {socket_id: '123.456'})
```

#### Batches

It's also possible to send multiple events with a single API call (max 10
events per call on multi-tenant clusters):

``` ruby
Eventflit.trigger_batch([
  {channel: 'channel_1', name: 'event_name', data: { foo: 'bar' }},
  {channel: 'channel_1', name: 'event_name', data: { hello: 'world' }}
])
```

#### Deprecated publisher API

Most examples and documentation will refer to the following syntax for triggering an event:

``` ruby
Eventflit['a_channel'].trigger('an_event', :some => 'data')
```

This will continue to work, but has been replaced by `Eventflit.trigger` which supports one or multiple channels.

### Using the Eventflit REST API

This gem provides methods for accessing information from the [Eventflit REST API](https://docs.eventflit.com/rest_api). The documentation also shows an example of the responses from each of the API endpoints.

The following methods are provided by the gem.

- `Eventflit.channel_info('channel_name')` returns information about that channel.

- `Eventflit.channel_users('channel_name')` returns a list of all the users subscribed to the channel.

- `Eventflit.channels` returns information about all the channels in your Eventflit application.

### Asynchronous requests

There are two main reasons for using the `_async` methods:

* In a web application where the response from Eventflit is not used, but you'd like to avoid a blocking call in the request-response cycle
* Your application is running in an event loop and you need to avoid blocking the reactor

Asynchronous calls are supported either by using an event loop (eventmachine, preferred), or via a thread.

The following methods are available (in each case the calling interface matches the non-async version):

* `Eventflit.get_async`
* `Eventflit.post_async`
* `Eventflit.trigger_async`

It is of course also possible to make calls to eventflit via a job queue. This approach is recommended if you're sending a large number of events to eventflit.

#### With eventmachine

* Add the `em-http-request` gem to your Gemfile (it's not a gem dependency).
* Run the eventmachine reactor (either using `EM.run` or by running inside an evented server such as Thin).

The `_async` methods return an `EM::Deferrable` which you can bind callbacks to:

``` ruby
Eventflit.get_async("/channels").callback { |response|
  # use response[:channels]
}.errback { |error|
  # error is an instance of Eventflit::Error
}
```

A HTTP error or an error response from eventflit will cause the errback to be called with an appropriate error object.

#### Without eventmachine

If the eventmachine reactor is not running, async requests will be made using threads (managed by the httpclient gem).

An `HTTPClient::Connection` object is returned immediately which can be [interrogated](http://rubydoc.info/gems/httpclient/HTTPClient/Connection) to discover the status of the request. The usual response checking and processing is not done when the request completes, and frankly this method is most useful when you're not interested in waiting for the response.


## Authenticating subscription requests

It's possible to use the gem to authenticate subscription requests to private or presence channels. The `authenticate` method is available on a channel object for this purpose and returns a JSON object that can be returned to the client that made the request. More information on this authentication scheme can be found in the docs on <http://eventflit.com>

### Private channels

``` ruby
Eventflit.authenticate('private-my_channel', params[:socket_id])
```

### Presence channels

These work in a very similar way, but require a unique identifier for the user being authenticated, and optionally some attributes that are provided to clients via presence events:

``` ruby
Eventflit.authenticate('presence-my_channel', params[:socket_id],
  user_id: 'user_id',
  user_info: {} # optional
)
```

## Receiving WebHooks

A WebHook object may be created to validate received WebHooks against your app credentials, and to extract events. It should be created with the `Rack::Request` object (available as `request` in Rails controllers or Sinatra handlers for example).

``` ruby
webhook = Eventflit.webhook(request)
if webhook.valid?
  webhook.events.each do |event|
    case event["name"]
    when 'channel_occupied'
      puts "Channel occupied: #{event["channel"]}"
    when 'channel_vacated'
      puts "Channel vacated: #{event["channel"]}"
    end
  end
  render text: 'ok'
else
  render text: 'invalid', status: 401
end
```

## Push Notifications (BETA)

Eventflit now allows sending native notifications to iOS and Android devices. Check out the [documentation](https://docs.eventflit.com/push_notifications) for information on how to set up push notifications on Android and iOS. There is no additional setup required to use it with this library. It works out of the box with the same Eventflit instance. All you need are the same eventflit credentials.

### Sending native pushes

The native notifications API is hosted at `push.eventflit.com` and only accepts https requests.

You can send pushes by using the `notify` method, either globally or on the instance. The method takes two parameters:

- `interests`: An Array of strings which represents the interests your devices are subscribed to. These are akin to channels in the DDN with less of an epehemeral nature. Note that currently, you can only publish to, at most, _ten_ interests.
- `data`: The content of the notification represented by a Hash. You must supply either the `gcm` or `apns` key. For a detailed list of the acceptable keys, take a look at the [iOS](https://docs.eventflit.com/push_notifications/ios/server) and [Android](https://docs.eventflit.com/push_notifications/android/server) docs.

Example:

```ruby
data = {
  apns: {
    aps: {
      alert: {
        body: 'tada'
      }
    }
  }
}

eventflit.notify(["my-favourite-interest"], data)
```

### Errors

Push notification requests, once submitted to the service are executed asynchronously. To make reporting errors easier, you can supply a `webhook_url` field in the body of the request. This will be used by the service to send a webhook to the supplied URL if there are errors.

For example:

```ruby
data = {
  apns: {
    aps: {
      alert: {
        body: "hello"
      }
    }
  },
  gcm: {
    notification: {
      title: "hello",
      icon: "icon"
    }
  },
  webhook_url: "http://yolo.com"
}
```

**NOTE:** This is currently a BETA feature and there might be minor bugs and issues. Changes to the API will be kept to a minimum, but changes are expected. If you come across any bugs or issues, please do get in touch via [support](support@eventflit.com) or create an issue here.
