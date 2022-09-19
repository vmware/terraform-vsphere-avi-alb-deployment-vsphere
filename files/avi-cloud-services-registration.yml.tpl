# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0
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
    register_controller:
      ${ indent(6, yamlencode(register_controller))}
%{ if configure_gslb || create_gslb_se_group ~}
    gslb_site_name: ${gslb_site_name}
%{ endif ~}
  tasks:
    - name: Cloud Services Registration
      vmware.alb.avi_pulse_registration:
        avi_credentials: "{{ avi_credentials }}"
        state: present
        jwt_token: "{{ register_controller.jwt_token }}"
%{ if configure_gslb || create_gslb_se_group ~}
        name: "{{ name_prefix }}-{{ gslb_site_name }}-cluster"
        description: "{{ name_prefix }} {{ gslb_site_name }} Cluster"
%{ else ~}
        name: "{{ name_prefix }}-cluster"
        description: "{{ name_prefix }} Cluster"
%{ endif ~}
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
      until: register_controller is not failed
      retries: 10
      delay: 10
      register: register_controller