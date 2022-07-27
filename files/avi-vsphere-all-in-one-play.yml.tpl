---
- name: Avi Configuration
  hosts: localhost
  connection: local
  gather_facts: no
  roles:
    - role: avinetworks.avisdk
  vars:
    avi_credentials:
        controller: "{{ controller_ip[0] }}"
        username: "{{ username }}"
        password: "{{ password }}"
        api_version: "{{ api_version }}"
    username: "admin"
    password: "{{ password }}"
    api_version: ${avi_version}
    controller_ip:
      ${ indent(6, yamlencode(controller_ip))}
    controller_names:
      ${ indent(6, yamlencode(controller_names))}
    cloud_name: "Default-Cloud"
    vsphere_user: ${vsphere_user}
    vsphere_server: ${vsphere_server}
    vm_datacenter: ${vm_datacenter}
    use_content_lib: ${use_content_lib}
    content_lib_name: ${content_lib_name}
%{ if configure_se_mgmt_network ~}
    se_mgmt_portgroup: ${se_mgmt_portgroup}
%{ endif ~}
    dns_search_domain: ${dns_search_domain}
    ansible_become: yes
    ansible_become_password: "{{ password }}"
    name_prefix: ${name_prefix}
    vcenter_folder: ${vcenter_folder}
    se_cpu: ${se_cpu}
    se_memory: ${se_memory}
    se_disk: ${se_disk}
    se_ha_mode: ${se_ha_mode}
    controller_ha: ${controller_ha}
%{ if configure_ipam_profile ~}
    ipam_networks:
      ${ indent(6, yamlencode(ipam_networks))}
%{ endif ~}
%{ if configure_se_mgmt_network ~}
    se_mgmt_network:
      ${ indent(6, yamlencode(se_mgmt_network))}
%{ endif ~}
    dns_servers:
      ${ indent(6, yamlencode(dns_servers))}
    ntp_servers:
%{ for item in ntp_servers ~}
      - server:
          addr: "${item.addr}"
          type: ${item.type}
%{ endfor ~}  
%{ if configure_dns_profile ~}
    dns_service_domain: ${dns_service_domain}
%{ endif ~}
%{ if configure_dns_vs ~}
    dns_vs_settings: 
      ${ indent(6, yamlencode(dns_vs_settings))}
%{ endif ~}
%{ if configure_gslb ~}
    gslb_site_name: ${gslb_site_name}
    additional_gslb_sites:
      ${ indent(6, yamlencode(additional_gslb_sites))}
%{ endif ~}
  tasks:
    - name: Wait for Controller to become ready
      wait_for:
        port: 443
        timeout: 600
        sleep: 5

    - name: Configure System Configurations
      avi_systemconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        email_configuration:
          smtp_type: "SMTP_LOCAL_HOST"
          from_email: admin@avicontroller.net
        global_tenant_config:
          se_in_provider_context: true
          tenant_access_to_provider_se: true
          tenant_vrf: false
        dns_configuration:
          server_list: "{{ dns_servers }}"
          search_domain: "{{ dns_search_domain }}"
        ntp_configuration:
          ntp_servers: "{{ ntp_servers }}"
        portal_configuration:
          allow_basic_authentication: false
          disable_remote_cli_shell: false
          enable_clickjacking_protection: true
          enable_http: true
          enable_https: true
          password_strength_check: true
          redirect_to_https: true
          use_uuid_from_input: false
        welcome_workflow_complete: true

    - name: Set Backup Passphrase
      avi_backupconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        avi_api_update_method: patch
        avi_api_patch_op: add
        state: present
        name: Backup-Configuration
        backup_passphrase: "{{ password }}"
        upload_to_remote_host: false

%{ if configure_cloud ~}
    - name: Wait for connection to vCenter to become ready
      wait_for:
        host: "{{ vsphere_server }}"
        port: 443
        timeout: 600
        sleep: 5
        msg: "Can't connect to vCenter Server - {{ vsphere_server }}"

    - name: Configure Cloud
      avi_cloud:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: add
        name: "{{ cloud_name }}"
        vtype: CLOUD_VCENTER
        vcenter_configuration:
          username: "{{ vsphere_user }}"
          password: "{{ vsphere_password }}"
          vcenter_url: "{{ vsphere_server }}"
          privilege: WRITE_ACCESS
          datacenter: "{{ vm_datacenter }}"
