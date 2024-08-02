#
define wireguard::iface (
  Array[Stdlib::IP::Address] $addresses,
  String                     $iface        = $title,
  Optional[Integer[1,65535]] $listenport   = undef,
  Optional[Integer[1,9000]]  $mtu          = undef,
  Optional[String]           $fwmark       = undef,
  Array[String]              $collect_tags = [],
) {
  # create a key pair for $iface
  exec { "wg genkey for ${iface}":
    command  => "wg genkey > ${iface}.key && rm -f ${iface}.pub",
    provider => 'shell',
    umask    => '0077',
    cwd      => '/etc/wireguard',
    creates  => "/etc/wireguard/${iface}.key",
    require  => Class['wireguard'],
    notify   => Exec["wg pubkey for ${iface}"],
  }
  exec { "wg pubkey for ${iface}":
    command => "wg pubkey < ${iface}.key > ${iface}.pub",
    cwd     => '/etc/wireguard',
    creates => "/etc/wireguard/${iface}.pub",
    require => Exec["wg genkey for ${iface}"],
  }

  # cobble up a systemd.netdev file

  # Aggregate all the peers that belong to this tunnel
  concat { "${iface}.netdev":
    path      => "/etc/wireguard/${iface}.netdev",
    owner     => 'root',
    group     => 'systemd-network',
    mode      => '0440',
    show_diff => false,
    warn      => true,
  }

  # [NetDev]
  $netdev_template_params = {
    'iface'      => $iface,
    'listenport' => $listenport,
    'MTU'        => $mtu,
    'fwmark'     => $fwmark,
  }
  $netdev = inline_epp(@(EOT), $netdev_template_params)

  [NetDev]
  Name=<%= $iface %>
  Kind=wireguard
  | EOT
  concat::fragment{ "[NetDev]-${iface}":
    order   => '01',
    content => $netdev,
    target  => "${iface}.netdev",
  }

  # [WireGuard]
  $wireguard = inline_epp(@(EOT), { 'listenport' => $listenport, 'MTU' => $mtu, 'fwmark' => $fwmark })

  [WireGuard]
  <% if $listenport { -%>
  ListenPort=<%= $listenport %>
  <% } -%>
  <% if $fwmark { -%>
  FwMark=<%= $fwmark %>
  <% } -%>
  <% if $mtu { -%>
  MTU=<%= $mtu %>
  <% } -%>
  PrivateKey=
  |-EOT
  concat::fragment{ "[WireGuard]-${iface}":
    order   => '02',
    content => $wireguard,
    target  => "${iface}.netdev",
  }

  # [WireGuard].PrivateKey
  concat::fragment{ "[WireGuard]-${iface}-privatekey":
    order   => '03',
    source  => "file:///etc/wireguard/${iface}.key",
    require => Exec["wg pubkey for ${iface}"],
    target  => "${iface}.netdev",
  }

  # [WireGuardPeer]
  # collect all *other* peers with the tags we are interested in
  # Note: filtering *out* based on members in the tags array doesn't work
  $collect_tags.each | String $t | {
    Concat::Fragment <<| tag == 'wireguard::peer' and tag == $t and target == "${iface}.netdev" and title != "[WireGuardPeer]-${::fqdn}-${iface}" |>>
  }

  # cobble up a systemd.netdev file
  concat { "${iface}.network":
    path => "/etc/wireguard/${iface}.network",
    warn => true,
  }

  # [Network]
  $network = inline_epp(@(EOT), { iface => $iface, addresses => $addresses, })
  [Match]
  Name=<%= $iface %>

  [Network]
  <% $addresses.each |String $address| { -%>
  Address=<%= $address %>
  <% } -%>
  | EOT
  concat::fragment{ "[Network]-${iface}":
    order   => '01',
    content => $network,
    target  => "${iface}.network",
  }

  # [Route]
  # collect all *other* peers' routes with the tags we are interested in
  # Note: filtering *out* based on members in the tags array doesn't work
  $collect_tags.each | String $t | {
    Concat::Fragment <<| tag == 'wireguard::peer' and tag == $t and target == "${iface}.network" and title != "[Route]-${::fqdn}-${iface}" |>>
  }

  # systemd-networkd integration
  systemd::network { "${iface}.netdev":
    source    => "/etc/wireguard/${iface}.netdev",
    group     => 'systemd-network',
    mode      => '0440',
    show_diff => false,
    require   => Concat["${iface}.netdev"],
  }
  systemd::network { "${iface}.network":
    source  => "/etc/wireguard/${iface}.network",
    require => [Concat["${iface}.network"],Systemd::Network["${iface}.netdev"]],
  }
}
