require "init"
require 'resque/server'

Main.set :run, false
Main.set :environment, :production

# run Main
run Rack::URLMap.new \
  "/" => Main,
  "/resque" => Resque::Server.new