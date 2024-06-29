#!/bin/bash
# #########################################
# Program: ParsVT CRM Repair Script
# Developer: Mohammad Hadadpour
# Release: 1402-11-28
# Update: 1403-04-09
# #########################################
set -e
shecanDNS1="178.22.122.100"
shecanDNS2="185.51.200.2"
googleDNS1="8.8.8.8"
googleDNS2="8.8.4.4"
cloudflareDNS1="1.1.1.1"
cloudflareDNS2="1.0.0.1"
Color_Off="\e[0m"
Red="\e[0;31m"
Green="\e[0;32m"
Yellow="\e[0;33m"
Blue="\e[0;34m"
Purple="\e[0;35m"
Cyan="\e[0;36m"
output() {
	echo -e "$1"
}
checkInternetConnection() {
	TIMESTAMP=$(date +%s)
	ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "\n${Green}Internet connection is UP - $(date +%Y-%m-%d_%H:%M:%S_%Z) - $(($(date +%s) - $TIMESTAMP))${Color_Off}"
		INTERNET_STATUS="UP"
	else
		echo -e "\n${Red}Internet connection is DOWN - $(date +%Y-%m-%d_%H:%M:%S_%Z) - $(($(date +%s) - $TIMESTAMP))${Color_Off}"
		INTERNET_STATUS="DOWN"
		output "Please check the server's internet connection and DNS settings and run the script again."
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	fi
}
setDNS() {
	echo -e "\nPlease enter the item number you want to use as DNS during repair:\n"
	echo -e "[${Cyan}1${Color_Off}] Shecan (recommended)"
	echo -e "[${Cyan}2${Color_Off}] Google"
	echo -e "[${Cyan}3${Color_Off}] Cloudflare"
	echo -e "[${Yellow}4${Color_Off}] Continue without changing DNS\n"
	read -p "Please select an item (1-4): " rundns
	if [ "$rundns" == "1" ]; then
		mv -n /etc/resolv.conf /etc/resolv.conf.parsvt
		echo -e "nameserver ${shecanDNS1}\nnameserver ${shecanDNS2}\n" >/etc/resolv.conf
	elif [ "$rundns" == "2" ]; then
		mv -n /etc/resolv.conf /etc/resolv.conf.parsvt
		echo -e "nameserver ${googleDNS1}\nnameserver ${googleDNS2}\n" >/etc/resolv.conf
	elif [ "$rundns" == "3" ]; then
		mv -n /etc/resolv.conf /etc/resolv.conf.parsvt
		echo -e "nameserver ${cloudflareDNS1}\nnameserver ${cloudflareDNS2}\n" >/etc/resolv.conf
	elif [ "$rundns" == "4" ]; then
		echo -e "${Green}Done!${Color_Off}"
	else
		setDNS
	fi
}
restoreDNS() {
	if [ -e /etc/resolv.conf.parsvt ]; then
		mv /etc/resolv.conf.parsvt /etc/resolv.conf
	fi
}
getPHPConfigPath() {
	PHPINI="/etc/php.ini"
	if [ ! -f "$PHPINI" ]; then
		PHPINI=$(php -r 'print php_ini_loaded_file();')
	fi
}
restartApache() {
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
		systemctl restart httpd
		set +e
		systemctl restart php-fpm
		set -e
	else
		service httpd restart
	fi
}
installIonCube() {
	cd /tmp
	rm -rf ioncube_loaders_lin*.tar.gz*
	if [ "$ARCH" = "x86_64" ]; then
		wget http://aweb.co/modules/addons/easyservice/Installer/ioncube_loaders_lin_x86-64.tar.gz -O ioncube_loaders_lin_x86-64.tar.gz
	else
		wget http://aweb.co/modules/addons/easyservice/Installer/ioncube_loaders_lin_x86.tar.gz -O ioncube_loaders_lin_x86-64.tar.gz
	fi
	tar xfz ioncube_loaders_lin_x86-64.tar.gz
	PHP_CONFD="/etc/php.d"
	PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
	if [ "$major" = "8" ] || [ "$major" = "9" ]; then
		PHP_EXT_DIR=$(php -r "echo ini_get('extension_dir');")
	else
		PHP_EXT_DIR=$(php-config --extension-dir)
	fi
	cp "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" $PHP_EXT_DIR
	echo "zend_extension = ${PHP_EXT_DIR}/ioncube_loader_lin_${PHP_VERSION}.so" >"${PHP_CONFD}/00-ioncube.ini"
	rm -rf ./ioncube
	rm -rf ioncube_loaders_lin*.tar.gz*
	cd /root
	restartApache
}
function string_replace {
	echo "${1/\/\//$2}"
}
echo -e "\n${Yellow}██████   █████  ██████  ███████ ██    ██ ████████"
echo -e "██   ██ ██   ██ ██   ██ ██      ██    ██    ██   "
echo -e "██████  ███████ ██████  ███████ ██    ██    ██   "
echo -e "██      ██   ██ ██   ██      ██  ██  ██     ██   "
echo -e "██      ██   ██ ██   ██ ███████   ████      ██   \n"
echo -e "Shell script to repair ParsVT CRM package on Linux."
echo -e "Please run as root. if you are not, enter 'n' now and enter 'sudo su' before running the script."
echo -e "Run the script? (y/n): ${Color_Off}"
read -e run
if [ "$run" == n ]; then
	output "\n${Red}The operation aborted!${Color_Off}"
	output "${Yellow}www.parsvt.com${Color_Off}\n"
	exit
