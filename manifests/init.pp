#
class wireguard (
  String  $ppa              = 'ppa:wireguard/wireguard',
  Boolean $restart_networkd = true,
) {
  apt::ppa { $ppa: }
  package { 'wireguard':
    require => Apt::Ppa[$ppa],
  }

  # apply systemd::network changes even if $systemd::manage_networkd is false
  if $restart_networkd and ! $systemd::manage_networkd {
    service { 'systemd-networkd': }
    Systemd::Network <| |>
    ~> Class['systemd::systemctl::daemon_reload']
    ~> Service['systemd-networkd']
  }
}
