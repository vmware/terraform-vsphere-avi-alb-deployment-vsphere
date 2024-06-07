---
- name: Avi Configuration
  hosts: localhost
  connection: local
  gather_facts: no
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
%{ if cluster_ip != null ~}
    cluster_ip:
      type: V4
      addr: ${cluster_ip}
%{ else ~}
    cluster_ip:
      type: V4
      addr: ""
%{ endif ~}
    controller_names:
      ${ indent(6, yamlencode(controller_names))}
    cloud_name: "Default-Cloud"
    license_tier: ${license_tier}
    license_key: ${license_key}
    ca_certificates:
      ${ indent(6, yamlencode(ca_certificates))}
    portal_certificate:
      ${ indent(6, yamlencode(portal_certificate))}
    securechannel_certificate:
      ${ indent(6, yamlencode(securechannel_certificate))}
    configure_nsx_cloud:
      ${ indent(6, yamlencode(configure_nsx_cloud))}
    configure_nsx_vcenter:
      ${ indent(6, yamlencode(configure_nsx_vcenter))}
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
    se_size:
      cpu: ${se_size[0]}
      memory: ${se_size[1]}
      disk: ${se_size[2]}
    se_ha_mode: ${se_ha_mode}
    controller_ha: ${controller_ha}
    configure_ipam_profile:
      ${ indent(6, yamlencode(configure_ipam_profile))}
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
    email_config:
      ${ indent(6, yamlencode(email_config))}
    configure_dns_profile:
      ${ indent(6, yamlencode(configure_dns_profile))}
    configure_dns_vs:
      ${ indent(6, yamlencode(configure_dns_vs))}
    configure_gslb:
      ${ indent(6, yamlencode(configure_gslb))}
    gslb_user: "gslb-admin"
%{ if avi_upgrade.enabled || register_controller.enabled  ~}
    avi_upgrade:
      enabled: ${avi_upgrade.enabled}
    register_controller:
      enabled: ${register_controller.enabled}