else
	if [ ! -f "/var/www/html/config.inc.php" ]; then
		output "\n${Red}VtigerCRM is not installed!${Color_Off}"
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	fi
	checkInternetConnection
	restoreDNS
	if [ ! -f "/etc/redhat-release" ]; then
		output "\n${Red}Operating system is not supported!${Color_Off}"
		output "ParsVT repair script only works on CentOS and RHEL-based Linuxes."
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		if [ "$rundns" != "5" ]; then
			restoreDNS
		fi
		exit
	else
		fullname=$(cat /etc/redhat-release)
		major=$(cat /etc/redhat-release | tr -dc '0-9.' | cut -d \. -f1)
		ARCH=$(uname -m)
		output "\n${Green}${fullname} ${ARCH}${Color_Off}"
		setDNS
		output "\n${Cyan}Disabling SELinux...${Color_Off}"
		STATUS=$(getenforce)
		if [ "$STATUS" = "disabled" ] || [ "$STATUS" = "Disabled" ]; then
			output "${Green}SELinux is already disabled!${Color_Off}\n"
		else
			setenforce 0
			sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
			sed -i -e 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
			output "${Green}SELinux successfully disabled!${Color_Off}\n"
		fi
		if [ "$major" = "8" ] || [ "$major" = "9" ]; then
			if grep -rnwq "/etc/redhat-release" -e "CentOS"; then
				if ! grep -rnwq "/etc/redhat-release" -e "Stream"; then
					output "${Cyan}Converting from CentOS Linux to CentOS Stream...${Color_Off}"
					dnf --disablerepo '*' --enablerepo extras swap centos-linux-repos centos-stream-repos -y
					dnf distro-sync -y
					output "${Green}CentOS successfully converted!${Color_Off}\n"
					output "${Cyan}Updating installed packages...${Color_Off}"
					yum install dnf -y
					dnf update -y
					output "${Green}Installed packages successfully updated!${Color_Off}\n"
				else
					output "${Cyan}Updating installed packages...${Color_Off}"
					yum install dnf -y
					dnf update -y
					output "${Green}Installed packages successfully updated!${Color_Off}\n"
				fi
			else
				output "${Cyan}Updating installed packages...${Color_Off}"
				yum install dnf -y
				dnf update -y
				output "${Green}Installed packages successfully updated!${Color_Off}\n"
			fi
		elif [ "$major" = "7" ]; then
			output "${Cyan}Updating installed packages...${Color_Off}"
			yum install dnf -y
			dnf update -y
			output "${Green}Installed packages successfully updated!${Color_Off}\n"
		else
			output "${Cyan}Updating installed packages...${Color_Off}"
			yum update -y
			output "${Green}Installed packages successfully updated!${Color_Off}\n"
		fi
		output "${Cyan}Installing required packages...${Color_Off}"
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
			dnf install wget curl expect psmisc net-tools yum-utils zip unzip tar crontabs tzdata -y
		else
			yum install wget curl expect psmisc net-tools yum-utils zip unzip tar crontabs tzdata -y
		fi
		if [ "$major" = "9" ]; then
			dnf install initscripts -y
		fi
		output "${Green}required packages successfully installed!${Color_Off}\n"
		wgetfile="/usr/bin/wget"
		curlfile="/usr/bin/curl"
		if [ ! -f "$wgetfile" ] || [ ! -f "$curlfile" ]; then
			output "${Red}required packages failed to install!${Color_Off}"
			output "Please check the server's internet connection and DNS settings and run the script again."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			if [ "$rundns" != "5" ]; then
				restoreDNS
			fi
			exit
		fi
		file="/etc/ntp.conf"
		if [ ! -f "$file" ]; then
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
				output "${Cyan}Installing Chrony...${Color_Off}"
				dnf install chrony -y
				systemctl start chronyd
				systemctl enable chronyd
				output "${Green}Chrony successfully installed!${Color_Off}\n"
			else
				output "${Cyan}Installing NTP...${Color_Off}"
				yum install ntp ntpdate ntp-doc -y
				ntpdate pool.ntp.org
				systemctl start ntpd
				systemctl enable ntpd
				output "${Green}NTP successfully installed!${Color_Off}\n"
			fi
		fi
		file="/etc/yum.repos.d/remi.repo"
		if [ ! -f "$file" ]; then
			output "${Red}Remi repository is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			if [ "$rundns" != "5" ]; then
				restoreDNS
			fi
			exit
		else
			output "${Green}Remi repository is already installed!${Color_Off}\n"
		fi
		if ! command -v "php" &>/dev/null; then
			output "${Red}PHP is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			if [ "$rundns" != "5" ]; then
				restoreDNS
			fi
			exit
		else
			output "${Green}PHP is already installed!${Color_Off}\n"
			output "Checking the PHP version..."
			PHP_VER=$(php -r "if (version_compare(PHP_VERSION,'5.6.0','>')) echo 'Ok'; else echo 'Failed';")
			PHP_VERSION=$(php -r "echo PHP_VERSION;")
			if [ "$PHP_VER" = "Ok" ]; then
				cd /root
				output "Current PHP version: ${Green}${PHP_VERSION}${Color_Off}\n"
				output "Checking the ionCube loader version..."
				wget -q http://aweb.co/modules/addons/easyservice/Installer/ic.txt -O /root/IC.php
				set +e
				IONCUBE_VER=$(php -f /root/IC.php)
				IONCUBE_VERSION=$(php -r "error_reporting(0); echo ioncube_loader_version();")
				set -e
				rm -rf /root/IC.php*
				if [ "$IONCUBE_VER" = "Ok" ]; then
					output "Current ionCube loader version: ${Green}${IONCUBE_VERSION}${Color_Off}\n"
				elif [ "$IONCUBE_VER" = "Upgrade" ]; then
					output "Current ionCube loader version: ${Red}${IONCUBE_VERSION}${Color_Off}"
					output "\n${Cyan}Updating ionCube loader...${Color_Off}"
					installIonCube
					output "${Green}ionCube loader successfully updated!${Color_Off}\n"
				elif [ "$IONCUBE_VER" = "Failed" ]; then
					output "Current ionCube loader version: ${Red}${IONCUBE_VERSION}${Color_Off}"
					output "${Red}ionCube loader version must be greater than 10.0.0${Color_Off}"
					output "\n${Red}The operation aborted!${Color_Off}"
					output "${Yellow}www.parsvt.com${Color_Off}\n"
					if [ "$rundns" != "5" ]; then
						restoreDNS
					fi
					exit
				else
					output "ionCube loader is not installed!"
					output "\n${Cyan}Installing ionCube loader...${Color_Off}"
					installIonCube
					output "${Green}ionCube loader successfully installed!${Color_Off}\n"
				fi
			else
				output "Current PHP version: ${Red}${PHP_VER}${Color_Off}"
				output "${Red}PHP version must be greater than 5.5${Color_Off}"
				output "\n${Red}The operation aborted!${Color_Off}"
				output "${Yellow}www.parsvt.com${Color_Off}\n"
				if [ "$rundns" != "5" ]; then
					restoreDNS
				fi
				exit
			fi
		fi
		if ! command -v "httpd" &>/dev/null; then
			output "${Red}Apache is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			if [ "$rundns" != "5" ]; then
				restoreDNS
			fi
			exit
		else
			output "${Green}Apache is already installed!${Color_Off}\n"
		fi
		output "${Cyan}Installing timezonedb extension...${Color_Off}"
		cd /root
		mkdir -p timezonedb
		cd timezonedb
		getPHPConfigPath
		set +e
		wget http://aweb.co/modules/addons/easyservice/Installer/timezonedb-2024.1.tgz -O timezonedb-2024.1.tgz
		pear install -f timezonedb-2024.1.tgz
		if ! grep -rnwq "$PHPINI" -e "extension=timezonedb.so"; then
			echo "extension=timezonedb.so" >>"$PHPINI"
		fi
		set -e
		restartApache
		date
		hwclock
		rm -rf /root/timezonedb*
		cd /root
		output "${Green}timezonedb extension successfully installed!${Color_Off}\n"
		output "${Cyan}Setting ParsVT requirements...${Color_Off}"
		getPHPConfigPath
		sed -i -e 's/max_execution_time = 30/max_execution_time = 600/g' $PHPINI
		sed -i -e 's/memory_limit = 128M/memory_limit = 512M/g' $PHPINI
		sed -i -e 's/allow_call_time_pass_reference = Off/allow_call_time_pass_reference = On/g' $PHPINI
		sed -i -e 's/short_open_tag = Off/short_open_tag = On/g' $PHPINI
		sed -i -e 's/;max_input_vars = 1000/max_input_vars = 10000/g' $PHPINI
		sed -i -e 's/; max_input_vars = 1000/max_input_vars = 10000/g' $PHPINI
		sed -i -e 's/log_errors = On/log_errors = Off/g' $PHPINI
		sed -i -e 's/display_errors = Off/display_errors = On/g' $PHPINI
		sed -i -e 's/error_reporting = E_ALL \& ~E_DEPRECATED \& ~E_STRICT/error_reporting = E_ALL \& ~E_NOTICE \& ~E_WARNING \& ~E_DEPRECATED \& ~E_STRICT/g' $PHPINI
		sed -i -e 's/output_buffering = Off/output_buffering = 4096/g' $PHPINI
		sed -i -e 's/file_uploads = Off/file_uploads = On/g' $PHPINI
		sed -i -e 's/post_max_size = 8M/post_max_size = 128M/g' $PHPINI
		sed -i -e 's/upload_max_filesize = 2M/upload_max_filesize = 128M/g' $PHPINI
		sed -i -e 's/max_input_time = 60 /max_input_time = 600/g' $PHPINI
		sed -i -e 's/zlib.output_compression = On/zlib.output_compression = Off/g' $PHPINI
		sed -i -e 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 21600/g' $PHPINI
		sed -i -e 's/session.gc_divisor = 500/session.gc_divisor = 1000/g' $PHPINI
		sed -i -e 's/session.gc_probability = 0/session.gc_probability = 1/g' $PHPINI
		sed -i -e 's/default_socket_timeout = 60 /default_socket_timeout = 600/g' $PHPINI
		sed -i -e 's/session.use_strict_mode = 0/session.use_strict_mode = 1/g' $PHPINI
		sed -i -e 's/session.cookie_httponly =/session.cookie_httponly = 1/g' $PHPINI
		sed -i -e 's/session.cookie_secure = 1/;session.cookie_secure =/g' $PHPINI
		sed -i -e 's/expose_php = On/expose_php = Off/g' $PHPINI
		sed -i -e 's/CustomLog "logs\/access_log" combined/#CustomLog "logs\/access_log" combined/g' /etc/httpd/conf/httpd.conf
		sed -i -e 's/CustomLog logs\/ssl_request_log/#CustomLog logs\/ssl_request_log/g' /etc/httpd/conf.d/ssl.conf
		sed -i -e 's/php_admin_flag\[log_errors\] = on/;php_admin_flag\[log_errors\] = on/g' /etc/php-fpm.d/www.conf
		sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
		restartApache
		output "${Green}ParsVT requirements have been set!${Color_Off}\n"
		if type mysql >/dev/null 2>&1; then
			output "${Green}MySQL is already installed!${Color_Off}\n"
		else
			output "${Red}MySQL is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			if [ "$rundns" != "5" ]; then
				restoreDNS
			fi
			exit
		fi
		if java -version 2>&1 >/dev/null | grep -q "java version"; then
			output "${Green}Java libraries are already installed!${Color_Off}\n"
		else
			output "${Cyan}Installing Java libraries...${Color_Off}"
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
				if [ "$ARCH" = "x86_64" ]; then
					dnf install http://files.aweb.asia/JAVA/jdk-8u411-linux-x64.rpm -y
					dnf install http://files.aweb.asia/JAVA/jre-8u411-linux-x64.rpm -y
				else
					dnf install http://files.aweb.asia/JAVA/jdk-8u411-linux-i586.rpm -y
					dnf install http://files.aweb.asia/JAVA/jre-8u411-linux-i586.rpm -y
				fi
			else
				if [ "$ARCH" = "x86_64" ]; then
					yum install http://files.aweb.asia/JAVA/jdk-8u411-linux-x64.rpm -y
					yum install http://files.aweb.asia/JAVA/jre-8u411-linux-x64.rpm -y
				else
					yum install http://files.aweb.asia/JAVA/jdk-8u411-linux-i586.rpm -y
					yum install http://files.aweb.asia/JAVA/jre-8u411-linux-i586.rpm -y
				fi
			fi
			output "${Green}Java libraries successfully installed!${Color_Off}\n"
		fi
		output "${Cyan}Fixing permissions of directories and files...${Color_Off}"
		chown -R apache:apache /var/www/html
		cd /var/www/html
		find -type d -exec chmod 755 {} \;
		find -type f -exec chmod 644 {} \;
		cd /root
		output "${Green}Permissions of directories and files successfully fixed!${Color_Off}\n"
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
			output "${Cyan}Opening required firewall ports...${Color_Off}"
			systemctl enable firewalld
			systemctl restart firewalld
			firewall-cmd --zone=public --permanent --add-service=http
			firewall-cmd --zone=public --permanent --add-service=https
			firewall-cmd --zone=public --permanent --add-service=imaps
			firewall-cmd --zone=public --permanent --add-service=ssh
			firewall-cmd --zone=public --permanent --add-service=smtp
			firewall-cmd --zone=public --permanent --add-port=80/tcp
			firewall-cmd --zone=public --permanent --add-port=443/tcp
			firewall-cmd --zone=public --permanent --add-port=143/tcp
			firewall-cmd --zone=public --permanent --add-port=993/tcp
			firewall-cmd --zone=public --permanent --add-port=110/tcp
			firewall-cmd --zone=public --permanent --add-port=995/tcp
			firewall-cmd --zone=public --permanent --add-port=22/tcp
			firewall-cmd --zone=public --permanent --add-port=25/tcp
			firewall-cmd --zone=public --permanent --add-port=2525/tcp
			firewall-cmd --zone=public --permanent --add-port=587/tcp
			firewall-cmd --zone=public --permanent --add-port=465/tcp
			firewall-cmd --zone=public --permanent --add-port=3306/tcp
			firewall-cmd --zone=public --permanent --add-port=5038/tcp
			firewall-cmd --zone=public --permanent --add-port=9999/tcp
			firewall-cmd --zone=public --permanent --add-port=7777/tcp
			firewall-cmd --zone=public --permanent --add-port=2222/tcp
			firewall-cmd --zone=public --permanent --add-port=8080/tcp
			firewall-cmd --zone=public --permanent --add-port=8081/tcp
			firewall-cmd --zone=public --permanent --add-port=10000/tcp
			firewall-cmd --reload
		else
			iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 143 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 993 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 110 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 995 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 25 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 2525 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 587 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 465 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 5038 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 9999 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 7777 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 2222 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 8081 -j ACCEPT
			iptables -A INPUT -p tcp -m tcp --dport 10000 -j ACCEPT
			service iptables save
		fi
		output "${Green}Required firewall ports successfully opened!${Color_Off}"
		output "\n${Yellow} ___            __   _______              "
		output "| _ \__ _ _ _ __\ \ / /_   _|__ ___ _ __  "
		output "|  _/ _\` | '_(_-<\ V /  | |_/ _/ _ \ '  \ "
		output "|_| \__,_|_| /__/ \_/   |_(_)__\___/_|_|_|${Color_Off}\n"
		output "${Green}ParsVT repair successfully completed!${Color_Off}\n"
	fi
fi
if [ "$rundns" != "5" ]; then
	restoreDNS
fi
