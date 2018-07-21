#!/bin/bash
#
# Usage:
#
# This script was designed to run in-client to deploy VTR node
#

Version=0.0.1a

help_message="\
Options:
  -h, --help               Show this help information.
  -v, --verbose            Increase verbosity. Useful for debugging.
      --no-system-update   Skip Ubuntu and dependencies updates
      --no-swap            Skip Swapfile creation
      --no-bootstrap       Skip Bootstrap loading
      --no-monit           Skip Monit install and configure
      --build-from-source  Build from source
"

# Set variables flags
system_update=true
create_swap=true
bootstrap=true
setup_monit=true
build_from_source=false
  
parse_args() {
  # Set args from a local environment file.
  if [ -e ".env" ]; then
    source .env
  fi
	
  # Parse arg flags
  # If something is exposed as an environment variable, set/overwrite it
  # here. Otherwise, set/overwrite the internal variable instead.
  while : ; do
    if [[ $1 = "-h" || $1 = "--help" ]]; then
		echo "$help_message"
		return 0
    elif [[ $1 = "-v" || $1 = "--verbose" ]]; then
		verbose=true
		shift
    elif [[ $1 = "--no-system-update" ]]; then
		system_update=false
		shift
    elif [[ $1 = "--no-swap" ]]; then
		create_swap=false
		shift
	elif [[ $1 = "--no-bootstrap" ]]; then
		bootstrap=false
		shift
	elif [[ $1 = "--no-monit" ]]; then
		setup_monit=false
		shift
	elif [[ $1 = "--build-from-source" ]]; then
		build_from_source=true
		shift
    else
      break
    fi
  done
}

clear

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

set -e

# echo -e "==========  Node Initialise Steps  =========="
# echo -e " [x] Update Ubuntu and dependencies"
# echo -e " [x] Create Swap"
# echo -e " [x] Add user 'vtorrent'"
# echo -e " [x] Daemon 'vTorrentd' to /usr/local/bin/vTorrentd"
# echo -e "     [+] Download official compiled binary from Github"
# echo -e "     [ ] Build with latest source from Github"
# echo -e " [x] Generate vtorrent.conf to /home/vtorrent/.vtorrent/vtorrent.conf"
# echo -e " [ ] Setup Bootstrap"
# echo -e " [x] Setup Monit"
# echo -e ""

system_update() {	
	echo -e "-------- Updating Ubuntu and dependencies"
	echo -e ""
	
	apt-get -y update
	apt-get -y upgrade
# 	apt-get -y dist-upgrade
	apt -y autoremove
}

create_swap() {
	echo -e ""
	echo -e ""
	echo -e "-------- Creating Swap"
	echo -e ""
	
	if [ -e /swapfile ]; then
		echo ">> Swapfile already present, skipping.."
	else
		dd if=/dev/zero of=/swapfile bs=1M count=2048 ; mkswap /swapfile ; swapon /swapfile
		echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
		chown root:root /swapfile
		chmod 0600 /swapfile
		echo ">> Swapfile created completed.."
	fi
}

add_user() {
	echo -e ""
	echo -e ""
	echo -e "-------- Adding user 'vtorrent'"
	echo -e ""
		
	if [ id -u vtorrent >/dev/null 2>&1 ]; then
		echo -e ">> User 'vtorrent' already present, skipping.."
	else
		useradd -m -p $1 vtorrent
		[ $? -eq 0 ] && echo -e ">> User 'vtorrent' has been added to system" || echo ">> Failed to add 'vtorrent' user"
	fi
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

generate_conf() {
	echo -e ""
	echo -e ""
	echo -e "-------- Generating vtorrent.conf"
	echo -e ""
		
	cd ~vtorrent
	
	if [ -d "/home/vtorrent/.vtorrent" ]; then
		echo -e ">> Directory '.vtorrent' already present"
	else
		sudo -u vtorrent mkdir .vtorrent || &>/dev/null
	fi
	
	if [ -f "/home/vtorrent/.vtorrent/vtorrent.conf" ]; then
		echo -e ">> Configuration file 'vtorrent.conf' already present, overwriting.."
	fi

	config=".vtorrent/vtorrent.conf"
	sudo -u vtorrent touch $config
	echo "server=1" > $config
	echo "daemon=1" >> $config
	echo "maxconnections=200" >> $config
	echo "txindex=1" >> $config
	echo "disablewallet=1" >> $config
	randUser=`< /dev/urandom tr -dc A-Za-z0-9 | head -c30`
	randPass=`< /dev/urandom tr -dc A-Za-z0-9 | head -c30`
	echo "rpcuser=$randUser" >> $config
	echo "rpcpassword=$randPass" >> $config
	
	echo -e ">> /home/vtorrent/.vtorrent/vtorrent.conf"
	echo -e ""	
	echo -e "server=1"
	echo -e "daemon=1"
	echo -e "maxconnections=200"
	echo -e "txindex=1"
	echo -e "disablewallet=1"
	echo -e "rpcuser=$randUser"
	echo -e "rpcpassword=$randPass"
	
}

setup_monit() {
	echo -e ""
	echo -e ""
	echo -e "-------- Installing and configuring monit"
	echo -e ""
	
	echo -e "### Installing Monit..."
    apt-get -y install monit
	monitrc="/etc/monit/monitrc"
	echo "set httpd port 2812 and" > $monitrc
	echo "    use address localhost" >> $monitrc
	echo "    allow localhost" >> $monitrc
	echo " " >> $monitrc
	echo "set daemon 60" >> $monitrc
	echo "set logfile /var/log/monit.log" >> $monitrc
	echo " " >> $monitrc
	echo "check process vTorrentd with pidfile \"/home/vtorrent/.vtorrent/vtorrentd.pid\"" >> $monitrc
	echo "  start program \"/usr/local/bin/vTorrentd -pid=/home/vtorrent/.vtorrent/vtorrentd.pid -datadir=/home/vtorrent/.vtorrent\"" >> $monitrc
	echo "    as uid vtorrent and gid vtorrent" >> $monitrc
	echo "  stop program \"/usr/local/bin/vTorrentd -datadir=/home/vtorrent/.vtorrent stop\"" >> $monitrc
	echo "    as uid vtorrent and gid vtorrent" >> $monitrc
	echo "  if 3 restarts within 5 cycles then timeout" >> $monitrc
	echo "  if failed port 22524 for 3 cycles then restart" >> $monitrc
	monit reload
	monit start all
	/etc/init.d/monit restart
}
	
system_update
create_swap
add_user "$1"
download_vtorrent
generate_conf
setup_monit

touch ~/deploy_success

echo -e ""
echo -e ""
echo -e "---------- Node Initialised Completed ----------"
echo -e ""
echo -e " Note: Wallet disabled for running as node only"
echo -e ""
echo -e " &#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;(remove 'disablewallet=1' from 'vtorrent.conf' to re-enable wallet)"
echo -e ""
echo -e ""
echo -e "<b>######## You may restart the server now ########</b>"
echo -e ""
echo -e "<i> *** 'vtorrentd' will be automatically start and monitor by monit after restart</i>"
