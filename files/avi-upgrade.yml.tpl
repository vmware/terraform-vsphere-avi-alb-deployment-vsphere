# Copyright 2022 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0
---
- name: Avi Upgrade
  hosts: localhost
  connection: local
  gather_facts: no
  roles:
    - role: avinetworks.avisdk
  vars:
    upgrade_file_uri: ${avi_upgrade.upgrade_file_uri}
    upgrade_type: patch
    upgrade_file_url: "{{ upgrade_file_uri }}"
    upgrade_file_location: "{{ upgrade_file_path | default('/tmp/controller.pkg') }}"
    avi_credentials:
        controller: "{{ controller_ip[0] }}"
        username: "{{ username }}"
        password: "{{ password }}"
        api_version: "{{ api_version }}"
    controller: "{{ ansible_host }}"
    username: admin
    password: "{{ password }}"
    api_version: ${avi_version}
    cloud_name: "Default-Cloud"
    controller_ip:
      ${ indent(6, yamlencode(controller_ip))}
    ansible_become: yes
    ansible_become_password: "{{ password }}"  
  tasks:
    - name: Download Avi Update Package
      get_url:
        url: "{{ upgrade_file_url }}"
        dest: "{{ upgrade_file_location }}"
        mode: '0655'
      until: download_image is not failed
      retries: 30
      delay: 5
      register: download_image

    - name: block to upload image
      block:
      - name: Get existing image list
        avi_api_session:
          avi_credentials: "{{ avi_credentials }}"
          http_method: get
          timeout: 3000
          path: image
        register: before_image_list

      - name: upload image using api
        avi_api_image:
          avi_credentials: "{{ avi_credentials }}"
          file_path: "{{ upgrade_file_location }}"
          api_version: "{{ avi_credentials.api_version }}"
          timeout: 3000
      
      - name: Remove upgrade file
        ansible.builtin.file:
          path: "{{ upgrade_file_location }}"
          state: absent

      - name: get image list
        avi_api_session:
          avi_credentials: "{{ avi_credentials }}"       
          http_method: get
          timeout: 3000
          path: image
        register: image_list
      
      - name: Set variable for image list length
        ansible.builtin.set_fact:
          image_list_comparison: "{{ image_list.obj.results|length - before_image_list.obj.results|length  }}"
          image_index: "{{ image_list.obj.results|length - 1 | int }}"

    - name: Block to patch controller
      block:
      - name: System Upgrade
        avi_api_session:
          avi_credentials: "{{ avi_credentials }}"
          api_version: "{{ avi_credentials.api_version }}"
          http_method: post
          timeout: 300
          path: "upgrade"
          data:
            image_uuid: "{{ image_list.obj.results[image_index|int].uuid }}"
            system: true
            skip_warnings: true
        when: upgrade_type == "system"
        until: system_upgrade is not failed
        retries: 30
        delay: 5
        register: system_upgrade

      - name: Patch Upgrade
        avi_api_session:
          avi_credentials: "{{ avi_credentials }}"
          api_version: "{{ avi_credentials.api_version }}"
          http_method: post
          timeout: 300
          path: "upgrade"
          data:
            system: true
            skip_warnings: true
            controller_patch_uuid: "{{ image_list.obj.results[image_index|int].uuid }}"
            se_patch_uuid: "{{ image_list.obj.results[image_index|int].uuid }}"
        when: upgrade_type == "patch"
        until: patch_upgrade is not failed
        retries: 60
        delay: 10
        register: patch_upgrade
      when: image_list_comparison == "1"