%{ if split(".", avi_version)[0] == "22" ~}
          use_content_lib: "{{ use_content_lib }}"
%{ if use_content_lib ~}
          content_lib:
            name: "{{ content_lib_name }}"
%{ endif ~}%{ endif ~}
        dhcp_enabled: true
        license_type: "LIC_CORES"
      register: avi_cloud

    - name: Get Mangement Network UUID
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: get
        path: "vimgrnwruntime?name={{ se_mgmt_portgroup }}"
      until: mgmt_network.obj.results.0.url is defined
      retries: 5
      delay: 10
      register: mgmt_network

    - name: Update Cloud Configuration with Mgmt Network 
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: patch
        path: "cloud/{{ avi_cloud.obj.uuid }}"
        data:
          add:
            vcenter_configuration:
              management_network: "{{ mgmt_network.obj.results.0.url }}"
%{ if configure_se_mgmt_network ~}
              management_ip_subnet:
                ip_addr:
                  addr: "{{ se_mgmt_network.network | ipaddr('network') }}"
                  type: "{{ se_mgmt_network.type }}"
                mask: "{{ se_mgmt_network.network | ipaddr('prefix') }}"
    %{ if split(".", avi_version)[0] != "22" }
    - name: Wait for vCenter Discovery to complete
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: get
        path: "vimgrvcenterruntime"
      until: vcenter_discovery.obj.results.0.inventory_state == "VCENTER_DISCOVERY_COMPLETE"
      retries: 5
      delay: 10
      register: vcenter_discovery
      
    - name: Wait for Cloud Status to be ready
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: get
        path: "cloud/{{ avi_cloud.obj.uuid }}/status"
      until: cloudplacement.obj.state == "CLOUD_STATE_PLACEMENT_READY"
      retries: 60
      delay: 10
      register: cloudplacement
    %{ endif }
    - name: Update SE Mgmt Network Object with Static Pool
      avi_network:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: add
        name: ${se_mgmt_portgroup}
        dhcp_enabled: false
        configured_subnets:
          - prefix:
              ip_addr:
                addr: "{{ se_mgmt_network.network | ipaddr('network') }}"
                type: V4
              mask: "{{ se_mgmt_network.network | ipaddr('prefix') }}"
            static_ip_ranges:
            - range:
                begin:
                  addr: "{{ se_mgmt_network.static_pool.0 }}"
                  type: "{{ se_mgmt_network.type }}"
                end:
                  addr: "{{ se_mgmt_network.static_pool.1 }}"
                  type: "{{ se_mgmt_network.type }}"
              type: STATIC_IPS_FOR_VIP_AND_SE
        ip6_autocfg_enabled: false
      register: update_mgmt_network

    - name: Create Default Route in Mgmt VRF
      avi_vrfcontext:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: add
        name: "management"
        static_routes:
          - prefix:
              ip_addr:
                addr: %{if se_mgmt_network.type == "V4" ~}0.0.0.0 %{ else ~}0 %{ endif }
                type: "{{ se_mgmt_network.type }}"
              mask: 0
            next_hop:
              addr: "{{ se_mgmt_network.gateway }}"
              type: "{{ se_mgmt_network.type }}"
            route_id: 1
      register: mgmt_network_default_route
%{ endif ~} 
%{ if se_ha_mode == "active/active" ~}

    - name: Configure SE-Group
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: post
        path: "serviceenginegroup"
        tenant: "admin"
        data:
          name: "Default-Group" 
          state: present
          cloud_ref: "{{ avi_cloud.obj.url }}"
          ha_mode: HA_MODE_SHARED_PAIR
          min_scaleout_per_vs: 2
          algo: PLACEMENT_ALGO_DISTRIBUTED
          buffer_se: "0"
          max_se: "10"
          se_name_prefix: "{{ name_prefix }}"
          vcenter_folder: "{{ vcenter_folder }}"
          vcpus_per_se: "{{ se_cpu }}"
          memory_per_se: "{{ se_memory * 1024 }}"
          disk_per_se: "{{ se_disk }}"
          realtime_se_metrics:
            duration: "10080"
            enabled: true
