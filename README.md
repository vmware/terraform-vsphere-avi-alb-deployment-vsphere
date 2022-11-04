# AVI Controller Deployment on vSphere Terraform module
This Terraform module creates and configures an AVI (NSX Advanced Load-Balancer) Controller on vSphere

## Module Functions
The module is meant to be modular and can create all or none of the prerequiste resources needed for the AVI vSphere Deployment including:
* vSphere Role for Avi (optional with create_role variable)
* vSphere virtual machines for Avi Controller(s)
* Cluster Anti-Affinity rules for HA Avi Controller Deployment

During the creation of the Controller instance the following initialization steps are performed:
* Change default password to user specified password
* Copy Ansible playbook to controller using the assigned IP Address
* Run Ansible playbook to configure initial settings and vSphere Full Access Cloud 

Optionally the following Avi configurations can be created:
* Avi IPAM Profile (configure_ipam_profile variable)
* Avi DNS Profile (configure_dns_profile variable)
* DNS Virtual Service (configure_dns_vs variable)

# Environment Requirements

## vSphere
The following are vSphere prerequisites for running this module:
* vSphere Account with permissions to create VMs and any other vSphere resources created by this module
* Port Groups indentified for Management

## vSphere Authentication
For authenticating to vSphere both the vsphere_username and vsphere_password variables will be used. The credentials must have the following permissions in vSphere:

By default this module will use the same credentials (vsphere_username and vsphere_password) for the Avi Controller to connect to vCenter and deploy resources.
To change this behavior set the "vsphere_avi_user" and "vsphere_avi_password" variables.
## Controller Image
The AVI Controller image for vSphere should be uploaded to a vSphere Content Library before running this module with the content library name and image name specified in the respective content_library and vm_template variables. 
## Host OS 
The following packages must be installed on the host operating system:
* curl 

# Usage
```hcl
terraform {
  backend "local" {
  }
}
module "avi-controller-vsphere" {
  source  = "slarimore02/avi-controller-vsphere/vsphere"
  version = "1.0.x"
  
  controller_default_password = "PASSWORD"
  avi_version                 = "20.1.5"
  controller_password         = "NEWPASSWORD"
  controller_ha               = "true"
  create_roles                = "true"
  vsphere_datacenter          = "DATACENTER"
  content_library             = "CONTENT_LIBRARY_NAME"
  vm_template                 = "controller-20.1.5-9148"
  vm_datastore                = "DATASTORE"
  name_prefix                 = "PREFIX"
  dns_servers                 = [{ addr = "8.8.4.4", type = "V4" }, { addr = "8.8.8.8", type = "V4" }]
  dns_search_domain           = "vmware.com"
  ntp_servers                 = [{ "addr": "0.us.pool.ntp.org","type": "DNS" },{ "addr": "1.us.pool.ntp.org","type": "DNS" },{ "addr": "2.us.pool.ntp.org", "type": "DNS" },{ "addr": "3.us.pool.ntp.org", "type": "DNS" }]
  se_mgmt_portgroup           = "SE_PORTGROUP"
  se_mgmt_network             = { network = "192.168.110.0/24", gateway = "192.168.110.1", type = "V4", static_pool = ["192.168.110.100", "192.168.110.200"] }
  controller_mgmt_portgroup   = "MGMT_PORTGROUP"
  compute_cluster             = "CLUSTER"
  vm_folder                   = "FOLDER"
  vsphere_user                = "USERNAME"
  vsphere_avi_user            = "USERNAME"
  vsphere_avi_password        = "PASSWORD"
  vsphere_password            = "PASSWORD"
  vsphere_server              = "VCENTER_ADDRESS"
  controller_ip               = ["192.168.110.10"]
  controller_netmask          = "24"
  controller_gateway          = "192.168.110.1"
  configure_ipam_profile      = { enabled = "true", networks = [{ portgroup = "PORTGROUP", network = "100.64.220.0/24", type = "V4", static_pool = ["100.64.220.20", "100.64.220.45"] }]
  configure_dns_profile       = { enabled = "true", usable_domains = ["domain.net"] }
  configure_dns_vs            = { enabled = "true", auto_allocate_ip = "true", vs_ip = "", portgroup = "PORTGROUP", network = "100.64.220.0/24", type = "V4" }
}


output "controllers" {
  value = module.avi-controller-vsphere.controllers
}
```
## GSLB Deployment
For GSLB to be configured successfully the configure_gslb and configure_dns_vs variables must be configured. By default a new Service Engine Group (g-dns) and user (gslb-admin) will be created for the configuration. 

