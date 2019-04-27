## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).

# Set environment
ENV['RACK_ENV'] ||= 'production'

require 'sinatra'
require 'sinatra/config_file'
require 'yaml'
require 'json-schema'
require 'open-uri'

# Require the bundler gem and then call Bundler.require to load in all gems
# listed in Gemfile.
require 'bundler'
Bundler.require :default, ENV['RACK_ENV'].to_sym

require_relative 'models/init'
require_relative 'routes/init'
require_relative 'helpers/init'

configure do

end

before do

end

# set MongoDB mongoid configuration file from variables
# write variables to mongoid config file unless empty?
unless ENV['MAIN_DB'].nil?
  p "MAIN_DB = #{ENV['MAIN_DB']}"
  config = YAML.load_file('config/mongoid.yml')
  config[ENV['RACK_ENV'].to_s]['sessions']['default']['database'] = ENV['MAIN_DB']
  config[ENV['RACK_ENV'].to_s]['sessions']['default']['hosts'][0] = ENV['MAIN_DB_HOST']
  File.open('config/mongoid.yml','w') do |conf|
    conf.write config.to_yaml
  end
end


# Configurations for Services Repository
class SonataNsRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
end

# Configurations for Slice Repository
class SonataNsiRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
end

# Configurations for Functions Repository
class SonataVnfRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
end

# Configurations for Catalogues
class TangoVnVTrRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
end