%{ endif ~}
  tasks:
    - name: Wait for Controller to become ready
      uri:
        url: "https://localhost/api/initial-data"
        validate_certs: no
        status_code: 200
      register: result
      until: result.status == 200
      retries: 300
      delay: 10

    - name: Configure System Configurations
      avi_systemconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        default_license_tier: "{{ license_tier }}"
        email_configuration: "{{ email_config }}"
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
      until: sysconfig is not failed
      retries: 30
      delay: 5
      register: sysconfig

    - name: Apply Avi License for ENTERPRISE Tier
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: put
        path: "licensing"
        data:
          serial_key: "{{ license_key }}"
      when: license_tier == "ENTERPRISE" and license_key != ""
      register: license
      ignore_errors: yes

    - name: Delete Trial Avi License when license is added successfully
      avi_api_session:
        avi_credentials: "{{ avi_credentials }}"
        http_method: delete
        path: "licensing/Eval"
      when: license_tier == "ENTERPRISE" and license_key != "" and license.failed != true
      ignore_errors: yes

    - name: Import CA SSL Certificates
      avi_sslkeyandcertificate:
        avi_credentials: "{{ avi_credentials }}"
        name: "{{ item.name }}"
        certificate_base64: true
        certificate:
          certificate: "{{ item.certificate }}"
        format: SSL_PEM
        type: SSL_CERTIFICATE_TYPE_CA
      when: ca_certificates.0.certificate != ""
      ignore_errors: yes
      loop: "{{ ca_certificates }}"

    - name: Import Portal SSL Certificate
      avi_sslkeyandcertificate:
        avi_credentials: "{{ avi_credentials }}"
        name: "{{ name_prefix }}-Portal-Cert"
        certificate_base64: true
        key_base64: true
        key: "{{ portal_certificate.key }}"
        certificate:
          certificate: "{{ portal_certificate.certificate }}"
        key_passphrase: "{{ portal_certificate.key_passphrase | default(omit) }}"
        format: SSL_PEM
        type: SSL_CERTIFICATE_TYPE_SYSTEM
      when: portal_certificate.certificate != ""
      register: portal_cert
      ignore_errors: yes

    - name: Update Portal Cert in System Configuration
      avi_systemconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: replace
        portal_configuration:
          sslkeyandcertificate_refs:
            - "/api/sslkeyandcertificate?name={{ name_prefix }}-Portal-Cert"
      when: portal_cert is changed
      ignore_errors: yes

    - name: Import Secure Channel SSL Certificate
      avi_sslkeyandcertificate:
        avi_credentials: "{{ avi_credentials }}"
        name: "{{ name_prefix }}-Secure-Channel-Cert"
        certificate_base64: true
        key_base64: true
        key: "{{ securechannel_certificate.key }}"
        certificate:
          certificate: "{{ securechannel_certificate.certificate }}"
        key_passphrase: "{{ securechannel_certificate.key_passphrase | default(omit) }}"
        format: SSL_PEM
        type: SSL_CERTIFICATE_TYPE_SYSTEM
      when: securechannel_certificate.certificate != ""
      register: securechannel_cert

    - name: Update Secure Channel Cert in System Configuration
      avi_systemconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        avi_api_update_method: patch
        avi_api_patch_op: replace
        secure_channel_configuration:
          sslkeyandcertificate_refs:
            - "/api/sslkeyandcertificate?name={{ name_prefix }}-Secure-Channel-Cert"
      when: securechannel_cert is changed

    - name: Set Backup Passphrase
      avi_backupconfiguration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        name: Backup-Configuration
        backup_passphrase: "{{ password }}"
        upload_to_remote_host: false

    - name: Wait for connection to vCenter to become ready
      wait_for:
        host: "{{ vsphere_server }}"
        port: 443
        timeout: 600
        sleep: 5
        msg: "Can't connect to vCenter Server - {{ vsphere_server }}"

    - name: Configure NSX-T Cloud
      block:
      - name: Configure NSX-T Cloud User
        avi_cloudconnectoruser:
          avi_credentials: "{{ avi_credentials }}"
          state: present
          avi_api_update_method: patch
          avi_api_patch_op: replace
          name: nsx-cloud-user
          nsxt_credentials:
            password: "{{ nsx_password }}"
            username: "{{ configure_nsx_cloud.username }}"
        register: nsx_user
      
      - name: Configure vCenter Cloud User
        avi_cloudconnectoruser:
          avi_credentials: "{{ avi_credentials }}"
          state: present
          avi_api_update_method: patch
          avi_api_patch_op: replace
          name: "{{ item.name }}"
          vcenter_credentials:
            password: "{{ vsphere_password }}"
            username: "{{ vsphere_user }}"
        register: vcenter_user
        loop: "{{ configure_nsx_vcenter }}"

      - name: Build list for vCenter Users
        set_fact:
          vcenter_user_results: "{{ vcenter_user_results | default({}) | combine({ item.obj.name: item.obj.uuid , }) }}"
        loop: "{{ vcenter_user.results }}"
        loop_control:
          loop_var: item

      - name: Get Content Library ID
        avi_api_session:
          avi_credentials: "{{ avi_credentials }}"
          http_method: post
          path: "vcenter/contentlibraries"
          data:
            credentials_uuid: "{{ vcenter_user_results[item.name] }}"
            host: "{{ item.url }}"
        loop: "{{ configure_nsx_vcenter }}"
        register: vcenter_content_libraries

      - name: Build list for content libraries
        set_fact:
          content_library_results: "{{ content_library_results | default([]) + [{ 'url': vcenter.item.url, 'content_libs': vcenter.obj.resource.vcenter_clibs , }] }}"
        loop: "{{ vcenter_content_libraries.results }}"
        loop_control:
          loop_var: vcenter
      
      - name: Build list for vCenter content libraries api field
        set_fact:
          contentlib_results: "{{ contentlib_results | default({}) | combine({ item.0.url : { item.1.name : item.1.id } }, recursive=true) }}"
        loop: "{{ content_library_results|subelements('content_libs') }}"
        loop_control:
          loop_var: item
        ignore_errors: yes
        
      - name: Build list for nsx data t1 segment config API field
        set_fact:
          nsx_data_t1_segment_config: "{{ nsx_data_t1_segment_config | default([]) + [{'segment_id': '/infra/segments/' + segment.segment_name, 'tier1_lr_id': '/infra/tier-1s/' + segment.t1_name }] }}"
        loop: "{{ configure_nsx_cloud.data_segments }}"
        loop_control:
          loop_var: segment
        ignore_errors: yes

      - name: Configure NSX-T Cloud
        avi_cloud:
          avi_credentials: "{{ avi_credentials }}"
          state: present
          avi_api_update_method: patch
          avi_api_patch_op: replace
          name: "{{ configure_nsx_cloud.cloud_name }}"
          vtype: CLOUD_NSXT
          nsxt_configuration:
            data_network_config:
              tier1_segment_config:
                manual:
                  tier1_lrs: "{{ nsx_data_t1_segment_config }}"
              transport_zone: "/infra/sites/default/enforcement-points/default/transport-zones/{{ configure_nsx_cloud.data_tz.id }}"
              tz_type: "{{ configure_nsx_cloud.data_tz.type }}"
            management_network_config:
              overlay_segment:
                segment_id: "/infra/segments/{{ configure_nsx_cloud.mgmt_segment.name }}"
                tier1_lr_id: "/infra/tier-1s/{{ configure_nsx_cloud.mgmt_segment.t1_name }}"
              transport_zone: "/infra/sites/default/enforcement-points/default/transport-zones/{{ configure_nsx_cloud.mgmt_tz.id }}"
              tz_type: "{{ configure_nsx_cloud.mgmt_tz.type }}"
            nsxt_credentials_ref: /api/cloudconnectoruser?name=nsx-cloud-user
            nsxt_url: "{{ configure_nsx_cloud.nsx_mgr_url }}"
          obj_name_prefix: "{{ name_prefix }}"
        register: nsx_cloud

      - name: Configure vCenter for NSX-T Cloud
        avi_vcenterserver:
          avi_credentials: "{{ avi_credentials }}"
          state: present
          avi_api_update_method: patch
          avi_api_patch_op: replace
          cloud_ref: "/api/cloud?name={{ configure_nsx_cloud.cloud_name }}"
          content_lib:
            id: "{{ contentlib_results[item.url][item.content_library] }}"
          name: vcenter-nsx
          vcenter_credentials_ref: "/api/cloudconnectoruser?name={{ item.name }}"
          vcenter_url: "{{ item.url }}"
        loop: "{{ configure_nsx_vcenter }}"
      - name: Set cloud_name variable to nsx cloud name
        set_fact:
          cloud_name: "{{ configure_nsx_cloud.cloud_name }}"
      when: configure_nsx_cloud.enabled == true

    - name: Configure vCenter Cloud
      block:
      - name: Configure Cloud
        avi_cloud:
          avi_credentials: "{{ avi_credentials }}"
          state: present
          avi_api_update_method: patch
          avi_api_patch_op: replace
          name: "{{ cloud_name }}"
          vtype: CLOUD_VCENTER
          vcenter_configuration:
            username: "{{ vsphere_user }}"
            password: "{{ vsphere_password }}"
            vcenter_url: "{{ vsphere_server }}"
            privilege: WRITE_ACCESS
            datacenter: "{{ vm_datacenter }}"
