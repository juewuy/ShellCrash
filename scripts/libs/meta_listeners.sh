#!/bin/sh
# Copyright (C) Juewuy

#meta内核vmess入站生成
[ "$vms_service" = ON ] && {
	cat >>"$TMPDIR"/listeners.yaml <<EOF
  - name: "vmess-in"
    type: vmess
    port: $vms_port
    listen:
    users:
      - uuid: $vms_uuid
        alterId: 0
    ws-path: $vms_ws_path
EOF
}
#meta内核ss入站生成
[ "$sss_service" = ON ] && {
	cat >>"$TMPDIR"/listeners.yaml <<EOF
  - name: "ss-in"
    type: shadowsocks
    port: $sss_port
    listen:
    cipher: $sss_cipher
    password: $sss_pwd
    udp: true
EOF
}