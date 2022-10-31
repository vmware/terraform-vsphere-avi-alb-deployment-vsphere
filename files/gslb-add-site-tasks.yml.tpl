- name: GSLB Config | Verify Remote Site is Ready
  avi_api_session:
    controller: "{{ site.ip_address_list.0 }}"
    username: "{{ gslb_user }}"
    password: "{{ password }}"
    api_version: "{{ api_version }}"
    http_method: get
    path: virtualservice?name=DNS-VS
  until: remote_site_check is not failed
  retries: 60
  delay: 10
  register: remote_site_check

- name: GSLB Config | Verify DNS configuration
  avi_api_session:
    controller: "{{ site.ip_address_list.0 }}"
    username: "{{ gslb_user }}"
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
        username: "{{ gslb_user }}"
        password: "{{ password }}"
        port: 443
        ip_addresses:
        - type: "V4"
          addr: "{{ site.ip_address_list.0 }}"
  register: gslb_verify
    
- name: Display GSLB Siteops Verify
  ansible.builtin.debug:
    var: gslb_verify

- name: Build list for gslb ip_addresses API field
  set_fact:
    gslb_ip_addresses: "{{ gslb_ip_addresses | default([]) + [{ 'type': 'V4','addr': ip }] }}"
  loop: "{{ site.ip_address_list }}"
  loop_control:
    loop_var: ip

- name: Add GSLB Sites
  avi_api_session:
    avi_credentials: "{{ avi_credentials }}"
    http_method: patch
    path: "gslb/{{ gslb_results.obj.uuid }}"
    tenant: "admin"
    data:
      add:
        sites:
          - name: "{{ site.name }}"
            member_type: "GSLB_ACTIVE_MEMBER"
            username: "{{ gslb_user }}"
            password: "{{ password }}"
            cluster_uuid: "{{ gslb_verify.obj.rx_uuid }}"
            ip_addresses: "{{ gslb_ip_addresses }}"
            dns_vses:
              - dns_vs_uuid: "{{ dns_vs_verify.obj.results.0.uuid }}"
