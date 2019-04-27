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
ENV['SEC_FLAG'] ||= true

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
  # Configuration for logging
  enable :logging
  Dir.mkdir("#{settings.root}/log") unless File.exist?("#{settings.root}/log")
  log_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
  log_file.sync = true
  use Rack::CommonLogger, log_file

  LOGGER = LOGGER.new(log_file)
  LOGGER.level = LOGGER::DEBUG
  set :LOGGER, LOGGER

  # Configuration for Authentication and Authorization layer
  conf = YAML::load_file("#{settings.root}/config/adapter.yml")
  set :auth_address, conf['address']
  set :auth_port, conf['port']
  set :api_ver, conf['api_ver']
  set :pub_key_path, conf['public_key_path']
  set :reg_path, conf['registration_path']
  set :login_path, conf['login_path']
  # set :authz_path, conf['authorization_path']
  set :access_token, nil

  # log_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
  # STDOUT.reopen(log_file)
  # STDOUT.sync = true
  retries = 0
  code = 503
  if ENV['SEC_FLAG'] == 'true'
    while retries <= 6 do
      # turn keycloak realm pub key into an actual openssl compat pub key
      LOGGER.debug(component:LOGGED_COMPONENT, operation:'msg', message:"RETRY=#{retries}")
      code, keycloak_key = get_public_key(settings.auth_address,
                                          settings.auth_port,
                                          settings.api_ver,
                                          settings.pub_key_path)
      LOGGER.debug(component:LOGGED_COMPONENT, operation:'msg', message:"PUBLIC_KEY_CODE=#{code}")
      LOGGER.debug(component:LOGGED_COMPONENT, operation:'msg', message:"PUBLIC_KEY_MSG=#{keycloak_key}")
      if code.to_i == 200
        keycloak_key, errors = parse_json(keycloak_key)
        LOGGER.debug(component:LOGGED_COMPONENT, operation:'msg', message:"PUBLIC_KEY=#{keycloak_key['items']['public-key']}")
        break unless keycloak_key['items']['public-key'].empty?
      end
      retries += 1
      sleep(8)
    end
  end

  if code.to_i == 200
    # keycloak_key, errors = parse_json(keycloak_key)
    # LOGGER.debug(component:LOGGED_COMPONENT, operation:'msg', message:"PUBLIC_KEY=#{keycloak_key['items']['public-key']}")
    @s = "-----BEGIN PUBLIC KEY-----\n"
    @s += keycloak_key['items']['public-key'].scan(/.{1,64}/).join("\n")
    @s += "\n-----END PUBLIC KEY-----\n"
    begin
      @key = OpenSSL::PKey::RSA.new @s
      set :keycloak_pub_key, @key
    rescue
      set :keycloak_pub_key, nil
    end
  else
    set :keycloak_pub_key, nil
  end

  unless settings.keycloak_pub_key.nil?
    response, r_code = register_service(settings.auth_address, settings.auth_port, settings.api_ver, settings.reg_path)
    LOGGER.debug(component:LOGGED_COMPONENT, operation:'msg', message:"REG_RESPONSE=#{response} - #{r_code}")
    if response
      access_token = login_service(settings.auth_address, settings.auth_port, settings.api_ver, settings.login_path)
      LOGGER.debug(component:LOGGED_COMPONENT, operation:'msg', message:"ACCESS_TOKEN=#{access_token}")
      set :access_token, access_token unless access_token.nil?
    end
  end
  # STDOUT.sync = false
end

before do
  LOGGER.level = LOGGER::DEBUG

  log_file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
  STDOUT.reopen(log_file)
  STDOUT.sync = true

  # SECURITY CHECKS
  unless settings.keycloak_pub_key.nil? || settings.access_token.nil?
    settings.LOGGER.debug "TOKEN_TO_CHECK=#{settings.access_token}"
    status = decode_token(settings.access_token, settings.keycloak_pub_key)
    settings.LOGGER.debug "TOKEN_STATUS=#{status}"
    unless status
    access_token = login_service(settings.auth_address, settings.auth_port, settings.api_ver, settings.login_path)
    settings.access_token = access_token unless access_token.nil?
    end
  end
  STDOUT.sync = false

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

unless ENV['SECOND_DB'].nil?
  p "SECOND_DB = #{ENV['SECOND_DB']}"
  config = YAML.load_file('config/mongoid.yml')
  config['production_secondary'] = {'sessions' =>
                                       {'default' =>
                                            {'database' => ENV['SECOND_DB'],
                                                              'hosts' => [ENV['SECOND_DB_HOST']]}}}
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
  before {
    env['rack.LOGGER'] = LOGGER.new "#{settings.root}/log/#{settings.environment}.log"
  }
end

# Configurations for Slice Repository
class SonataNsiRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
  before {
    env['rack.LOGGER'] = LOGGER.new "#{settings.root}/log/#{settings.environment}.log"
  }
end

# Configurations for Functions Repository
class SonataVnfRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
  before {
     env['rack.LOGGER'] = LOGGER.new "#{settings.root}/log/#{settings.environment}.log"
  }
end

# Configurations for Catalogues
class TangoVnVTrRepository < Sinatra::Application
  register Sinatra::ConfigFile
  # Load configurations
  config_file 'config/config.yml'
  Mongoid.load!('config/mongoid.yml')
  before {
    env['rack.LOGGER'] = LOGGER.new "#{settings.root}/log/#{settings.environment}.log"
  }
end
