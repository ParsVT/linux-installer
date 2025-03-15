#!/bin/bash
# #########################################
# Program: ParsVT CRM Installation Script
# Developer: Hamid Rabiei, Mohammad Hadadpour
# Release: 1397-12-10
# Update: 1403-12-25
# #########################################
set -e
shecanProDNS1="178.22.122.101"
shecanProDNS2="185.51.200.1"
shecanDNS1="178.22.122.100"
shecanDNS2="185.51.200.2"
Color_Off="\e[0m"
Red="\e[0;31m"
Green="\e[0;32m"
Yellow="\e[0;33m"
Blue="\e[0;34m"
Purple="\e[0;35m"
Cyan="\e[0;36m"
primarySite="aweb.co"
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
installationType="Install"
JavaVersion="431"
output() {
	echo -e "$1"
}
startInstallation() {
	echo -e "\nPlease enter the item number you want to use:"
	echo -e "[${Cyan}1${Color_Off}] ${Cyan}Install ParsVT CRM${Color_Off}"
	echo -e "[${Cyan}2${Color_Off}] ${Cyan}Repair server configurations${Color_Off}"
	echo -e "[${Cyan}3${Color_Off}] ${Cyan}Update ionCube loader${Color_Off}"
	echo -e "[${Cyan}4${Color_Off}] ${Cyan}Install ClamAV (not recommended for low end servers)${Color_Off}"
	echo -e "[${Cyan}5${Color_Off}] ${Cyan}Install SSL certificate${Color_Off}"
	echo -e "[${Yellow}6${Color_Off}] ${Yellow}Cancel installation${Color_Off}\n"
	read -p "Please select an action (1-6): " run
	if [ "$run" == "1" ]; then
		installationType="Install"
	elif [ "$run" == "2" ]; then
		installationType="Repair"
	elif [ "$run" == "3" ]; then
		installationType="ionCube"
	elif [ "$run" == "4" ]; then
		installationType="clamAV"
	elif [ "$run" == "5" ]; then
		installationType="SSL"
	elif [ "$run" == "6" ]; then
		echo -e "\n${Red}The operation aborted!${Color_Off}"
		echo -e "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	else
		startInstallation
	fi
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
	read -p "Do you want to use Shecan as DNS during installation? (y/n): " rundns
	if [ "$rundns" = "y" ] || [ "$rundns" = "yes" ] || [ "$rundns" = "Y" ] || [ "$rundns" = "Yes" ] || [ "$rundns" = "YES" ] || [ "$rundns" = "1" ]; then
		if [ "$installationType" = "Install" ]; then
			shecanURI=$(echo -n "${RESPONSES[3]}" | base64 --decode)
			curl -s -o /dev/null "${shecanURI}"
			mv -n /etc/resolv.conf /etc/resolv.conf.parsvt
			echo -e "nameserver ${shecanProDNS1}\nnameserver ${shecanProDNS2}\n" >/etc/resolv.conf
			curl -s -o /dev/null "${shecanURI}"
			echo -e "${Green}DONE!${Color_Off}"
		else
			mv -n /etc/resolv.conf /etc/resolv.conf.parsvt
			echo -e "nameserver ${shecanDNS1}\nnameserver ${shecanDNS2}\n" >/etc/resolv.conf
		fi
	elif [ "$rundns" = "n" ] || [ "$rundns" = "no" ] || [ "$rundns" = "N" ] || [ "$rundns" = "No" ] || [ "$rundns" = "NO" ] || [ "$rundns" = "0" ]; then
		echo -e "${Yellow}OK!${Color_Off}"
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
	if [ -d "$MYSQLFOLDER" ]; then
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
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		systemctl restart httpd
		set +e
		systemctl restart php-fpm
		set -e
	else
		service httpd restart
	fi
}
restartDatabase() {
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		systemctl restart mariadb
	else
		service mariadb restart
	fi
}
disableSELinux() {
	STATUS=$(getenforce)
	if [ "$STATUS" = "disabled" ] || [ "$STATUS" = "Disabled" ]; then
		output "\n${Green}SELinux is already disabled!${Color_Off}"
	else
		output "\n${Cyan}Disabling SELinux...${Color_Off}"
		setenforce 0
		sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
		sed -i -e 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
		output "${Green}SELinux successfully disabled!${Color_Off}"
	fi
}
updatePackage() {
	if grep -rnwq "/etc/redhat-release" -e "CentOS"; then
		if ! { [ "$major" = "9" ] || [ "$major" = "10" ]; }; then
			output "\n${Cyan}Fixing deprecated CentOS repositories...${Color_Off}"
			set +e
			sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/CentOS-*.repo
			sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/CentOS-*.repo
			sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/CentOS-*.repo
			set -e
			output "${Green}Deprecated CentOS repositories successfully fixed!${Color_Off}"
		fi
	fi
	if [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		if grep -rnwq "/etc/redhat-release" -e "CentOS"; then
			if ! grep -rnwq "/etc/redhat-release" -e "Stream"; then
				output "\n${Cyan}Converting from CentOS Linux to CentOS Stream...${Color_Off}"
				dnf --disablerepo '*' --enablerepo extras swap centos-linux-repos centos-stream-repos -y
				dnf distro-sync -y
				output "${Green}CentOS successfully converted!${Color_Off}\n"
				output "${Cyan}Updating installed packages...${Color_Off}"
				yum install --skip-broken dnf -y
				if [ "$installationType" = "Install" ]; then
					dnf update --skip-broken -y
				else
					if [ "$major" = "8" ]; then
						dnf update --skip-broken --nobest -y
					else
						dnf update --skip-broken -y
					fi
				fi
				output "${Green}Installed packages successfully updated!${Color_Off}"
			else
				output "\n${Cyan}Updating installed packages...${Color_Off}"
				yum install --skip-broken dnf -y
				if [ "$installationType" = "Install" ]; then
					dnf update --skip-broken -y
				else
					if [ "$major" = "8" ]; then
						dnf update --skip-broken --nobest -y
					else
						dnf update --skip-broken -y
					fi
				fi
				output "${Green}Installed packages successfully updated!${Color_Off}"
			fi
		else
			output "\n${Cyan}Updating installed packages...${Color_Off}"
			yum install --skip-broken dnf -y
			dnf update --skip-broken -y
			output "${Green}Installed packages successfully updated!${Color_Off}"
		fi
	elif [ "$major" = "7" ]; then
		output "\n${Cyan}Updating installed packages...${Color_Off}"
		yum install --skip-broken dnf -y
		dnf update --skip-broken -y
		output "${Green}Installed packages successfully updated!${Color_Off}"
	else
		output "\n${Cyan}Updating installed packages...${Color_Off}"
		yum update --skip-broken -y
		output "${Green}Installed packages successfully updated!${Color_Off}"
	fi
}
installPackage() {
	output "\n${Cyan}Installing required packages...${Color_Off}"
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		dnf install --skip-broken wget curl expect psmisc net-tools yum-utils zip unzip tar crontabs tzdata chrony -y
	else
		yum install --skip-broken wget curl expect psmisc net-tools yum-utils zip unzip tar crontabs tzdata ntp ntpdate ntp-doc -y
	fi
	if [ "$major" = "9" ] || [ "$major" = "10" ]; then
		dnf install --skip-broken initscripts -y
	fi
	output "${Green}Required packages successfully installed!${Color_Off}\n"
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
	if [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
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
installTimezonedb() {
	getPHPConfigPath
	if ! grep -rnwq "$PHPINI" -e "extension=timezonedb.so"; then
		output "${Cyan}Installing timezonedb extension...${Color_Off}"
		cd /tmp
		rm -rf timezonedb*
		mkdir -p timezonedb
		cd timezonedb
		wget http://$primarySite/modules/addons/easyservice/Installer/timezonedb-2024.2.tgz -O timezonedb-2024.2.tgz
		pear install timezonedb-2024.2.tgz
		if ! grep -rnwq "$PHPINI" -e "extension=timezonedb.so"; then
			sed -i '/extension=<ext>) syntax./a extension=timezonedb.so' $PHPINI
		fi
		rm -rf timezonedb*
		cd /root
		restartApache
		date
		hwclock
		output "${Green}timezonedb extension successfully installed!${Color_Off}\n"
	else
		output "${Green}timezonedb extension is already installed!${Color_Off}\n"
	fi
}
setRequirements() {
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
	if ! grep -rnwq "$PHPINI" -e "max_input_time = 600"; then
		sed -i -e 's/max_input_time = 60/max_input_time = 600/g' $PHPINI
	fi
	sed -i -e 's/zlib.output_compression = On/zlib.output_compression = Off/g' $PHPINI
	sed -i -e 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 21600/g' $PHPINI
	sed -i -e 's/session.gc_divisor = 500/session.gc_divisor = 1000/g' $PHPINI
	sed -i -e 's/session.gc_probability = 0/session.gc_probability = 1/g' $PHPINI
	if ! grep -rnwq "$PHPINI" -e "default_socket_timeout = 600"; then
		sed -i -e 's/default_socket_timeout = 60/default_socket_timeout = 600/g' $PHPINI
	fi
	sed -i -e 's/session.use_strict_mode = 0/session.use_strict_mode = 1/g' $PHPINI
	sed -i -e 's/session.cookie_httponly =/session.cookie_httponly = 1/g' $PHPINI
	sed -i -e 's/session.cookie_secure = 1/;session.cookie_secure =/g' $PHPINI
	sed -i -e 's/expose_php = On/expose_php = Off/g' $PHPINI
	sed -i -e 's/;date.timezone =/date.timezone = "Asia\/Tehran"/g' $PHPINI
	httpdfile="/etc/httpd/conf/httpd.conf"
	if [ -f "$httpdfile" ]; then
		sed -i -e 's/CustomLog "logs\/access_log" combined/#CustomLog "logs\/access_log" combined/g' /etc/httpd/conf/httpd.conf
		sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
		if ! grep -rnwq "/etc/httpd/conf/httpd.conf" -e "TimeOut"; then
			sed -i '/Listen 80/a TimeOut 600' /etc/httpd/conf/httpd.conf
		fi
		if ! grep -rnwq "/etc/httpd/conf/httpd.conf" -e "ServerTokens"; then
			sed -i '/TimeOut 600/a ServerTokens Prod' /etc/httpd/conf/httpd.conf
		fi
		if ! grep -rnwq "/etc/httpd/conf/httpd.conf" -e "ServerSignature"; then
			sed -i '/ServerTokens Prod/a ServerSignature Off' /etc/httpd/conf/httpd.conf
		fi
	fi
	sslfile="/etc/httpd/conf.d/ssl.conf"
	if [ -f "$sslfile" ]; then
		sed -i -e 's/CustomLog logs\/ssl_request_log/#CustomLog logs\/ssl_request_log/g' /etc/httpd/conf.d/ssl.conf
	fi
	wwwfile="/etc/php-fpm.d/www.conf"
	if [ -f "$wwwfile" ]; then
		sed -i -e 's/php_admin_value\[error_log\] = \/var\/log\/php-fpm\/www-error.log/;php_admin_value\[error_log\] = \/var\/log\/php-fpm\/www-error.log/g' /etc/php-fpm.d/www.conf
		sed -i -e 's/php_admin_flag\[log_errors\] = on/;php_admin_flag\[log_errors\] = on/g' /etc/php-fpm.d/www.conf
	fi
	restartApache
	output "${Green}ParsVT requirements have been set!${Color_Off}\n"
}
installJava() {
	if java -version 2>&1 >/dev/null | grep -q "java version \"1.8.0_$JavaVersion\""; then
		output "${Green}Java libraries are already installed!${Color_Off}\n"
	else
		if java -version 2>&1 >/dev/null | grep -q "java version"; then
			output "${Cyan}Updating Java libraries...${Color_Off}"
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
				if [ "$ARCH" = "x86_64" ]; then
					dnf install --skip-broken http://files.aweb.asia/JAVA/jdk-8u$JavaVersion-linux-x64.rpm -y
					dnf install --skip-broken http://files.aweb.asia/JAVA/jre-8u$JavaVersion-linux-x64.rpm -y
				else
					dnf install --skip-broken http://files.aweb.asia/JAVA/jdk-8u$JavaVersion-linux-i586.rpm -y
					dnf install --skip-broken http://files.aweb.asia/JAVA/jre-8u$JavaVersion-linux-i586.rpm -y
				fi
			else
				if [ "$ARCH" = "x86_64" ]; then
					yum install --skip-broken http://files.aweb.asia/JAVA/jdk-8u$JavaVersion-linux-x64.rpm -y
					yum install --skip-broken http://files.aweb.asia/JAVA/jre-8u$JavaVersion-linux-x64.rpm -y
				else
					yum install --skip-broken http://files.aweb.asia/JAVA/jdk-8u$JavaVersion-linux-i586.rpm -y
					yum install --skip-broken http://files.aweb.asia/JAVA/jre-8u$JavaVersion-linux-i586.rpm -y
				fi
			fi
			if java -version 2>&1 >/dev/null | grep -q "java version \"1.8.0_$JavaVersion\""; then
				output "${Green}Java libraries successfully updated!${Color_Off}\n"
			else
				output "${Red}Java libraries failed to update!${Color_Off}"
				output "You have to update JDK and JRE manually."
				output "\n${Red}The operation aborted!${Color_Off}"
				output "${Yellow}www.parsvt.com${Color_Off}\n"
				exit
			fi
		else
			output "${Cyan}Installing Java libraries...${Color_Off}"
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
				if [ "$ARCH" = "x86_64" ]; then
					dnf install --skip-broken http://files.aweb.asia/JAVA/jdk-8u$JavaVersion-linux-x64.rpm -y
					dnf install --skip-broken http://files.aweb.asia/JAVA/jre-8u$JavaVersion-linux-x64.rpm -y
				else
					dnf install --skip-broken http://files.aweb.asia/JAVA/jdk-8u$JavaVersion-linux-i586.rpm -y
					dnf install --skip-broken http://files.aweb.asia/JAVA/jre-8u$JavaVersion-linux-i586.rpm -y
				fi
			else
				if [ "$ARCH" = "x86_64" ]; then
					yum install --skip-broken http://files.aweb.asia/JAVA/jdk-8u$JavaVersion-linux-x64.rpm -y
					yum install --skip-broken http://files.aweb.asia/JAVA/jre-8u$JavaVersion-linux-x64.rpm -y
				else
					yum install --skip-broken http://files.aweb.asia/JAVA/jdk-8u$JavaVersion-linux-i586.rpm -y
					yum install --skip-broken http://files.aweb.asia/JAVA/jre-8u$JavaVersion-linux-i586.rpm -y
				fi
			fi
			if java -version 2>&1 >/dev/null | grep -q "java version \"1.8.0_$JavaVersion\""; then
				output "${Green}Java libraries successfully installed!${Color_Off}\n"
			else
				output "${Red}Java libraries failed to install!${Color_Off}"
				output "You have to install JDK and JRE 1.8 or higher manually."
				output "\n${Red}The operation aborted!${Color_Off}"
				output "${Yellow}www.parsvt.com${Color_Off}\n"
				exit
			fi
		fi
	fi
}
openPorts() {
	output "${Cyan}Opening required firewall ports...${Color_Off}"
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		systemctl enable firewalld
		systemctl restart firewalld
		firewall-cmd --zone=public --permanent --add-service=http
		firewall-cmd --zone=public --permanent --add-service=https
		firewall-cmd --zone=public --permanent --add-service=imaps
		firewall-cmd --zone=public --permanent --add-service=ssh
		firewall-cmd --zone=public --permanent --add-service=smtp
		firewall-cmd --zone=public --permanent --add-service=ntp
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
sqlConf() {
	if [ ! -f "/etc/my.cnf.d/disable_mysql_strict_mode.cnf.old" ]; then
		read -p "Do you want to overwrite the MySQL configuration file with the suggested file? (y/n): " sqlconfig
		if [ "$sqlconfig" = "y" ] || [ "$sqlconfig" = "yes" ] || [ "$sqlconfig" = "Y" ] || [ "$sqlconfig" = "Yes" ] || [ "$sqlconfig" = "YES" ] || [ "$sqlconfig" = "1" ]; then
			CHECKMYSQL=$(mysql -V)
			if ${CHECKMYSQL} | grep -q "MariaDB"; then
				mv -n /etc/my.cnf.d/disable_mysql_strict_mode.cnf /etc/my.cnf.d/disable_mysql_strict_mode.cnf.old
				wget -q http://$primarySite/modules/addons/easyservice/Installer/sqlconf.txt -O /etc/my.cnf.d/disable_mysql_strict_mode.cnf
				if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
					systemctl restart mariadb
				else
					service mariadb restart
				fi
			else
				mv -n /etc/my.cnf.d/disable_mysql_strict_mode.cnf /etc/my.cnf.d/disable_mysql_strict_mode.cnf.old
				wget -q http://$primarySite/modules/addons/easyservice/Installer/sqlconf2.txt -O /etc/my.cnf.d/disable_mysql_strict_mode.cnf
				if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
					systemctl restart mysqld
				else
					service mysqld restart
				fi
			fi
			echo -e "${Green}DONE!${Color_Off}\n"
		elif [ "$sqlconfig" = "n" ] || [ "$sqlconfig" = "no" ] || [ "$sqlconfig" = "N" ] || [ "$sqlconfig" = "No" ] || [ "$sqlconfig" = "NO" ] || [ "$sqlconfig" = "0" ]; then
			echo -e "${Yellow}OK!${Color_Off}\n"
		else
			sqlConf
		fi
	fi
}
sslDomain() {
	read -p "Please enter your domain name (example.com): " domain
	staticip=$(wget -O- -q "http://$primarySite/ip.php")
	read -p "Are you sure you have created a DNS (A record) to connect the domain $(tput bold)${domain}$(tput sgr0) to the static IP $(tput bold)${staticip}$(tput sgr0)? (y/n): " confirmdomain
	if [ "$confirmdomain" = "y" ] || [ "$confirmdomain" = "yes" ] || [ "$confirmdomain" = "Y" ] || [ "$confirmdomain" = "Yes" ] || [ "$confirmdomain" = "YES" ] || [ "$confirmdomain" = "1" ]; then
		if [ ! -L "/var/www/$domain" ]; then
			ln -s /var/www/html /var/www/$domain
		fi
		wget -q http://$primarySite/modules/addons/easyservice/Installer/domain.txt -O /etc/httpd/conf.d/$domain.conf
		sed -i -e "s/example.com/$domain/g" /etc/httpd/conf.d/$domain.conf
		restartApache
		certbot --apache -d $domain
		certbot renew --dry-run
		grep "python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew" /var/spool/cron/root || echo "0 0,12 * * * python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew" >>/var/spool/cron/root
		restartApache
		output "${Green}SSL certificate successfully installed!${Color_Off}\n"
	else
		sslDomain
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
echo -e "Shell script to install ParsVT CRM on Linux."
echo -e "Please run as root. if you are not, enter '6' now and enter 'sudo su' before running the script.${Color_Off}"
startInstallation
restoreDNS
cd /root
if [ "$installationType" = "Install" ]; then
	if [ -e /var/www/html/config.inc.php ]; then
		output "\n${Red}VtigerCRM already exists!${Color_Off}"
		output "Press Ctrl+C within the next 10 seconds to cancel the installation."
		output "Otherwise, wait until the installation continues, but it will destroy the existing data!"
		INSTALLTYPE="Exist"
		sleep 10
	fi
	checkInternetConnection
	if [ ! -f "/etc/redhat-release" ]; then
		output "\n${Red}Operating system is not supported!${Color_Off}"
		output "ParsVT installer only installs on CentOS and RHEL-based Linuxes."
		output "You have to install Apache, PHP and MySQL manually."
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	else
		fullname=$(cat /etc/redhat-release)
		major=$(cat /etc/redhat-release | tr -dc '0-9.' | cut -d \. -f1)
		ARCH=$(uname -m)
		output "${Green}${fullname} ${ARCH}${Color_Off}"
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
					exit
				fi
				ETH_DEV=${ipsarray[$DEVS]}
			else
				ETH_DEV=${ipsarray[0]}
			fi
		else
			output "${Red}Your ethernet device not found!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			exit
		fi
		output "\nParsVT CRM will be installed on ${Green}${ETH_DEV}${Color_Off}\n"
		checkLicense
		RESPONSE=$(curl -fs -d "licenseid=$LICENSEKEY&serverip=$ETH_DEV" -H "Content-Type: application/x-www-form-urlencoded" -X POST "http://$primarySite/modules/addons/easyservice/Installer/check.php")
		IFS=';' read -ra RESPONSES <<<"$RESPONSE"
		if [ "${RESPONSES[0]}" != "Active" ] || [ "${#RESPONSES[2]}" == 0 ]; then
			output "\nLicense key status: ${Red}${RESPONSES[0]}!${Color_Off}"
			output "\n${Red}${RESPONSES[1]}${Color_Off}"
			output "For more information, please contact us."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			exit
		fi
		output "\n${Green}${LICENSEKEY}${Color_Off} will be used as the license key.\n"
		setDNS
		disableSELinux
		updatePackage
		installPackage
		wgetfile="/usr/bin/wget"
		curlfile="/usr/bin/curl"
		if [ ! -f "$wgetfile" ] || [ ! -f "$curlfile" ]; then
			output "${Red}required packages failed to install!${Color_Off}"
			output "Please check the server's internet connection and DNS settings and run the installer again."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		fi
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
			output "${Cyan}Installing Remi repository...${Color_Off}"
			file="/etc/yum.repos.d/remi.repo"
			if [ ! -f "$file" ]; then
				if [ "$major" = "8" ]; then
					dnf config-manager --set-enabled powertools
				fi
				if [ "$major" = "9" ] || [ "$major" = "10" ]; then
					dnf config-manager --set-enabled crb
				fi
				dnf install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/epel-release-latest-$major.noarch.rpm -y
				if [ "$major" = "9" ]; then
					set +e
					dnf install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/epel-next-release-latest-$major.noarch.rpm -y
					set -e
				fi
				dnf install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/remi-release-$major.rpm -y
			fi
		else
			output "${Cyan}Installing Remi repository...${Color_Off}"
			file="/etc/yum.repos.d/remi.repo"
			if [ ! -f "$file" ]; then
				yum install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/epel-release-latest-$major.noarch.rpm -y
				yum install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/remi-release-$major.rpm -y
			fi
		fi
		if [ "$major" = "8" ]; then
			dnf config-manager --set-enabled powertools
			dnf install --enablerepo=remi,powertools --skip-broken epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA -y
		elif [ "$major" = "9" ]; then
			dnf config-manager --set-enabled crb
			dnf install --enablerepo=remi,crb --skip-broken epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA -y
			set +e
			dnf install --enablerepo=remi,crb --skip-broken epel-next-release -y
			set -e
		elif [ "$major" = "10" ]; then
			dnf config-manager --set-enabled crb
			dnf install --enablerepo=remi,crb --skip-broken epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA -y
		else
			yum install --enablerepo=remi --skip-broken epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA -y
		fi
		output "${Green}Remi repository successfully installed!${Color_Off}\n"
		file="/etc/yum.repos.d/remi.repo"
		if [ ! -f "$file" ]; then
			output "${Red}Remi repository failed to install!${Color_Off}"
			output "Please check the server's internet connection and DNS settings and run the installer again."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		fi
		if ! command -v "php" &>/dev/null; then
			if [ "$major" = "7" ]; then
				output "${Cyan}Installing Apache and PHP...${Color_Off}"
				dnf install --enablerepo=remi,remi-php74 --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-curl php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql php-mysqlnd php-sqlsrv php-xz php-fpm php-pdo curl-devel -y
			elif [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
				output "${Cyan}Installing Apache and PHP...${Color_Off}"
				dnf module reset php -y
				dnf module install php:remi-7.4 -y
				dnf install --enablerepo=remi --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-curl php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql php-mysqlnd php-sqlsrv php-xz php-fpm php-pdo curl-devel -y
			else
				output "${Cyan}Installing Apache and PHP...${Color_Off}"
				yum install --enablerepo=remi,remi-php74 --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-curl php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql php-mysqlnd php-sqlsrv php-xz php-fpm php-pdo curl-devel -y
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
				if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
					dnf install --enablerepo=remi --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot -y
				else
					yum install --enablerepo=remi --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot -y
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
					restoreDNS
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
				restoreDNS
				exit
			fi
		fi
		installTimezonedb
		setRequirements
		if type mysql >/dev/null 2>&1; then
			output "${Green}MySQL is already installed!${Color_Off}\n"
			mysqlConnection
		else
			removeMySQL
			output "${Cyan}Installing MySQL (MariaDB)...${Color_Off}"
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
				dnf install --enablerepo=remi --skip-broken mariadb mariadb-server mariadb-backup mariadb-common mariadb-devel galera php-mysql php-mysqlnd phpMyAdmin -y
			else
				yum install --enablerepo=remi --skip-broken mariadb mariadb-server mariadb-backup mariadb-common mariadb-devel galera php-mysql php-mysqlnd phpMyAdmin -y
			fi
			pmafile="/etc/httpd/conf.d/phpMyAdmin.conf"
			if [ -f "$pmafile" ]; then
				sed -i '/<Directory \/usr\/share\/phpMyAdmin\/>/,/<\/Directory>/ s/Require local/Require all granted/' /etc/httpd/conf.d/phpMyAdmin.conf
			fi
			DBPassword=$(date +%s | sha256sum | base64 | head -c 20)
			output "MySQL Username: ${DBUSER}\nMySQL Password: ${DBPassword}" >/root/mysql.txt
			restartDatabase
			restartApache
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
				systemctl enable mariadb
			else
				chkconfig mariadb on
			fi
			mysqladmin -uroot create $DBNAME
			if [ "$major" = "9" ] || [ "$major" = "10" ]; then
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
			output "${Green}MySQL (MariaDB) successfully installed!${Color_Off}\n"
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
		find -type d -exec chmod 0755 {} \;
		find -type f -exec chmod 0644 {} \;
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
		installJava
		output "${Cyan}Setting backup directory...${Color_Off}"
		if [ -f "/home/backup-$DBNAME.sh" ]; then
			rm -rf "/home/backup-$DBNAME.sh"
		fi
		output "#!/bin/bash\n delfile=\$(date --date='-7 day' +'%Y-%d-%m')\n yest=\$(date --date='today' +'%Y-%d-%m')\n backupdirectory='$SETUPDIR2'\n storagedirectory='$backupdirectory'\n mysqldump --user=$DBUSER --password=$DBPassword --host=$DBHOST $DBNAME | gzip -c > \$storagedirectory/$DBNAME-\$yest.sql.gz\n tar -czf \$storagedirectory/$DBNAME-\$yest.tar.gz \$backupdirectory\n rm -rf \$storagedirectory/$DBNAME-\$delfile.sql.gz*\n rm -rf \$storagedirectory/$DBNAME-\$delfile.tar.gz*" >/home/backup-$DBNAME.sh
		if [ ! -d $backupdirectory ]; then
			mkdir -p $backupdirectory
		fi
		chmod +x /home/backup-$DBNAME.sh
		grep "sh /home/backup-$DBNAME.sh" /var/spool/cron/root || echo "0 22 * * * sh /home/backup-$DBNAME.sh >/dev/null 2>&1" >>/var/spool/cron/root
		output "${Green}Backup directory successfully set!${Color_Off}\n"
		output "${Cyan}Installing Webmin...${Color_Off}"
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
			dnf install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/webmin-2.202-1.noarch.rpm -y
			dnf install --skip-broken webmin -y
		else
			yum install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/webmin-2.202-1.noarch.rpm -y
			yum install --skip-broken webmin -y
		fi
		output "${Green}Webmin successfully installed!${Color_Off}\n"
		openPorts
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
if [ "$installationType" = "Repair" ]; then
	if [ ! -f "/var/www/html/config.inc.php" ]; then
		output "\n${Red}VtigerCRM is not installed!${Color_Off}"
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	fi
	checkInternetConnection
	if [ ! -f "/etc/redhat-release" ]; then
		output "\n${Red}Operating system is not supported!${Color_Off}"
		output "ParsVT repair script only works on CentOS and RHEL-based Linuxes."
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	else
		fullname=$(cat /etc/redhat-release)
		major=$(cat /etc/redhat-release | tr -dc '0-9.' | cut -d \. -f1)
		ARCH=$(uname -m)
		output "${Green}${fullname} ${ARCH}${Color_Off}\n"
		setDNS
		disableSELinux
		set +e
		updatePackage
		installPackage
		set -e
		wgetfile="/usr/bin/wget"
		curlfile="/usr/bin/curl"
		if [ ! -f "$wgetfile" ] || [ ! -f "$curlfile" ]; then
			output "${Red}required packages failed to install!${Color_Off}"
			output "Please check the server's internet connection and DNS settings and run the script again."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		fi
		file="/etc/yum.repos.d/remi.repo"
		if [ ! -f "$file" ]; then
			output "${Red}Remi repository is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		else
			output "${Green}Remi repository is already installed!${Color_Off}\n"
		fi
		if ! command -v "php" &>/dev/null; then
			output "${Red}PHP is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		else
			output "${Green}PHP is already installed!${Color_Off}\n"
			output "Checking the PHP version..."
			PHP_VER=$(php -r "if (version_compare(PHP_VERSION,'5.6.0','>')) echo 'Ok'; else echo 'Failed';")
			PHP_VERSION=$(php -r "echo PHP_VERSION;")
			if [ "$PHP_VER" = "Ok" ]; then
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
					restoreDNS
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
				restoreDNS
				exit
			fi
		fi
		if ! command -v "httpd" &>/dev/null; then
			output "${Red}Apache is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		else
			output "${Green}Apache is already installed!${Color_Off}\n"
		fi
		installTimezonedb
		setRequirements
		if type mysql >/dev/null 2>&1; then
			output "${Green}MySQL is already installed!${Color_Off}\n"
			sqlConf
		else
			output "${Red}MySQL is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		fi
		installJava
		output "${Cyan}Fixing permissions of directories and files...${Color_Off}"
		chown -R apache:apache /var/www/html
		cd /var/www/html
		find -type d -exec chmod 0755 {} \;
		find -type f -exec chmod 0644 {} \;
		cd /root
		output "${Green}Permissions of directories and files successfully fixed!${Color_Off}\n"
		set +e
		openPorts
		set -e
		output "\n${Yellow} ___            __   _______              "
		output "| _ \__ _ _ _ __\ \ / /_   _|__ ___ _ __  "
		output "|  _/ _\` | '_(_-<\ V /  | |_/ _/ _ \ '  \ "
		output "|_| \__,_|_| /__/ \_/   |_(_)__\___/_|_|_|${Color_Off}\n"
		output "${Green}ParsVT repair successfully completed!${Color_Off}\n"
	fi
fi
if [ "$installationType" = "ionCube" ]; then
	checkInternetConnection
	if [ ! -f "/etc/redhat-release" ]; then
		output "\n${Red}Operating system is not supported!${Color_Off}"
		output "ionCube loader installer only installs on CentOS and RHEL-based Linuxes."
		output "You have to install/update ionCube loader manually."
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	else
		if [ -f "/etc/redhat-release" ]; then
			fullname=$(cat /etc/redhat-release)
			major=$(cat /etc/redhat-release | tr -dc '0-9.' | cut -d \. -f1)
			ARCH=$(uname -m)
			output "${Green}${fullname} ${ARCH}${Color_Off}\n"
		fi
		setDNS
		set +e
		updatePackage
		installPackage
		set -e
		wgetfile="/usr/bin/wget"
		curlfile="/usr/bin/curl"
		if [ ! -f "$wgetfile" ] || [ ! -f "$curlfile" ]; then
			output "${Red}required packages failed to install!${Color_Off}"
			output "Please check the server's internet connection and DNS settings and run the installer again."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		fi
		if ! command -v "php" &>/dev/null; then
			output "${Red}PHP is not installed!${Color_Off}"
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		else
			output "${Green}PHP is already installed!${Color_Off}\n"
			output "Checking the PHP version..."
			PHP_VER=$(php -r "if (version_compare(PHP_VERSION,'5.6.0','>')) echo 'Ok'; else echo 'Failed';")
			PHP_VERSION=$(php -r "echo PHP_VERSION;")
			if [ "$PHP_VER" = "Ok" ]; then
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
					restoreDNS
					exit
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
					restoreDNS
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
				restoreDNS
				exit
			fi
		fi
	fi
fi
if [ "$installationType" = "clamAV" ]; then
	checkInternetConnection
	if [ ! -f "/etc/redhat-release" ]; then
		output "\n${Red}Operating system is not supported!${Color_Off}"
		output "ClamAV installer only installs on CentOS and RHEL-based Linuxes."
		output "You have to install ClamAV manually."
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	else
		if [ -f "/etc/redhat-release" ]; then
			fullname=$(cat /etc/redhat-release)
			major=$(cat /etc/redhat-release | tr -dc '0-9.' | cut -d \. -f1)
			ARCH=$(uname -m)
			output "${Green}${fullname} ${ARCH}${Color_Off}\n"
		fi
		setDNS
		set +e
		updatePackage
		installPackage
		set -e
		wgetfile="/usr/bin/wget"
		curlfile="/usr/bin/curl"
		if [ ! -f "$wgetfile" ] || [ ! -f "$curlfile" ]; then
			output "${Red}required packages failed to install!${Color_Off}"
			output "Please check the server's internet connection and DNS settings and run the installer again."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		fi
		output "${Cyan}Installing ClamAV...${Color_Off}"
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
			dnf install --skip-broken epel-release -y
			dnf install --skip-broken clamav clamav-update -y
		else
			yum install --skip-broken epel-release -y
			yum install --skip-broken clamav clamav-update -y
		fi
		freshclam
		mkdir -p /var/log/clamav
		touch /var/log/clamav/daily_scan.log
		chmod 0755 /var/log/clamav
		chmod 0640 /var/log/clamav/daily_scan.log
		wget http://$primarySite/modules/addons/easyservice/Installer/daily_clamscan.txt -O /usr/local/bin/daily_clamscan.sh
		chmod +x /usr/local/bin/daily_clamscan.sh
		setfacl -m u:root:rwx /var/log/clamav
		setfacl -m u:root:rx /usr/local/bin/daily_clamscan.sh
		grep "/usr/local/bin/daily_clamscan.sh" /var/spool/cron/root || echo "0 2 * * * /usr/local/bin/daily_clamscan.sh" >>/var/spool/cron/root
		output "${Green}ClamAV successfully installed!${Color_Off}\n"
	fi
fi
if [ "$installationType" = "SSL" ]; then
	if [ ! -f "/var/www/html/config.inc.php" ]; then
		output "\n${Red}VtigerCRM is not installed!${Color_Off}"
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	fi
	checkInternetConnection
	if [ ! -f "/etc/redhat-release" ]; then
		output "\n${Red}Operating system is not supported!${Color_Off}"
		output "ClamAV installer only installs on CentOS and RHEL-based Linuxes."
		output "You have to install ClamAV manually."
		output "\n${Red}The operation aborted!${Color_Off}"
		output "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	else
		if [ -f "/etc/redhat-release" ]; then
			fullname=$(cat /etc/redhat-release)
			major=$(cat /etc/redhat-release | tr -dc '0-9.' | cut -d \. -f1)
			ARCH=$(uname -m)
			output "${Green}${fullname} ${ARCH}${Color_Off}\n"
		fi
		setDNS
		set +e
		updatePackage
		installPackage
		set -e
		wgetfile="/usr/bin/wget"
		curlfile="/usr/bin/curl"
		if [ ! -f "$wgetfile" ] || [ ! -f "$curlfile" ]; then
			output "${Red}required packages failed to install!${Color_Off}"
			output "Please check the server's internet connection and DNS settings and run the installer again."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			restoreDNS
			exit
		fi
		output "${Cyan}Installing SSL certificate requirements...${Color_Off}"
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
			dnf install --skip-broken epel-release -y
			dnf install --skip-broken snapd -y
			systemctl enable --now snapd.socket
			if [ ! -L "/snap" ]; then
				ln -s /var/lib/snapd/snap /snap
			fi
			dnf remove certbot -y
			snap install --classic certbot
			if [ ! -L "/usr/bin/certbot" ]; then
				ln -s /snap/bin/certbot /usr/bin/certbot
			fi
		else
			yum install --skip-broken epel-release -y
			yum remove certbot -y
			yum install --skip-broken mod_ssl python-certbot-apache certbot -y
		fi
		output "${Green}SSL certificate requirements successfully installed!${Color_Off}\n"
		sslDomain
	fi
fi
restoreDNS
