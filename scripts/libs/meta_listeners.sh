#!/bin/sh
# Copyright (C) Juewuy

#meta内核vmess入站生成
[ "$vms_service" = ON ] && {
	cat >>"$TMPDIR"/yamls/listeners.yaml <<EOF
- name: "vmess-in"
  type: vmess
  port: $vms_port
  listen: 0.0.0.0
  uuid: $vms_uuid
  ws-path: $vms_ws_path
EOF
}
#meta内核ss入站生成
[ "$sss_service" = ON ] && {
	cat >>"$TMPDIR"/yamls/listeners.yaml <<EOF
- name: "ss-in"
  port: $sss_port
  listen: 0.0.0.0
  cipher: $sss_cipher
  password: $sss_pwd
  udp: true
EOF
}