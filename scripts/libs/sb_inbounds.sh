#!/bin/sh
# Copyright (C) Juewuy

[ "$vms_service" = ON ] && {
	[ -n "$vms_ws_path" ] && transport=', "transport": { "type": "ws", "path": "'"$vms_ws_path"'" }'
	cat >"$TMPDIR"/jsons/vmess-in.json <<EOF
{
  "inbounds": [
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $vms_port,
	  "users": [
        {
          "uuid": "$vms_uuid"
        }
      ]$transport
    }
  ]
}
EOF
}

[ "$sss_service" = ON ] && {
	cat >"$TMPDIR"/jsons/ss-in.json <<EOF
{
  "inbounds": [
	{
	  "type": "shadowsocks",
	  "tag": "ss-in",
      "listen": "::",
      "listen_port": $sss_port,
	  "method": "$sss_cipher",
	  "password": "$sss_pwd",
	}
  ]
}
EOF
}
