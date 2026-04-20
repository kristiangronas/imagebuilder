#cloud-config
%{~ if modern_network_manager ~}

bootcmd:
  - cloud-init-per once mkdir -p /etc/NetworkManager/conf.d
  # we need networkmanager to send dhcp releases before we can change the client-id format
  - | cloud-init-per once cat <<-EOR >> /etc/NetworkManager/conf.d/41-cloud-init-send-release.conf
      [connection]
      ipv6.dhcp-send-release = 1
      EOR
  - "cloud-init-per once systemctl is-active NetworkManager && nmcli general reload || true"
%{~ endif ~}
%{~ if modern_systemd_networkd || modern_network_manager ~}

write_files:
  %{~ if modern_network_manager ~}
  - path: /etc/NetworkManager/conf.d/41-cloud-init-ip6-duid-mode.conf
    content: |
      [connection]
      ipv6.dhcp-duid=ll
      ipv6.dhcp-iaid=0
  %{~ endif ~}
  %{~ if modern_systemd_networkd ~}
  - path: /etc/systemd/network/10-netplan-local_if.network.d/41-cloud-init-ip6-duid-mode.conf
    content: |
      [DHCPv6]
      DUIDType=link-layer
      IAID=0
  %{~ endif ~}

runcmd:
  %{~ if modern_systemd_networkd ~}
  # restarting systemd-networkd is less destructive in e.g. debian 13, so we need to stop and start it to make it send dhcp release
  - "systemctl is-active systemd-networkd && systemctl stop systemd-networkd && systemctl start systemd-networkd || true"
  %{~ endif ~}
  %{~ if modern_network_manager ~}
  - "systemctl is-active NetworkManager && systemctl restart NetworkManager || true"
  %{~ endif ~}

%{~ endif ~}
%{~ if var.platform == "debian" || var.platform == "ubuntu" ~}
networks:
  %{~ if var.platform == "debian" && contains([11], var.major) ~}
  version: 1
  config:
  - type: physical
    name: enp3s0
    subnets:
      - type: dhcp
      - type: dhcp6
  %{~ endif ~}
  %{~ if (var.platform == "debian" && contains(["12", "13"], var.major)) || (var.platform == "ubuntu" && contains(recent_ubuntu, var.major)) ~}
  version: 2
  ethernets:
    # opaque ID for physical interfaces, only referred to by other stanzas
    local_if:
      match:
        name: e* # Important: this does not work with NetworkManager
      accept-ra: true
      dhcp6: true
      dhcp4: true
  %{~ endif ~}
%{~ endif }
