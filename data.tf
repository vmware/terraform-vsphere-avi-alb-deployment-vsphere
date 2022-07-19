data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}
data "vsphere_compute_cluster" "avi" {
  count         = var.compute_cluster != null ? 1 : 0
  name          = var.compute_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_folder" "root" {
  path = "/"
}
data "vsphere_datastore" "datastore" {
  name          = var.vm_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_resource_pool" "pool" {
  count         = var.compute_cluster != null ? 0 : 1
  name          = var.vm_resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "avi" {
  name          = var.controller_mgmt_portgroup
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_content_library" "library" {
  name = var.content_library
}
data "vsphere_content_library_item" "item" {
  name       = var.vm_template
  library_id = data.vsphere_content_library.library.id
  type       = "ovf"
}