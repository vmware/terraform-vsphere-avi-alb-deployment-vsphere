---
- name: Avi Cloud Services Registration
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
    controller_ip:
      ${ indent(6, yamlencode(controller_ip))}
    username: "admin"
    password: "{{ password }}"
    api_version: ${avi_version}
    ansible_become: yes
    ansible_become_password: "{{ password }}"
    name_prefix: ${name_prefix}
    registration_account_id: ${registration_account_id}
    registration_email: ${registration_email}
    registration_jwt: ${registration_jwt}
  tasks:
%{ if controller_ha ~}
    - name: Pause for 7 minutes for Cluster to form
      ansible.builtin.pause:
        minutes: 7
    
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
%{ endif ~}

    - name: Cloud Services Registration
      vmware.alb.avi_pulse_registration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        jwt_token: "{{ registration_jwt }}"
        name: "{{ name_prefix }}-cluster"
        description: "{{ name_prefix }} Cluster"
        email: "{{ registration_email }}"
        account_id: "{{ registration_account_id }}"
        optins: present
        enable_pulse_case_management: True
        case_config:
          enable_auto_case_creation_on_controller_failure: False
          enable_auto_case_creation_on_se_failure: False
        enable_pulse_waf_management: True
        waf_config:
          enable_waf_signatures_notifications: True
          enable_auto_download_waf_signatures: True
        enable_user_agent_db_sync: True
        enable_ip_reputation: True
        enable_appsignature_sync: True
      until: register_controller is not failed
      retries: 10
      delay: 10
      register: register_controller