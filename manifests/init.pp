#
class wireguard (
  Boolean $restart_networkd = true,
) {
  # avoids pulling in wireguard-dkms and nftables/iptables
  package { 'wireguard-tools':
    install_options => ['--no-install-recommends'],
  }

  # apply systemd::network changes even if $systemd::manage_networkd is false
  if $restart_networkd and ! $systemd::manage_networkd {
    service { 'systemd-networkd': }
    Systemd::Network <| |>
    ~> Class['systemd::systemctl::daemon_reload']
    ~> Service['systemd-networkd']
  }
}
