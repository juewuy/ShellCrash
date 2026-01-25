#!/bin/sh
# Copyright (C) Juewuy

echo "***********************************************"
echo "**               Welcome to                  **"
echo "**                ShellCrash                 **"
echo "**                             by  Juewuy    **"
echo "***********************************************"

language=en
[ -z "$url" ] && url="https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master"

# Internal Tools
cecho() {
    printf '%b\n' "$*"
}
dir_avail() {
    df -h >/dev/null 2>&1 && h="$2"
	df -P $h "${1:-.}" 2>/dev/null | awk 'NR==2 {print $4}'
}
ckcmd() {
    if command -v sh >/dev/null 2>&1; then
        command -v "$1" >/dev/null 2>&1
    else
        type "$1" >/dev/null 2>&1
    fi
}
webget() {
    # Parameter [$1] Download Path, [$2] Online URL
    # Parameter [$3] Display Output, [$4] Disable Redirects
    if curl --version >/dev/null 2>&1; then
        [ "$3" = "echooff" ] && progress='-s' || progress='-#'
        [ -z "$4" ] && redirect='-L' || redirect=''
        result=$(curl -w %{http_code} --connect-timeout 5 "$progress" "$redirect" -ko "$1" "$2")
        [ -n "$(echo $result | grep -e ^2)" ] && result="200"
    else
        if wget --version >/dev/null 2>&1; then
            [ "$3" = "echooff" ] && progress='-q' || progress='-q --show-progress'
            [ "$4" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
            certificate='--no-check-certificate'
            timeout='--timeout=3'
        fi
        [ "$3" = "echoon" ] && progress=''
        [ "$3" = "echooff" ] && progress='-q'
        wget "$progress" "$redirect" "$certificate" "$timeout" -O "$1" "$2"
        [ $? -eq 0 ] && result="200"
    fi
}
error_down() {
    cecho "Please refer to \033[32mhttps://github.com/juewuy/ShellCrash/blob/master/README.md"
    cecho "\033[33mUse an alternative source to reinstall!\033[0m"
}

# Installation and Initialization
set_alias() {
    while true; do
        echo "-----------------------------------------------"
        cecho "\033[36mPlease select an alias or enter a custom one:\033[0m"
        echo "-----------------------------------------------"
        cecho " 1 【\033[32mcrash\033[0m】"
        cecho " 2 【\033[32m sc \033[0m】"
        cecho " 3 【\033[32m mm \033[0m】"
        cecho " 0 Exit Installation"
        echo "-----------------------------------------------"
        read -p "Enter number or custom alias > " res
        case "$res" in
        0)
            echo "Installation cancelled"
            exit 1
            ;;
        1)
            my_alias=crash
            ;;
        2)
            my_alias=sc
            ;;
        3)
            my_alias=mm
            ;;
        *)
            my_alias=$res
            ;;
        esac
        cmd=$(ckcmd "$my_alias" | grep 'menu.sh')
        ckcmd "$my_alias" && [ -z "$cmd" ] && {
            cecho "\033[33mThis alias conflicts with a system command; please choose another!\033[0m"
            sleep 1
            continue
        }
        break
    done
}
gettar() {
    webget /tmp/ShellCrash.tar.gz "$url/ShellCrash.tar.gz" >/dev/null 2>&1
    if [ "$result" != "200" ]; then
        cecho "\033[33mFile download failed!\033[0m"
        error_down
        exit 1
    else
        "$CRASHDIR"/start.sh stop 2>/dev/null
        # Extract
        echo "-----------------------------------------------"
        echo "Starting file extraction!"
        mkdir -p "$CRASHDIR" >/dev/null
        tar -zxf '/tmp/ShellCrash.tar.gz' -C "$CRASHDIR"/ || tar -zxf '/tmp/ShellCrash.tar.gz' --no-same-owner -C "$CRASHDIR"/
        if [ -s "$CRASHDIR"/init.sh ]; then
            set_alias
            . "$CRASHDIR"/init.sh >/dev/null
            [ "$?" != 0 ] && cecho "\033[33mInitialization failed, try local installation!\033[0m" && exit 1
        else
            rm -rf /tmp/ShellCrash.tar.gz
            cecho "\033[33mFile extraction failed!\033[0m"
            error_down
            exit 1
        fi
    fi
}
set_usb_dir() {
    while true; do
        cecho "Please select installation directory"
        du -hL /mnt | awk '{print " "NR" "$2"  "$1}'
        read -p "Enter number > " num
        dir=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
        if [ -z "$dir" ]; then
            cecho "\033[31mInvalid input! Please try again!\033[0m"
            continue
        fi
        break 1
    done
}
set_xiaomi_dir() {
	cecho "\033[33mXiaomi device detected, please select installation location\033[0m"
	[ -d /data ] && cecho " 1 Install to /data, Free space: $(dir_avail /data -h) (Supports soft-hardening)"
	[ -d /userdisk ] && cecho " 2 Install to /userdisk, Free space: $(dir_avail /userdisk -h) (Supports soft-hardening)"
	[ -d /data/other_vol ] && cecho " 3 Install to /data/other_vol, Free space: $(dir_avail /data/other_vol -h) (Supports soft-hardening)"
	cecho " 4 Custom directory (Not recommended for beginners!)"
	cecho " 0 Exit"
	echo "-----------------------------------------------"
	read -p "Enter number > " num
	case "$num" in
	1)
		dir=/data
		;;
	2)
		dir=/userdisk
		;;
	3)
		dir=/data/other_vol
		;;
	4)
		set_cust_dir
		;;
	*)
		exit 1
		;;
	esac
}
set_asus_usb() {
	while true; do
		echo -e "Please select USB directory"
		du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print " "NR" "$2"  "$1}'
		read -p "Enter number > " num
		dir=$(du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print $2}' | sed -n "$num"p)
		if [ ! -f "$dir/asusware.arm/etc/init.d/S50downloadmaster" ]; then
			echo -e "\033[31mDownload Master startup file not found: $dir/asusware.arm/etc/init.d/S50downloadmaster. Check settings!\033[0m"
			sleep 1
		else
			break
		fi
	done
}
set_asus_dir() {
	cecho "\033[33mAsus firmware detected, please select installation method\033[0m"
	cecho " 1 Via USB + Download Master (Supports all firmware, ARM only, USB required)"
	cecho " 2 Via startup script (Merlin firmware only)"
	cecho " 0 Exit"
	echo "-----------------------------------------------"
	read -p "Enter number > " num
	case "$num" in
	1)
		echo -e "Please install and enable Download Master in the router web UI first, then select the storage directory!"
		sleep 2
		set_asus_usb
	;;
	2)
		cecho "If auto-start fails after reboot, please use USB + Download Master method instead!"
		sleep 2
		dir=/jffs
	;;
	*)
		exit 1
	;;
	esac
}
set_cust_dir() {
    while true; do
        echo "-----------------------------------------------"
        echo 'Path | Free Space:'
        df -h | awk '{print $6,$4}' | sed 1d
        echo 'Path must start with "/". Files in virtual memory (/tmp, /opt, /sys...) will be lost on reboot!!!'
        read -p "Enter custom path > " dir
        if [ "$(dir_avail "$dir")" = 0 ] || [ -n "$(echo "$dir" | grep -Eq '^/(tmp|opt|sys)(/|$)')" ]; then
            cecho "\033[31mInvalid path! Please try again!\033[0m"
            continue
        fi
        break 1
    done
}

