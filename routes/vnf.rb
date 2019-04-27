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

require 'tng/gtk/utils/logger'

# @see VNFRepository
class SonataVnfRepository < Sinatra::Application
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  @@began_at = Time.now.utc
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'START', message:"Started at #{@@began_at}")

  @@vnfr_schema=JSON.parse(JSON.dump(YAML.load(open('https://raw.githubusercontent.com/sonata-nfv/tng-schema/master/function-record/vnfr-schema.yml'){|f| f.read})))
  # https and openssl libs (require 'net/https' require 'openssl') enable access to external https links behind a proxy
  LOGGER.info(component:LOGGED_COMPONENT, operation:'msg', message:"schema = #{@@vnfr_schema.to_yaml}")

  DEFAULT_PAGE_NUMBER = '0'
  DEFAULT_PAGE_SIZE = '10'
  DEFAULT_MAX_PAGE_SIZE = '100'

  before do
    # Gatekeepr authn. code will go here for future implementation
    # --> Gatekeeper authn. disabled

    if settings.environment == 'development'
      return
    end
    #authorized?
  end

  # @method get_doc
  # @overload get '/doc'
  # Get all available interfaces
  # -> Get all interfaces
  get '/doc' do
      headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, interfaces_list.to_yaml
  end

  get '/pings' do
    headers 'Content-Type' => 'text/plain; charset=utf8'
    halt 200, 'pong'
  end

  # @method get_vnfs
  # @overload get '/'
  #	Returns a list of VNFRs
  # List all VNFRs in JSON or YAML
  #   - JSON (default)
  #   - YAML including output parameter (e.g /?output=YAML)
  get '/' do

    uri = Addressable::URI.new
    params['page_number'] ||= DEFAULT_PAGE_NUMBER
    params['page_size'] ||= DEFAULT_PAGE_SIZE
    uri.query_values = params
    LOGGER.info(component:LOGGED_COMPONENT, operation:'msg', message:"vnfr: entered GET /vnfrs?#{uri.query}")

    # Only accept positive numbers
    params[:page_number] = 1 if params[:page_number].to_i < 1
    params[:page_size] = 2 if params[:page_size].to_i < 1

    # transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)

    # Get paginated list
    headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    headers[:params] = params unless params.empty?
    # get rid of :page_number and :page_size
    [:page_number, :page_size, :descriptor_reference].each { |k| keyed_params.delete(k) }
    valid_fields = [:page_number, :page_size, :descriptor_reference]
    LOGGER.info(component:LOGGED_COMPONENT, operation:'msg', message:"vnfrs: keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}")
    json_error 400, "vnfrs: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []

    if params[:descriptor_reference]
      vnfs = Vnfr.paginate(page: params[:page_number], limit: params[:page_size]).where("descriptor_reference" => params[:descriptor_reference]).desc(:created_at)
    else
      vnfs = Vnfr.paginate(page: params[:page_number], limit: params[:page_size]).desc(:created_at)
    end
    LOGGER.info(component:LOGGED_COMPONENT, operation:'msg', message:"vnfs: leaving GET /vnfrs?#{uri.query} with #{vnfs.to_json}")
    halt 200, vnfs.to_json if vnfs
    json_error 404, 'vnfs: No vnfrs were found'

    # Get paginated list
    vnfs = Vnfr.paginate(page: params[:page_number], limit: params[:page_size]).desc(:created_at)
    LOGGER.debug(component:LOGGED_COMPONENT, operation:'msg', message: "vnfs #{vnfs}")
    # Build HTTP Link Header
    headers['Link'] = build_http_link(params[:page_number].to_i, params[:page_size])

    if params[:output] == 'YAML'
      content_type = 'application/x-yaml'
    else
      content_type = 'application/json'
    end

    begin
      vnfs_json = vnfs.to_json
      if content_type == 'application/json'
        return 200, vnfs_json
      elsif content_type == 'application/x-yaml'
        vnfs_yml = json_to_yaml(vnfs_json)
        return 200, vnfs_yml
      end
    rescue
      LOGGER.error(component:LOGGED_COMPONENT, operation:'msg', message: 'Error Establishing a Database Connection')
      return 500, 'Error Establishing a Database Connection'
    end
  end

  # @method get
  # @overload get "/"
  # Gets vnf instances with an id
  # Return JSON or YAML
  #   - JSON (default)
  #   - YAML including output parameter (e.g /?output=YAML)
  get '/:id' do
    begin
      @vnfInstance = Vnfr.find(params[:id])
    rescue Mongoid::Errors::DocumentNotFound => e
      halt (404)
    end

    if params[:output] == 'YAML'
      content_type = 'application/x-yaml'
    else
      content_type = 'application/json'
    end
    vnfs_json = @vnfInstance.to_json
    if content_type == 'application/json'
      return 200, vnfs_json
    elsif content_type == 'application/x-yaml'
      vnfs_yml = json_to_yaml(vnfs_json)
      return 200, vnfs_yml
    end
  end

  # @method post_vnfrs
  # @overload post '/'
  # Post a VNF in YAML format
  # Return JSON or YAML depending on content_type
  post '/' do

    if request.content_type ==  'application/json'
      instance, errors = parse_json(request.body.read)
      return 400, errors.to_json if errors
      vnf_json = instance
    elsif request.content_type == 'application/x-yaml'
      instance, errors = parse_yaml(request.body.read)
      return 400, errors.to_json if errors
      vnf_json = yaml_to_json(instance)
      instance, errors = parse_json(vnf_json)
      return 400, errors.to_json if errors
    end
    puts 'vnf: ', Vnfr.to_json
    errors = validate_json(vnf_json,@@vnfr_schema)
    return 422, errors.to_json if errors

    begin
      instance = Vnfr.find( instance['id'] )
      return 409, 'ERROR: Duplicated VNF ID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Save to DB
    begin
      instance = Vnfr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated VNF ID' if e.message.include? 'E11000'
    end

    puts 'New VNF has been added'
    vnf_json = instance.to_json
    if request.content_type == 'application/json'
      return 200, vnf_json
    elsif request.content_type == 'application/x-yaml'
      vnf_yml = json_to_yaml(vnf_json)
      return 200, vnf_yml
    end
  end

  # @method put_vnfrs
  # @overload put '/'
  # Put a VNF in YAML format
  # Put a vnfr
  # Return JSON or YAML depending on content_type
  put '/:id' do

    if request.content_type ==  'application/json'
      instance, errors = parse_json(request.body.read)
      return 400, errors.to_json if errors
      vnf_json = instance
    elsif request.content_type == 'application/x-yaml'
      instance, errors = parse_yaml(request.body.read)
      return 400, errors.to_json if errors
      vnf_json = yaml_to_json(instance)
      instance, errors = parse_json(vnf_json)
      return 400, errors.to_json if errors
    end

    begin
      vnfr = Vnfr.find( instance['id'] )
      puts 'VNF is found'
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404, 'This VNFR does not exists'
    end

    puts 'validating entry: ', vnf_json
    errors = validate_json(vnf_json,@@vnfr_schema)
    return 422, errors.to_json if errors

    # Update to new version
    puts 'Updating...'
    begin
      # Delete old record
      Vnfr.where( {'id' => params[:id] }).delete
      # Create a record
      new_vnfr = Vnfr.create!(instance)
    rescue Moped::Errors::OperationFailure => e
      return 409, 'ERROR: Duplicated NS ID' if e.message.include? 'E11000'
    end

    puts 'New VNF has been updated'
    vnf_json = instance.to_json
    if request.content_type == 'application/json'
      return 200, vnf_json
    elsif request.content_type == 'application/x-yaml'
      vnf_yml = json_to_yaml(vnf_json)
      return 200, vnf_yml
    end
  end

  # @method delete_vnfr_external_vnf_id
  # @overload delete '/:id'
  #	Delete a vnf by its ID
  # Delete a vnf
  delete '/:id' do
    begin
      vnf = Vnfr.find_by( {'id' =>  params[:id]})
    rescue Mongoid::Errors::DocumentNotFound => e
      return 404,'ERROR: Operation failed'
    end
    vnf.destroy
    return 200, 'OK: vnfr removed'
  end
end
