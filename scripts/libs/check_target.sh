if echo "$crashcore" | grep -q 'singbox'; then
	target=singbox
	format=json
else
	target=clash
	format=yaml
fi
core_config="$CRASHDIR/${format}s/config.$format"
