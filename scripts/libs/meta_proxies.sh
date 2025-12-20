#!/bin/sh
# Copyright (C) Juewuy

[ "$wg_service" = ON ] && {
	cat >>"$TMPDIR"/proxies.yaml <<EOF
  - name: "wg"
    type: wireguard
    private-key: $wg_private_key
    server: $wg_server
    port: $wg_port
    ip: $wg_ipv4
    ipv6: $wg_ipv6
    public-key: $wg_public_key
    allowed-ips: ['0.0.0.0/0', '::/0']
    pre-shared-key: $wg_pre_shared_key
    mtu: 1420
    udp: true
EOF
}
