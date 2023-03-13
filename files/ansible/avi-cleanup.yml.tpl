# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0
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
%{ if configure_gslb.enabled ~}
    controller_name: "{{ name_prefix }}-{{ configure_gslb.site_name }}-cluster"
    controller_description: "{{ name_prefix }} {{ configure_gslb.site_name }} Cluster"
%{ else ~}
    controller_name: "{{ name_prefix }}-cluster"
    controller_description: "{{ name_prefix }} Cluster"
%{ endif ~}
    username: admin
    cloud_name: "Default-Cloud"
    ansible_become: yes
    ansible_become_password: "{{ password }}"
    name_prefix: ${name_prefix}
    api_version: ${avi_version}
    tenant_name: "admin"
    register_controller:
      ${ indent(6, yamlencode(register_controller))}
    configure_gslb:
      ${ indent(6, yamlencode(configure_gslb))}
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

%{ if register_controller.enabled ~}
    - name: Cloud Services Deregistration
      vmware.alb.avi_pulse_registration:
        avi_credentials: "{{ avi_credentials }}"
        state: absent
        jwt_token: "{{ register_controller.jwt_token }}"
        name: "{{ register_controller.name | default(controller_name) }}"
        description: "{{ register_controller.description | default(controller_description) }}"
        email: "{{ register_controller.email }}"
        account_id: "{{ register_controller.organization_id }}"
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