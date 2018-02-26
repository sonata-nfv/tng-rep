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

# This Class is the Class of Sonata Network Slice Repository
class SonataNslRepository < Sinatra::Application
  @@nslr_schema = JSON.parse(JSON.dump(YAML.load(open('https://raw.githubusercontent.com/sonata-nfv/tng-schema/master/slice-record/nsir-schema.yml') { |f| f.read })))
  # https and openssl libs (require 'net/https' require 'openssl') enable access to external https links behind a proxy

  DEFAULT_OFFSET = '0'
  DEFAULT_LIMIT = '10'
  DEFAULT_MAX_LIMIT = '100'

  # @method get_root
  # @overload get '/'
  get '/' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, interfaces_list.to_yaml
  end

  # @method get_nsl-instances
  # @overload get "/nsl-instances"
  # Gets all nsl-instances
  get '/nsl-instances' do
    uri = Addressable::URI.new
    params['offset'] ||= DEFAULT_OFFSET
    params['limit'] ||= DEFAULT_LIMIT
    uri.query_values = params
    logger.info "nslr: entered GET /records/nslr/nsl-instances?#{uri.query}"

    # transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)

    # Get paginated list
    headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    headers[:params] = params unless params.empty?
    # get rid of :offset and :limit
    [:offset, :limit].each { |k| keyed_params.delete(k) }
    valid_fields = [:page]
    logger.info "nslr: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"
    json_error 400, "nslr: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

    requests = Nslr.paginate(page: params[:page], limit: params[:limit])
    logger.info "nslr: leaving GET /requests?#{uri.query} with #{requests.to_json}"
    halt 200, requests.to_json if requests
    json_error 404, 'nslr: No requests were found'

    begin
      # Get paginated list
      nslr_json = @nslr.to_json
      if content_type == 'application/json'
        return 200, nslr_json
      elsif content_type == 'application/x-yaml'
        headers 'Content-Type' => 'text/plain; charset=utf8'
        nslr_yml = json_to_yaml(nslr_json)
        return 200, nslr_yml
      end
    rescue
      logger.error 'Error Establishing a Database Connection'
      return 500, 'Error Establishing a Database Connection'
    end
  end

  # @method get_nsl-instances
  # @overload get "/nsl-instances"
  # Gets nsl-instances with an id
  get '/nsl-instances/:id' do
    begin
      @nslinstance = Nslr.find(params[:id])
    rescue Mongoid::Errors::DocumentNotFound => e
      halt(404)
    end
    nslr_json = @nslinstance.to_json
    return 200, nslr_json
  end

  # @method post_nsl-instances
  # @overload post "/nsl-instances"
  # Post a new nsl-instances information
  post '/nsl-instances' do
    return 415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    nslr_json = instance
    return 400, errors.to_json if errors
    # Validation against schema
    errors = validate_json(nslr_json, @@nslr_schema)

    puts 'nslr: ', Nslr.to_json
    return 422, errors.to_json if errors

    begin
      instance = Nslr.find({ '_id' => instance['_id'] })
      return 409, 'ERROR: Duplicated nslr UUID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    begin
      instance = Nslr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated nslr UUID'
    end
    return 200, instance.to_json
  end

  # @method put_nsl-instances
  # @overload put "/nsl-instances"
  # Puts a nsl-instances record
  put '/nsl-instances/:id' do
    # Return if content-type is invalid
    415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    return 400, errors.to_json if errors
    # Retrieve stored version
    new_nslr = instance
    
    # Validation against schema
    errors = validate_json(new_nslr, @@nslr_schema)

    puts 'nslr: ', Nslr.to_json
    return 422, errors.to_json if errors

    begin
      nslr = Nslr.find_by('_id' => params[:id])
      puts 'nslr is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'nslr not found'
    end

    # Update to new version
    puts 'Updating...'
    begin
      # Delete old record
      Nslr.where('_id' => params[:id]).delete
      # Create a record
      new_nslr = Nslr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated nslr UUID'
    end

    nslr_json = new_nslr.to_json
    return 200, nslr_json
  end

  delete '/nsl-instances/:id' do
    # Return if content-type is invalid
    begin
      nslr = Nslr.find_by('_id' => params[:id])
      puts 'nslr is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'nslr not found'
    end

    # Delete the nslr
    puts 'Deleting...'
    begin
      # Delete the network service record
      Nslr.where('_id' => params[:id]).delete
    end

    return 200
    # return 200, new_ns.to_json
  end
end