%{ endif ~}
%{ if se_ha_mode == "n+m" ~}

    - name: Configure SE-Group
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: post
        path: "serviceenginegroup"
        tenant: "admin"
        data:
          name: "Default-Group" 
          state: present
          cloud_ref: "{{ avi_cloud.obj.url }}"
          ha_mode: HA_MODE_SHARED
          min_scaleout_per_vs: 1
          algo: PLACEMENT_ALGO_PACKED
          buffer_se: "1"
          max_se: "10"
          se_name_prefix: "{{ name_prefix }}"
          vcenter_folder: "{{ vcenter_folder }}"
          vcpus_per_se: "{{ se_cpu }}"
          memory_per_se: "{{ se_memory * 1024 }}"
          disk_per_se: "{{ se_disk }}"
          realtime_se_metrics:
            duration: "10080"
            enabled: true
%{ endif ~}
%{ if se_ha_mode == "active/standby" ~}

    - name: Configure SE-Group
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: post
        path: "serviceenginegroup"
        tenant: "admin"
        data:
          name: "Default-Group" 
          state: present
          cloud_ref: "{{ avi_cloud.obj.url }}"
          ha_mode: HA_MODE_LEGACY_ACTIVE_STANDBY
          min_scaleout_per_vs: 1
          buffer_se: "0"
          max_se: "2"
          se_name_prefix: "{{ name_prefix }}"
          vcenter_folder: "{{ vcenter_folder }}"
          vcpus_per_se: "{{ se_cpu }}"
          memory_per_se: "{{ se_memory * 1024 }}"
          disk_per_se: "{{ se_disk }}"
          realtime_se_metrics:
            duration: "10080"
            enabled: true
%{ endif ~}
%{ if configure_ipam_profile ~}

    - name: Update IPAM Network Objects with Static Pool
      avi_network:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: add
        name: "{{ item.portgroup }}"
        dhcp_enabled: false
        configured_subnets:
          - prefix:
              ip_addr:
                addr: "{{ item.network | ipaddr('network') }}"
                type: "{{ item.type }}"
              mask: "{{ item.network | ipaddr('prefix') }}"
            static_ip_ranges:
            - range:
                begin:
                  addr: "{{ item.static_pool.0 }}"
                  type: "{{ item.type }}"
                end:
                  addr: "{{ item.static_pool.1 }}"
                  type: "{{ item.type }}"
              type: STATIC_IPS_FOR_VIP_AND_SE
        ip6_autocfg_enabled: false
      loop: "{{ ipam_networks }}"
      register: ipam_net

    - name: Create list with IPAM Network URLs
      set_fact: ipam_net_urls="{{ ipam_net.results | map(attribute='obj.url') | list }}"

    - name: Create list formated for Avi IPAM profile API
      set_fact:
        ipam_list: "{{ ipam_list | default([]) + [{ 'nw_ref': item  }] }}"
      loop: "{{ ipam_net_urls }}"

    - name: Create Avi IPAM Profile
      avi_ipamdnsproviderprofile:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        name: Avi_IPAM
        type: IPAMDNS_TYPE_INTERNAL
        internal_profile:
          ttl: 30
          usable_networks: "{{ ipam_list }}"
        allocate_ip_in_vrf: false
      register: create_ipam

    - name: Update Cloud Configuration with IPAM profile 
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: patch
        path: "cloud/{{ avi_cloud.obj.uuid }}"
        data:
          add:
            ipam_provider_ref: "{{ create_ipam.obj.url }}"
%{ endif ~}
%{ if configure_dns_profile ~}

    - name: Create Avi DNS Profile
      avi_ipamdnsproviderprofile:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        name: Avi_DNS
        type: IPAMDNS_TYPE_INTERNAL_DNS
        internal_profile:
          dns_service_domain:
          - domain_name: "{{ dns_service_domain }}"
            pass_through: true
          ttl: 30
      register: create_dns

    - name: Update Cloud Configuration with DNS profile 
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: patch
        path: "cloud/{{ avi_cloud.obj.uuid }}"
        data:
          add:
            dns_provider_ref: "{{ create_dns.obj.url }}"
%{ endif ~}
%{ if configure_gslb ~}

    - name: Configure GSLB SE-Group
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: post
        path: "serviceenginegroup"
        tenant: "admin"
        data:
          name: "g-dns" 
          cloud_ref: "{{ avi_cloud.obj.url }}"
          ha_mode: HA_MODE_SHARED
          algo: PLACEMENT_ALGO_PACKED
          buffer_se: "1"
          max_se: "4"
          max_vs_per_se: "2"
          extra_shared_config_memory: 2000
          se_name_prefix: "{{ name_prefix }}"
          vcenter_folder: "{{ vcenter_folder }}"
          realtime_se_metrics:
            duration: "10080"
            enabled: true
      register: gslb_se_group
