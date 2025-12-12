#!/bin/sh
# Copyright (C) Juewuy

[ "ts_advertise_routes" = true ] && advertise_routes='"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"'
cat >"$TMPDIR"/jsons/tailscale.json <<EOF
{
  "endpoints": [
    {
	  "type": "tailscale",
	  "tag": "ts-ep",
	  "state_directory": "/tmp/ShellCrash/tailscale",
	  "auth_key": "$ts_auth_key",
	  "hostname": "ShellCrash-ts-ep",
	  "advertise_routes": [$advertise_routes],
	  "advertise_exit_node": $ts_advertise_exit_node,
	  "udp_timeout": "5m"
    }
  ]
}
EOF
