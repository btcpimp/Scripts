#!/bin/bash
#
# Usage:
#
# This script was designed to run in-client to deploy VTR node
#

Version=0.0.1a

clear

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

set -e

# echo -e "==========  Node Update Steps  =========="
# echo -e " [x] Update Ubuntu and dependencies"
# echo -e " [x] Update Daemon 'vTorrentd' at /usr/local/bin/vTorrentd"
# echo -e "     [+] Download official compiled binary from Github"
# echo -e "     [ ] Build with latest source from Github"
# echo -e ""

system_update() {	
	echo -e "-------- Updating Ubuntu and dependencies"
	echo -e ""
	
	apt-get -y update
	apt-get -y upgrade
# 	apt-get -y dist-upgrade
	apt -y autoremove
}

download_vtorrent() {
	echo -e ""
	echo -e ""
	echo -e "-------- Downloading latest vTorrentd to /usr/local/bin/vTorrentd"
	echo -e ""
	
	bin_file=/usr/local/bin/vTorrentd
	
	if [ -e "$bin_file" ]; then
		echo -e "vTorrentd binary already exists at /usr/local/bin, replacing with latest version.."
		echo -e ""
	fi

#	Always overwrite new daemon on init
	wget -qO- https://raw.githubusercontent.com/vtorrent/official-binary/master/Ubuntu_x64/vTorrentd-Ubuntu-X64-Static.tar.gz | tar xz -C "/usr/local/bin/"
	echo -e ">> latest vTorrentd binary downloaded and successfully saved to /usr/local/bin/"
}

system_update
download_vtorrent

echo -e ""
echo -e ""
echo -e "---------- Node Update Completed ----------"
echo -e ""
echo -e ""
echo -e ""
echo -e "<b>######## You may restart the server now ########</b>"
