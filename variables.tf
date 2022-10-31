variable "name_prefix" {
  description = "This prefix is appended to the names of the Controller and SEs"
  type        = string
}
variable "controller_ha" {
  description = "If true a HA controller cluster is deployed and configured"
  type        = bool
  default     = "false"
}
variable "register_controller" {
  description = "If enabled is set to true the controller will be registered and licensed with Avi Cloud Services. The Long Organization ID (organization_id) can be found from https://console.cloud.vmware.com/csp/gateway/portal/#/organization/info. The jwt_token can be retrieved at https://portal.avipulse.vmware.com/portal/controller/auth/cspctrllogin"
  sensitive   = false
  type        = object({ enabled = bool, jwt_token = string, email = string, organization_id = string })
  default     = { enabled = "false", jwt_token = "", email = "", organization_id = "" }
}
variable "create_roles" {
  description = "This variable controls the creation of Avi specific vSphere Roles for the Avi Controller to use. When set to false these roles should already be created and assigned to the vSphere account used by the Avi Controller."
  type        = bool
  default     = "false"
}
variable "controller_default_password" {
  description = "This is the default password for the Avi controller image and can be found in the image download page."
  type        = string
  sensitive   = false
}
variable "controller_password" {
  description = "The password that will be used authenticating with the Avi Controller. This password be a minimum of 8 characters and contain at least one each of uppercase, lowercase, numbers, and special characters"
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.controller_password) > 7
    error_message = "The controller_password value must be more than 8 characters and contain at least one each of uppercase, lowercase, numbers, and special characters."
  }
}
variable "avi_version" {
  description = "The version of Avi that will be deployed"
  type        = string
}
variable "avi_upgrade" {
  description = "This variable determines if a patch upgrade is performed after install. The enabled key should be set to true and the url from the Avi Cloud Services portal for the should be set for the upgrade_file_uri key. Valid upgrade_type values are patch or system"
  sensitive   = false
  type        = object({ enabled = bool, upgrade_type = string, upgrade_file_uri = string })
  default     = { enabled = "false", upgrade_type = "patch", upgrade_file_uri = "" }
}
variable "controller_size" {
  description = "This value determines the number of vCPUs and memory allocated for the Avi Controller. Possible values are small, medium, or large."
  type        = string
  default     = "small"
  validation {
    condition     = contains(["small", "medium", "large"], var.controller_size)
    error_message = "Acceptable values are small, medium, or large."
  }
}
variable "configure_controller" {
  description = "Configure the Avi Cloud via Ansible after controller deployment. If not set to true this must be done manually with the desired config"
  type        = bool
  default     = "true"
}
variable "configure_ipam_profile" {
  description = "Configure Avi IPAM Profile for Virtual Service Address Allocation. If set to true the virtualservice_network variable must also be set"
  type        = bool
  default     = "false"
}
variable "configure_dns_profile" {
  description = "Configure a DNS Profile for DNS Record Creation for Virtual Services. The usable_domains is a list of domains that Avi will be the Authoritative Nameserver for and NS records may need to be created pointing to the Avi Service Engine addresses. Supported profiles for the type parameter are AWS or AVI"
  type = object({
    enabled        = bool,
    type           = optional(string, "AVI"),
    usable_domains = list(string),
    ttl            = optional(string, "30"),
    aws_profile    = optional(object({ iam_assume_role = string, region = string, vpc_id = string, access_key_id = string, secret_access_key = string }))
  })
  default = { enabled = false, type = "AVI", usable_domains = [] }
  validation {
    condition     = contains(["AWS", "AVI"], var.configure_dns_profile.type)
    error_message = "Supported DNS Profile types are 'AWS' or 'AVI'"
  }
}
variable "configure_dns_vs" {
  description = "Create Avi DNS Virtual Service. The subnet_name parameter must be an existing AWS Subnet. If the allocate_public_ip parameter is set to true a EIP will be allocated for the VS. The VS IP address will automatically be allocated via the AWS IPAM"
  type = object({
    enabled          = bool,
    portgroup        = string,
    network          = string,
    auto_allocate_ip = optional(bool, true),
    vs_ip            = optional(string)
    type             = optional(string, "V4")
  })
  default = { enabled = "false", network = "", portgroup = "" }
}
variable "configure_gslb" {
  description = "Configures GSLB. In addition the configure_dns_vs variable must also be set for GSLB to be configured. See the GSLB Deployment README section for more information."
  type = object({
    enabled          = bool,
    leader           = optional(bool, false),
    site_name        = string,
    domains          = optional(list(string)),
    create_se_group  = optional(bool, true),
    se_size          = optional(list(string), ["2", "8", "30"]),
    additional_sites = optional(list(object({ name = string, ip_address_list = list(string) })))
  })
  default = { enabled = "false", site_name = "", domains = [""] }
}
variable "vsphere_datacenter" {
  description = "The vSphere Datacenter that the Avi Controller(s) will be deployed"
  type        = string
}
variable "vm_resource_pool" {
  description = "The Resource Pool that the Avi Controller(s) will be deployed to"
  type        = string
  default     = ""
}
variable "content_library" {
  description = "The name of the Content Library that has the Avi Controller Image"
  type        = string
}
variable "se_use_content_lib" {
  description = "Determines if a Content Libary will be used to store the Avi SE Image. Only applies to 22.1.1 and above."
  type        = bool
  default     = "true"
}
variable "se_content_lib_name" {
  description = "The name the Content Library used for the SE image. If se_use_content_lib is true and this variable is not set the content_library variable will be used"
  type        = string
  default     = null
}
variable "vm_datastore" {
  description = "The vSphere Datastore that will back the Avi Controller VMs"
  type        = string
}
variable "controller_mgmt_portgroup" {
  description = "The vSphere portgroup name that the Avi Controller will use for management"
  type        = string
}
variable "se_mgmt_portgroup" {
  description = "The vSphere portgroup that the Avi Service Engines will use for management"
  type        = string
  default     = null
}
variable "configure_se_mgmt_network" {
  description = "When true the se_mgmt_network_address variable must be configured. If set to false, DHCP is enabled on the vSphere portgroup that the Avi Service Engines will use for management."
  type        = bool
  default     = "true"
}
variable "se_mgmt_network" {
  description = "This variable configures the SE management network. Example: { network = \"192.168.10.0/24\" , gateway = \"192.168.10.1\", type = \"V4\", static_pool = [\"192.168.10.10\",\"192.168.10.30\"]}"
  type        = object({ network = string, gateway = string, type = string, static_pool = list(string) })
  default     = { network = "", gateway = "", type = "", static_pool = [""] }
}
variable "ipam_networks" {
  description = "This variable configures the IPAM network(s). Example: { portgroup = \"vs-portgroup\", network = \"192.168.20.0/24\" , gateway = \"192.168.20.1\", type = \"V4\", static_pool = [\"192.168.20.10\",\"192.168.20.30\"]}"
  type        = list(object({ portgroup = string, network = string, type = string, static_pool = list(string) }))
  default     = [{ portgroup = "", network = "", type = "", static_pool = [""] }]
}
variable "vm_folder" {
  description = "The folder that the Avi Controller(s) will be placed in. This will be the full path and name of the folder that will be created"
  type        = string
}
variable "vm_template" {
  description = "The name of the Avi Controller Image that is hosted in a Content Library"
  type        = string
}
variable "vsphere_user" {
  description = "The user account that will be used to create the Avi Controller(s)"
  type        = string
}
variable "vsphere_avi_user" {
  description = "The user account that will be used for accessing vCenter from the Avi Controller(s)"
  type        = string
  default     = null
}
variable "vsphere_avi_password" {
  description = "The password for the user account that will be used for accessing vCenter from the Avi Controller(s)"
  sensitive   = false
  type        = string
  default     = null
}
variable "vsphere_password" {
  description = "The password for the user account that will be used for creating vSphere resources"
  type        = string
  sensitive   = false
}
variable "vsphere_server" {
  description = "The IP Address or FQDN of the VMware vCenter server"
  type        = string
}
variable "compute_cluster" {
  description = "The name of the vSphere cluster that the Avi Controllers will be deployed to"
  type        = string
  default     = null
}
variable "controller_ip" {
  description = "A list of IP Addresses that will be assigned to the Avi Controller(s). For a full HA deployment the list should contain 4 IP addresses. The first 3 addresses will be used for the individual controllers and the 4th IP address listed will be used as the Cluster IP"
  type        = list(string)
  validation {
    condition     = length(var.controller_ip) == 4 || length(var.controller_ip) == 1
    error_message = "The controller_ip value must be a list of either 1 for a single node deployment or 4 IP Addresses if controller_ha is set to true."
  }
}
variable "controller_netmask" {
  description = "The subnet mask of the controller mgmt network"
  type        = string
}
variable "controller_gateway" {
  description = "The IP Address of the gateway for the controller mgmt network"
  type        = string
}
variable "boot_disk_size" {
  description = "The boot disk size for the Avi controller"
  type        = number
  default     = 128
  validation {
    condition     = var.boot_disk_size >= 128
    error_message = "The Controller boot disk size should be greater than or equal to 128 GB."
  }
}
variable "se_size" {
  description = "The CPU, Memory, Disk Size of the Service Engines. The default is 1 vCPU, 2 GB RAM, and a 15 GB Disk per Service Engine. Syntax [\"cpu_cores\", \"memory_in_GB\", \"disk_size_in_GB\"]"
  type        = list(string)
  default     = ["1", "2", "15"]
}
variable "se_ha_mode" {
  description = "The HA mode of the Service Engine Group. Possible values active/active, n+m, or active/standby"
  type        = string
  default     = "active/active"
  validation {
    condition     = contains(["active/active", "n+m", "active/standby"], var.se_ha_mode)
    error_message = "Acceptable values are active/active, n+m, or active/standby."
  }
}
variable "dns_servers" {
  description = "The optional DNS servers that will be used for local DNS resolution by the controller. The server should be a valid IP address (v4 or v6) and valid options for type are V4 or V6. Example: [{ addr = \"8.8.4.4\", type = \"V4\"}, { addr = \"8.8.8.8\", type = \"V4\"}]"
  type        = list(object({ addr = string, type = string }))
  default     = null
}
variable "dns_search_domain" {
  description = "The optional DNS search domain that will be used by the controller"
  type        = string
  default     = null
}
variable "ntp_servers" {
  description = "The NTP Servers that the Avi Controllers will use. The server should be a valid IP address (v4 or v6) or a DNS name. Valid options for type are V4, DNS, or V6"
  type        = list(object({ addr = string, type = string }))
  default     = [{ addr = "0.us.pool.ntp.org", type = "DNS" }, { addr = "1.us.pool.ntp.org", type = "DNS" }, { addr = "2.us.pool.ntp.org", type = "DNS" }, { addr = "3.us.pool.ntp.org", type = "DNS" }]
}
variable "email_config" {
  description = "The Email settings that will be used for sending password reset information or for trigged alerts. The default setting will send emails directly from the Avi Controller"
  sensitive   = false
  type        = object({ smtp_type = string, from_email = string, mail_server_name = string, mail_server_port = string, auth_username = string, auth_password = string })
  default     = { smtp_type = "SMTP_LOCAL_HOST", from_email = "admin@avicontroller.net", mail_server_name = "localhost", mail_server_port = "25", auth_username = "", auth_password = "" }
}