%{ if (split(".", avi_version)[0] == "30") || (split(".", avi_version)[0] == "22") || (split(".", avi_version)[0] == "21" && split(".", avi_version)[2] >= 6) ~}
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
        avi_cloud:
          avi_credentials: "{{ avi_credentials }}"
          avi_api_update_method: patch
          avi_api_patch_op: add
          name: "{{ cloud_name }}"
          vtype: CLOUD_VCENTER
          vcenter_configuration:
            management_network: "{{ mgmt_network.obj.results.0.url }}"
%{ if configure_se_mgmt_network ~}
            management_ip_subnet:
              ip_addr:
                addr: "{{ se_mgmt_network.network | ipaddr('network') }}"
                type: "{{ se_mgmt_network.type }}"
              mask: "{{ se_mgmt_network.network | ipaddr('prefix') }}"              
      
      - name: Wait for Cloud Status to be ready
        avi_api_session:
          avi_credentials: "{{ avi_credentials }}"
          http_method: get
          path: "cloud-inventory?name={{ cloud_name }}"
        until: cloudstatus.obj.results.0.status.state == "CLOUD_STATE_PLACEMENT_READY"
        retries: 60
        delay: 10
        register: cloudstatus

      - name: Update SE Mgmt Network Object with Static Pool
        avi_network:
          avi_credentials: "{{ avi_credentials }}"
          state: present
          avi_api_update_method: patch
          avi_api_patch_op: add
          name: "{{ se_mgmt_portgroup }}"
          cloud_ref: "/api/cloud?name={{ cloud_name }}"
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
          name: %{if configure_nsx_cloud.enabled == true ~}"{{ configure_nsx_cloud.mgmt_segment.name }}" %{ else ~}"management" %{ endif }
          cloud_ref: "/api/cloud?name={{ cloud_name }}"
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
      when: configure_nsx_cloud.enabled == false