%{ endif ~}
%{ if configure_dns_vs ~}

    - name: Create DNS VSVIP
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: post
        path: "vsvip"
        tenant: "admin"
        data:
          east_west_placement: false
          cloud_ref: "{{ avi_cloud.obj.url }}"
%{ if configure_gslb ~}
          se_group_ref: "{{ gslb_se_group.obj.url }}"
%{ endif ~}
          vip:
          - enabled: true
            vip_id: 0
%{ if dns_vs_settings.auto_allocate_ip == "false" ~}
            ip_address:
              addr: "{{ dns_vs_settings.vs_ip }}"
              type: "{{ dns_vs_settings.type }}"
%{ endif ~}
            auto_allocate_ip: "{{ dns_vs_settings.auto_allocate_ip }}"
            avi_allocated_vip: false
            avi_allocated_fip: false
            auto_allocate_ip_type: V4_ONLY
            prefix_length: 32
            placement_networks: []
%{ if dns_vs_settings.auto_allocate_ip == "true" ~}
            ipam_network_subnet:
              network_ref: "/api/network/?name={{ dns_vs_settings.portgroup }}"
              subnet:
                ip_addr:
                  addr: "{{ dns_vs_settings.network | ipaddr('network') }}"
                  type: V4
                mask: "{{ dns_vs_settings.network | ipaddr('prefix') }}"
%{ endif ~}
          dns_info:
          - type: DNS_RECORD_A
            algorithm: DNS_RECORD_RESPONSE_CONSISTENT_HASH
            fqdn: "dns.{{ dns_service_domain }}"
          name: vsvip-DNS-VS-Default-Cloud
      register: vsvip_results

    - name: Display DNS VS VIP
      ansible.builtin.debug:
        var: vsvip_results

    - name: Create DNS Virtual Service
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: post
        path: "virtualservice"
        tenant: "admin"
        data:
          name: DNS-VS
          enabled: true
          analytics_policy:
            full_client_logs:
              enabled: true
              duration: 30
            metrics_realtime_update:
              enabled: true
              duration: 30
          traffic_enabled: true
          application_profile_ref: /api/applicationprofile?name=System-DNS
          network_profile_ref: /api/networkprofile?name=System-UDP-Per-Pkt
          analytics_profile_ref: /api/analyticsprofile?name=System-Analytics-Profile
          %{ if configure_gslb && create_gslb_se_group }
          se_group_ref: "{{ gslb_se_group.obj.url }}"
          %{ endif}
          cloud_ref: "{{ avi_cloud.obj.url }}"
          services:
          - port: 53
            port_range_end: 53
          - port: 53
            port_range_end: 53
            override_network_profile_ref: /api/networkprofile/?name=System-TCP-Proxy
          vsvip_ref: "{{ vsvip_results.obj.url }}"
      register: dns_vs

    - name: Add DNS-VS to System Configuration
      avi_systemconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        avi_api_update_method: patch
        avi_api_patch_op: add
        tenant: admin
        dns_virtualservice_refs: "{{ dns_vs.obj.url }}"
%{ endif ~}
%{ if configure_gslb && gslb_site_name != "" ~}

    - name: GSLB Config | Verify Cluster UUID
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: get
        path: cluster
      register: cluster

    - name: Create GSLB Config
      avi_gslb:
        avi_credentials: "{{ avi_credentials }}"
        name: "GSLB"
        sites:
          - name: "{{ gslb_site_name }}"
            username: "{{ username }}"
            password: "{{ password }}"
            ip_addresses:
              - type: "V4"
                addr: "{{ controller_ip[0] }}"
%{ if controller_ha ~}
              - type: "V4"
                addr: "{{ controller_ip[1] }}"
              - type: "V4"
                addr: "{{ controller_ip[2] }}"
%{ endif ~}
            enabled: True
            member_type: "GSLB_ACTIVE_MEMBER"
            port: 443
            dns_vses:
              - dns_vs_uuid: "{{ dns_vs.obj.uuid }}"
            cluster_uuid: "{{ cluster.obj.uuid }}"
        dns_configs:
