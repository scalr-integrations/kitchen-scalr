# -*- encoding: utf-8 -*-
#
# Author:: Mohammed HAWARI (<mohammed@hawari.fr>)
#
# Copyright (C) 2016, Mohammed HAWARI
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen'
require 'kitchen/driver/ScalrAPI'
require "kitchen/driver/scalr_version"
require "kitchen/driver/scalr_ssh_script_template"
require "kitchen/driver/scalr_cred"
require "kitchen/driver/scalr_ps_script_template"
require "kitchen/driver/scalr_farm_role"
require "json"
require 'os'
require 'securerandom'
require 'deep_merge'
module Kitchen

  module Driver

    # Scalr driver for Kitchen.
    #
    # @author Mohammed HAWARI <mohammed@hawari.fr>
    class Scalr < Kitchen::Driver::Base
      include CredentialsManager

      include FarmRoleObjectBuilder

      kitchen_driver_api_version 2

      plugin_version Kitchen::Driver::SCALR_VERSION

      default_config :scalr_api_url, ''

      default_config :scalr_api_key_id, ''

      default_config :scalr_api_key_secret, ''

      default_config :scalr_env_id, ''

      default_config :scalr_project_id, ''

      default_config :scalr_ssh_key_filename, ''

      default_config :scalr_server_status_polling_period, 10

      default_config :scalr_server_status_polling_timeout, 600

      default_config :scalr_server_image, ''

      default_config :scalr_server_instanceType, ''

      default_config :scalr_use_role, -1

      default_config :scalr_platform, ''

      default_config :scalr_location, ''

      default_config :scalr_base_farm_role, Hash.new

      default_config :scalr_permit_ssh_root_login, false

      default_config :scalr_use_private_ip, false

      def create(state)
      	if config[:scalr_api_key_id]==''
      	  #We have to find some other way of getting the credentials
      	  loadCredentials
      	end
        #Create a Scalr API object
        scalr_api = ScalrAPI.new(config[:scalr_api_url], config[:scalr_api_key_id], config[:scalr_api_key_secret])
        #Create a farm
        state[:suuid] = SecureRandom.uuid
        uuid = 'KITCHEN_FARM_' + instance.name + "_" + state[:suuid]
        createFarmObject = {
          'name' => uuid,
          'description' => 'Test Kitchen Farm',
          'project' => {
            'id' => config[:scalr_project_id]
          }
        }
        puts 'Creating farm with name: %s' % [uuid]
        response = scalr_api.create('/api/v1beta0/user/%s/farms/' % [config[:scalr_env_id] ], createFarmObject)
        state[:farmId] = response['id']
        puts 'Success: farmId is %d' % [state[:farmId]]
        if !config[:scalr_global_variables].nil?
          puts 'Creating global variables'
          config[:scalr_global_variables].each do |key, val|
            puts 'Checking for %s global variable' % [key]
            begin
              # this stdout hack is to handle fetchs for global vars that don't exist yet
              $stdout = File.new("/dev/null", "w")
              response = scalr_api.fetch('/api/v1beta0/user/%s/farms/%d/global-variables/%s' % [config[:scalr_env_id], state[:farmId], key])
              $stdout = STDOUT
            rescue => e
              response = {}
            end
            if response['name'] == key.to_s
              puts 'Global variable "%s" exists, updating with value "%s"...' % [key, val[:value]]
              # edit global vars
              globalVariableObjectEdit = {
                'value' => val[:value]
              }
              response = scalr_api.edit('/api/v1beta0/user/%s/farms/%d/global-variables/%s' % [config[:scalr_env_id], state[:farmId], key], globalVariableObjectEdit)
            else
              puts 'Global variable "%s" not found, creating with value: "%s"...' % [key, val[:value]]
              # create global vars
              globalVariableObjectCreate = {
                'category' => 'Uncategorized',
                'name' => key,
                'description' => '%s description' % [key],
                'hidden' => false,
                'locked' => false
              }
              globalVariableObject = globalVariableObjectCreate.deep_merge(val)
              response = scalr_api.create('/api/v1beta0/user/%s/farms/%d/global-variables/' % [config[:scalr_env_id], state[:farmId]], globalVariableObject)
            end
          end
          puts 'Global variables created/updated'
        end
        if config[:scalr_use_role] == -1
          createCustomRole(scalr_api, state)
        else
          state[:roleId] = config[:scalr_use_role]
          state[:imagePlatform] = config[:scalr_platform]
          state[:imageLocation] = config[:scalr_location]
        end
        #Now create the farm role object
        puts "Creating the Farm Role"
        farmRoleObject = buildFarmRoleObject(state, config)
        response = scalr_api.create('/api/v1beta0/user/%s/farms/%d/farm-roles/' % [config[:scalr_env_id], state[:farmId]], farmRoleObject)
        puts "Farm Role created"
        state[:farmRoleId] = response['id']
        #Start the farm now
        response = scalr_api.post('/api/v1beta0/user/%s/farms/%d/actions/launch/' % [config[:scalr_env_id], state[:farmId]], {})
        state[:farmLaunched] = 1
        #Keep polling for server status
        wait_for_status(scalr_api, state, 'running')
        #Generate and upload credentials to the instance
        setup_credentials(scalr_api,state)
        #Finally get the IP address
        response = scalr_api.list('/api/v1beta0/user/%s/farms/%d/servers/' % [config[:scalr_env_id], state[:farmId]] )
        if response.size == 0 then
          raise "No running server in the farm!"
        end
        if config[:scalr_use_private_ip] then
          state[:hostname] = response[0]['privateIp'][0]
        else
          state[:hostname] = response[0]['publicIp'][0]
        end
        state[:ssh_key] = state[:keyfileName]
        #state[:proxy_command] =
        #state[:rdp_port] =
      end

      def cleanup_scalr(scalr_api, state)
        puts "Starting the tear-down process"
        if state.key?(:farmLaunched)
          puts "A running server is here, terminate the farm"
          scalr_api.post('/api/v1beta0/user/%s/farms/%d/actions/terminate/' % [config[:scalr_env_id], state[:farmId]], {})
          state.delete(:hostname)
          state.delete(:port)
          state.delete(:username)
          state.delete(:ssh_key)
          state.delete(:farmLaunched)
        end
        if state.key?(:farmRoleId)
          puts "Now waiting until all the servers are terminated..."
          wait_for_empty(scalr_api, '/api/v1beta0/user/%s/farms/%d/servers/' % [config[:scalr_env_id], state[:farmId]])
          puts "...Done"
          puts "Cleanup of the farm role..."
          scalr_api.delete('/api/v1beta0/user/%s/farm-roles/%d/' % [config[:scalr_env_id], state[:farmRoleId]])
          puts '...Done'
          state.delete(:farmRoleId)
        end
        if state.key?(:roleId) && config[:scalr_use_role] == -1
          puts "Cleanup of the role..."
          scalr_api.delete('/api/v1beta0/user/%s/roles/%s/' % [config[:scalr_env_id], state[:roleId]])
          puts '...Done'
          state.delete(:roleId)
        end
        if state.key?(:farmId)
          puts "Cleanup of the farm..."
          scalr_api.delete('/api/v1beta0/user/%s/farms/%d/' % [config[:scalr_env_id], state[:farmId]])
          puts '...Done'
          state.delete(:farmId)
        end
        if state.key?(:scriptId)
          puts "Cleanup of the script..."
          scalr_api.delete('/api/v1beta0/user/%s/scripts/%d/' % [config[:scalr_env_id], state[:scriptId]])
          puts "...Done"
          state.delete(:scriptId)
        end
        if state.key?(:keyfileName)
          puts "Cleanup of the local keys..."
          res = `rm -rf #{state[:keyfileName]}`
          res = `rm -rf #{state[:keyfileName]}.pub`
          puts "...Done"
          state.delete(:scriptId)
        end
      end

      def wait_for_empty(scalr_api, endpoint)
        elapsed_time = 0
        while elapsed_time < config[:scalr_server_status_polling_timeout] do
          response = scalr_api.list(endpoint)
          nbOfNonTerminatedServers = 0
          for s in response
            if s['status'] != 'terminated'
              nbOfNonTerminatedServers += 1
            end
          end
          if (nbOfNonTerminatedServers == 0) then
            return
          end
          puts "Still %d servers." % [nbOfNonTerminatedServers]
          sleep config[:scalr_server_status_polling_period]
          elapsed_time += config[:scalr_server_status_polling_period]
          puts "Elapsed time: %d seconds. Still polling for number of servers in farm" % [elapsed_time]
        end
        raise "Timeout! And some servers are still running...Try later"
      end

      def destroy(state)
        if config[:scalr_api_key_id]=='' then
          #We have to find some other way of getting the credentials
          loadCredentials
        end
        scalr_api = ScalrAPI.new(config[:scalr_api_url], config[:scalr_api_key_id], config[:scalr_api_key_secret])
        cleanup_scalr(scalr_api, state)
      end

      def wait_for_status(scalr_api,state, status)
        elapsed_time = 0
        puts 'Waiting for server to be %s.' % [status]
        while elapsed_time < config[:scalr_server_status_polling_timeout] do
          response = scalr_api.list('/api/v1beta0/user/%s/farms/%d/servers/' % [config[:scalr_env_id], state[:farmId]] )
          if (response.size > 0 && response[0]['status'] == status) then
            puts 'Server is %s!' % [response[0]['status']]
            return
          end
          if (response.size > 0) then
            puts 'Server is still %s.' % [response[0]['scalrAgent']['reachabilityStatus']['status']]
          end
          sleep config[:scalr_server_status_polling_period]
          elapsed_time += config[:scalr_server_status_polling_period]
          puts "Elapsed time: %d seconds. Still polling for server status" % [elapsed_time]
        end
        raise "Server status timeout!"
      end

      def createCustomRole(scalr_api,state)
        #Get the imageId for the provided image
        puts 'Getting the imageId for image %s' % [config[:scalr_server_image]]
        response = scalr_api.list('/api/v1beta0/user/%s/images/?name=%s' % [config[:scalr_env_id], config[:scalr_server_image] ])
        if response.size == 0 then
          raise 'No matching image was found in this environment!'
        end
        state[:imageId] = response[0]['id']
        state[:imageOsId] = response[0]['os']['id']
        state[:imagePlatform] = response[0]['cloudPlatform']
        state[:imageLocation] = response[0]['cloudLocation']
        puts 'The image id is %s' % [state[:imageId]]
        puts 'The image os id is %s' % [state[:imageOsId]]
        puts 'The image platform is %s' % [state[:imagePlatform]]
        puts 'The image Location is %s' % [state[:imageLocation]]
        #Create a matching role on the fly
        ruuid = 'KITCHEN-ROLE-' + state[:suuid]
        roleObject = {
          "builtinAutomation" => ["base"],
          "category" => {
                          "id" => 1
                        },
          "description" => "test kitchen role",
          "name" => ruuid,
          "os" => {
                    "id" => state[:imageOsId]
                  },
          "quickStart" => false,
          "useScalrAgent" => true
        }
        puts 'Creating a role with name %s' % [ruuid]
        response = scalr_api.create('/api/v1beta0/user/%s/roles/' % [config[:scalr_env_id] ], roleObject)
        state[:roleId] = response['id']
        puts 'The role id is %d' % [state[:roleId]]
        #Create a RoleImage matching
        roleImageObject = {
          "image" => {
            "id" => state[:imageId],
          },
          "role" => {
            "id" => state[:roleId]
          }
        }
        response = scalr_api.create('/api/v1beta0/user/%s/roles/%d/images/' % [config[:scalr_env_id], state[:roleId]], roleImageObject)
        puts "RoleImage association created"
      end

      def setup_credentials(scalr_api,state)
        response = scalr_api.list('/api/v1beta0/user/%s/farms/%d/servers/' % [config[:scalr_env_id], state[:farmId]])
        state[:serverId] = response[0]['id']
        #Handle the Linux case
        #Generate a key
        if !windows_os? then
          keyfileName = 'KEY_' + state[:suuid]
          state[:username] = 'root'
          state[:keyfileName] = keyfileName
          puts "Generating a key named %s" % [keyfileName]
          res = `yes | ssh-keygen -q -f #{keyfileName} -N ""`
          f = File.open(keyfileName + ".pub")
          scriptData = Kitchen::Driver::SCALR_SSH_SCRIPT % { :ssh_pub_key => f.read }
          if config[:scalr_permit_ssh_root_login]
            scriptData += Kitchen::Driver::SCALR_SSH_ROOT_PERMIT_SCRIPT
          end
          f.close
          state[:scriptOsType] = "linux"
        else
          instance_password = SecureRandom.urlsafe_base64(20)
          instance_username = "adminchef"
          scriptData = Kitchen::Driver::SCALR_PS_SCRIPT % {:username => instance_username, :password => instance_password}
          state[:scriptOsType] = "windows"
          state[:username] = instance_username
          state[:password] = instance_password
        end
        #Now create a script in Scalr
        puts "Creating a script in Scalr with this key"
        response = scalr_api.create('/api/v1beta0/user/%s/scripts/' % [config[:scalr_env_id]],
        {
          'name' => 'TestKitchenScript_%s' % [keyfileName],
          'osType' => state[:scriptOsType]
        })
        state[:scriptId] = response['id']
        puts "Script created with id %s" % [state[:scriptId]]
        #Now create a script version with the actual body
        puts "Creating a script version"
        puts "Script content:"
        puts scriptData
        puts "End of script content"
        response = scalr_api.create('/api/v1beta0/user/%s/scripts/%d/script-versions/' % [config[:scalr_env_id], state[:scriptId]],
        {
          'body' => scriptData,
          'script' => {
            'id' => state[:scriptId]
          }
        })
        puts "Script version created"
        #Finally try and execute the script
        puts "Executing the script"
        response = scalr_api.create('/api/v1beta0/user/%s/scripts/%d/actions/execute/' % [config[:scalr_env_id], state[:scriptId]],
          {
            'server' => {
              'id' => state[:serverId]
            }
          })
        state[:scriptExecutionId] = response['id']
        puts "Execution started with id %s" % [state[:scriptExecutionId]]
        #Wait for execution to be complete
        elapsed_time = 0
        "Waiting for execution to be finished"
        while (elapsed_time < config[:scalr_server_status_polling_timeout]) do
          puts "%d seconds elapsed. Polling" % [elapsed_time]
          response = scalr_api.fetch('/api/v1beta0/user/%s/script-executions/%s/' % [config[:scalr_env_id], state[:scriptExecutionId]])
          if (response['status'] == 'finished')
            puts "Script execution has finished."
            return
          end
          puts "Script execution is still in %s state" % [response['status']]
          sleep config[:scalr_server_status_polling_period]
          elapsed_time += config[:scalr_server_status_polling_period]
        end
        raise "Error in script execution"
      end
    end
  end
end
