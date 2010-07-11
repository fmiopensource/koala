ENV['RACK_ENV'] = 'test'

require File.expand_path(File.join(File.dirname(__FILE__), "..", "init"))

require "spec"
require "rack/test"
require 'webrat'

begin
  puts "Connected to Redis #{Ohm.redis.info[:redis_version]} on #{monk_settings(:redis)[:host]}:#{monk_settings(:redis)[:port]}, database #{monk_settings(:redis)[:db]}."
rescue Errno::ECONNREFUSED
  puts <<-EOS

    Cannot connect to Redis.

    Make sure Redis is running on #{monk_settings(:redis)[:host]}:#{monk_settings(:redis)[:port]}.
    This testing suite connects to the database #{monk_settings(:redis)[:db]}.

    To start the server:
      env RACK_ENV=test monk redis start

    To stop the server:
      env RACK_ENV=test monk redis stop

  EOS
  exit 1
end

module Koala
  module SpecMethods
    def app
      Main.new
    end
  end
end

Spec::Runner.configure do |config|
  config.include Rack::Test::Methods
  config.include Koala::SpecMethods
  config.include Webrat::Matchers
  config.mock_with :mocha
  config.after(:all) do
    Ohm.flush
  end
end