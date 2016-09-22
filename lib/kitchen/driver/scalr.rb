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
require "kitchen/driver/vagrant_version"

module Kitchen

  module Driver

    # Scalr driver for Kitchen.
    #
    # @author Mohammed HAWARI <mohammed@hawari.fr>
    class Scalr < Kitchen::Driver::Base

      kitchen_driver_api_version 2

      plugin_version Kitchen::Driver::SCALR_VERSION

      default_config :scalr_api_url, 'https://demo.scalr.com'

      default_config :scalr_api_key_id, ''

      default_config :scalr_api_key_secret, ''

      default_config :scalr_env_id, ''

      default_config :scalr_project_id, ''

      default_config :scalr_ssh_key_filename, ''

      default_config :scalr_server_status_polling_period, 10

      default_config :scalr_server_status_polling_timeout, 600

      default_config :scalr_server_image, 'base-ubuntu1404-us-west-1-05062015'

      default_config :scalr_server_instanceType, 'm3.medium'

      def create(state)
        #Create a Scalr API object
        scalr_api = ScalrAPI.new(config[:scalr_api_url], config[:scalr_api_key_id], config[:scalr_api_key_secret])
        #Create a farm
        suuid = SecureRandom.uuid
        uuid = 'KITCHEN_FARM_' + instance.name + "_" + suuid
        createFarmObject = {
          'name' => uuid,
          'description' => 'Test Kitchen Farm',
          'project' => {
            'id' => config[:scalr_project_id]
          }
        }
        puts 'Creating farm with name: %s' % [uuid]
        response = scalr_api.create('/api/v1beta0/user/%s/farms/' % [config[:scalr_env_id] ], createFarmObject)
        farmId = response['id']
        puts 'Success: farmId is %d' % [farmId]
        #Get the imageId for the provided image
        puts 'Getting the imageId for image %s' % [config[:scalr_server_image]]
        response = scalr_api.list('/api/v1beta0/user/%s/images/?name=%s' % [config[:scalr_env_id], config[:scalr_server_image] ])
        if response.size == 0 then
          raise 'No matching image was found in this environment!'
        end
        imageId = response[0]['id']
        imageOsId = response[0]['os']['id']
        puts 'The image id is %s' % [imageId]
        #Create a matching role on the fly
        ruuid = 'KITCHEN_ROLE_' + instance.name + "_" + suuid
        roleObject = {
          'name' => ruuid,
          'os' => {
            'id' => imageOsId
          },
          'category' => {
            'id' => 1
          }
        }
        puts 'Creating a role with name %s' % [ruuid]
        reponse = scalr_api.create('/api/v1beta0/user/%s/roles/' % [config[:scalr_env_id] ], roleObject)
        roleId = response['id']
        puts 'The role id is %d' % [roleId]
        #Create a RoleImage matching
        roleImageObject = {
          "image" => {
            "id" => imageId,
          },
          "role" => {
            "id" => roleId
          }
        }
        response = scalr_api.create('/api/v1beta0/user/%s/roles/%d/images/' % [config[:scalr_env_id], roleId], roleImageObject)
        puts "RoleImage association created"
        #Now create the farm role object
        puts "Creating the Farm Role"
        fruuid = "KITCHEN_FARM_ROLE_" + instance.name + "_" + uuid
        farmRoleObject = {
          "alias" => fruuid,
          "placement" => {

          },
          "instance" => {

          },
          "platform" => "ec2",
          "role" => {

          }
        }        
        response = scalr_api.create('/api/v1beta0/user/%s/farms/%d/farm-roles/' % [config[:scalr_env_id], farmId], farmRoleObject)
        puts "Farm Role created"
      end

      def destroy(state)
      end
    end
  end
end
