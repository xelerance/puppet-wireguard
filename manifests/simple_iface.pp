define wireguard::simple_iface (
  Optional[String] $interface_name = $name,
  Optional[String] $source         = undef,
  Optional[String] $content        = undef,
) {
  include wireguard

  $service_name="wg-quick@${interface_name}.service"

  file { "/etc/wireguard/${interface_name}.conf":
    content   => $content,
    source    => $source,
    mode      => '0400',
    show_diff => false,
    notify    => Service[$service_name],
  }

  service { $service_name:
    ensure => running,
    enable => true,
  }
}