%{ if se_ha_mode == "active/active" ~}
    - name: Configure SE-Group
      avi_serviceenginegroup:
        avi_credentials: "{{ avi_credentials }}"
        tenant: "admin"
        name: "Default-Group" 
        state: present
        cloud_ref: "/api/cloud?name={{ cloud_name }}"
        ha_mode: HA_MODE_SHARED_PAIR
        min_scaleout_per_vs: 2
        algo: PLACEMENT_ALGO_DISTRIBUTED
        buffer_se: "0"
        max_se: "10"
        se_name_prefix: "{{ name_prefix }}"
        vcenter_folder: "{{ vcenter_folder }}"
        vcpus_per_se: "{{ se_size.cpu }}"
        memory_per_se: "{{ se_size.memory * 1024 }}"
        disk_per_se: "{{ se_size.disk }}"
        cpu_reserve: true
        mem_reserve: true
        realtime_se_metrics:
          duration: "10080"
          enabled: true
%{ endif ~}
%{ if se_ha_mode == "n+m" ~}
    - name: Configure SE-Group
      avi_serviceenginegroup:
        avi_credentials: "{{ avi_credentials }}"
        tenant: "admin"
        name: "Default-Group" 
        state: present
        cloud_ref: "/api/cloud?name={{ cloud_name }}"
        ha_mode: HA_MODE_SHARED
        min_scaleout_per_vs: 1
        algo: PLACEMENT_ALGO_PACKED
        buffer_se: "1"
        max_se: "10"
        se_name_prefix: "{{ name_prefix }}"
        vcenter_folder: "{{ vcenter_folder }}"
        vcpus_per_se: "{{ se_size.cpu }}"
        memory_per_se: "{{ se_size.memory * 1024 }}"
        disk_per_se: "{{ se_size.disk }}"
        cpu_reserve: true
        mem_reserve: true
        realtime_se_metrics:
          duration: "10080"
          enabled: true
%{ endif ~}
%{ if se_ha_mode == "active/standby" ~}
    - name: Configure SE-Group
      avi_serviceenginegroup:
        avi_credentials: "{{ avi_credentials }}"
        tenant: "admin"
        name: "Default-Group" 
        state: present
        cloud_ref: "/api/cloud?name={{ cloud_name }}"
        ha_mode: HA_MODE_LEGACY_ACTIVE_STANDBY
        min_scaleout_per_vs: 1
        buffer_se: "0"
        max_se: "2"
        se_name_prefix: "{{ name_prefix }}"
        vcenter_folder: "{{ vcenter_folder }}"
        vcpus_per_se: "{{ se_size.cpu }}"
        memory_per_se: "{{ se_size.memory * 1024 }}"
        disk_per_se: "{{ se_size.disk }}"
        cpu_reserve: true
        mem_reserve: true
        realtime_se_metrics:
          duration: "10080"
          enabled: true
