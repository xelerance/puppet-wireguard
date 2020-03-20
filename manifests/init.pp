#
class wireguard (
  String  $ppa              = 'ppa:wireguard/wireguard',
  Boolean $force_ppa        = false,
  Boolean $restart_networkd = true,
) {
  if $force_ppa or (versioncmp($::os['release']['full'], '20.04') < 0) {
    apt::ppa { $ppa: }
    package { 'wireguard':
      require => Apt::Ppa[$ppa],
    }
  } else {
    package { 'wireguard': }
  }

  # apply systemd::network changes even if $systemd::manage_networkd is false
  if $restart_networkd and ! $systemd::manage_networkd {
    service { 'systemd-networkd': }
    Systemd::Network <| |>
    ~> Class['systemd::systemctl::daemon_reload']
    ~> Service['systemd-networkd']
  }
}
