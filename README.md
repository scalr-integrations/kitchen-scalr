# <a name="title"></a> Kitchen::Scalr

[![Gem Version](https://badge.fury.io/rb/kitchen-scalr.svg)](https://badge.fury.io/rb/kitchen-scalr)

A Test Kitchen Driver for Scalr. This driver creates an instance on Scalr by creating a Farm containing a single Farm Role and granting Test Kitchen access to the corresponding server. It can work in two modes:
* **Image Mode:** (default) The user provides an image name and the driver will automatically create a role corresponding to this image as well as instanciate this role in a farm.
* **Role Mode:** the user provides a role id and the driver will instanciate it in a farm

## <a name="installation"></a> Installation and Setup

In short:
```
gem install kitchen-scalr
```

Please read the [Driver usage][driver_usage] page for more details.

## <a name="config"></a> Configuration

### scalr_api_url
**Required** This is the URL of the Scalr server that will be reached by the driver.

### scalr_env_id
**Required** This is a string corresponding to the environment id used by the plugin.

### scalr_api_key_id and scalr_api_key_secret
**Required except on macOS and Windows** These are respectively the API KEY ID and API KEY secret used to make the API calls to Scalr. This option **SHOULD NOT** be used on Windows and macOS because kitchen scalr integrates natively with these OSes to ensure secure storage of the Scalr credentials. In this case, Kitchen-Scalr will prompt for credentials at the first use, and memorize them for further calls.

### scalr_project_id
**Required** This is a string corresponding to the project identifier used to create the farm in Scalr. This is used in Scalr for accountability and cost management.

### scalr_use_role
**Optional** Setting this option to an integer corresponding to a role id will trigger Role mode with the provided role identifier. If this option is not set, the driver will work in Image mode.

### scalr_server_image
**Required in Image mode** This is a string corresponding to the image name used to instanciate the server.

### scalr_server_instanceType
**Required** This is a string corresponding to the instance type of the VMs in the underlying cloud. Example: 'm3.medium'

### scalr_platform
**Required in Role mode** This is the identifier of the underlying cloud platform. Examples: "ec2", "gce", "openstack".

### scalr_location
**Required in Role mode** This is a string corresponding to the cloud location used to create the instance. Example: "us-east-1"

### scalr_global_variables
**Optional** This is a dictionary of Scalr Global Variables to set or create. Global Variables in this dictionary are created if they don't exist in Scalr, otherwise their value is set. By default these global variables are set at the Farm Role scope, if you need to set one at the Farm scope, add `scope: Farm` to its description. Additional Global Variable settings corresponding to the definition of a [Global Variable object](https://api-explorer.scalr.com/definitions/G/GlobalVariable.html) in Scalr's APIv2 can be passed for each Global Variable. These settings are used only when the global variable is created, they are ignored if it is only set.

### scalr_permit_ssh_root_login
**Optional** This is a boolean, default is 'false', that configures sshd to allow root logins and bounces the service during kitchen create. Useful if your base image does not allow ssh as root by default.

### scalr_base_farm_role
**Optional** This is a yaml representation of a [Farm Role Object](https://api-explorer.scalr.com/definitions/F/FarmRole.html) as represented in the APIv2 in Scalr. When kitchen-scalr creates a server, it merges this object with the previously-described parameters and creates the corresponding Farm Role. This section can be used to configure Security Groups, Networking etc... You can put the same parameters there as the ones you would get with a `scalr-ctl farm-roles get`.

### scalr_use_private_ip
**Optional** If set to true, kitchen will use Scalr private ips for the instances, otherwise it will use the public one.

## Configuration example

```yaml
---
driver:
  name: scalr

provisioner:
  name: chef_zero

verifier:
  name: inspec

platforms:
  - name: ubuntu-16.04
    driver:
      scalr_api_url: 'https://my.scalr.com'
      scalr_env_id: '2'
      scalr_project_id: '30c59dba-fc9b-4d0f-83ec-4b5043b12f72'
      scalr_server_instanceType: 'm3.medium'
      scalr_use_role: 12345
      scalr_platform: 'ec2'
      scalr_location: 'us-east-1'
      scalr_base_farm_role:   # Add platform-specific Farm Role settings
        cloudFeatures:
          type: AwsCloudFeatures
          ebsOptimized: false
        networking:
          networks:
            - id: vpc-xxxxxxxx
          subnets:
            - id: subnet-xxxxxxxx
        security:
          securityGroups:
            - id: 'sg-3b3d9153'
            - id: 'sg-349a765f'
            - id: 'sg-4a9a7621'
      scalr_global_variables:
        My_Global_Variable:   # Set or create a global variable named My_Global_Variable
          value: Hello World
        My_Secret_GV:         # Create a Global Variable with additional settings
          value: access-token
          category: Monitoring
          hidden: true
        My_Farm_Scope_GV:     # Set a Global Variable at the Farm scope
          value: Farm name
          scope: Farm
```

## <a name="development"></a> Development

* Source hosted at [GitHub][repo]
* Report issues/questions/feature requests on [GitHub Issues][issues]

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## <a name="thanks"></a> Thanks

- [@daxgames](https://github.com/daxgames) for contributing the `permit_ssh_root_login` setting.
- [@bpezan](https://github.com/bpezan) for contributing the `scalr_global_variables` setting.

## <a name="authors"></a> Authors

- Created by [Mohammed HAWARI][author] (<mohammed@hawari.fr>)
- Maintained by [Aloys AUGUSTIN][maintainer] (<aloys@scalr.com>)

## <a name="license"></a> License

Apache 2.0 (see [LICENSE][license


[author]:           https://github.com/momohawari
[maintainer]:       https://github.com/aloysaugustin
[issues]:           https://github.com/scalr-integrations/kitchen-scalr/issues
[license]:          https://github.com/scalr-integrations/kitchen-scalr/blob/master/LICENSE
[repo]:             https://github.com/scalr-integrations/kitchen-scalr
[driver_usage]:     http://kitchen.ci/docs/getting-started/adding-platform
[chef_omnibus_dl]:  http://www.chef.io/chef/install/