%{ endif ~}
    - name: Configure IPAM Profile
      block:
        - name: Update IPAM Network Objects with Static Pool
          avi_network:
            avi_credentials: "{{ avi_credentials }}"
            state: present
            avi_api_update_method: patch
            avi_api_patch_op: add
            name: "{{ item.portgroup }}"
            cloud_ref: "/api/cloud?name={{ cloud_name }}"
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
          loop: "{{ configure_ipam_profile.networks }}"
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
          avi_cloud:
            avi_credentials: "{{ avi_credentials }}"
            avi_api_update_method: patch
            avi_api_patch_op: add
            name: "{{ cloud_name }}"
            ipam_provider_ref: "{{ create_ipam.obj.url }}"
            vtype: %{if configure_nsx_cloud.enabled == true ~}"CLOUD_NSXT" %{ else ~}"CLOUD_VCENTER" %{ endif }

      when: configure_ipam_profile.enabled == true
      tags: ipam_profile

    - name: Configure DNS Profile
      block:
        - name: Build list for dns_service_domain API field
          set_fact:
            dns_service_domain: "{{ dns_service_domain | default([]) + [{'domain_name': domain, 'pass_through': 'true' }] }}"
          loop: "{{ configure_dns_profile.usable_domains }}"
          loop_control:
            loop_var: domain
          when: configure_dns_profile.type == "AVI"

        - name: Create Avi DNS Profile
          avi_ipamdnsproviderprofile:
            avi_credentials: "{{ avi_credentials }}"
            state: present
            name: "Avi_DNS"
            type: "IPAMDNS_TYPE_INTERNAL_DNS"          
            internal_profile:
              dns_service_domain: "{{ dns_service_domain }}"
              ttl: "{{ configure_dns_profile.ttl | default('30') }}"
          register: create_dns_avi
          when: configure_dns_profile.type == "AVI"

        - name: Update Cloud Configuration with DNS profile 
          avi_cloud:
            avi_credentials: "{{ avi_credentials }}"
            avi_api_update_method: patch
            avi_api_patch_op: add
            name: "{{ cloud_name }}"
            dns_provider_ref: "{{ create_dns_avi.obj.url }}"
            vtype: CLOUD_VCENTER
          when: configure_dns_profile.type == "AVI"

        - name: Create AWS Route53 DNS Profile
          avi_ipamdnsproviderprofile:
            avi_credentials: "{{ avi_credentials }}"
            state: present
            name: "AWS_R53_DNS"
            type: "IPAMDNS_TYPE_AWS_DNS"
            aws_profile:
              iam_assume_role: "{{ configure_dns_profile.aws_profile.iam_assume_role }}"
              access_key_id: "{{ configure_dns_profile.aws_profile.access_key_id }}"
              secret_access_key: "{{ configure_dns_profile.aws_profile.secret_access_key }}"
              region: "{{ configure_dns_profile.aws_profile.region }}"
              vpc_id: "{{ configure_dns_profile.aws_profile.vpc_id }}"
              usable_domains: "{{ configure_dns_profile.usable_domains }}"
              ttl: "{{ configure_dns_profile.ttl | default('30') }}"
          register: create_dns_aws
          when: configure_dns_profile.type == "AWS"
        
        - name: Update Cloud Configuration with DNS profile
          avi_cloud:
            avi_credentials: "{{ avi_credentials }}"
            avi_api_update_method: patch
            avi_api_patch_op: add
            name: "{{ cloud_name }}"
            dns_provider_ref: "{{ create_dns_aws.obj.url }}"
            vtype: CLOUD_VCENTER
          when: configure_dns_profile.type == "AWS"
      when: configure_dns_profile.enabled == true
      tags: dns_profile
      ignore_errors: yes

    - name: Configure GSLB SE Group and Account
      block:
        - name: Configure GSLB SE-Group
          avi_serviceenginegroup:
            avi_credentials: "{{ avi_credentials }}"
            tenant: "admin"
            name: "g-dns" 
            cloud_ref: "/api/cloud?name={{ cloud_name }}"
            ha_mode: HA_MODE_SHARED_PAIR
            min_scaleout_per_vs: 2
            algo: PLACEMENT_ALGO_PACKED
            buffer_se: "0"
            max_se: "4"
            max_vs_per_se: "1"
            extra_shared_config_memory: 2000
            se_name_prefix: "{{ name_prefix }}{{ configure_gslb.site_name }}"
            vcenter_folder: "{{ vcenter_folder }}"
            vcpus_per_se: "{{ configure_gslb.se_size.0 }}"
            memory_per_se: "{{ configure_gslb.se_size.1 | int * 1024 }}"
            disk_per_se: "{{ configure_gslb.se_size.2 }}"
            cpu_reserve: true
            mem_reserve: true
            realtime_se_metrics:
              duration: "60"
              enabled: true
          register: gslb_se_group
          when: configure_gslb.create_se_group == true or configure_gslb.create_se_group == "null"

        - name: Create User for GSLB
          avi_user:
            avi_credentials: "{{ avi_credentials }}"
            default_tenant_ref: "/api/tenant?name=admin"
            state: present
            name: "{{ gslb_user }}"
            access:
              - all_tenants: true
                role_ref: "/api/role?name=System-Admin"
            email: "{{ user_email | default(omit) }}"
            user_profile_ref: "/api/useraccountprofile?name=No-Lockout-User-Account-Profile"
            is_superuser: false
            obj_password: "{{ password }}"
            obj_username: "{{ gslb_user }}"
      when: configure_gslb.enabled == true
      tags: gslb

    - name: Configure DNS Virtual Service
      block:
        - name: Create DNS VSVIP
          avi_vsvip:
            avi_credentials: "{{ avi_credentials }}"
            tenant: "admin"
            cloud_ref: "/api/cloud?name={{ cloud_name }}"
