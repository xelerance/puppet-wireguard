#
class wireguard (
  String $ppa = 'ppa:wireguard/wireguard',
) {
  apt::ppa { $ppa: }
  package { 'wireguard':
    require => Apt::Ppa[$ppa],
  }
}
