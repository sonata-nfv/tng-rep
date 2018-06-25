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

# Class for Sonata_NS_Repository
class TangoVnVTrRepository < Sinatra::Application
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

  def json_error(code, message)
    msg = {'error' => message}
    logger.error msg.to_s
    halt code, {'Content-type'=>'application/json'}, msg.to_json
  end

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

  # Checks if a JSON message is valid acording to a json_schema
  #
  # @param [JSON] message some JSON message
  # @return [Hash, nil] if the parsed message is a valid JSON
  # @return [Hash, String] if the parsed message is an invalid JSON

  def validate_json(message,schema)
    begin
      JSON::Validator.validate!(schema, message)
    rescue JSON::Schema::ValidationError => e
      logger.error "JSON validating: #{e.to_s}"
      return e.to_s + "\n"
    end
    nil
  end

  # Transform the params for search into sequence of stored ids
  # @param [Dict] params from CURL
  # @param [Dict] keyed_params from CURL
  # @param [Symbol] type_of_descriptor is valid symbol from the hosted type of descriptors
  # @return [Object] keyed_params is dict with replaced the values of the inverted index
  def parse_keys_dict(type_of_descriptor, keyed_params)
    paths_dict =  parse_dict(type_of_descriptor)
    cur_array_id = []
    array_id = []
    cur_bool = true
    keyed_params.each do |key, value|
      keys = key.to_s.split('.')[-1]
      if paths_dict.key? keys.to_sym
        keyed_params.delete((type_of_descriptor.to_s + '.' + keys).to_sym)
        value.class == String ?
            Dict.all.each {|field_of_dict| cur_array_id += field_of_dict[keys][value] unless field_of_dict[keys][value].empty?}:
            Dict.all.each do |field_of_dict|
              field_of_dict.as_document[keys].keys.each do |key_field_dict|
                value.each {|key, value| cur_bool &= compare_objects(key.split('$')[-1], key_field_dict, value)}
                cur_array_id += field_of_dict[keys][key_field_dict] if cur_bool
                cur_bool = true
              end
            end
      end
      array_id = cur_array_id.select{ |e| cur_array_id.count(e) >= keyed_params.length }.uniq
    end
    keyed_params[:'_id'.in] = array_id unless array_id == 1 || array_id.empty?
    keyed_params
  end

  def keyed_hash(hash)
    Hash[hash.map { |(k, v)| [k.to_sym, v] }]
  end

  def interfaces_list
    [
      {
        'uri' => '/trr/',
        'method' => 'GET',
        'purpose' => 'REST API Structure and Capability Discovery /trr/'
      },
      {
        'uri' => '/trr/test-plans',
        'method' => 'GET',
        'purpose' => 'List all TRR'
      },
      {
        'uri' => '/trr/test-plans/:id',
        'method' => 'GET',
        'purpose' => 'List specific TRR'
      },
      {
        'uri' => '/trr/test-plans',
        'method' => 'POST',
        'purpose' => 'Store a new TRR'
      },
      {
        'uri' => '/trr/test-plans/:id',
        'method' => 'DELETE',
        'purpose' => 'Delete a TRR'
      },
#
#
#test-suite-results interfaces list
#
#
      {
        'uri' => '/trr/test-suite-results',
        'method' => 'GET',
        'purpose' => 'List all TSR'
      },
      {
        'uri' => '/trr/test-suite-results/:id',
        'method' => 'GET',
        'purpose' => 'List specific TSR'
      },
      {
        'uri' => '/trr/test-suite-results',
        'method' => 'POST',
        'purpose' => 'Store a new TSR'
      },
      {
        'uri' => '/trr/test-suite-results/:id',
        'method' => 'PUT',
        'purpose' => 'Update a new TSR'
      },      
      {
        'uri' => '/trr/test-suite-results/:id',
        'method' => 'DELETE',
        'purpose' => 'Delete a TSR'
      }
#
#
#end of test-suite-results interfaces list
#
#
    ]
  end
end
