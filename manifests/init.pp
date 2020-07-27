#
class wireguard (
  Boolean $restart_networkd = true,
) {
  package { 'wireguard': }

  # apply systemd::network changes even if $systemd::manage_networkd is false
  if $restart_networkd and ! $systemd::manage_networkd {
    service { 'systemd-networkd': }
    Systemd::Network <| |>
    ~> Class['systemd::systemctl::daemon_reload']
    ~> Service['systemd-networkd']
  }
}