The following is a description of the configure_gslb variable parameters and their usage:
| Parameter   | Description | Type |
| ----------- | ----------- | ----------- |
| enabled      | Must be set to "true" for Active GSLB sites | bool
| leader      | Must be set to "true" for only one GSLB site that will be the leader | bool
| site_name   | Name of the GSLB site   | string
| domains   | List of GSLB domains that will be configured | list(string)
| create_se_group | Determines whether a g-dns SE group will be created        | bool
| se_size   | The CPU, Memory, Disk Size of the Service Engines. The default is 2 vCPU, 8 GB RAM, and a 30 GB Disk per Service Engine | list(number)
| additional_sites   | Additional sites that will be configured. This parameter should only be set for the primary GSLB site | string

The example below shows a GSLB deployment with 2 regions utilized.
```hcl
terraform {
  backend "local" {
  }
}
module "avi_controller_west" {
  source  = "slarimore02/avi-controller-vsphere/vsphere"
  version = "1.0.x"
  
  controller_default_password     = "PASSWORD"
  avi_version                     = "20.1.5"
  controller_password             = "NEWPASSWORD"
  controller_ha                   = "true"
  create_roles                    = "true"
  vsphere_datacenter              = "DATACENTER"
  content_library                 = "CONTENT_LIBRARY_NAME"
  vm_template                     = "controller-20.1.5-9148"
  vm_datastore                    = "DATASTORE"
  name_prefix                     = "PREFIX"
  dns_servers                     = [{ addr = "8.8.4.4", type = "V4" }, { addr = "8.8.8.8", type = "V4" }]
  dns_search_domain               = "vmware.com"
  ntp_servers                     = [{ "addr": "0.us.pool.ntp.org","type": "DNS" },{ "addr": "1.us.pool.ntp.org","type": "DNS" },{ "addr": "2.us.pool.ntp.org", "type": "DNS" },{ "addr": "3.us.pool.ntp.org", "type": "DNS" }]
  se_mgmt_portgroup               = "SE_PORTGROUP"
  se_mgmt_network                 = { network = "192.168.110.0/24", gateway = "192.168.110.1", type = "V4", static_pool = ["192.168.110.100", "192.168.110.200"] }
  controller_mgmt_portgroup       = "MGMT_PORTGROUP"
  compute_cluster                 = "CLUSTER"
  vm_folder                       = "FOLDER"
  vsphere_user                    = "USERNAME"
  vsphere_avi_user                = "USERNAME"
  vsphere_avi_password            = "PASSWORD"
  vsphere_password                = "PASSWORD"
  vsphere_server                  = "VCENTER_ADDRESS"
  controller_ip                   = ["192.168.110.10"]
  controller_netmask              = "24"
  controller_gateway              = "192.168.110.1"
  configure_ipam_profile          = { enabled = "true", networks = [{ portgroup = "PORTGROUP", network = "100.64.220.0/24", type = "V4", static_pool = ["100.64.220.20", "100.64.220.45"] }] }
  configure_dns_profile           = { enabled = "true", usable_domains = ["demowest.net"] }
  configure_dns_vs                = { enabled = "true", auto_allocate_ip = "true", vs_ip = "", portgroup = "PORTGROUP", network = "100.64.220.0/24", type = "V4" }
  configure_gslb                  = { enabled = "true", site_name = "West1", domains = ["gslb.avidemo.net"], additional_sites = [{name = "East1", ip_address_list = module.avi_controller_east.controllers[*].private_ip_address , dns_vs_name = "DNS-VS"}] }
}

module "avi_controller_east" {
  source  = "slarimore02/avi-controller-vsphere/vsphere"
  version = "1.0.x"
  
  controller_default_password = "PASSWORD"
  avi_version                 = "20.1.5"
  controller_password         = "NEWPASSWORD"
  controller_ha               = "true"
  create_roles                = "true"
  vsphere_datacenter          = "DATACENTER"
  content_library             = "CONTENT_LIBRARY_NAME"
  vm_template                 = "controller-20.1.5-9148"
  vm_datastore                = "DATASTORE"
  name_prefix                 = "PREFIX"
  dns_servers                 = [{ addr = "8.8.4.4", type = "V4" }, { addr = "8.8.8.8", type = "V4" }]
  dns_search_domain           = "vmware.com"
  ntp_servers                 = [{ "addr": "0.us.pool.ntp.org","type": "DNS" },{ "addr": "1.us.pool.ntp.org","type": "DNS" },{ "addr": "2.us.pool.ntp.org", "type": "DNS" },{ "addr": "3.us.pool.ntp.org", "type": "DNS" }]
  se_mgmt_portgroup           = "SE_PORTGROUP"
  se_mgmt_network             = { network = "192.168.120.0/24", gateway = "192.168.120.1", type = "V4", static_pool = ["192.168.120.100", "192.168.120.200"] }
  controller_mgmt_portgroup   = "MGMT_PORTGROUP"
  compute_cluster             = "CLUSTER"
  vm_folder                   = "FOLDER"
  vsphere_user                = "USERNAME"
  vsphere_avi_user            = "USERNAME"
  vsphere_avi_password        = "PASSWORD"
  vsphere_password            = "PASSWORD"
  vsphere_server              = "VCENTER_ADDRESS"
  controller_ip               = ["192.168.120.10"]
  controller_netmask          = "24"
  controller_gateway          = "192.168.120.1"
  configure_ipam_profile      = { enabled = "true", networks = [{ portgroup = "PORTGROUP", network = "100.64.230.0/24", type = "V4", static_pool = ["100.64.230.20", "100.64.230.45"] }] }
  configure_dns_profile       = { enabled = "true", usable_domains = ["demoeast.net"] }
  configure_dns_vs            = { enabled = "true", auto_allocate_ip = "true", portgroup = "PORTGROUP", network = "100.64.230.0/24" }
  configure_gslb              =  { enabled = "true", site_name = "East" }
}

output "controllers_west" {
  value = module.avi_controller_west.controllers
}
output "gslb_leader_ip" {
  value = module.avi_controller_west.gslb_ip
}
output "controllers_east" { 
  value = module.avi_controller_east.controllers
}
```

