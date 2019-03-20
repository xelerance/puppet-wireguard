#!/bin/sh
# Author: Simon Deziel

d="/etc/wireguard"
cd "$d" 2> /dev/null || exit 0

i=0
echo '{
  "wireguard": {'
for f in ./*.pub; do
  [ -r "$f" ] || continue
  iface="${f#./}"
  iface="${iface%.pub}"
  read -r p < "$f"
  echo "    \"${iface}\": \"${p}\","
  i=$((++1))
done 2> /dev/null
echo '  }
}'