%{ for domain in gslb_domains ~}
          - domain_name: "${domain}"
%{ endfor ~}
        leader_cluster_uuid: "{{ cluster.obj.uuid }}"
      register: gslb_results
%{ endif ~}
%{ if configure_gslb_additional_sites ~}%{ for site in additional_gslb_sites ~}

    - name: GSLB Config | Verify Remote Site is Ready
      avi_api_session:
        controller: "${site.ip_address_list[0]}"
        username: "{{ username }}"
        password: "{{ password }}"
        api_version: "{{ api_version }}"
        http_method: get
        path: virtualservice?name=DNS-VS
      until: remote_site_check is not failed
      retries: 30
      delay: 10
      register: remote_site_check

    - name: GSLB Config | Verify DNS configuration
      avi_api_session:
        controller: "${site.ip_address_list[0]}"
        username: "{{ username }}"
        password: "{{ password }}"
        api_version: "{{ api_version }}"
        http_method: get
        path: virtualservice?name=DNS-VS
      until: dns_vs_verify is not failed
      failed_when: dns_vs_verify.obj.count != 1
      retries: 30
      delay: 10
      register: dns_vs_verify

    - name: Display DNS VS Verify
      ansible.builtin.debug:
        var: dns_vs_verify

    - name: GSLB Config | Verify GSLB site configuration
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: post
        path: gslbsiteops/verify
        data:
          name: name
          username: admin
          password: "{{ password }}"
          port: 443
          ip_addresses:
            - type: "V4"
              addr: "${site.ip_address_list[0]}"
      register: gslb_verify

    - name: Display GSLB Siteops Verify
      ansible.builtin.debug:
        var: gslb_verify

    - name: Add GSLB Sites
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: patch
        path: "gslb/{{ gslb_results.obj.uuid }}"
        tenant: "admin"
        data:
          add:
            sites:
              - name: "${site.name}"
                member_type: "GSLB_ACTIVE_MEMBER"
                username: "{{ username }}"
                password: "{{ password }}"
                cluster_uuid: "{{ gslb_verify.obj.rx_uuid }}"
                ip_addresses:
%{ for address in site.ip_address_list ~}
                  - type: "V4"
                    addr: "${address}"
%{ endfor ~}
                dns_vses:
                  - dns_vs_uuid: "{{ dns_vs_verify.obj.results.0.uuid }}"
%{ endfor ~}%{ endif ~}%{ endif ~}
%{ if controller_ha ~}

    - name: Controller Cluster Configuration
      avi_cluster:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        virtual_ip:
          type: V4
          addr: "{{ controller_ip[3] }}"
        nodes:
            - name: "{{ controller_names[0] }}" 
              password: "{{ password }}"
              ip:
                type: V4
                addr: "{{ controller_ip[0] }}"
            - name: "{{ controller_names[1] }}"
              password: "{{ password }}"
              ip:
                type: V4
                addr: "{{ controller_ip[1] }}"
            - name: "{{ controller_names[2] }}"
              password: "{{ password }}"
              ip:
                type: V4
                addr: "{{ controller_ip[2] }}"
        name: "cluster01"
        tenant_uuid: "admin"
      until: cluster_config is not failed
      retries: 10
      delay: 5
      register: cluster_config
%{ endif ~}
%{ if register_controller ~}

    - name: Create Ansible collection directory
      ansible.builtin.file:
        path: /usr/share/ansible/collections
        state: directory
        mode: '0755'
        owner: admin
        group: admin

    - name: Install Avi Collection
      shell: ansible-galaxy collection install vmware.alb -p /usr/share/ansible/collections

    - name: Copy Ansible module file
      ansible.builtin.copy:
        src: /home/admin/avi_pulse_registration.py
        dest: /usr/share/ansible/collections/ansible_collections/vmware/alb/plugins/modules/avi_pulse_registration.py
    
    - name: Remove unused module file
      ansible.builtin.file:
        path: /home/admin/avi_pulse_registration.py
        state: absent

%{ if split(".", avi_version)[0] == "21" && split(".", avi_version)[2] == "4"  ~}
    - name: Patch file
      shell: patch --directory /opt/avi/python/bin/portal/api/ < /home/admin/views_albservices.patch
    
%{ endif ~}
%{ endif ~}
    - name: Remove patch file
      ansible.builtin.file:
        path: /home/admin/views_albservices.patch
        state: absent