## VMware User Role for Avi
Optionally the vSphere Roles detailed in https://avinetworks.com/docs/latest/vmware-user-role can be created and associated with an vSphere Account. 
To enable this feature set the create_roles variable to "true". If set to "false" these roles should have already been created and assigned to the account that Avi will use.
 
When the create_roles variable is set to "true" the following command should be ran to remove the avi_root role and permissions before running a terraform destroy. The avi_root role can be cleaned up manually by navigating to the Administration > Access Control > Roles section and selecting delete for the avi_root role. This is due to a bug in the vSphere provider - https://github.com/hashicorp/terraform-provider-vsphere/issues/1400
```bash  
terraform state rm vsphere_entity_permissions.avi_root vsphere_role.avi_root
```

## Controller Sizing
The controller_size variable can be used to determine the vCPU and Memory resources allocated to the Avi Controller. There are 3 available sizes for the Controller as documented below:

| Size | vCPU Cores | Memory (GB)|
|------|-----------|--------|
| small | 8 | 24 |
| medium | 16 | 32 |
| large | 24 | 48 |

Additional resources on sizing the Avi Controller:

https://avinetworks.com/docs/latest/avi-controller-sizing/
https://avinetworks.com/docs/latest/system-limits/

## Day 1 Ansible Configuration and Avi Resource Cleanup
The module copies and runs an Ansible play for configuring the initial day 1 Avi config. The plays listed below can be reviewed by connecting to the Avi Controller by SSH. In an HA setup the first controller will have these files. 

### avi-controller-aws-all-in-one-play.yml
This play will configure the Avi Cloud, Network, IPAM/DNS profiles, DNS Virtual Service, GSLB depending on the variables used. The initial run of this play will output into the ansible-playbook.log file which can be reviewed to determine what tasks were ran. 

