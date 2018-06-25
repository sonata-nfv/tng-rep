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
## page_sizeations under the License.
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

# This Class is the Class of Sonata Ns Repository
class TangoVnVTrRepository < Sinatra::Application
  # @@trr_schema = JSON.parse(JSON.dump(YAML.load(open('') { |f| f.read })))
  # https and openssl libs (require 'net/https' require 'openssl') enable access to external https links behind a proxy

  DEFAULT_PAGE_NUMBER = '0'
  DEFAULT_PAGE_SIZE = '10'
  DEFAULT_MAX_LIMIT = '100'

  # @method get_root
  # @overload get '/'
  get '/' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, interfaces_list.to_yaml
  end

  # @method get_test-plans
  # @overload get "/test-plans"
  # Gets all test-plans
  get '/test-plans' do
    uri = Addressable::URI.new
    params['page_number'] ||= DEFAULT_PAGE_NUMBER
    params['page_size'] ||= DEFAULT_PAGE_SIZE
    uri.query_values = params
    logger.info "trr: entered GET /trr/test-plans?#{uri.query}"

    # transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)

    # Get paginated list
    headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    headers[:params] = params unless params.empty?
    # get rid of :page_number and :page_size
    [:page_number, :page_size].each { |k| keyed_params.delete(k) }
    valid_fields = [:page]
    logger.info "trr: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"
    json_error 400, "trr: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

    requests = Trr.paginate(page: params[:page], page_size: params[:page_size])
    logger.info "trr: leaving GET /requests?#{uri.query} with #{requests.to_json}"
    halt 200, requests.to_json if requests
    json_error 404, 'trr: No requests were found'

    begin
      # Get paginated list
      trr_json = @trr.to_json
      if content_type == 'application/json'
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
        return 200, trr_json
      elsif content_type == 'application/x-yaml'
        #headers 'Content-Type' => 'text/plain; charset=utf8'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
        trr_yml = json_to_yaml(trr_json)
        return 200, trr_yml
      end
    rescue
      logger.error 'Error Establishing a Database Connection'
      return 500, 'Error Establishing a Database Connection'
    end
  end

  # @method get_test-plans
  # @overload get "/test-plans"
  # Gets test-plans with an id
  get '/test-plans/:id' do
    begin
      @nsinstance = Trr.find(params[:id])
    rescue Mongoid::Errors::DocumentNotFound => e
      halt(404)
    end
    trr_json = @nsinstance.to_json
    return 200, trr_json
  end

  # @method post_test-plans
  # @overload post "/test-plans"
  # Post a new test-plans information
  post '/test-plans' do    
    content_type:json
    return 415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    #trr_json = instance
    return 400, errors.to_json if errors
    # Validation against schema
    #errors = validate_json(trr_json, @@trr_schema)

    #puts 'trr: ', Trr.to_json
    #return 422, errors.to_json if errors

    begin
      instance = Trr.find({ '_id' => instance['_id'] })
      return 409, 'ERROR: Duplicated trr UUID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    begin
      instance = Trr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated trr UUID'
    end
    return 200, instance.to_json
  end

  # @method put_test-plans
  # @overload put "/test-plans"
  # Puts a test-plans record
  put '/test-plans/:id' do
    content_type:json
    # Return if content-type is invalid
    415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    return 400, errors.to_json if errors
    # Retrieve stored version
    #new_trr = instance
    
    # Validation against schema
    #errors = validate_json(new_trr, @@trr_schema)

    #puts 'trr: ', Trr.to_json
    #return 422, errors.to_json if errors

    begin
      trr = Trr.find_by('_id' => params[:id])
      puts 'trr is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'trr not found'
    end

    # Update to new version
    puts 'Updating...'
    begin
      # Delete old record
      Trr.where('_id' => params[:id]).delete
      # Create a record
      new_trr = Trr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated trr UUID'
    end

    trr_json = new_trr.to_json
    return 200, trr_json
  end

  delete '/test-plans/:id' do
    # Return if content-type is invalid
    begin
      trr = Trr.find_by('_id' => params[:id])
      puts 'trr is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'trr not found'
    end

    # Delete the trr
    puts 'Deleting...'
    begin
      # Delete the network service record
      Trr.where('_id' => params[:id]).delete
    end

    return 200
    # return 200, new_ns.to_json
  end
 #
 #
 ########################
 # test-suite-results API
 ########################
 #
 #
 # @method get_test-suite-results
  # @overload get "/test-suite-results"
  # Gets all test-suite-results
  get '/test-suite-results' do
    uri = Addressable::URI.new
    params['page_number'] ||= DEFAULT_PAGE_NUMBER
    params['page_size'] ||= DEFAULT_PAGE_SIZE
    uri.query_values = params
    logger.info "trr: entered GET /trr/test-suite-results?#{uri.query}"

    # transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)

    # Get paginated list
    headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    headers[:params] = params unless params.empty?
    # get rid of :page_number and :page_size
    [:page_number, :page_size].each { |k| keyed_params.delete(k) }
    valid_fields = [:page]
    logger.info "trr: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"
    json_error 400, "trr: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

    requests = Tsr.paginate(page: params[:page], page_size: params[:page_size])
    logger.info "trr: leaving GET /requests?#{uri.query} with #{requests.to_json}"
    halt 200, requests.to_json if requests
    json_error 404, 'trr: No requests were found'

    begin
      # Get paginated list
      trr_json = @trr.to_json
      if content_type == 'application/json'
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
        return 200, trr_json
      elsif content_type == 'application/x-yaml'
        headers 'Content-Type' => 'text/plain; charset=utf8'
        trr_yml = json_to_yaml(trr_json)
        return 200, trr_yml
      end
    rescue
      logger.error 'Error Establishing a Database Connection'
      return 500, 'Error Establishing a Database Connection'
    end
  end

  # @method get_test-suite-results
  # @overload get '/test-suite-results/?'
  #	Returns a list of NSs
  # -> List many descriptors
  get '/test-suite-results/?' do
    params['page_number'] ||= DEFAULT_PAGE_NUMBER
    params['page_size'] ||= DEFAULT_PAGE_SIZE
    logger.info "trr: entered GET /test-suite-results?#{query_string}"

    headers[:params] = params unless params.empty?

    # Get rid of :page_number and :page_size
    [:page_number, :page_size].each { |k| keyed_params.delete(k) }

    # Validating URL Fields
    valid_fields = [:page, :ns_uuid]
    logger.info "trr: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"
    json_error 400, "trr: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

      # Do the query
      keyed_params = parse_keys_dict(:ns_uuid, keyed_params)
      tsr = Tsr.where(keyed_params)
      # Set total count for results
      headers 'Record-Count' => tsr.count.to_s
      logger.info "trr: Test Suite Results=#{tsr}"
      if tsr && tsr.size.to_i > 0
        logger.info "trr: leaving GET /test-suite-results?#{query_string} with #{tsr}"
        # Paginate results
        tsr = tsr.paginate(page_number: params[:page_number], page_size: params[:page_size])
      else
        logger.info "trr: leaving GET /test-suite-results?#{query_string} with 'No Test Suite Results were found'"
      end
    end

    response = ''
    case request.content_type
      when 'application/json'
        response = tsr.to_json
      when 'application/x-yaml'
        response = json_to_yaml(tsr.to_json)
      else
        halt 415
    end
    halt 200, {'Content-type' => request.content_type}, response
  end

  # @method get_test-suite-results
  # @overload get "/test-suite-results"
  # Gets test-suite-results with an id
  get '/test-suite-results/:id' do
    begin
      @nsinstance = Tsr.find(params[:id])
    rescue Mongoid::Errors::DocumentNotFound => e
      halt(404)
    end
    trr_json = @nsinstance.to_json
    return 200, trr_json
  end

  # @method post_test-suite-results
  # @overload post "/test-suite-results"
  # Post a new test-suite-results information
  post '/test-suite-results' do
    content_type:json
    return 415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    #trr_json = instance
    return 400, errors.to_json if errors
    # Validation against schema
    #errors = validate_json(trr_json, @@trr_schema)
    #puts 'trr: ', Tsr.to_json
    #return 422, errors.to_json if errors

    begin
      instance = Tsr.find({ '_id' => instance['_id'] })
      return 409, 'ERROR: Duplicated trr UUID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    begin
      instance = Tsr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated trr UUID'
    end
    return 200, instance.to_json
  end

  # @method puttest-suite-results
  # @overload put "/test-suite-results"
  # Puts a test-suite-results record
  put '/test-suite-results/:id' do
    content_type:json
    # Return if content-type is invalid
    415 unless request.content_type == 'application/json'
    # Validate JSON format
    instance, errors = parse_json(request.body.read)
    return 400, errors.to_json if errors
    # Retrieve stored version
    #new_trr = instance
    
    # Validation against schema
    #errors = validate_json(new_trr, @@trr_schema)

    puts 'trr: ', Tsr.to_json
    return 422, errors.to_json if errors

    begin
      trr = Tsr.find_by('_id' => params[:id])
      puts 'trr is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'trr not found'
    end

    # Update to new version
    puts 'Updating...'
    begin
      # Delete old record
      Tsr.where('_id' => params[:id]).delete
      # Create a record
      new_trr = Tsr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated trr UUID'
    end

    trr_json = new_trr.to_json
    return 200, trr_json
  end

  delete '/test-suite-results/:id' do
    # Return if content-type is invalid
    begin
      trr = Tsr.find_by('_id' => params[:id])
      puts 'trr is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'trr not found'
    end
    puts 'trr: ', Tsr.to_json
    return 422, errors.to_json if errors
    # Delete the test-suite-results
    puts 'Deleting...'
    begin
      # Delete the network service record
      Tsr.where('_id' => params[:id]).delete
    end

    return 200
    # return 200, new_ns.to_json
  end
end