setdir() {
    while true; do
        echo "-----------------------------------------------"
        cecho "\033[33mNote: ShellCrash requires at least 1MB of disk space\033[0m"
        case "$systype" in
			Padavan) dir=/etc/storage ;;
			mi_snapshot) set_xiaomi_dir ;;
			asusrouter) set_asus_dir ;;
			ng_snapshot) dir=/tmp/mnt ;;
			*)
				cecho " 1 Install in \033[32m/etc\033[0m (Best for root users)"
				cecho " 2 Install in \033[32m/usr/share\033[0m (Standard Linux systems)"
				cecho " 3 Install in \033[32mUser Directory\033[0m (Best for non-root users)"
				cecho " 4 Install on \033[32mExternal Storage\033[0m"
				cecho " 5 Manual path entry"
				cecho " 0 Exit"
				echo "----------------------------------------------"
				read -p "Enter number > " num
				# Set Dir
				case "$num" in
				1)
					dir=/etc
					;;
				2)
					dir=/usr/share
					;;
				3)
					dir=~/.local/share
					mkdir -p ~/.config/systemd/user
					;;
				4)
					set_usb_dir
					;;
				5)
					set_cust_dir
					;;
				*)
					echo "Installation cancelled"
					exit 1
					;;
				esac
			;;
		esac

        if [ ! -w "$dir" ]; then
            cecho "\033[31mNo write permission for $dir! Please reset!\033[0m"
            sleep 1
        else
            cecho "Target directory: \033[32m$dir\033[0m | Free space: $(dir_avail "$dir" -h)"
            read -p "Confirm installation? (1/0) > " res
            if [ "$res" = "1" ]; then
                CRASHDIR="$dir"/ShellCrash
                break
            fi
        fi
    done
}
install() {
    echo "-----------------------------------------------"
    echo "Retrieving installation files from server..."
    echo "-----------------------------------------------"
    gettar
    echo "-----------------------------------------------"
    echo "ShellCrash installed successfully!"
    [ "$profile" = "~/.bashrc" ] && echo "Please run [. ~/.bashrc > /dev/null] to update environment variables!"
    [ -n "$(ls -l /bin/sh | grep -oE 'zsh')" ] && echo "Please run [. ~/.zshrc > /dev/null] to update environment variables!"
    echo "-----------------------------------------------"
    cecho "\033[33mType \033[30;47m $my_alias \033[0;33m to start management dashboard!!!\033[0m"
    echo "-----------------------------------------------"
}
setversion() {
    echo "-----------------------------------------------"
    cecho "\033[33mSelect version to install:\033[0m"
    cecho " 1 \033[32mBeta (Recommended)\033[0m"
    cecho " 2 \033[36mStable\033[0m"
    cecho " 3 \033[31mDev (Unstable)\033[0m"
    echo "-----------------------------------------------"
    read -p "Enter number > " num
    case "$num" in
	1) release_type=master ;;
    2) release_type=stable ;;
    3) release_type=dev ;;
    *) ;;
    esac
	url=$(echo "$url" | sed "s/master/$release_type/")
}