Example run (appropriate variable values should be used):
```bash
~$ ansible-playbook avi-controller-aws-all-in-one-play.yml -e password=${var.controller_password} -e aws_access_key_id=${var.aws_access_key} -e aws_secret_access_key=${var.aws_secret_key} > ansible-playbook-run.log
```

### avi-upgrade.yml
This play will upgrade or patch the Avi Controller and SEs depending on the variables used. When ran this play will output into the ansible-playbook.log file which can be reviewed to determine what tasks were ran. This play can be ran during the initial Terraform deployment with the avi_upgrade variable as shown in the example below:

```hcl
avi_upgrade = { enabled = "true", upgrade_type = "patch", upgrade_file_uri = "URL Copied From portal.avipulse.vmware.com"}
```

An full version upgrade can be done by changing changing the upgrade_type to "system". It is recommended to run this play in a lower environment before running in a production environment and is not recommended for a GSLB setup at this time.

Example run (appropriate variable values should be used):
```bash
~$ ansible-playbook avi-upgrade.yml -e password=${var.controller_password} -e upgrade_type=${var.avi_upgrade.upgrade_type} -e upgrade_file_uri=${var.avi_upgrade.upgrade_file_uri} > ansible-playbook-run.log
```

### avi-cloud-services-registration.yml
This play will register the Controller with Avi Cloud Services. This can be done to enable centralized licensing, live security threat updates, and proactive support. When ran this play will output into the ansible-playbook.log file which can be reviewed to determine what tasks were ran. This play can be ran during the initial Terraform deployment with the register_controller variable as shown in the example below:

```hcl
register_controller = { enabled = "true", jwt_token = "TOKEN", email = "EMAIL", organization_id = "LONG_ORG_ID" }
```

The organization_id can be found as the Long Organization ID field from https://console.cloud.vmware.com/csp/gateway/portal/#/organization/info.

The jwt_token can be retrieved at https://portal.avipulse.vmware.com/portal/controller/auth/cspctrllogin.

Example run (appropriate variable values should be used):
```bash
~$ ansible-playbook avi-cloud-services-registration.yml -e password=${var.controller_password} -e registration_account_id=${var.register_controller.organization_id} -e registration_email=${var.register_controller.email} -e registration_jwt=${var.register_controller.jwt_token} > ansible-playbook-run.log
```

### avi-cleanup.yml
This play will disable all Virtual Services and delete all existing Avi service engines. This playbook should be ran before deleting the controller with terraform destroy to clean up the resources created by the Avi Controller. 

Example run (appropriate variable values should be used):
```bash
~$ ansible-playbook avi-cleanup.yml -e password=${var.controller_password}
```

## Contributing

