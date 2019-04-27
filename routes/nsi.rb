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

require 'addressable/uri'
require 'pp'
require 'json'
require 'tng/gtk/utils/logger'

# This is the Class of Sonata Network Slice Repository
class SonataNsiRepository < Sinatra::Application
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  @@began_at = Time.now.utc
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'START', message:"Started at #{@@began_at}")

  @@nsir_schema = JSON.parse(JSON.dump(YAML.load(open('https://raw.githubusercontent.com/sonata-nfv/tng-schema/master/slice-record/nsir-schema.yml') { |f| f.read })))
  # https and openssl libs (require 'net/https' require 'openssl') enable access to external https links behind a proxy
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', message:"nsir_schema #{nsir_schema.to_yaml}")

  DEFAULT_PAGE_NUMBER = '0'
  DEFAULT_PAGE_SIZE = '10'
  DEFAULT_MAX_PAGE_SIZE = '100'

  # @method get_root
  # @overload get '/'
  get '/' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, interfaces_list.to_yaml
  end

   get '/pings' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, 'pong'
   end

  # @method get_ns-instances
  # @overload get "/ns-instances"
  # Gets all ns-instances
  get '/ns-instances' do
    uri = Addressable::URI.new
    params['page_number'] ||= DEFAULT_PAGE_NUMBER
    params['page_size'] ||= DEFAULT_PAGE_SIZE
    uri.query_values = params
    LOGGER.info(component:LOGGED_COMPONENT, operation:'msg', message:"nsir: entered GET /records/nsir/ns-instances?#{uri.query}")

    # transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)

    # Get paginated list
    headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    headers[:params] = params unless params.empty?
    # get rid of :page_number and :page_size
    [:page_number, :page_size].each { |k| keyed_params.delete(k) }
    valid_fields = [:page_number, :page_size]
    LOGGER.info(component:LOGGED_COMPONENT, operation:'msg', message:"nsir: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}")
    json_error 400, "nsir: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

    requests = Nsir.paginate(page_number: params[:page_number], limit: params[:page_size]).desc(:created_at)
    LOGGER.info(component:LOGGED_COMPONENT, operation:'msg', message:"nsir: leaving GET /requests?#{uri.query} with #{requests.to_json}")
    halt 200, requests.to_json if requests
    json_error 404, 'nsir: No requests were found'

    begin
      # Get paginated list
      nsir_json = @nsir.to_json
      if content_type == 'application/json'
        return 200, nsir_json
      elsif content_type == 'application/x-yaml'
        headers 'Content-Type' => 'text/plain; charset=utf8'
        nsir_yml = json_to_yaml(nsir_json)
        return 200, nsir_yml
      end
    rescue
      LOGGER.error(component:LOGGED_COMPONENT, operation:'msg', message: 'Error Establishing a Database Connection')
      return 500, 'Error Establishing a Database Connection'
    end
  end

  # @method get_ns-instances
  # @overload get "/ns-instances"
  # Gets ns-instances with an id
  get '/ns-instances/:id' do
    begin
      @nsiinstance = Nsir.find(params[:id])
    rescue Mongoid::Errors::DocumentNotFound => e
      halt(404)
    end
    nsir_json = @nsiinstance.to_json
    return 200, nsir_json
  end

  # @method post_ns-instances
  # @overload post "/ns-instances"
  # Post a new ns-instances information
  post '/ns-instances' do
    return 415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    nsir_json = instance
    return 400, errors.to_json if errors
    # Validation against schema
    errors = validate_json(nsir_json, @@nsir_schema)

    puts 'nsir: ', Nsir.to_json
    return 422, errors.to_json if errors

    begin
      instance = Nsir.find({ '_id' => instance['_id'] })
      return 409, 'ERROR: Duplicated nsir UUID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    begin
      instance = Nsir.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated nsir UUID'
    end
    return 200, instance.to_json
  end

  # @method put_ns-instances
  # @overload put "/ns-instances"
  # Puts a ns-instances record
  put '/ns-instances/:id' do
    # Return if content-type is invalid
    415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    return 400, errors.to_json if errors
    # Retrieve stored version
    new_nsir = instance
    
    # Validation against schema
    errors = validate_json(new_nsir, @@nsir_schema)

    puts 'nsir: ', Nsir.to_json
    return 422, errors.to_json if errors

    begin
      nsir = Nsir.find_by('_id' => params[:id])
      puts 'nsir is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'nsir not found'
    end

    # Update to new version
    puts 'Updating...'
    begin
      # Delete old record
      Nsir.where('_id' => params[:id]).delete
      # Create a record
      new_nsir = Nsir.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated nsir UUID'
    end

    nsir_json = new_nsir.to_json
    return 200, nsir_json
  end

  delete '/ns-instances/:id' do
    # Return if content-type is invalid
    begin
      nsir = Nsir.find_by('_id' => params[:id])
      puts 'nsir is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'nsir not found'
    end

    # Delete the nsir
    puts 'Deleting...'
    begin
      # Delete the network service record
      Nsir.where('_id' => params[:id]).delete
    end

    return 200
    # return 200, new_ns.to_json
  end
end
