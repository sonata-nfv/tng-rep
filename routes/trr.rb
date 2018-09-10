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

# This Class is the Class of Sonata Ns Repository
class TangoVnVTrRepository < Sinatra::Application
  # @@trr_schema = JSON.parse(JSON.dump(YAML.load(open('') { |f| f.read })))
  # https and openssl libs (require 'net/https' require 'openssl') enable access to external https links behind a proxy

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
    valid_fields = [:page_number, :page_size]
    logger.info "trr: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"
    json_error 400, "trr: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

    requests = Trr.paginate(page_number: params[:page_number], page_size: params[:page_size])
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
      instance['_id'] = SecureRandom.uuid
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
      instance['_id'] = SecureRandom.uuid
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
    [:page_number, :page_size, :ns_uuid, :test_uuid].each { |k| keyed_params.delete(k) }
    valid_fields = [:page_number, :page_size, :ns_uuid, :test_uuid]
    logger.info "trr: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"
    json_error 400, "trr: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

    if params[:ns_uuid]
      requests = Tsr.paginate(page_number: params[:page_number], page_size: params[:page_size]).where("ns_uuid" => params[:ns_uuid])
    elsif params[:test_uuid]
      requests = Tsr.paginate(page_number: params[:page_number], page_size: params[:page_size]).where("test_uuid" => params[:test_uuid])
    elsif
      requests = Tsr.paginate(page_number: params[:page_number], page_size: params[:page_size])
    end
    logger.info "trr: leaving GET /requests?#{uri.query} with #{requests.to_json}"

    fields = ['created_at', 'instance_uuid', 'package_id', 'service_uuid', 'status', 'test_plan_id', 'test_uuid', 'updated_at', 'uuid']
    halt 200, requests.to_json(:only => fields) if requests
    
#    halt 200, requests.to_json if requests
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
  # @overload get "/test-suite-results"
  # Gets test-suite-results with an id
  
  get '/test-suite-results/:id' do
    begin
      @nsinstance = Tsr.find_by('uuid' => params[:id])
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
      instance['_id'] = SecureRandom.uuid
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
      instance['_id'] = SecureRandom.uuid
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
  
  get '/test-suite-results/count/:test_uuid' do
    begin      
      requests = Tsr.where("test_uuid" => params[:test_uuid]).count()
      number = {}
      number['test_uuid'] = params[:test_uuid].to_s
      number['count'] = requests.to_s
      logger.info "tsr: test_uuid: #{number[:test_uuid]} count: #{number[:count]}"
      halt 200,  number.to_json
      json_error 404, 'trr: No requests were found'
    rescue Mongoid::Errors::DocumentNotFound => e
      halt(404)
    end
  end


  get '/test-suite-results/last-time-executed/:test_uuid' do
    begin      
      requests = Tsr.where("test_uuid" => params[:test_uuid])
      number = {}
      number['test_uuid'] = params[:test_uuid].to_s

      last_time = ['created_at']
      requests.to_json(:only => last_time) if requests
      final = requests[-1].to_json(:only => last_time)

      string_0 = final.to_s 
      string_1 = string_0.split(':')     
      string_2 = string_1[1] + ":" + string_1[2] + ":" + string_1[3] + ":" + string_1[4]
      string_3 = string_2.split('"')   
      string_4 = string_3[1]

      number['last_time_executed'] = string_4

#      logger.info "tsr: test_uuid: #{number[:test_uuid]} count: #{number[:count]}"
      halt 200,  number.to_json
      json_error 404, 'trr: No requests were found'
    rescue Mongoid::Errors::DocumentNotFound => e
      halt(404)
    end
  end


end