The terraform-vsphere-avi-alb-deployment-vsphere project team welcomes contributions from the community. Before you start working with this project please read and sign our Contributor License Agreement (https://cla.vmware.com/cla/1/preview). If you wish to contribute code and you have not signed our Contributor Licence Agreement (CLA), our bot will prompt you to do so when you open a Pull Request. For any questions about the CLA process, please refer to our [FAQ](https://cla.vmware.com/faq). For more detailed information, refer to [CONTRIBUTING.md](CONTRIBUTING.md).

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.1.1 |
| <a name="requirement_vsphere"></a> [vsphere](#requirement\_vsphere) | ~> 2.2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | 3.1.1 |
| <a name="provider_vsphere"></a> [vsphere](#provider\_vsphere) | 2.2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.ansible_provisioner](https://registry.terraform.io/providers/hashicorp/null/3.1.1/docs/resources/resource) | resource |
| [vsphere_compute_cluster_vm_anti_affinity_rule.avi](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/compute_cluster_vm_anti_affinity_rule) | resource |
| [vsphere_entity_permissions.avi_folder](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/entity_permissions) | resource |
| [vsphere_entity_permissions.avi_root](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/entity_permissions) | resource |
| [vsphere_folder.avi](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/folder) | resource |
| [vsphere_role.avi_folder](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/role) | resource |
| [vsphere_role.avi_root](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/role) | resource |
| [vsphere_virtual_machine.avi_controller](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/virtual_machine) | resource |
| [vsphere_compute_cluster.avi](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/data-sources/compute_cluster) | data source |
| [vsphere_content_library.library](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/data-sources/content_library) | data source |
| [vsphere_content_library_item.item](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/data-sources/content_library_item) | data source |
| [vsphere_datacenter.dc](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/data-sources/datacenter) | data source |
| [vsphere_datastore.datastore](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/data-sources/datastore) | data source |
| [vsphere_folder.root](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/data-sources/folder) | data source |
| [vsphere_network.avi](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/data-sources/network) | data source |
| [vsphere_resource_pool.pool](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/data-sources/resource_pool) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_avi_upgrade"></a> [avi\_upgrade](#input\_avi\_upgrade) | This variable determines if a patch upgrade is performed after install. The enabled key should be set to true and the url from the Avi Cloud Services portal for the should be set for the upgrade\_file\_uri key. Valid upgrade\_type values are patch or system | `object({ enabled = bool, upgrade_type = string, upgrade_file_uri = string })` | <pre>{<br>  "enabled": "false",<br>  "upgrade_file_uri": "",<br>  "upgrade_type": "patch"<br>}</pre> | no |
| <a name="input_avi_version"></a> [avi\_version](#input\_avi\_version) | The version of Avi that will be deployed | `string` | n/a | yes |
| <a name="input_boot_disk_size"></a> [boot\_disk\_size](#input\_boot\_disk\_size) | The boot disk size for the Avi controller | `number` | `128` | no |
| <a name="input_compute_cluster"></a> [compute\_cluster](#input\_compute\_cluster) | The name of the vSphere cluster that the Avi Controllers will be deployed to | `string` | `null` | no |
| <a name="input_configure_controller"></a> [configure\_controller](#input\_configure\_controller) | Configure the Avi Cloud via Ansible after controller deployment. If not set to true this must be done manually with the desired config | `bool` | `"true"` | no |
| <a name="input_configure_dns_profile"></a> [configure\_dns\_profile](#input\_configure\_dns\_profile) | Configure a DNS Profile for DNS Record Creation for Virtual Services. The usable\_domains is a list of domains that Avi will be the Authoritative Nameserver for and NS records may need to be created pointing to the Avi Service Engine addresses. Supported profiles for the type parameter are AWS or AVI | <pre>object({<br>    enabled        = bool,<br>    type           = optional(string, "AVI"),<br>    usable_domains = list(string),<br>    ttl            = optional(string, "30"),<br>    aws_profile    = optional(object({ iam_assume_role = string, region = string, vpc_id = string, access_key_id = string, secret_access_key = string }))<br>  })</pre> | <pre>{<br>  "enabled": false,<br>  "type": "AVI",<br>  "usable_domains": []<br>}</pre> | no |
| <a name="input_configure_dns_vs"></a> [configure\_dns\_vs](#input\_configure\_dns\_vs) | Create Avi DNS Virtual Service. The subnet\_name parameter must be an existing AWS Subnet. If the allocate\_public\_ip parameter is set to true a EIP will be allocated for the VS. The VS IP address will automatically be allocated via the AWS IPAM | <pre>object({<br>    enabled          = bool,<br>    portgroup        = string,<br>    network          = string,<br>    auto_allocate_ip = optional(bool, true),<br>    vs_ip            = optional(string)<br>    type             = optional(string, "V4")<br>  })</pre> | <pre>{<br>  "enabled": "false",<br>  "network": "",<br>  "portgroup": ""<br>}</pre> | no |
| <a name="input_configure_gslb"></a> [configure\_gslb](#input\_configure\_gslb) | Configures GSLB. In addition the configure\_dns\_vs variable must also be set for GSLB to be configured. See the GSLB Deployment README section for more information. | <pre>object({<br>    enabled          = bool,<br>    leader           = optional(bool, false),<br>    site_name        = string,<br>    domains          = optional(list(string)),<br>    create_se_group  = optional(bool, true),<br>    se_size          = optional(list(number), [2, 8, 30]),<br>    additional_sites = optional(list(object({ name = string, ip_address_list = list(string) })))<br>  })</pre> | <pre>{<br>  "domains": [<br>    ""<br>  ],<br>  "enabled": "false",<br>  "site_name": ""<br>}</pre> | no |
| <a name="input_configure_ipam_profile"></a> [configure\_ipam\_profile](#input\_configure\_ipam\_profile) | Configure Avi IPAM Profile for Virtual Service Address Allocation. If set to true the virtualservice\_network variable must also be set | `bool` | `"false"` | no |
| <a name="input_configure_nsx_cloud"></a> [configure\_nsx\_cloud](#input\_configure\_nsx\_cloud) | Configure the Cloud type as NSX. The nsx\_password and configure\_nsx\_vcenter variables should also be configured | <pre>object({<br>    enabled       = bool,<br>    username      = string,<br>    nsx_mgr_url   = string,<br>    cloud_name    = optional(string, "NSX")<br>    mgmt_segment  = object({ name = string, t1_name = string }),<br>    mgmt_tz       = object({ id = string, type = string }),<br>    data_tz       = object({ id = string, type = string }),<br>    data_segments = list(object({ segment_name = string, t1_name = string }))<br>  })</pre> | <pre>{<br>  "data_segments": [<br>    {<br>      "segment_name": "",<br>      "t1_name": ""<br>    }<br>  ],<br>  "data_tz": {<br>    "id": "",<br>    "type": "OVERLAY"<br>  },<br>  "enabled": false,<br>  "mgmt_segment": {<br>    "name": "",<br>    "t1_name": ""<br>  },<br>  "mgmt_tz": {<br>    "id": "",<br>    "type": "OVERLAY"<br>  },<br>  "nsx_mgr_url": "",<br>  "username": ""<br>}</pre> | no |
| <a name="input_configure_nsx_vcenter"></a> [configure\_nsx\_vcenter](#input\_configure\_nsx\_vcenter) | Configure the vCenters used for the NSX Cloud configuration. The vsphere\_avi\_user and vsphere\_avi\_password variables must also be set and will be used for authenticating to all vCenters configured with this variable | <pre>list(object({<br>    name            = string,<br>    url             = string,<br>    content_library = string<br>  }))</pre> | <pre>[<br>  {<br>    "content_library": "",<br>    "name": "",<br>    "url": ""<br>  }<br>]</pre> | no |
| <a name="input_configure_se_mgmt_network"></a> [configure\_se\_mgmt\_network](#input\_configure\_se\_mgmt\_network) | When true the se\_mgmt\_network\_address variable must be configured. If set to false, DHCP is enabled on the vSphere portgroup that the Avi Service Engines will use for management. | `bool` | `"true"` | no |
| <a name="input_content_library"></a> [content\_library](#input\_content\_library) | The name of the Content Library that has the Avi Controller Image | `string` | n/a | yes |
| <a name="input_controller_default_password"></a> [controller\_default\_password](#input\_controller\_default\_password) | This is the default password for the Avi controller image and can be found in the image download page. | `string` | n/a | yes |
| <a name="input_controller_gateway"></a> [controller\_gateway](#input\_controller\_gateway) | The IP Address of the gateway for the controller mgmt network | `string` | n/a | yes |
| <a name="input_controller_ha"></a> [controller\_ha](#input\_controller\_ha) | If true a HA controller cluster is deployed and configured | `bool` | `"false"` | no |
| <a name="input_controller_ip"></a> [controller\_ip](#input\_controller\_ip) | A list of IP Addresses that will be assigned to the Avi Controller(s). For a full HA deployment the list should contain 4 IP addresses. The first 3 addresses will be used for the individual controllers and the 4th IP address listed will be used as the Cluster IP | `list(string)` | n/a | yes |
| <a name="input_controller_mgmt_portgroup"></a> [controller\_mgmt\_portgroup](#input\_controller\_mgmt\_portgroup) | The vSphere portgroup name that the Avi Controller will use for management | `string` | n/a | yes |
| <a name="input_controller_netmask"></a> [controller\_netmask](#input\_controller\_netmask) | The subnet mask of the controller mgmt network | `string` | n/a | yes |
| <a name="input_controller_password"></a> [controller\_password](#input\_controller\_password) | The password that will be used authenticating with the Avi Controller. This password be a minimum of 8 characters and contain at least one each of uppercase, lowercase, numbers, and special characters | `string` | n/a | yes |
| <a name="input_controller_size"></a> [controller\_size](#input\_controller\_size) | This value determines the number of vCPUs and memory allocated for the Avi Controller. Possible values are small, medium, or large. | `string` | `"small"` | no |
| <a name="input_create_roles"></a> [create\_roles](#input\_create\_roles) | This variable controls the creation of Avi specific vSphere Roles for the Avi Controller to use. When set to false these roles should already be created and assigned to the vSphere account used by the Avi Controller. | `bool` | `"false"` | no |
| <a name="input_dns_search_domain"></a> [dns\_search\_domain](#input\_dns\_search\_domain) | The optional DNS search domain that will be used by the controller | `string` | `null` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | The optional DNS servers that will be used for local DNS resolution by the controller. The server should be a valid IP address (v4 or v6) and valid options for type are V4 or V6. Example: [{ addr = "8.8.4.4", type = "V4"}, { addr = "8.8.8.8", type = "V4"}] | `list(object({ addr = string, type = string }))` | `null` | no |
| <a name="input_email_config"></a> [email\_config](#input\_email\_config) | The Email settings that will be used for sending password reset information or for trigged alerts. The default setting will send emails directly from the Avi Controller | `object({ smtp_type = string, from_email = string, mail_server_name = string, mail_server_port = string, auth_username = string, auth_password = string })` | <pre>{<br>  "auth_password": "",<br>  "auth_username": "",<br>  "from_email": "admin@avicontroller.net",<br>  "mail_server_name": "localhost",<br>  "mail_server_port": "25",<br>  "smtp_type": "SMTP_LOCAL_HOST"<br>}</pre> | no |
| <a name="input_ipam_networks"></a> [ipam\_networks](#input\_ipam\_networks) | This variable configures the IPAM network(s). Example: { portgroup = "vs-portgroup", network = "192.168.20.0/24" , gateway = "192.168.20.1", type = "V4", static\_pool = ["192.168.20.10","192.168.20.30"]} | `list(object({ portgroup = string, network = string, type = string, static_pool = list(string) }))` | <pre>[<br>  {<br>    "network": "",<br>    "portgroup": "",<br>    "static_pool": [<br>      ""<br>    ],<br>    "type": ""<br>  }<br>]</pre> | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | This prefix is appended to the names of the Controller and SEs | `string` | n/a | yes |
| <a name="input_nsx_password"></a> [nsx\_password](#input\_nsx\_password) | The NSX Manager password for the user account that will be used for the NSX Cloud configured with the configure\_nsx\_cloud variable | `string` | `""` | no |
| <a name="input_ntp_servers"></a> [ntp\_servers](#input\_ntp\_servers) | The NTP Servers that the Avi Controllers will use. The server should be a valid IP address (v4 or v6) or a DNS name. Valid options for type are V4, DNS, or V6 | `list(object({ addr = string, type = string }))` | <pre>[<br>  {<br>    "addr": "0.us.pool.ntp.org",<br>    "type": "DNS"<br>  },<br>  {<br>    "addr": "1.us.pool.ntp.org",<br>    "type": "DNS"<br>  },<br>  {<br>    "addr": "2.us.pool.ntp.org",<br>    "type": "DNS"<br>  },<br>  {<br>    "addr": "3.us.pool.ntp.org",<br>    "type": "DNS"<br>  }<br>]</pre> | no |
| <a name="input_register_controller"></a> [register\_controller](#input\_register\_controller) | If enabled is set to true the controller will be registered and licensed with Avi Cloud Services. The Long Organization ID (organization\_id) can be found from https://console.cloud.vmware.com/csp/gateway/portal/#/organization/info. The jwt\_token can be retrieved at https://portal.avipulse.vmware.com/portal/controller/auth/cspctrllogin | `object({ enabled = bool, jwt_token = string, email = string, organization_id = string })` | <pre>{<br>  "email": "",<br>  "enabled": "false",<br>  "jwt_token": "",<br>  "organization_id": ""<br>}</pre> | no |
| <a name="input_se_content_lib_name"></a> [se\_content\_lib\_name](#input\_se\_content\_lib\_name) | The name the Content Library used for the SE image. If se\_use\_content\_lib is true and this variable is not set the content\_library variable will be used | `string` | `null` | no |
| <a name="input_se_ha_mode"></a> [se\_ha\_mode](#input\_se\_ha\_mode) | The HA mode of the Service Engine Group. Possible values active/active, n+m, or active/standby | `string` | `"active/active"` | no |
| <a name="input_se_mgmt_network"></a> [se\_mgmt\_network](#input\_se\_mgmt\_network) | This variable configures the SE management network. Example: { network = "192.168.10.0/24" , gateway = "192.168.10.1", type = "V4", static\_pool = ["192.168.10.10","192.168.10.30"]} | `object({ network = string, gateway = string, type = string, static_pool = list(string) })` | <pre>{<br>  "gateway": "",<br>  "network": "",<br>  "static_pool": [<br>    ""<br>  ],<br>  "type": ""<br>}</pre> | no |
| <a name="input_se_mgmt_portgroup"></a> [se\_mgmt\_portgroup](#input\_se\_mgmt\_portgroup) | The vSphere portgroup that the Avi Service Engines will use for management | `string` | `null` | no |
| <a name="input_se_size"></a> [se\_size](#input\_se\_size) | The CPU, Memory, Disk Size of the Service Engines. The default is 2 vCPU, 4 GB RAM, and a 20 GB Disk per Service Engine. Syntax ["cpu\_cores", "memory\_in\_GB", "disk\_size\_in\_GB"] | `list(number)` | <pre>[<br>  2,<br>  4,<br>  20<br>]</pre> | no |
| <a name="input_se_use_content_lib"></a> [se\_use\_content\_lib](#input\_se\_use\_content\_lib) | Determines if a Content Libary will be used to store the Avi SE Image. Only applies to 22.1.1 and above. | `bool` | `"true"` | no |
| <a name="input_vm_datastore"></a> [vm\_datastore](#input\_vm\_datastore) | The vSphere Datastore that will back the Avi Controller VMs | `string` | n/a | yes |
| <a name="input_vm_folder"></a> [vm\_folder](#input\_vm\_folder) | The folder that the Avi Controller(s) will be placed in. This will be the full path and name of the folder that will be created | `string` | n/a | yes |
| <a name="input_vm_resource_pool"></a> [vm\_resource\_pool](#input\_vm\_resource\_pool) | The Resource Pool that the Avi Controller(s) will be deployed to | `string` | `""` | no |
| <a name="input_vm_template"></a> [vm\_template](#input\_vm\_template) | The name of the Avi Controller Image that is hosted in a Content Library | `string` | n/a | yes |
| <a name="input_vsphere_avi_password"></a> [vsphere\_avi\_password](#input\_vsphere\_avi\_password) | The password for the user account that will be used for accessing vCenter from the Avi Controller(s) | `string` | `null` | no |
| <a name="input_vsphere_avi_user"></a> [vsphere\_avi\_user](#input\_vsphere\_avi\_user) | The user account that will be used for accessing vCenter from the Avi Controller(s) | `string` | `null` | no |
| <a name="input_vsphere_datacenter"></a> [vsphere\_datacenter](#input\_vsphere\_datacenter) | The vSphere Datacenter that the Avi Controller(s) will be deployed | `string` | n/a | yes |
| <a name="input_vsphere_password"></a> [vsphere\_password](#input\_vsphere\_password) | The password for the user account that will be used for creating vSphere resources | `string` | n/a | yes |
| <a name="input_vsphere_server"></a> [vsphere\_server](#input\_vsphere\_server) | The IP Address or FQDN of the VMware vCenter server | `string` | n/a | yes |
| <a name="input_vsphere_user"></a> [vsphere\_user](#input\_vsphere\_user) | The user account that will be used to create the Avi Controller(s) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_controllers"></a> [controllers](#output\_controllers) | AVI Controller Information |
| <a name="output_gslb_ip"></a> [gslb\_ip](#output\_gslb\_ip) | The IP Address of AVI Controller Information |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->