#
define wireguard::peer (
  Array[String]     $allowedips,
  String            $iface                 = $title,
  Optional[
    Pattern[/[A-Za-z0-9+\/=]{44}/]
  ]                 $publickey             = $facts['wireguard'] ? {
    undef   => undef,
    default => $facts['wireguard'][$iface],
  },
  Optional[String]  $presharedkey          = undef,
  Optional[String]  $endpoint              = undef,
  Integer[0,65535]  $persistentkeepalive   = 0, # 0 == off
  Array[String]     $export_tags           = [],
  String            $peername              = $::fqdn,
  Optional[Boolean] $routes_depend_on_peer = true,
) {
  # the publickey is not optional despite the parameter specification
  # saying otherwise but we don't want to fail a run if it's not there
  # as it will likely be there the next time
  if $publickey {
    $template_params = {
      'publickey'           => $publickey,
      'allowedips'          => $allowedips,
      'endpoint'            => $endpoint,
      'persistentkeepalive' => $persistentkeepalive,
    }

    # [WireGuardPeer]
    $wireguardpeer = inline_epp(@(EOT), $template_params)

    [WireGuardPeer]
    <% if length($peername) > 0 { -%>
    # peer: <%= $peername %>
    <% } -%>
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
      tag     => $export_tags,
    }

    if $routes_depend_on_peer {
      # routes are only meaningful if there are multiple allowedips (Destination=)
      if length($allowedips) > 1 {
        # [Route]
        $route = inline_epp(@(EOT), $template_params)

        <% if length($peername) > 0 { -%>
        # peer: <%= $peername %>
        <% } -%>
        <% $allowedips.each |Integer $index, String $ip| {
             # skip self (first allowedips)
             if $index == 0 { next() } -%>
        [Route]
        Gateway=<%= $allowedips[0] %>
        Destination=<%= $ip %>
        <%   unless $index == $allowedips.length - 1 { -%>

        <%   } -%>
        <% } -%>
        | EOT

        @@concat::fragment{ "[Route]-${::fqdn}-${iface}":
          order   => '10',
          content => $route,
          target  => "${iface}.network",
          tag     => $export_tags,
        }
      }
    } else {
      # routes are only meaningful if there are multiple allowedips (Destination=)
      if length($allowedips) > 1 {
        # [Route]
        $route = inline_epp(@(EOT), $template_params)

        <% if length($peername) > 0 { -%>
        # peer: <%= $peername %>
        <% } -%>
        <% $allowedips.each |Integer $index, String $ip| {
             # skip self (first allowedips)
             if $index == 0 { next() } -%>
        [Route]
        Destination=<%= $ip %>
        Scope=link
        <%   unless $index == $allowedips.length - 1 { -%>

        <%   } -%>
        <% } -%>
        | EOT

        @@concat::fragment{ "[Route]-${::fqdn}-${iface}":
          order   => '10',
          content => $route,
          target  => "${iface}.network",
          tag     => $export_tags,
        }
      }
    }
  } else {
    notice("wireguard::peer: no publickey was provided nor collected from the wireguard[${iface}] fact")
  }
}
