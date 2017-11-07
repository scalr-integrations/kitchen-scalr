module Kitchen
  module Driver
    module FarmRoleObjectBuilder
      def buildFarmRoleObject(state, config)
        fruuid = "KITCHEN-ROLE-" + state[:suuid]
        farmRoleObject = {
          "alias" => fruuid,
          "cloudPlatform" => state[:imagePlatform],
          "cloudLocation" => state[:imageLocation],
          "instanceType" => {
            "id" => config[:scalr_server_instanceType]
          },
          "role" => {
            "id" => state[:roleId]
          },
          {
            "scaling" => {
                "enabled" => true
          }
        }
        farmRoleObject = farmRoleObject.deep_merge(config[:scalr_base_farm_role])
        return farmRoleObject
      end
    end
  end
end