resource "vsphere_entity_permissions" "avi_folder" {
  count       = var.create_roles ? 1 : 0
  entity_id   = vsphere_folder.avi.id
  entity_type = "Folder"

  permissions {
    user_or_group = var.vsphere_avi_user == null ? var.vsphere_user : var.vsphere_avi_user
    propagate     = true
    is_group      = false
    role_id       = var.configure_nsx_cloud.enabled ? vsphere_role.nsx_avi_folder[0].id : vsphere_role.avi_folder[0].id
  }
  lifecycle {
    ignore_changes = [permissions]
  }
}
resource "vsphere_entity_permissions" "avi_root" {
  count       = var.create_roles && var.configure_nsx_cloud.enabled == false ? 1 : 0
  entity_id   = data.vsphere_folder.root.id
  entity_type = "Folder"

  permissions {
    user_or_group = var.vsphere_avi_user == null ? var.vsphere_user : var.vsphere_avi_user
    propagate     = true
    is_group      = false
    role_id       = vsphere_role.avi_root[0].id
  }
  lifecycle {
    ignore_changes = [permissions]
  }
}
resource "vsphere_role" "avi_root" {
  count = var.create_roles && var.configure_nsx_cloud.enabled == false ? 1 : 0
  name  = "avi_root"
  role_privileges = [
    "ContentLibrary.AddLibraryItem",
    "ContentLibrary.DeleteLibraryItem",
    "ContentLibrary.UpdateLibraryItem",
    "ContentLibrary.UpdateSession",
    "Datastore.AllocateSpace",
    "Network.Assign",
    "Host.Config.Network",
    "VirtualMachine.Config.AddNewDisk",
    "VirtualMachine.Config.AdvancedConfig",
    "Resource.AssignVMToPool",
    "VApp.Import"
  ]
}
resource "vsphere_role" "avi_folder" {
  count = var.create_roles && var.configure_nsx_cloud.enabled == false ? 1 : 0
  name  = "avi_folder"
  role_privileges = [
    "Datacenter.IpPoolConfig",
    "Datacenter.IpPoolReleaseIp",
    "Datacenter.IpPoolQueryAllocations",
    "Datastore.Browse",
    "Datastore.DeleteFile",
    "Datastore.FileManagement",
    "Datastore.AllocateSpace",
    "Datastore.Config",
    "Datastore.UpdateVirtualMachineFiles",
    "Datastore.UpdateVirtualMachineMetadata",
    "Network.Move",
    "Network.Delete",
    "Network.Config",
    "Network.Assign",
    "DVSwitch.Create",
    "DVSwitch.Modify",
    "DVSwitch.HostOp",
    "DVSwitch.PolicyOp",
    "DVSwitch.PortConfig",
    "DVSwitch.PortSetting",
    "DVSwitch.ResourceManagement",
    "DVPortgroup.Create",
    "DVPortgroup.Modify",
    "DVPortgroup.PolicyOp",
    "DVPortgroup.ScopeOp",
    "DVPortgroup.Ipfix",
    "DVPortgroup.Delete",
    "Host.Inventory.AddStandaloneHost",
    "Host.Inventory.CreateCluster",
    "Host.Inventory.AddHostToCluster",
    "Host.Inventory.RemoveHostFromCluster",
    "Host.Inventory.MoveCluster",
    "Host.Inventory.RenameCluster",
    "Host.Inventory.DeleteCluster",
    "Host.Inventory.EditCluster",
    "Host.Inventory.MoveHost",
    "Host.Inventory.ManageClusterLifecyle",
    "Host.Config.SystemManagement",
    "Host.Config.AutoStart",
    "Host.Config.HyperThreading",
    "Host.Config.Memory",
    "Host.Config.Network",
    "Host.Config.Resources",
    "Host.Config.Settings",
    "Host.Config.Power",
    "Host.Config.Image",
    "Host.Local.InstallAgent",
    "Host.Local.ManageUserGroups",
    "Host.Local.CreateVM",
    "Host.Local.ReconfigVM",
    "Host.Local.DeleteVM",
    "Host.Cim.CimInteraction",
    "VirtualMachine.Inventory.Create",
    "VirtualMachine.Inventory.CreateFromExisting",
    "VirtualMachine.Inventory.Register",
    "VirtualMachine.Inventory.Delete",
    "VirtualMachine.Inventory.Unregister",
    "VirtualMachine.Inventory.Move",
    "VirtualMachine.Interact.PowerOn",
    "VirtualMachine.Interact.PowerOff",
    "VirtualMachine.Interact.Suspend",
    "VirtualMachine.Interact.SuspendToMemory",
    "VirtualMachine.Interact.Reset",
    "VirtualMachine.Interact.Pause",
    "VirtualMachine.Interact.AnswerQuestion",
    "VirtualMachine.Interact.ConsoleInteract",
    "VirtualMachine.Interact.DeviceConnection",
    "VirtualMachine.Interact.SetCDMedia",
    "VirtualMachine.Interact.SetFloppyMedia",
    "VirtualMachine.Interact.ToolsInstall",
    "VirtualMachine.Interact.GuestControl",
    "VirtualMachine.Interact.DefragmentAllDisks",
    "VirtualMachine.Interact.CreateSecondary",
    "VirtualMachine.Interact.TurnOffFaultTolerance",
    "VirtualMachine.Interact.MakePrimary",
    "VirtualMachine.Interact.TerminateFaultTolerantVM",
    "VirtualMachine.Interact.DisableSecondary",
    "VirtualMachine.Interact.EnableSecondary",
    "VirtualMachine.Interact.Record",
    "VirtualMachine.Interact.Replay",
    "VirtualMachine.Interact.Backup",
    "VirtualMachine.Interact.CreateScreenshot",
    "VirtualMachine.Interact.PutUsbScanCodes",
    "VirtualMachine.Interact.SESparseMaintenance",
    "VirtualMachine.Interact.DnD",
    "VirtualMachine.GuestOperations.Query",
    "VirtualMachine.GuestOperations.Modify",
    "VirtualMachine.GuestOperations.Execute",
    "VirtualMachine.GuestOperations.QueryAliases",
    "VirtualMachine.GuestOperations.ModifyAliases",
    "VirtualMachine.Config.Rename",
    "VirtualMachine.Config.Annotation",
    "VirtualMachine.Config.AddExistingDisk",
    "VirtualMachine.Config.AddNewDisk",
    "VirtualMachine.Config.RemoveDisk",
    "VirtualMachine.Config.RawDevice",
    "VirtualMachine.Config.HostUSBDevice",
    "VirtualMachine.Config.CPUCount",
    "VirtualMachine.Config.Memory",
    "VirtualMachine.Config.AddRemoveDevice",
    "VirtualMachine.Config.EditDevice",
    "VirtualMachine.Config.Settings",
    "VirtualMachine.Config.Resource",
    "VirtualMachine.Config.UpgradeVirtualHardware",
    "VirtualMachine.Config.ResetGuestInfo",
    "VirtualMachine.Config.ToggleForkParent",
    "VirtualMachine.Config.AdvancedConfig",
    "VirtualMachine.Config.DiskLease",
    "VirtualMachine.Config.SwapPlacement",
    "VirtualMachine.Config.DiskExtend",
    "VirtualMachine.Config.ChangeTracking",
    "VirtualMachine.Config.QueryUnownedFiles",
    "VirtualMachine.Config.ReloadFromPath",
    "VirtualMachine.Config.QueryFTCompatibility",
    "VirtualMachine.Config.MksControl",
    "VirtualMachine.Config.ManagedBy",
    "VirtualMachine.State.CreateSnapshot",
    "VirtualMachine.State.RevertToSnapshot",
    "VirtualMachine.State.RemoveSnapshot",
    "VirtualMachine.State.RenameSnapshot",
    "VirtualMachine.Hbr.ConfigureReplication",
    "VirtualMachine.Hbr.ReplicaManagement",
    "VirtualMachine.Hbr.MonitorReplication",
    "VirtualMachine.Provisioning.Customize",
    "VirtualMachine.Provisioning.Clone",
    "VirtualMachine.Provisioning.PromoteDisks",
    "VirtualMachine.Provisioning.CreateTemplateFromVM",
    "VirtualMachine.Provisioning.DeployTemplate",
    "VirtualMachine.Provisioning.CloneTemplate",
    "VirtualMachine.Provisioning.MarkAsTemplate",
    "VirtualMachine.Provisioning.MarkAsVM",
    "VirtualMachine.Provisioning.ReadCustSpecs",
    "VirtualMachine.Provisioning.ModifyCustSpecs",
    "VirtualMachine.Provisioning.DiskRandomAccess",
    "VirtualMachine.Provisioning.DiskRandomRead",
    "VirtualMachine.Provisioning.FileRandomAccess",
    "VirtualMachine.Provisioning.GetVmFiles",
    "VirtualMachine.Provisioning.PutVmFiles",
    "VirtualMachine.Namespace.Management",
    "VirtualMachine.Namespace.Query",
    "VirtualMachine.Namespace.ModifyContent",
    "VirtualMachine.Namespace.ReadContent",
    "VirtualMachine.Namespace.Event",
    "VirtualMachine.Namespace.EventNotify",
    "Task.Create",
    "Task.Update",
    "Performance.ModifyIntervals",
    "VApp.ResourceConfig",
    "VApp.InstanceConfig",
    "VApp.ApplicationConfig",
    "VApp.ManagedByConfig",
    "VApp.Export",
    "VApp.Import",
    "VApp.PullFromUrls",
    "VApp.ExtractOvfEnvironment",
    "VApp.AssignVM",
    "VApp.AssignResourcePool",
    "VApp.AssignVApp",
    "VApp.Clone",
    "VApp.Create",
    "VApp.Delete",
    "VApp.Unregister",
    "VApp.Move",
    "VApp.PowerOn",
    "VApp.PowerOff",
    "VApp.Suspend",
    "VApp.Rename"
  ]
}
resource "vsphere_role" "nsx_avi_global" {
  count = var.create_roles && var.configure_nsx_cloud.enabled ? 1 : 0
  name  = "AviRole- Global"
  role_privileges = [
    "ContentLibrary.AddLibraryItem",
    "ContentLibrary.DeleteLibraryItem",
    "ContentLibrary.UpdateLibraryItem",
    "ContentLibrary.UpdateSession",
    "Datastore.AllocateSpace",
    "Datastore.DeleteFile",
    "Network.Assign",
    "Network.Delete",
    "VApp.Import",
    "VirtualMachine.Config.AddNewDisk"
  ]
}
resource "vsphere_role" "nsx_avi_folder" {
  count = var.create_roles && var.configure_nsx_cloud.enabled ? 1 : 0
  name  = "AviRole-Folder"
  role_privileges = [
    "Folder.Create",
    "Network.Delete",
    "Network.Assign",
    "Resource.AssignVMToPool",
    "Task.Create",
    "Task.Update",
    "VApp.AssignVM",
    "VApp.AssignResourcePool",
    "VApp.AssignVApp",
    "VApp.Create",
    "VApp.Delete",
    "VApp.Export",
    "VApp.Import",
    "VApp.PowerOff",
    "VApp.PowerOn",
    "VApp.ApplicationConfig",
    "VApp.InstanceConfig",
    "VirtualMachine.Config.AddExistingDisk",
    "VirtualMachine.Config.AddNewDisk",
    "VirtualMachine.Config.AddRemoveDevice",
    "VirtualMachine.Config.AdvancedConfig",
    "VirtualMachine.Config.CPUCount",
    "VirtualMachine.Config.Memory",
    "VirtualMachine.Config.Settings",
    "VirtualMachine.Config.Resource",
    "VirtualMachine.Config.MksControl",
    "VirtualMachine.Config.DiskExtend",
    "VirtualMachine.Config.EditDevice",
    "VirtualMachine.Config.RemoveDisk",
    "VirtualMachine.Inventory.Create",
    "VirtualMachine.Inventory.Delete",
    "VirtualMachine.Inventory.Register",
    "VirtualMachine.Inventory.Unregister",
    "VirtualMachine.Interact.DeviceConnection",
    "VirtualMachine.Interact.ToolsInstall",
    "VirtualMachine.Interact.PowerOff",
    "VirtualMachine.Interact.PowerOn",
    "VirtualMachine.Interact.Reset",
    "VirtualMachine.Provisioning.DiskRandomAccess",
    "VirtualMachine.Provisioning.FileRandomAccess",
    "VirtualMachine.Provisioning.DiskRandomRead",
    "VirtualMachine.Provisioning.DeployTemplate",
    "VirtualMachine.Provisioning.MarkAsVM"
  ]
}