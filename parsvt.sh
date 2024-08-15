#!/bin/bash
# #########################################
# Program: ParsVT CRM Installation Script
# Developer: Hamid Rabiei, Mohammad Hadadpour
# Release: 1397-12-10
# Update: 1403-05-25
# #########################################
set -e
shecanDNS1="178.22.122.101"
shecanDNS2="185.51.200.1"
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
primarySite="aweb.co"
secondarySite="files.aweb.asia"
ETH_DEV="127.0.0.1"
IP=$(ifconfig eth0 2>/dev/null | awk '/inet addr:/ {print $2}' | sed 's/addr://')
INSTALLTYPE="Fresh"
DBHOST="localhost"
DBUSER="root"
DBNAME="parsvt"
SETUPDIR="/var/www/html/"
SETUPDIR2="/var/www/html"
backupdirectory="/home/backup"
counter=0
LICENSEKEY=""
app_dir=""
adminPWD="123456789"
mysqlPWD="123456789"
INTERNET_STATUS="DOWN"
output() {
	echo -e "$1"
}
checkInternetConnection() {
	TIMESTAMP=$(date +%s)
	set +e
	ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1
	set -e
	if [ $(($(date +%s) - $TIMESTAMP)) -eq 0 ]; then
		echo -e "\n${Green}Internet connection is UP - $(date +%Y-%m-%d_%H:%M:%S_%Z) - $(($(date +%s) - $TIMESTAMP))${Color_Off}"
		INTERNET_STATUS="UP"
	else
		echo -e "\n${Red}Internet connection is DOWN - $(date +%Y-%m-%d_%H:%M:%S_%Z) - $(($(date +%s) - $TIMESTAMP))${Color_Off}"
		INTERNET_STATUS="DOWN"
		output "Please check the server's internet connection and DNS settings and run the installer again."
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	fi
}
setDNS() {
	echo -e "\nPlease enter the item number you want to use as DNS during installation:\n"
	echo -e "[${Cyan}1${Color_Off}] Shecan Pro (recommended)"
	echo -e "[${Cyan}2${Color_Off}] Google"
	echo -e "[${Cyan}3${Color_Off}] Cloudflare"
	echo -e "[${Yellow}4${Color_Off}] Continue without changing DNS\n"
	read -p "Please select an item (1-4): " rundns
	if [ "$rundns" == "1" ]; then
		shecanURI=$(echo -n "${RESPONSES[3]}" | base64 --decode)
		curl -s -o /dev/null "${shecanURI}"
		mv -n /etc/resolv.conf /etc/resolv.conf.parsvt
		echo -e "nameserver ${shecanDNS1}\nnameserver ${shecanDNS2}\n" >/etc/resolv.conf
		curl -s -o /dev/null "${shecanURI}"
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
getLicense() {
	read -p "Please enter your ParsVT CRM license key: " LICENSEKEY
	LICENSEKEY=${LICENSEKEY//[[:blank:]]/}
}
precheckLicense() {
	chrlen=${#LICENSEKEY}
	if [[ $chrlen -ne 26 ]] && [[ $chrlen -ne 25 ]]; then
		echo -e "${Red}The license key is invalid!${Color_Off}"
		checkLicense
	fi
	if [[ ${LICENSEKEY:0:6} != \ParsVT ]] && [[ ${LICENSEKEY:0:5} != \Cloud ]]; then
		echo -e "${Red}The license key is invalid!${Color_Off}"
		checkLicense
	fi
}
checkLicense() {
	if [[ $counter -gt 3 ]]; then
		echo -e "\n${Red}The number of incorrect entries exceeded!${Color_Off}"
		echo -e "\n${Red}The operation aborted!${Color_Off}"
		echo -e "${Yellow}www.parsvt.com${Color_Off}\n"
		if [ "$rundns" != "5" ]; then
			restoreDNS
		fi
		exit
	fi
	counter=$((counter + 1))
	getLicense
	precheckLicense
}
setAdminPassword() {
	adminPWD=$(date +%s | sha256sum | base64 | head -c 32)
	adminPWD=${adminPWD:0:15}
	mysqlPWD=$(php -r "echo crypt('$adminPWD', 'ad');")
}
removeMySQL() {
	MYSQLFOLDER="/var/lib/mysql"
	if [ -f "$MYSQLFOLDER" ]; then
		dt=$(date '+%d-%m-%Y_%H-%M-%S')
		mv /var/lib/mysql /var/lib/old_backup_mysql_"$dt"
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
		systemctl restart php-fpm
	else
		service httpd restart
	fi
}
restartDatabase() {
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
		systemctl restart mariadb
	else
		service mariadb restart
	fi
}
installIonCube() {
	cd /tmp
	rm -rf ioncube_loaders_lin*.tar.gz*
	if [ "$ARCH" = "x86_64" ]; then
		wget http://$primarySite/modules/addons/easyservice/Installer/ioncube_loaders_lin_x86-64.tar.gz -O ioncube_loaders_lin_x86-64.tar.gz
	else
		wget http://$primarySite/modules/addons/easyservice/Installer/ioncube_loaders_lin_x86.tar.gz -O ioncube_loaders_lin_x86-64.tar.gz
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
mysqlConnection() {
	read -p "Enter your MySQL hostname (default: $(tput bold)localhost$(tput sgr0)): " mysql_db_host
	DBHOST="${mysql_db_host:=localhost}"
	read -p "Enter your MySQL username (default: $(tput bold)root$(tput sgr0)): " mysql_root_name
	DBUSER="${mysql_root_name:=root}"
	read -p "Enter your MySQL password: " DBPassword
	read -p "Enter your new MySQL database (default: $(tput bold)parsvt$(tput sgr0)): " mysql_db_name
	DBNAME="${mysql_db_name:=parsvt}"
	COMMAND="error_reporting(0); \$conn = new mysqli(\""$DBHOST"\", \""$DBUSER"\", \""$DBPassword"\"); if (\$conn->connect_error) { die(\"Connection failed: \" . \$conn->connect_error);} die(\"Connected\");"
	mysqlresult=$(php -r "$COMMAND")
	if [ "$mysqlresult" = "Connected" ]; then
		output "${Green}Connection successfully established!${Color_Off}\n"
		output "Database information:"
		output "Database hostname: ${Yellow}${DBHOST}${Color_Off}"
		output "Database username: ${Yellow}${DBUSER}${Color_Off}"
		output "Database password: ${Yellow}${DBPassword}${Color_Off}"
		output "Database name: ${Yellow}${DBNAME}${Color_Off}\n"
		output "Setting up your new database..."
		mysql -h ${DBHOST} -u ${DBUSER} -p${DBPassword} --default-character-set=utf8mb4 --silent -e "CREATE DATABASE IF NOT EXISTS ${DBNAME} CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';"
		output "${Green}Database successfully created!${Color_Off}\n"
	else
		output "${Red}$mysqlresult${Color_Off}"
		mysqlConnection
	fi
}
function string_replace {
	echo "${1/\/\//$2}"
}
echo -e "\n${Yellow}██████   █████  ██████  ███████ ██    ██ ████████"
echo -e "██   ██ ██   ██ ██   ██ ██      ██    ██    ██   "
echo -e "██████  ███████ ██████  ███████ ██    ██    ██   "
echo -e "██      ██   ██ ██   ██      ██  ██  ██     ██   "
echo -e "██      ██   ██ ██   ██ ███████   ████      ██   \n"
echo -e "Shell script to install Apache, PHP, MySQL, VtigerCRM and ParsVT package on Linux."
echo -e "Please run as root. if you are not, enter 'n' now and enter 'sudo su' before running the script."
echo -e "Run the script? (y/n): ${Color_Off}"
read -e run
if [ "$run" == n ]; then
	output "\n${Red}The operation aborted!${Color_Off}"
	output "${Yellow}www.parsvt.com${Color_Off}\n"
	exit
else
	if [ -e /var/www/html/config.inc.php ]; then
		output "\n${Red}VtigerCRM already exists!${Color_Off}"
		output "Press Ctrl+C within the next 10 seconds to cancel the installation."
		output "Otherwise, wait until the installation continues, but it will destroy the existing data!"
		INSTALLTYPE="Exist"
		sleep 10
	fi
	checkInternetConnection
	restoreDNS
	if [ ! -f "/etc/redhat-release" ]; then
		output "\n${Red}Operating system is not supported!${Color_Off}"
		output "ParsVT installer only installs on CentOS and RHEL-based Linuxes."
		output "You have to install Apache, PHP and MySQL manually."
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
		IPS=$(hostname --all-ip-addresses)
		ipsarray=($IPS)
		if [ -n "$ipsarray" ]; then
			ipnums=${#ipsarray[@]}
			if (($ipnums > 1)); then
				output "\nThe following ethernet devices found! Please enter the item number you want to use: "
				COUNT=0
				for i in "${ipsarray[@]}"; do
					:
					output "# $COUNT - $i"
					COUNT=$(($COUNT + 1))
				done
				read -p "Please select an IP address: " DEVS
				if [ -z "${ipsarray[$DEVS]}" ]; then
					output "${Red}Invalid ethernet adapter!${Color_Off}"
					output "\n${Red}The operation aborted!${Color_Off}"
					output "${Yellow}www.parsvt.com${Color_Off}\n"
					if [ "$rundns" != "5" ]; then
						restoreDNS
					fi
					exit
				fi
				echo -n "Should IP address ($(tput bold)${ipsarray[$DEVS]}$(tput sgr0)) be used for licensing? (y/n): "
				read yesno
				if [ "$yesno" = "n" ]; then
					output "\n${Red}The operation aborted!${Color_Off}"
					output "${Yellow}www.parsvt.com${Color_Off}\n"
					if [ "$rundns" != "5" ]; then
						restoreDNS
					fi
					exit
				else
					ETH_DEV=${ipsarray[$DEVS]}
				fi
			else
				ETH_DEV=${ipsarray[0]}
			fi
		else
			output "${Red}Your ethernet device not found!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			if [ "$rundns" != "5" ]; then
				restoreDNS
			fi
			exit
		fi
		output "\nParsVT CRM will be installed on $(tput bold)${ETH_DEV}$(tput sgr0)\n"
		checkLicense
		RESPONSE=$(curl -fs -d "licenseid=$LICENSEKEY&serverip=$ETH_DEV" -H "Content-Type: application/x-www-form-urlencoded" -X POST "http://$primarySite/modules/addons/easyservice/Installer/check.php")
		IFS=';' read -ra RESPONSES <<<"$RESPONSE"
		if [ "${RESPONSES[0]}" != "Active" ] || [ "${#RESPONSES[2]}" == 0 ]; then
			output "\nLicense key status: ${Red}${RESPONSES[0]}!${Color_Off}"
			output "\n${Red}${RESPONSES[1]}${Color_Off}"
			output "For more information, please contact us."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			if [ "$rundns" != "5" ]; then
				restoreDNS
			fi
			exit
		fi
		output "\n${Green}${LICENSEKEY}${Color_Off} will be used as the license key."
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
			output "Please check the server's internet connection and DNS settings and run the installer again."
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
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
			output "${Cyan}Installing Remi repository...${Color_Off}"
			file="/etc/yum.repos.d/remi.repo"
			if [ ! -f "$file" ]; then
				dnf install http://$primarySite/modules/addons/easyservice/Installer/epel-release-latest-$major.noarch.rpm -y
				if [ "$major" = "9" ]; then
					set +e
					dnf install http://$primarySite/modules/addons/easyservice/Installer/epel-next-release-latest-$major.noarch.rpm -y
					set -e
				fi
				dnf install http://$primarySite/modules/addons/easyservice/Installer/remi-release-$major.rpm -y
			fi
		else
			output "${Cyan}Installing Remi repository...${Color_Off}"
			file="/etc/yum.repos.d/remi.repo"
			if [ ! -f "$file" ]; then
				yum install http://$primarySite/modules/addons/easyservice/Installer/epel-release-latest-$major.noarch.rpm -y
				yum install http://$primarySite/modules/addons/easyservice/Installer/remi-release-$major.rpm -y
			fi
		fi
		if [ "$major" = "8" ]; then
			dnf config-manager --set-enabled powertools
			dnf --enablerepo=remi,powertools install epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA -y
			set +e
			dnf --enablerepo=remi,powertools install epel-next-release -y
			set -e
		elif [ "$major" = "9" ]; then
			dnf config-manager --set-enabled crb
			dnf --enablerepo=remi,crb install epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA -y
			set +e
			dnf --enablerepo=remi,crb install epel-next-release -y
			set -e
		else
			yum --enablerepo=remi install epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA -y
		fi
		output "${Green}Remi repository successfully installed!${Color_Off}\n"
		file="/etc/yum.repos.d/remi.repo"
		if [ ! -f "$file" ]; then
			output "${Red}Remi repository failed to install!${Color_Off}"
			output "Please check the server's internet connection and DNS settings and run the installer again."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			if [ "$rundns" != "5" ]; then
				restoreDNS
			fi
			exit
		fi
		if ! command -v "php" &>/dev/null; then
			if [ "$major" = "7" ]; then
				output "${Cyan}Installing Apache and PHP...${Color_Off}"
				dnf install --enablerepo=remi,remi-php74 --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql php-mysqlnd php-sqlsrv php-xz php-fpm php-pdo curl-devel -y
			elif [ "$major" = "8" ] || [ "$major" = "9" ]; then
				output "${Cyan}Installing Apache and PHP...${Color_Off}"
				dnf module reset php -y
				dnf module install php:remi-7.4 -y
				dnf install --enablerepo=remi --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql php-mysqlnd php-sqlsrv php-xz php-fpm php-pdo curl-devel -y
			else
				output "${Cyan}Installing Apache and PHP...${Color_Off}"
				yum install --enablerepo=remi,remi-php72 --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql curl-devel -y
			fi
			if [ "$major" = "6" ]; then
				chkconfig httpd on
				iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
				service iptables save
			else
				systemctl enable httpd
			fi
			output "${Green}Apache and PHP successfully installed!${Color_Off}\n"
			output "${Cyan}Installing ionCube loader...${Color_Off}"
			installIonCube
			output "${Green}ionCube loader successfully installed!${Color_Off}\n"
		else
			output "${Green}PHP is already installed!${Color_Off}\n"
			if ! command -v "httpd" &>/dev/null; then
				output "${Cyan}Installing Apache...${Color_Off}"
				if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
					dnf install --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot -y
				else
					yum install --enablerepo=remi,remi-php72 --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot -y
				fi
				if [ "$major" = "6" ]; then
					chkconfig httpd on
					iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
					service iptables save
				else
					systemctl enable httpd
				fi
				output "${Green}Apache successfully installed!${Color_Off}\n"
			fi
			output "Checking the PHP version..."
			PHP_VER=$(php -r "if (version_compare(PHP_VERSION,'5.6.0','>')) echo 'Ok'; else echo 'Failed';")
			PHP_VERSION=$(php -r "echo PHP_VERSION;")
			if [ "$PHP_VER" = "Ok" ]; then
				cd /root
				output "Current PHP version: ${Green}${PHP_VERSION}${Color_Off}\n"
				output "Checking the ionCube loader version..."
				wget -q http://$primarySite/modules/addons/easyservice/Installer/ic.txt -O /root/IC.php
				set +e
				IONCUBE_VER=$(php -f /root/IC.php)
				IONCUBE_VERSION=$(php -r "error_reporting(0); echo ioncube_loader_version();")
				set -e
				rm -rf /root/IC.php*
				if [ "$IONCUBE_VER" = "Ok" ]; then
					output "Current ionCube loader version: ${Green}${IONCUBE_VERSION}${Color_Off}\n"
					read -p "Enter the directory path of your application (default: $(tput bold)${SETUPDIR}$(tput sgr0)): " app_dir
					SETUPDIR="/var/www/html/$app_dir"
					SETUPDIR=$(string_replace "$SETUPDIR" "/")
					SETUPDIR=$(string_replace "$SETUPDIR" "/")
					mkdir -p "$SETUPDIR"
					rm -rf $SETUPDIR/*
					output "\nYour application will be installed in ${Yellow}${SETUPDIR}${Color_Off}.\n"
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
		output "${Cyan}Installing timezonedb extension...${Color_Off}"
		cd /root
		mkdir -p timezonedb
		cd timezonedb
		getPHPConfigPath
		wget http://$primarySite/modules/addons/easyservice/Installer/timezonedb-2024.1.tgz -O timezonedb-2024.1.tgz
		pear install timezonedb-2024.1.tgz
		if ! grep -rnwq "$PHPINI" -e "extension=timezonedb.so"; then
			echo "extension=timezonedb.so" >>"$PHPINI"
		fi
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
		sed -i -e 's/max_input_time = 60/max_input_time = 600/g' $PHPINI
		sed -i -e 's/zlib.output_compression = On/zlib.output_compression = Off/g' $PHPINI
		sed -i -e 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 21600/g' $PHPINI
		sed -i -e 's/session.gc_divisor = 500/session.gc_divisor = 1000/g' $PHPINI
		sed -i -e 's/session.gc_probability = 0/session.gc_probability = 1/g' $PHPINI
		sed -i -e 's/default_socket_timeout = 60/default_socket_timeout = 600/g' $PHPINI
		sed -i -e 's/session.use_strict_mode = 0/session.use_strict_mode = 1/g' $PHPINI
		sed -i -e 's/session.cookie_httponly =/session.cookie_httponly = 1/g' $PHPINI
		sed -i -e 's/session.cookie_secure = 1/;session.cookie_secure =/g' $PHPINI
		sed -i -e 's/expose_php = On/expose_php = Off/g' $PHPINI
		sed -i -e 's/;date.timezone =/date.timezone = Asia\/Tehran/g' $PHPINI
		sed -i -e 's/CustomLog "logs\/access_log" combined/#CustomLog "logs\/access_log" combined/g' /etc/httpd/conf/httpd.conf
		sed -i -e 's/CustomLog logs\/ssl_request_log/#CustomLog logs\/ssl_request_log/g' /etc/httpd/conf.d/ssl.conf
		sed -i -e 's/php_admin_value\[error_log\] = \/var\/log\/php-fpm\/www-error.log/;php_admin_value\[error_log\] = \/var\/log\/php-fpm\/www-error.log/g' /etc/php-fpm.d/www.conf
		sed -i -e 's/php_admin_flag\[log_errors\] = on/;php_admin_flag\[log_errors\] = on/g' /etc/php-fpm.d/www.conf
		sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
		restartApache
		output "${Green}ParsVT requirements have been set!${Color_Off}\n"
		if type mysql >/dev/null 2>&1; then
			output "${Green}MySQL is already installed!${Color_Off}\n"
			mysqlConnection
		else
			removeMySQL
			output "${Cyan}Installing MySQL/MariaDB...${Color_Off}"
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
				dnf install --enablerepo=remi --skip-broken mariadb mariadb-server mariadb-backup mariadb-common mariadb-devel galera php-mysql php-mysqlnd phpMyAdmin -y
			else
				yum install --enablerepo=remi,remi-php72 --skip-broken mariadb mariadb-server mariadb-backup mariadb-common mariadb-devel galera php-mysql php-mysqlnd phpMyAdmin -y
			fi
			wget -q http://$primarySite/modules/addons/easyservice/Installer/pma.txt -O /etc/httpd/conf.d/phpMyAdmin.conf
			DBPassword=$(date +%s | sha256sum | base64 | head -c 20)
			output "MySQL Username: ${DBUSER}\nMySQL Password: ${DBPassword}" >/root/mysql.txt
			restartDatabase
			restartApache
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
				systemctl enable mariadb
			else
				chkconfig mariadb on
			fi
			mysqladmin -uroot create $DBNAME
			if [ "$major" = "9" ]; then
				SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Switch to unix_socket authentication\"
send \"n\r\"
expect \"Change the root password?\"
send \"y\r\"
expect \"New password:\"
send \"$DBPassword\r\"
expect \"Re-enter new password:\"
send \"$DBPassword\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
			else
				SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"y\r\"
expect \"New password:\"
send \"$DBPassword\r\"
expect \"Re-enter new password:\"
send \"$DBPassword\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
			fi
			echo "$SECURE_MYSQL"
			wget -q http://$primarySite/modules/addons/easyservice/Installer/sqlconf.txt -O /etc/my.cnf.d/disable_mysql_strict_mode.cnf
			restartDatabase
			output "${Green}MySQL/MariaDB successfully installed!${Color_Off}\n"
			output "${Cyan}Creating database...${Color_Off}"
			mysql -u ${DBUSER} -p${DBPassword} --default-character-set=utf8mb4 --silent -e "CREATE DATABASE IF NOT EXISTS ${DBNAME} CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';"
			mysql -u ${DBUSER} -p${DBPassword} --default-character-set=utf8mb4 --silent -e "ALTER DATABASE ${DBNAME} CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';"
			output "${Green}Database successfully created!${Color_Off}\n"
		fi
		restartDatabase
		output "${Cyan}Installing ParsVT CRM package...${Color_Off}"
		file="$SETUPDIR/latest.zip"
		if [ ! -f "$file" ]; then
			wget -q http://$primarySite/modules/addons/easyservice/Installer/download.php -O "$SETUPDIR"/latest.zip
		fi
		unzip -q -o $SETUPDIR/latest.zip -d $SETUPDIR
		mkdir -p "$SETUPDIR/test/data/modules/"
		file="$SETUPDIR/extensions.zip"
		if [ ! -f "$file" ]; then
			wget -q "${RESPONSES[2]}" -O "$SETUPDIR"/extensions.zip
		fi
		unzip -q -o $SETUPDIR/extensions.zip -d $SETUPDIR
		chown -R apache:apache $SETUPDIR
		cd $SETUPDIR
		find -type d -exec chmod 755 {} \;
		find -type f -exec chmod 644 {} \;
		cd /root
		rm -rf $SETUPDIR/latest.zip*
		rm -rf $SETUPDIR/extensions.zip*
		if [ "$INSTALLTYPE" = "Exist" ]; then
			(
				echo 'SET foreign_key_checks = 0;'
				(mysqldump -u $DBUSER -p$DBPassword --add-drop-table --no-data $DBNAME | grep ^DROP)
				echo 'SET foreign_key_checks = 1;'
			) |
				mysql -u $DBUSER -p$DBPassword -b $DBNAME --default-character-set=utf8mb4 --silent
		fi
		mysql -h $DBHOST -u $DBUSER -p$DBPassword $DBNAME --default-character-set=utf8mb4 --silent -e "SET NAMES 'utf8mb4';"
		mysql -h $DBHOST -u $DBUSER -p$DBPassword $DBNAME --default-character-set=utf8mb4 --silent <$SETUPDIR/test/data/tmp/database.sql
		setAdminPassword
		mysql -h $DBHOST -u $DBUSER -p$DBPassword $DBNAME --default-character-set=utf8mb4 --silent -e "UPDATE vtiger_users SET user_password = '$mysqlPWD', crypt_type = '' WHERE id = '1';"
		mysql -h $DBHOST -u $DBUSER -p$DBPassword $DBNAME --default-character-set=utf8mb4 --silent -e "UPDATE vtiger_users SET accesskey = UPPER(SUBSTRING(MD5(RAND()) FROM 1 FOR 16)) WHERE id = 1;"
		mysql -h $DBHOST -u $DBUSER -p$DBPassword $DBNAME --default-character-set=utf8mb4 --silent -e "TRUNCATE vtiger_crmsetup;"
		mysql -h $DBHOST -u $DBUSER -p$DBPassword $DBNAME --default-character-set=utf8mb4 --silent -e "TRUNCATE vtiger_loginhistory;"
		CRMURL="$ETH_DEV/$app_dir"
		CRMURL=$(string_replace "$CRMURL" "/")
		wget -q -o /dev/null -O /dev/null "http://$CRMURL/_install.php?db_hostname=$DBHOST&db_name=$DBNAME&db_username=$DBUSER&db_password=$DBPassword"
		wget -q -o /dev/null -O /dev/null "http://$CRMURL/_extensions.php?token=${RESPONSES[1]}"
		grep "http://$CRMURL/vtigercron.php" /var/spool/cron/root || echo "*/15 * * * * wget --spider \"http://$CRMURL/vtigercron.php\" >/dev/null 2>&1" >>/var/spool/cron/root
		rm -rf $SETUPDIR/_install*
		rm -rf $SETUPDIR/_extensions*
		output "${Green}ParsVT CRM package successfully installed!${Color_Off}\n"
		if java -version 2>&1 >/dev/null | grep -q "java version"; then
			output "${Green}Java libraries are already installed!${Color_Off}\n"
		else
			output "${Cyan}Installing Java libraries...${Color_Off}"
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
				if [ "$ARCH" = "x86_64" ]; then
					dnf install http://$secondarySite/JAVA/jdk-8u411-linux-x64.rpm -y
					dnf install http://$secondarySite/JAVA/jre-8u411-linux-x64.rpm -y
				else
					dnf install http://$secondarySite/JAVA/jdk-8u411-linux-i586.rpm -y
					dnf install http://$secondarySite/JAVA/jre-8u411-linux-i586.rpm -y
				fi
			else
				if [ "$ARCH" = "x86_64" ]; then
					yum install http://$secondarySite/JAVA/jdk-8u411-linux-x64.rpm -y
					yum install http://$secondarySite/JAVA/jre-8u411-linux-x64.rpm -y
				else
					yum install http://$secondarySite/JAVA/jdk-8u411-linux-i586.rpm -y
					yum install http://$secondarySite/JAVA/jre-8u411-linux-i586.rpm -y
				fi
			fi
			output "${Green}Java libraries successfully installed!${Color_Off}\n"
		fi
		output "${Cyan}Setting backup directory...${Color_Off}"
		output "#!/bin/bash\n delfile=\$(date --date='-7 day' +'%Y-%d-%m')\n yest=\$(date --date='today' +'%Y-%d-%m')\n backupdirectory='$SETUPDIR2'\n storagedirectory='$backupdirectory'\n mysqldump --user=$DBUSER --password=$DBPassword --host=$DBHOST $DBNAME | gzip -c > \$storagedirectory/$DBNAME-\$yest.sql.gz\n tar -czf \$storagedirectory/$DBNAME-\$yest.tar.gz \$backupdirectory\n rm -rf \$storagedirectory/$DBNAME-\$delfile.sql.gz*\n rm -rf \$storagedirectory/$DBNAME-\$delfile.tar.gz*" >/home/backup-$DBNAME.sh
		if [ ! -d $backupdirectory ]; then
			mkdir -p $backupdirectory
		fi
		chmod +x /home/backup-$DBNAME.sh
		grep "sh /home/backup-$DBNAME.sh" /var/spool/cron/root || echo "0 22 * * * sh /home/backup-$DBNAME.sh >/dev/null 2>&1" >>/var/spool/cron/root
		output "${Green}Backup directory successfully set!${Color_Off}\n"
		output "${Cyan}Installing Webmin...${Color_Off}"
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ]; then
			dnf install http://$primarySite/modules/addons/easyservice/Installer/webmin-2.201-1.noarch.rpm -y
			dnf install webmin -y
		else
			yum install http://$primarySite/modules/addons/easyservice/Installer/webmin-2.201-1.noarch.rpm -y
			yum install webmin -y
		fi
		output "${Green}Webmin successfully installed!${Color_Off}\n"
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
		output "${Green}ParsVT installation successfully completed!${Color_Off}\n"
		output "Webmin Information:"
		output "  Webmin URL:        ${Yellow}http://$ETH_DEV:10000${Color_Off}"
		output "  Webmin Username:   ${Yellow}$USER${Color_Off}"
		output "  Webmin Password:   ${Yellow}$USER SSH Password${Color_Off}\n"
		output "MySQL Information:"
		output "  Database Hostname: ${Yellow}$DBHOST${Color_Off}"
		output "  Database Username: ${Yellow}$DBUSER${Color_Off}"
		output "  Database Password: ${Yellow}$DBPassword${Color_Off}"
		output "  Database Name:     ${Yellow}$DBNAME${Color_Off}\n"
		output "CRM URL:      http://$CRMURL\nCRM Username: admin\nCRM Password: $adminPWD" >/root/crm.txt
		output "Vtiger Information:"
		output "  CRM URL:           ${Yellow}http://$CRMURL${Color_Off}"
		output "  CRM Username:      ${Yellow}admin${Color_Off}"
		output "  CRM Password:      ${Yellow}$adminPWD${Color_Off}\n"
		output "For more information, visit: www.parsvt.com\n"
	fi
fi
if [ "$rundns" != "5" ]; then
	restoreDNS
fi