%{ if configure_nsx_cloud.enabled == true ~}
            tier1_lr: "{{ nsx_data_t1_segment_config.0.tier1_lr_id }}"
            vrf_context_ref: /api/vrfcontext?name={{ configure_nsx_cloud.data_segments.0.t1_name }}
%{ endif ~}
            vip:
            - enabled: true
              vip_id: 0
%{ if configure_dns_vs.auto_allocate_ip == "false" ~}
              ip_address:
                addr: "{{ configure_dns_vs.vs_ip }}"
                type: "{{ configure_dns_vs.type }}"
%{ endif ~}
              auto_allocate_ip: "{{ configure_dns_vs.auto_allocate_ip }}"
              avi_allocated_vip: false
              avi_allocated_fip: false
              auto_allocate_ip_type: V4_ONLY
              prefix_length: 32
              placement_networks: []
%{ if configure_dns_vs.auto_allocate_ip == "true" ~}
              ipam_network_subnet:
                network_ref: "/api/network/?name={{ configure_dns_vs.portgroup }}"
                subnet:
                  ip_addr:
                    addr: "{{ configure_dns_vs.network | ipaddr('network') }}"
                    type: V4
                  mask: "{{ configure_dns_vs.network | ipaddr('prefix') }}"
%{ endif ~}
            dns_info:
            - type: DNS_RECORD_A
              algorithm: DNS_RECORD_RESPONSE_CONSISTENT_HASH
              fqdn: "dns.{{ configure_dns_profile.usable_domains.0 }}"
            name: vsvip-DNS-VS-Default-Cloud
          register: vsvip_results
          until: vsvip_results is not failed
          retries: 10

        - name: Create DNS Virtual Service
          avi_virtualservice:
            avi_credentials: "{{ avi_credentials }}"
            tenant: "admin"
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
%{ if configure_gslb.create_se_group ~}
            se_group_ref: "{{ gslb_se_group.obj.url }}"
%{ endif ~}
            cloud_ref: "/api/cloud?name={{ cloud_name }}"
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
      when: configure_dns_vs.enabled == true
      tags: configure_dns_vs

    - name: Configure GSLB
      block:
        - name: GSLB Config | Verify Cluster UUID
          avi_api_session:
            avi_credentials: "{{ avi_credentials }}"
            http_method: get
            path: cluster
          register: cluster
          
        - name: Build list for gslb ip_addresses API field
          set_fact:
            controller_ip_addresses: "{{ controller_ip_addresses | default([]) + [{ 'type': 'V4','addr': ip }] }}"
          loop: "{{ controller_ip }}"
          loop_control:
            loop_var: ip
            index_var: index
          when: index < 3

        - name: Build list for dns_configs API field
          set_fact:
            gslb_domains: "{{ gslb_domains | default([]) + [{ 'domain_name': domain }] }}"
          loop: "{{ configure_gslb.domains }}"
          loop_control:
            loop_var: domain
          ignore_errors: yes

        - name: Create GSLB Config
          avi_gslb:
            avi_credentials: "{{ avi_credentials }}"
            name: "GSLB"
            sites:
              - name: "{{ configure_gslb.site_name }}"
                username: "{{ gslb_user }}"
                password: "{{ password }}"
                ip_addresses: "{{ controller_ip_addresses }}"
                enabled: True
                member_type: "GSLB_ACTIVE_MEMBER"
                port: 443
                dns_vses:
                  - dns_vs_uuid: "{{ dns_vs.obj.uuid }}"
                cluster_uuid: "{{ cluster.obj.uuid }}"
            dns_configs: "{{ gslb_domains }}"
            leader_cluster_uuid: "{{ cluster.obj.uuid }}"
          register: gslb_results
      when: configure_gslb.enabled == true and configure_gslb.leader == true
      tags: gslb

    - name: Configure Additional GSLB Sites
      block:
      - name: Include gslb-add-site-tasks.yml in play
        include_tasks: gslb-add-site-tasks.yml
        loop: "{{ configure_gslb.additional_sites }}"
        loop_control:
          loop_var: site
      when: configure_gslb.additional_sites != "null"
      tags:
        - configure_gslb_additional_sites
        - gslb
      ignore_errors: yes

    - name: Controller Cluster Configuration
      avi_cluster:
        avi_credentials: "{{ avi_credentials }}"
        state: present
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
%{ if configure_gslb.enabled ~}
        name: "{{ name_prefix }}-{{ configure_gslb.site_name }}-cluster"
