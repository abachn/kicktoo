isafunc() {
	local func=$1

	if [ -n "$(type ${func} 2>/dev/null | grep "function")" ]; then
		return 0
	else
		return 1
	fi
}

runstep() {
	local func=$1
	local descr=$2

	local skipfunc=$(eval $(echo echo "\${skip_${func}}"))
	if [ "${skipfunc}" != "1" ]; then
		if [ -n "${server}" ]; then
			server_send_request "update_status" "func=${func}&descr=$(echo "${descr}" | sed -e 's: :+:g')"
		fi
		if $(isafunc pre_${func}); then
			echo -e "  => pre_${func}()"
			debug runstep "executing pre-hook for ${func}"
			pre_${func}
		fi

		notify "${descr}"
		${func}

		if $(isafunc post_${func}); then
			echo -e "  => post_${func}()"
			debug runstep "executing post-hook for ${func}"
			post_${func}
		fi
	else
		debug runstep "skipping step ${func}"
	fi
}
