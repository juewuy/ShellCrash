#!/bin/sh
# Copyright (C) Juewuy

[ "$ts_service" = ON ] && {
	[ "$ts_subnet" = true ] && {
		. "$CRASHDIR"/starts/fw_getlanip.sh && getlanip
		advertise_routes=$(echo "$host_ipv4"|sed 's/[[:space:]]\+/", "/g; s/^/"/; s/$/"/')
	}
	[ -z "$ts_exit_node" ] && ts_exit_node=false
	[ -z "$ts_hostname" ] && ts_hostname='ShellCrash'
	cat >"$TMPDIR"/jsons/tailscale.json <<EOF
{
  "endpoints": [
    {
	  "type": "tailscale",
	  "tag": "ts-ep",
	  "state_directory": "$CRASHDIR/tailscale",
	  "auth_key": "$ts_auth_key",
	  "hostname": "$ts_hostname",
	  "advertise_routes": [$advertise_routes],
	  "advertise_exit_node": $ts_exit_node,
	  "udp_timeout": "5m"
    }
  ]
}
EOF
}

[ "$wg_service" = ON ] && {
	[ -n "$wg_ipv6" ] && wg_ipv6_add=", \"$wg_ipv6\""
	cat >"$TMPDIR"/jsons/wireguard.json <<EOF
{
  "endpoints": [
	{
	  "type": "wireguard",
	  "tag": "wg-ep",
	  "system": true,
	  "mtu": 1420,
	  "address": [ "$wg_ipv4"$wg_ipv6_add ],
	  "private_key": "$wg_private_key",
	  "peers": [
		{
		  "address": "$wg_server",
		  "port": $wg_port,
		  "public_key": "$wg_public_key",
		  "pre_shared_key": "$wg_pre_shared_key",
		  "allowed_ips": ["0.0.0.0/0", "::/0"]
		}
	  ]
	}
  ]
}
EOF
}
