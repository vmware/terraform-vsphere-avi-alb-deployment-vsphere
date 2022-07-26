---
- name: Avi Cleanup Tasks
  hosts: localhost
  connection: local
  gather_facts: no
  roles:
    - role: avinetworks.avisdk
  vars:
    avi_credentials:
        controller: "{{ controller }}"
        username: "{{ username }}"
        password: "{{ password }}"
        api_version: "{{ api_version }}"
    controller: "{{ ansible_host }}"
    username: admin
    cloud_name: "Default-Cloud"
    ansible_become: yes
    ansible_become_password: "{{ password }}"
    name_prefix: ${name_prefix}
    api_version: ${avi_version}
    tenant_name: "admin"
    registration_account_id: ${registration_account_id}
    registration_email: ${registration_email}
    registration_jwt: ${registration_jwt}
    
  tasks:
    - name: Remove all DNS Service Refs from System Configuration
      avi_api_session:
        controller: "{{ controller }}"
        username: "{{ username }}"
        password: "{{ password }}"
        http_method: patch
        path: "systemconfiguration"
        tenant: "admin"
        data:
          replace:
            dns_virtualservice_refs: ""

    - name: Get Virtual Service Information
      avi_api_session:
        controller: "{{ controller }}"
        username: "{{ username }}"
        password: "{{ password }}"
        http_method: get
        path: virtualservice
        tenant: "*"
        params:
          fields: "name,enabled,uuid,tenant_ref"
      register: vs_results

    - name: Display all Virtual Services
      ansible.builtin.debug:
        var: vs_results.obj.results

    - name: Delete all Virtual Services
      avi_api_session:
        controller: "{{ controller }}"
        username: "{{ username }}"
        password: "{{ password }}"
        http_method: delete
        path: "virtualservice/{{ item.uuid }}"
        tenant: "*"
      loop: "{{ vs_results.obj.results }}"

    - name: Get Service Engine Information
      avi_api_session:
        controller: "{{ controller }}"
        username: "{{ username }}"
        password: "{{ password }}"
        http_method: get
        path: serviceengine
        tenant: "*"
        params:
          fields: "name,enabled,uuid,cloud_ref"
      register: se_results

    - name: Display all Service Engines
      ansible.builtin.debug:
        var: se_results.obj.results

    - name: Delete all Service Engines
      avi_api_session:
        controller: "{{ controller }}"
        username: "{{ username }}"
        password: "{{ password }}"
        http_method: delete
        path: "serviceengine/{{ item.uuid }}"
      loop: "{{ se_results.obj.results }}"

%{ if register_controller ~}
    - name: Cloud Services Deregistration
      vmware.alb.avi_pulse_registration:
        avi_credentials: "{{ avi_credentials }}"
        state: absent
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
%{ endif ~}