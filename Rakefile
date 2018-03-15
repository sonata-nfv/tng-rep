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

require 'yard'
require 'rspec/core/rake_task'
require 'ci/reporter/rake/rspec'
require './main'

task default: ['ci:all']

desc 'Start the service'
task :start do
  puts '5GTANGO REPOSITORIES STARTING...'
  puts 'Version 4.0'

  # puts ENV['MAIN_DB'].to_s, ENV['MAIN_DB_HOST'].to_s,

  puts "VAR `MAIN_DB`=#{ENV['MAIN_DB'].inspect}"
  puts "VAR `MAIN_DB_HOST`=#{ENV['MAIN_DB_HOST'].inspect}"
  puts "VAR `SEC_FLAG`=#{ENV['SEC_FLAG'].inspect}"

  conf = File.expand_path('config.ru', File.dirname(__FILE__))
  exec("puma #{conf} -b tcp://0.0.0.0:4012")
end

desc 'Run Unit Tests'
RSpec::Core::RakeTask.new :specs do |task|
  task.pattern = Dir['spec/**/*_spec.rb']
end

YARD::Rake::YardocTask.new do |t|
  t.files = %w(main.rb helpers/*.rb routes/*.rb)
end

task :default => [:swagger]

namespace :ci do
  task all: %w(ci:setup:rspec specs)
end

namespace :db do
  task :load_config do
    require './main'
  end
end

namespace :init do
  require 'fileutils'
  desc 'Fill Catalogues with default sonata-demo package contents'
  task :load_samples, :server do |_, args|
    
    server = 'tng-rep:4012'
    vnfr_random_sample = 'samples/sonata-demo/function-record/random-vnfr.yml'
	  sh "curl -X POST -H \"Content-Type: application/x-yaml\" --data-binary @#{ vnfr_random_sample } --connect-timeout 30 http://#{ server }/records/vnfr/vnf-instances"
  
  end
end
