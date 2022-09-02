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
    $systemd_module_name = load_module_metadata('systemd')['name']

    service { 'systemd-networkd': }
    if $systemd_module_name == 'camptocamp-systemd' {
      Systemd::Network <| |>
      ~> Class['systemd::systemctl::daemon_reload']
      ~> Service['systemd-networkd']
    } elsif $systemd_module_name == 'puppet-systemd' {
      Systemd::Network <| |>
      ~> Service['systemd-networkd']
    } else {
      fail("Unknown systemd module name '${systemd_module_name}'.")
    }
  }
}
