#
define wireguard::peer (
  Array[String]    $allowedips,
  String           $iface               = $title,
  Optional[String] $publickey           = $facts['wireguard'] ? {
    undef   => undef,
    default => $facts['wireguard'][$iface],
  },
  Optional[String] $presharedkey        = undef,
  Optional[String] $endpoint            = undef,
  Integer[0,65535] $persistentkeepalive = 0, # 0 == off
  Optional[String] $tunnelgroup         = undef,
) {
  # the publickey is not optional despite the parameter specification
  # saying otherwise but we don't want to fail a run if it's not there
  # as it will likely be there the next time
  if $publickey {
    $template_params = {
      'publickey'           => $facts['wireguard'][$iface],
      'allowedips'          => $allowedips,
      'endpoint'            => $endpoint,
      'persistentkeepalive' => $persistentkeepalive,
    }

    # [WireGuardPeer]
    $wireguardpeer = inline_epp(@(EOT), $template_params)

    [WireGuardPeer]
    PublicKey=<%= $publickey %>
    <% if $presharedkey { -%>
    PresharedKey=<%= $presharedkey %>
    <% } -%>
    <% $allowedips.each |String $ip| { -%>
    AllowedIPs=<%= $ip %>
    <% } -%>
    <% if $endpoint { -%>
    Endpoint=<%= $endpoint %>
    <% } -%>
    <% if $persistentkeepalive and $persistentkeepalive > 0 { -%>
    PersistentKeepalive=<%= $persistentkeepalive %>
    <% } -%>
    | EOT

    @@concat::fragment{ "[WireGuardPeer]-${::fqdn}-${iface}":
      order   => '10',
      content => $wireguardpeer,
      target  => "${iface}.netdev",
      tag     => ['wireguard-peer', $tunnelgroup],
    }

    # [Route]
    $route = inline_epp(@(EOT), $template_params)

    [Route]
    Gateway=<%= $allowedips[0] %>
    <% $allowedips.each |Integer $index, String $ip| {
         # skip self (first allowedips)
         if $index == 0 { next() } -%>
    Destination=<%= $ip %>
    <% } -%>
    | EOT

    @@concat::fragment{ "[Route]-${::fqdn}-${iface}":
      order   => '10',
      content => $route,
      target  => "${iface}.network",
      tag     => ['wireguard-peer', $tunnelgroup],
    }
  } else {
    notice("wireguard::peer: no publickey was provided nor collected from the wireguard[${iface}] fact")
  }
}