# Pre-Install Checks
check_systype() {
	[ -f "/etc/storage/started_script.sh" ] && {
		systype=Padavan # Padavan Firmware
		initdir='/etc/storage/started_script.sh'
	}
	[ -d "/jffs" ] && {
		systype=asusrouter # Asus Firmware
		[ -f "/jffs/.asusrouter" ] && initdir='/jffs/.asusrouter'
		[ -d "/jffs/scripts" ] && initdir='/jffs/scripts/nat-start'
	}
	[ -f "/data/etc/crontabs/root" ] && systype=mi_snapshot # Xiaomi device
	[ -w "/var/mnt/cfg/firewall" ] && systype=ng_snapshot   # NETGEAR device
}
check_user() {
	if [ "$USER" != "root" ] && [ -z "$systype" ]; then
		echo "Current User: $USER"
		cecho "\033[31mPlease use the root user (do not use sudo directly!) to install!\033[0m"
		echo "-----------------------------------------------"
		read -p "Install anyway? Unknown errors may occur! (1/0) > " res
		[ "$res" != "1" ] && exit 1
	fi
}
check_version() {
	echo "$url" | grep -q 'master' && setversion
	webget /tmp/version "$url/version" echooff
	[ "$result" = "200" ] && versionsh=$(cat /tmp/version)
	rm -rf /tmp/version

	# Output
	cecho "Latest Version: \033[32m$versionsh\033[0m"
	echo "-----------------------------------------------"
	cecho "\033[44mFor issues, please join the TG group: \033[42;30m t.me/ShellClash \033[0m"
	cecho "\033[37mSupports various OpenWrt-based router devices"
	cecho "\033[33mSupports Debian, Centos and standard Linux systems\033[0m"
}
check_dir() {
	if [ -n "$CRASHDIR" ]; then
		echo "-----------------------------------------------"
		cecho "Old installation detected at \033[36m$CRASHDIR\033[0m. Overwrite?"
		cecho "\033[32mConfiguration files will NOT be removed during overwrite!\033[0m"
		echo " 1 Overwrite Installation"
		echo " 2 Uninstall old version and reinstall"
		echo " 0 Cancel"
		read -p "Enter number > " num
		case "$num" in
		1)
			install
			;;
		2)
			[ "$CRASHDIR" != "/" ] && rm -rf "$CRASHDIR"
			echo "-----------------------------------------------"
			cecho "\033[31mOld version uninstalled!\033[0m"
			setdir
			install
			;;
		9)
			echo "Test Mode: Changing installation path $CRASHDIR"
			setdir
			install
			;;
		*)
			cecho "\033[31mInstallation cancelled!\033[0m"
			exit 1
			;;
		esac
	else
		setdir
		install
	fi
}

check_systype
check_user
check_version
check_dir