%{ else ~}
        name: "{{ name_prefix }}-cluster"
%{ endif ~}
        virtual_ip: "{{ cluster_ip if cluster_ip.addr != '' else omit }}"
        tenant_uuid: "admin"
      until: cluster_config is not failed
      retries: 10
      delay: 5
      register: cluster_config
      when: controller_ha == true
      tags: controller_ha
    
    - name: Check if Avi Collection is already installed
      stat:
        path: /home/admin/.ansible/collections/ansible_collections/vmware/alb
      register: avicollection

    - name: Add Prerequisites for avi-cloud-services-registration.yml Play
      block:
        - name: Install Avi Collection
          shell: ansible-galaxy collection install vmware.alb -p /home/admin/.ansible/collections

        - name: Copy Ansible module file
          ansible.builtin.copy:
            src: /home/admin/ansible/avi_pulse_registration.py
            dest: /home/admin/.ansible/collections/ansible_collections/vmware/alb/plugins/modules/avi_pulse_registration.py
        
        - name: Remove unused module file
          ansible.builtin.file:
            path: /home/admin/ansible/avi_pulse_registration.py
            state: absent

%{ if split(".", avi_version)[0] == "21" && split(".", avi_version)[2] == "4"  ~}
        - name: Patch file
          shell: patch --directory /opt/avi/python/bin/portal/api/ < /home/admin/ansible/views_albservices.patch
        
%{ endif ~}
      when: not avicollection.stat.exists
      tags: register_controller

    - name: Remove patch file
      ansible.builtin.file:
        path: /home/admin/ansible/views_albservices.patch
        state: absent

    - name: Remove Cert Keys
      ansible.builtin.replace:
        path: /home/admin/ansible/avi-controller-aws-all-in-one-play.yml
        regexp: '^(\s*)(\"key\":\s+)(.*)$'
        replace: '\1\2""'
      when: ca_certificates.0.certificate != "" or portal_certificate.certificate != "" or securechannel_certificate.certificate != ""

    - name: Remove Certificates
      ansible.builtin.replace:
        path: /home/admin/ansible/avi-controller-aws-all-in-one-play.yml
        regexp: '^(\s*)\s*(-\s+)?\"certificate\":\s+\".*\"$'
        replace: '\1\2"certificate": ""'
      when: ca_certificates.0.certificate != "" or portal_certificate.certificate != "" or securechannel_certificate.certificate != ""

%{ if avi_upgrade.enabled || register_controller.enabled  ~}
    - name: Verify Cluster State if avi_upgrade or register_controller plays will be ran
      block:
        - name: Pause for 8 minutes for Cluster to form
          ansible.builtin.pause:
            minutes: 8
        
        - name: Wait for Avi Cluster to be ready
          avi_api_session:
            avi_credentials: "{{ avi_credentials }}"
            http_method: get
            path: "cluster/runtime"
          until: cluster_check is not failed
          retries: 60
          delay: 10
          register: cluster_check

        - name: Wait for Avi Cluster to be ready
          avi_api_session:
            avi_credentials: "{{ avi_credentials }}"
            http_method: get
            path: "cluster/runtime"
          until: cluster_runtime.obj.cluster_state.state == "CLUSTER_UP_HA_ACTIVE"
          retries: 60
          delay: 10
          register: cluster_runtime
      when: (controller_ha == true and avi_upgrade.enabled == true) or
            (controller_ha == true and register_controller.enabled == true)
      tags: verify_cluster
%{ endif ~}