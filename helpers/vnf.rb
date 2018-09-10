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

# @see VNFRepository
class SonataVnfRepository < Sinatra::Application

  require 'json'
  require 'yaml'
  
  
  # Checks if a JSON message is valid
  #
  # @param [JSON] message some JSON message
  # @return [Hash, nil] if the parsed message is a valid JSON
  # @return [Hash, String] if the parsed message is an invalid JSON
  def parse_json(message)
    # Check JSON message format
    begin
      parsed_message = JSON.parse(message) # parse json message
    rescue JSON::ParserError => e
      # If JSON not valid, return with errors
      logger.error "JSON parsing: #{e.to_s}"
      return message, e.to_s + "\n"
    end

    return parsed_message, nil
  end

  # Checks if a JSON message is valid acording to a json_schema
  #
  # @param [JSON] message some JSON message
  # @return [Hash, nil] if the parsed message is a valid JSON
  # @return [Hash, String] if the parsed message is an invalid JSON
  def validate_json(message,schema)
    begin
           JSON::Validator.validate!(schema,message)
    rescue JSON::Schema::ValidationError => e
      logger.error "JSON validating: #{e.to_s}"
      return e.to_s + "\n"
    end
    nil
  end

  # Checks if a YAML message is valid
  #
  # @param [YAML] message some YAML message
  # @return [Hash, nil] if the parsed message is a valid YAML
  # @return [Hash, String] if the parsed message is an invalid YAML
   def parse_yaml(message)
    # Check YAML message format
    begin
      parsed_message = YAML.load(message) # parse YAML message
    rescue YAML::ParserError => e
      # If YAML not valid, return with errors
      logger.error "YAML parsing: #{e.to_s}"
      return message, e.to_s + "\n"
    end
    return parsed_message, nil
  end

  # Translates a message from YAML to JSON
  #
  # @param [YAML] input_yml some YAML message
  # @return [Hash, nil] if the input message is a valid YAML
  # @return [Hash, String] if the input message is an invalid YAML
  def yaml_to_json(input_yml)
    puts 'Parsing from YAML to JSON'
    begin
      output_json = JSON.dump(input_yml)
    rescue
      logger.error 'Error parsing from YAML to JSON'
      end
  output_json
  end

  # Translates a message from JSON to YAML
  #
  # @param [JSON] input_json some JSON message
  # @return [Hash, nil] if the input message is a valid JSON
  # @return [Hash, String] if the input message is an invalid JSON
  def json_to_yaml(input_json)
    require 'json'
    require 'yaml'

    begin
      output_yml = YAML.dump(JSON.parse(input_json))
    rescue
      logger.error 'Error parsing from JSON to YAML'
      end
    output_yml
  end

  # Builds an HTTP link for pagination
  #
  # @param [Integer] page_number link page_number
  # @param [Integer] limit link page_size position
  def build_http_link(page_number, page_size)
    link = ''
    # Next link
    next_page_number = page_number + 1
    next_vnfs = Vnfr.paginate(page: next_page_number, page_size: page_size)
    begin
      link << '<localhost:4012/virtual-network-functions?page_number=' + next_page_number.to_s + '&page_size=' + page_size.to_s + '>; rel="next"' unless next_vnfs.empty?
    rescue
      logger.error 'Error Establishing a Database Connection'
    end

    unless page_number == 1
      # Previous link
      previous_page_number = page_number - 1
      previous_vnfs = Vnf.paginate(page: previous_page_number, page_size: page_size)
      unless previous_vnfs.empty?
        link << ', ' unless next_vnfs.empty?
        link << '<localhost:4012/virtual-network-functions?page_number=' + previous_page_number.to_s + '&page_size=' + page_size.to_s + '>; rel="last"'
      end
    end
    link
  end

  # Extension of build_http_link
  def build_http_link_name(page_number, page_size, name)
    link = ''
    # Next link
    next_page_number = page_number + 1
    next_vnfs = Vnf.paginate(page: next_page_number, page_size: page_size)
    begin
      link << '<localhost:4012/virtual-network-functions/name/' + name.to_s + '?page_number=' + next_page_number.to_s + '&page_size=' + page_size.to_s + '>; rel="next"' unless next_vnfs.empty?
    rescue
      logger.error 'Error Establishing a Database Connection'
    end

    unless page_number == 1
      # Previous link
      previous_page_number = page_number - 1
      previous_vnfs = Vnf.paginate(page: previous_page_number, page_size: page_size)
      unless previous_vnfs.empty?
        link << ', ' unless next_vnfs.empty?
        link << '<localhost:4012/virtual-network-functions/name/' + name.to_s + '?page_number=' + previous_page_number.to_s + '&page_size=' + page_size.to_s + '>; rel="last"'
      end
    end
    link
  end

  def keyed_hash(hash)
    Hash[hash.map { |(k, v)| [k.to_sym, v] }]
  end

  def interfaces_list
    [
        {
            'uri' => '/records/vnfr/',
            'method' => 'GET',
            'purpose' => 'REST API Structure and Capability Discovery for /records/vnfr/'
        },
        {
            'uri' => '/records/vnfr/vnf-instances',
            'method' => 'GET',
            'purpose' => 'List all VNFR'
        },
        {
            'uri' => '/records/vnfr/vnf-instances/:id',
            'method' => 'GET',
            'purpose' => 'List specific VNFR'
        },
        {
            'uri' => '/records/vnfr/vnf-instances',
            'method' => 'POST',
            'purpose' => 'Store a new VNFR'
        }
    ]
  end
end
