#!/bin/bash
# #########################################
# Program: ParsVT CRM Installation Script
# Developer: Hamid Rabiei, Mohammad Hadadpour
# Release: 1397-12-10
# Update: 1405-08-12
# #########################################
set -e
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
INSTALLTYPE="Fresh"
DBHOST="localhost"
DBUSER="root"
DBNAME="parsvt"
SETUPDIR="/var/www/html"
SETUPDIR2="/var/www/html"
backupdirectory="/home/backup"
counter=0
LICENSEKEY=""
app_dir=""
adminPWD=""
mysqlPWD=""
DBPassword=""
INTERNET_STATUS="DOWN"
installationType="Install"
JavaVersion="461"
DBPASSFILE="/root/.parsvt-db.pwd"
CRONFILE="/var/spool/cron/root"
if [ -x /usr/bin/dnf ]; then
	PKG="dnf"
else
	PKG="yum"
fi
output() {
	echo -e "$1"
}
die() {
	output "$1"
	output "\n${Red}The operation aborted!${Color_Off}"
	output "${Yellow}www.parsvt.com${Color_Off}\n"
	exit 1
}
urlEncode() {
	local string="$1" encoded="" char index
	for ((index = 0; index < ${#string}; index++)); do
		char="${string:index:1}"
		case "$char" in
			[a-zA-Z0-9.~_-])
				encoded+="$char"
				;;
			*)
				printf -v char '%%%02X' "'$char"
				encoded+="$char"
				;;
		esac
	done
	printf '%s' "$encoded"
}
randomPassword() {
	local length="${1:-16}"
	LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c "$length"
}
downloadFile() {
	local path="$1" destination="$2" url
	for url in "https://${primarySite}${path}" "http://${primarySite}${path}"; do
		if wget -q --timeout=60 --tries=2 -O "$destination" "$url" 2>/dev/null; then
			if [ -s "$destination" ]; then
				return 0
			fi
		fi
	done
	rm -f "$destination"
	return 1
}
addCronJob() {
	local entry="$1" pattern="$2"
	mkdir -p "$(dirname "$CRONFILE")" 2>/dev/null || true
	touch "$CRONFILE"
	if [ -n "$pattern" ] && grep -Fq "$pattern" "$CRONFILE" 2>/dev/null; then
		return 0
	fi
	if [ -s "$CRONFILE" ] && [ -n "$(tail -c 1 "$CRONFILE")" ]; then
		printf '\n' >>"$CRONFILE"
	fi
	printf '%s\n' "$entry" >>"$CRONFILE"
}
saveDBPassword() {
	(
		umask 077
		printf '%s' "$DBPassword" >"$DBPASSFILE"
	)
	chmod 600 "$DBPASSFILE" 2>/dev/null || true
}
mysqlExec() {
	MYSQL_PWD="$(cat "$DBPASSFILE" 2>/dev/null)" mysql --host="$DBHOST" --user="$DBUSER" --default-character-set=utf8mb4 "$@"
}
mysqldumpExec() {
	MYSQL_PWD="$(cat "$DBPASSFILE" 2>/dev/null)" mysqldump --host="$DBHOST" --user="$DBUSER" "$@"
}
setIniDirective() {
	local directive="$1" value="$2" temporary
	[ -f "$PHPINI" ] || return 0
	temporary=$(mktemp "${PHPINI}.XXXXXX") || return 1
	if ! awk -v key="$directive" -v val="$value" '
		{
			line = $0
			trimmed = line
			sub(/^[ \t]*;?[ \t]*/, "", trimmed)
			name = trimmed
			sub(/[ \t]*=.*/, "", name)
			if (name == key) {
				print key " = " val
				found = 1
				next
			}
			print line
		}
		END {
			if (!found) {
				print key " = " val
			}
		}
	' "$PHPINI" >"$temporary"; then
		rm -f "$temporary"
		return 1
	fi
	cat "$temporary" >"$PHPINI"
	rm -f "$temporary"
}
startInstallation() {
	echo -e "\nPlease enter the item number you want to use:"
	echo -e "[${Cyan}1${Color_Off}] ${Cyan}Install ParsVT CRM${Color_Off}"
	echo -e "[${Cyan}2${Color_Off}] ${Cyan}Repair server configurations${Color_Off}"
	echo -e "[${Cyan}3${Color_Off}] ${Cyan}Update ionCube loader${Color_Off}"
	echo -e "[${Cyan}4${Color_Off}] ${Cyan}Install ClamAV (not recommended for low-end servers)${Color_Off}"
	echo -e "[${Cyan}5${Color_Off}] ${Cyan}Install SSL certificate${Color_Off}"
	echo -e "[${Cyan}6${Color_Off}] ${Cyan}Upgrade PHP to 8.3 (run '2' before and after this)${Color_Off}"
	echo -e "[${Yellow}7${Color_Off}] ${Yellow}Install ParsVT CRM (national internet)${Color_Off}"
	echo -e "[${Yellow}0${Color_Off}] ${Yellow}Cancel installation${Color_Off}\n"
	read -r -p "Please select an action (1-7): " run || exit
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
		installationType="PHP"
	elif [ "$run" == "7" ]; then
		installationType="Install2"
	elif [ "$run" == "0" ]; then
		echo -e "\n${Red}The operation aborted!${Color_Off}"
		echo -e "${Yellow}www.parsvt.com${Color_Off}\n"
		exit
	else
		startInstallation
	fi
}
checkInternetConnection() {
	local host="8.8.8.8" http_status=1
	if [ "$installationType" = "Install2" ]; then
		host="$primarySite"
	fi
	if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
		echo -e "\n${Green}Internet connection is UP - $(date +%Y-%m-%d_%H:%M:%S_%Z)${Color_Off}"
		INTERNET_STATUS="UP"
		return 0
	fi
	if command -v curl >/dev/null 2>&1; then
		if curl -fsS --max-time 15 -o /dev/null "http://${primarySite}/ip.php" 2>/dev/null; then
			http_status=0
		fi
	elif command -v wget >/dev/null 2>&1; then
		if wget -q --timeout=15 --spider "http://${primarySite}/ip.php" 2>/dev/null; then
			http_status=0
		fi
	fi
	if [ "$http_status" -eq 0 ]; then
		echo -e "\n${Green}Internet connection is UP - $(date +%Y-%m-%d_%H:%M:%S_%Z)${Color_Off}"
		INTERNET_STATUS="UP"
		return 0
	fi
	echo -e "\n${Red}Internet connection is DOWN - $(date +%Y-%m-%d_%H:%M:%S_%Z)${Color_Off}"
	INTERNET_STATUS="DOWN"
	output "Please check the server's internet connection and DNS settings and run the installer again."
	output "\n${Red}The operation aborted!${Color_Off}"
	output "${Yellow}www.parsvt.com${Color_Off}\n"
	exit
}
setDNS() {
	read -r -p "Do you want to use Shecan as DNS during installation? (y/n): " rundns || exit
	if [ "$rundns" = "y" ] || [ "$rundns" = "yes" ] || [ "$rundns" = "Y" ] || [ "$rundns" = "Yes" ] || [ "$rundns" = "YES" ] || [ "$rundns" = "1" ]; then
		if [ ! -e /etc/resolv.conf.parsvt ]; then
			cp -p /etc/resolv.conf /etc/resolv.conf.parsvt 2>/dev/null || true
		fi
		printf 'nameserver %s\nnameserver %s\n' "$shecanDNS1" "$shecanDNS2" >/etc/resolv.conf
	elif [ "$rundns" = "n" ] || [ "$rundns" = "no" ] || [ "$rundns" = "N" ] || [ "$rundns" = "No" ] || [ "$rundns" = "NO" ] || [ "$rundns" = "0" ]; then
		echo -e "${Yellow}OK!${Color_Off}"
	else
		setDNS
	fi
}
restoreDNS() {
	if [ -e /etc/resolv.conf.parsvt ]; then
		cat /etc/resolv.conf.parsvt >/etc/resolv.conf 2>/dev/null || cp -f /etc/resolv.conf.parsvt /etc/resolv.conf 2>/dev/null || true
		rm -f /etc/resolv.conf.parsvt
	fi
}
getLicense() {
	read -r -p "Please enter your ParsVT CRM license key: " LICENSEKEY || exit
	LICENSEKEY=${LICENSEKEY//[[:blank:]]/}
}
precheckLicense() {
	local chrlen=${#LICENSEKEY}
	if [ "$chrlen" -ne 26 ] && [ "$chrlen" -ne 25 ]; then
		return 1
	fi
	if [[ $LICENSEKEY != ParsVT* ]] && [[ $LICENSEKEY != Cloud* ]]; then
		return 1
	fi
	return 0
}
checkLicense() {
	while true; do
		if [ "$counter" -ge 3 ]; then
			echo -e "\n${Red}The number of incorrect entries exceeded!${Color_Off}"
			echo -e "\n${Red}The operation aborted!${Color_Off}"
			echo -e "${Yellow}www.parsvt.com${Color_Off}\n"
			exit
		fi
		getLicense
		if precheckLicense; then
			return 0
		fi
		echo -e "${Red}The license key is invalid!${Color_Off}"
		counter=$((counter + 1))
	done
}
setAdminPassword() {
	adminPWD=$(randomPassword 15)
	mysqlPWD=$(ADMINPW="$adminPWD" php -r 'echo crypt(getenv("ADMINPW"), "ad");' 2>/dev/null) || die "${Red}Failed to generate the CRM admin password hash!${Color_Off}"
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
		PHPINI=$(php -r 'echo php_ini_loaded_file();' 2>/dev/null || true)
	fi
	if [ -z "$PHPINI" ] || [ ! -f "$PHPINI" ]; then
		PHPINI="/etc/php.ini"
		return 1
	fi
	return 0
}
restartApache() {
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		systemctl restart httpd || die "${Red}Apache (httpd) failed to restart!${Color_Off}"
		if systemctl cat php-fpm >/dev/null 2>&1; then
			systemctl enable php-fpm >/dev/null 2>&1 || true
			systemctl restart php-fpm >/dev/null 2>&1 || output "${Yellow}Warning: php-fpm failed to restart!${Color_Off}"
		fi
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
	local STATUS="Disabled"
	if command -v getenforce >/dev/null 2>&1; then
		STATUS=$(getenforce 2>/dev/null || echo "Disabled")
	fi
	if [ "$STATUS" = "disabled" ] || [ "$STATUS" = "Disabled" ]; then
		if [ "$installationType" = "Install2" ]; then
			output "${Green}SELinux is already disabled!${Color_Off}"
		else
			output "\n${Green}SELinux is already disabled!${Color_Off}"
		fi
	else
		if [ "$installationType" = "Install2" ]; then
			output "${Cyan}Disabling SELinux...${Color_Off}"
		else
			output "\n${Cyan}Disabling SELinux...${Color_Off}"
		fi
		setenforce 0 >/dev/null 2>&1 || true
		if [ -f /etc/selinux/config ]; then
			sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
			sed -i -e 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
		fi
		output "${Green}SELinux successfully disabled!${Color_Off}"
	fi
}
updatePackage() {
	if grep -qw "CentOS" /etc/redhat-release 2>/dev/null; then
		if ! { [ "$major" = "9" ] || [ "$major" = "10" ]; }; then
			output "\n${Cyan}Fixing deprecated CentOS repositories...${Color_Off}"
			sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/CentOS-*.repo 2>/dev/null || true
			sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/CentOS-*.repo 2>/dev/null || true
			sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/CentOS-*.repo 2>/dev/null || true
			output "${Green}Deprecated CentOS repositories successfully fixed!${Color_Off}"
		fi
	fi
	if [ "$installationType" = "Install2" ]; then
		if grep -qw "AlmaLinux" /etc/redhat-release 2>/dev/null; then
			output "\n${Cyan}Fixing AlmaLinux repositories...${Color_Off}"
			sed -i 's/repo.almalinux.org/mirror.mobinhost.com/g' /etc/yum.repos.d/almalinux-*.repo 2>/dev/null || true
			sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/almalinux-*.repo 2>/dev/null || true
			sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/almalinux-*.repo 2>/dev/null || true
			if [ -f "/etc/yum.repos.d/epel.repo" ]; then
				sed -i 's/download.example\/pub/mirror.mobinhost.com/g' /etc/yum.repos.d/epel*.repo 2>/dev/null || true
				sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/epel*.repo 2>/dev/null || true
				sed -i 's/^metalink=http/#metalink=http/g' /etc/yum.repos.d/epel*.repo 2>/dev/null || true
			fi
			if [ -f "/etc/yum.repos.d/remi.repo" ]; then
				sed -i 's/rpms.remirepo.net/mirror.aweb.co\/remi/g' /etc/yum.repos.d/remi*.repo 2>/dev/null || true
				sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/remi*.repo 2>/dev/null || true
				sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/remi*.repo 2>/dev/null || true
				sed -i 's/baseurl=https/baseurl=http/g' /etc/yum.repos.d/remi*.repo 2>/dev/null || true
			fi
			output "${Green}AlmaLinux repositories successfully fixed!${Color_Off}"
		fi
	fi
	output "\n${Cyan}Updating installed packages...${Color_Off}"
	if [ "$PKG" = "dnf" ]; then
		if grep -qw "CentOS" /etc/redhat-release 2>/dev/null && ! grep -qw "Stream" /etc/redhat-release 2>/dev/null; then
			output "${Cyan}Converting from CentOS Linux to CentOS Stream...${Color_Off}"
			dnf --disablerepo '*' --enablerepo extras swap centos-linux-repos centos-stream-repos -y || true
			dnf distro-sync -y || true
			output "${Green}CentOS successfully converted!${Color_Off}\n"
		fi
		dnf install --skip-broken dnf dnf-plugins-core -y || true
		if [ "$major" = "8" ]; then
			dnf update --skip-broken --nobest -y || true
		else
			dnf update --skip-broken -y || true
		fi
	else
		yum update --skip-broken -y || true
	fi
	output "${Green}Installed packages successfully updated!${Color_Off}"
}
installPackage() {
	output "\n${Cyan}Installing required packages...${Color_Off}"
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		dnf install --skip-broken wget curl expect psmisc net-tools yum-utils zip unzip tar crontabs tzdata chrony bind-utils -y || true
	else
		yum install --skip-broken wget curl expect psmisc net-tools yum-utils zip unzip tar crontabs tzdata ntp ntpdate ntp-doc bind-utils -y || true
	fi
	if [ "$major" = "9" ] || [ "$major" = "10" ]; then
		dnf install --skip-broken initscripts -y || true
	fi
	output "${Green}Required packages successfully installed!${Color_Off}\n"
}
installIonCube() {
	cd /tmp
	rm -rf ioncube_loaders_lin*.tar.gz* ioncube
	if [ "$ARCH" = "x86_64" ]; then
		if ! downloadFile "/modules/addons/easyservice/Installer/ioncube_loaders_lin_x86-64.tar.gz" "ioncube_loaders_lin_x86-64.tar.gz"; then
			cd /root
			die "${Red}Unable to download the ionCube loader package!${Color_Off}"
		fi
	else
		if ! downloadFile "/modules/addons/easyservice/Installer/ioncube_loaders_lin_x86.tar.gz" "ioncube_loaders_lin_x86-64.tar.gz"; then
			cd /root
			die "${Red}Unable to download the ionCube loader package!${Color_Off}"
		fi
	fi
	if ! tar xfz ioncube_loaders_lin_x86-64.tar.gz; then
		cd /root
		die "${Red}The ionCube loader package is corrupted!${Color_Off}"
	fi
	PHP_CONFD="/etc/php.d"
	PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
	if [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		PHP_EXT_DIR=$(php -r 'echo ini_get("extension_dir");')
	else
		PHP_EXT_DIR=$(php-config --extension-dir 2>/dev/null || php -r 'echo ini_get("extension_dir");')
	fi
	if [ ! -f "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" ]; then
		cd /root
		die "${Red}ionCube loader is not available for PHP ${PHP_VERSION}!${Color_Off}"
	fi
	mkdir -p "$PHP_EXT_DIR" "$PHP_CONFD"
	cp -f "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" "$PHP_EXT_DIR"/
	printf 'zend_extension = %s/ioncube_loader_lin_%s.so\n' "$PHP_EXT_DIR" "$PHP_VERSION" >"${PHP_CONFD}/00-ioncube.ini"
	rm -rf ./ioncube ioncube_loaders_lin*.tar.gz*
	cd /root
	restartApache
}
installTimezonedb() {
	if ! getPHPConfigPath; then
		output "${Red}PHP configuration file (php.ini) was not found!${Color_Off}"
		output "${Yellow}Skipping the timezonedb installation.${Color_Off}\n"
		return 0
	fi
	if grep -q "extension=timezonedb.so" "$PHPINI"; then
		output "${Green}timezonedb extension is already installed!${Color_Off}\n"
		return 0
	fi
	output "${Cyan}Installing timezonedb extension...${Color_Off}"
	cd /tmp
	rm -rf timezonedb*
	mkdir -p timezonedb
	cd timezonedb
	if ! downloadFile "/modules/addons/easyservice/Installer/timezonedb-2026.6.tgz" "timezonedb-2026.6.tgz"; then
		cd /root
		rm -rf /tmp/timezonedb*
		die "${Red}Unable to download the timezonedb package!${Color_Off}"
	fi
	pear install timezonedb-2026.6.tgz || output "${Yellow}Warning: pear reported an error while installing timezonedb!${Color_Off}"
	if ! grep -q "extension=timezonedb.so" "$PHPINI"; then
		printf '\n; Added by the ParsVT installer\nextension=timezonedb.so\n' >>"$PHPINI"
	fi
	rm -rf /tmp/timezonedb*
	cd /root
	restartApache
	date
	if command -v hwclock >/dev/null 2>&1; then
		hwclock >/dev/null 2>&1 || true
	fi
	output "${Green}timezonedb extension successfully installed!${Color_Off}\n"
}
setRequirements() {
	output "${Cyan}Setting ParsVT requirements...${Color_Off}"
	if ! getPHPConfigPath; then
		die "${Red}PHP configuration file (php.ini) was not found!${Color_Off}"
	fi
	setIniDirective max_execution_time 600
	setIniDirective memory_limit 512M
	setIniDirective short_open_tag On
	setIniDirective max_input_vars 10000
	setIniDirective log_errors On
	setIniDirective display_errors Off
	setIniDirective error_reporting "E_ALL & ~E_NOTICE & ~E_WARNING & ~E_DEPRECATED & ~E_STRICT"
	setIniDirective output_buffering 4096
	setIniDirective file_uploads On
	setIniDirective post_max_size 128M
	setIniDirective upload_max_filesize 128M
	setIniDirective max_input_time 600
	setIniDirective zlib.output_compression Off
	setIniDirective session.gc_maxlifetime 21600
	setIniDirective session.gc_divisor 1000
	setIniDirective session.gc_probability 1
	setIniDirective default_socket_timeout 600
	setIniDirective date.timezone Asia/Tehran
	setIniDirective session.use_strict_mode 1
	setIniDirective session.cookie_httponly 1
	setIniDirective expose_php Off
	if grep -qE "^[[:space:]]*session\.cookie_secure[[:space:]]*=[[:space:]]*1" "$PHPINI"; then
		sed -i -r 's|^[[:space:]]*session\.cookie_secure[[:space:]]*=.*|;session.cookie_secure =|' "$PHPINI"
	fi
	httpdfile="/etc/httpd/conf/httpd.conf"
	if [ -f "$httpdfile" ]; then
		sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' "$httpdfile"
		if ! grep -qiE '^[[:space:]]*Timeout[[:space:]]' "$httpdfile"; then
			printf '\nTimeout 600\n' >>"$httpdfile"
		fi
		if ! grep -qiE '^[[:space:]]*ServerTokens[[:space:]]' "$httpdfile"; then
			printf 'ServerTokens Prod\n' >>"$httpdfile"
		fi
		if ! grep -qiE '^[[:space:]]*ServerSignature[[:space:]]' "$httpdfile"; then
			printf 'ServerSignature Off\n' >>"$httpdfile"
		fi
	fi
	restartApache
	output "${Green}ParsVT requirements have been set!${Color_Off}\n"
}
installJavaPackages() {
	local arch="x64"
	if [ "$ARCH" != "x86_64" ]; then
		arch="i586"
	fi
	"$PKG" install --skip-broken "http://files.aweb.asia/JAVA/jdk-8u${JavaVersion}-linux-${arch}.rpm" -y || true
	"$PKG" install --skip-broken "http://files.aweb.asia/JAVA/jre-8u${JavaVersion}-linux-${arch}.rpm" -y || true
}
installJava() {
	if java -version 2>&1 | grep -q "1\.8\.0_"; then
		output "${Green}Java libraries are already installed!${Color_Off}\n"
	elif java -version 2>&1 | grep -q "java version"; then
		output "${Cyan}Updating Java libraries...${Color_Off}"
		installJavaPackages
		if java -version 2>&1 | grep -q "1\.8\.0_"; then
			output "${Green}Java libraries successfully updated!${Color_Off}\n"
		else
			output "${Red}Java libraries failed to update!${Color_Off}\n"
		fi
	else
		output "${Cyan}Installing Java libraries...${Color_Off}"
		installJavaPackages
		if java -version 2>&1 | grep -q "1\.8\.0_"; then
			output "${Green}Java libraries successfully installed!${Color_Off}\n"
		else
			output "${Red}Java libraries failed to install!${Color_Off}"
			output "You have to install JDK and JRE 1.8 or higher manually."
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			exit
		fi
	fi
}
openPorts() {
	output "${Cyan}Opening required firewall ports...${Color_Off}"
	local ports="80 443 143 993 110 995 22 25 2525 587 465 3306 5038 9999 7777 2222 8080 8081 8443 10000"
	local services="http https imaps ssh smtp ntp"
	local port service
	if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
		if systemctl is-active --quiet firewalld; then
			systemctl enable firewalld >/dev/null 2>&1 || true
			for service in $services; do
				firewall-cmd --zone=public --permanent --add-service="$service" >/dev/null 2>&1 || true
			done
			for port in $ports; do
				firewall-cmd --zone=public --permanent --add-port="${port}/tcp" >/dev/null 2>&1 || true
			done
			firewall-cmd --reload >/dev/null 2>&1 || true
		fi
	else
		if systemctl is-active --quiet iptables; then
			for port in $ports; do
				iptables -C INPUT -p tcp -m tcp --dport "$port" -j ACCEPT >/dev/null 2>&1 ||
					iptables -A INPUT -p tcp -m tcp --dport "$port" -j ACCEPT || true
			done
			service iptables save >/dev/null 2>&1 || true
		fi
	fi
	output "${Green}Required firewall ports successfully opened!${Color_Off}"
}
mysqlConnection() {
	local mysql_db_host mysql_root_name mysql_db_name attempts=0 password_attempts=0
	read -r -p "Enter your MySQL hostname (default: $(tput bold)localhost$(tput sgr0)): " mysql_db_host || exit
	DBHOST="${mysql_db_host:=localhost}"
	read -r -p "Enter your MySQL username (default: $(tput bold)root$(tput sgr0)): " mysql_root_name || exit
	DBUSER="${mysql_root_name:=root}"
	while true; do
		if [ "$password_attempts" -ge 3 ]; then
			die "${Red}Connection failed: unable to connect to the MySQL server!${Color_Off}"
		fi
		read -r -s -p "Enter your MySQL password: " DBPassword || exit
		echo
		saveDBPassword
		if MYSQL_PWD="$DBPassword" mysql --host="$DBHOST" --user="$DBUSER" -e "SELECT 1" >/dev/null 2>&1; then
			output "${Green}Connection successfully established!${Color_Off}\n"
			break
		fi
		output "${Red}Connection failed: unable to connect to the MySQL server!${Color_Off}"
		password_attempts=$((password_attempts + 1))
	done
	read -r -p "Enter your new MySQL database (default: $(tput bold)parsvt$(tput sgr0)): " mysql_db_name || exit
	DBNAME="${mysql_db_name:=parsvt}"
	DBNAME="${DBNAME//[^A-Za-z0-9_]/}"
	if [ -z "$DBNAME" ]; then
		DBNAME="parsvt"
	fi
	output "Database information:"
	output "Database hostname: ${Yellow}${DBHOST}${Color_Off}"
	output "Database username: ${Yellow}${DBUSER}${Color_Off}"
	output "Database password: ${Yellow}${DBPassword}${Color_Off}"
	output "Database name: ${Yellow}${DBNAME}${Color_Off}\n"
	output "Setting up your new database..."
	mysqlExec -e "CREATE DATABASE IF NOT EXISTS \`${DBNAME}\` CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';"
	output "${Green}Database successfully created!${Color_Off}\n"
}
sslDomain() {
	local domain="" staticip="" confirmdomain=""
	while true; do
		read -r -p "Please enter your domain name (example.com): " domain || exit
		domain="${domain#http://}"
		domain="${domain#https://}"
		domain="${domain%%/*}"
		domain="${domain%.}"
		if [[ $domain =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]]; then
			break
		fi
		output "${Red}The domain name is invalid!${Color_Off}"
	done
	staticip=$(wget --no-check-certificate -O- -q "http://$primarySite/ip.php" 2>/dev/null || true)
	read -r -p "Are you sure you have created a DNS (A record) to connect the domain $(tput bold)${domain}$(tput sgr0) to the static IP $(tput bold)${staticip}$(tput sgr0)? (y/n): " confirmdomain || exit
	case "$confirmdomain" in
		y|Y|yes|Yes|YES|1) ;;
		*)
			sslDomain
			return 0
			;;
	esac
	if ! command -v certbot >/dev/null 2>&1; then
		die "${Red}certbot is not installed!${Color_Off}"
	fi
	if [ -e "/var/www/$domain" ] && [ ! -L "/var/www/$domain" ]; then
		die "${Red}/var/www/$domain already exists and it is not a symbolic link!${Color_Off}"
	fi
	ln -sfn "${SETUPDIR:-/var/www/html}" "/var/www/$domain"
	if ! downloadFile "/modules/addons/easyservice/Installer/domain.txt" "/etc/httpd/conf.d/$domain.conf"; then
		die "${Red}Unable to download the virtual host template!${Color_Off}"
	fi
	sed -i -e "s/example.com/$domain/g" "/etc/httpd/conf.d/$domain.conf"
	if ! httpd -t; then
		rm -f "/etc/httpd/conf.d/$domain.conf"
		die "${Red}The Apache configuration is invalid!${Color_Off}"
	fi
	restartApache
	if ! certbot --apache -d "$domain"; then
		die "${Red}Failed to issue the SSL certificate for ${domain}!${Color_Off}"
	fi
	certbot renew --dry-run || output "${Yellow}Warning: the certificate renewal test failed, please renew the certificate manually.${Color_Off}"
	addCronJob "0 0,12 * * * sleep \$((RANDOM % 3600)) && certbot renew -q" "certbot renew"
	systemctl enable --now crond >/dev/null 2>&1 || true
	systemctl daemon-reload >/dev/null 2>&1 || true
	restartApache
	output "${Green}SSL certificate successfully installed!${Color_Off}\n"
}
echo -e "\n${Yellow}██████   █████  ██████  ███████ ██    ██ ████████"
echo -e "██   ██ ██   ██ ██   ██ ██      ██    ██    ██   "
echo -e "██████  ███████ ██████  ███████ ██    ██    ██   "
echo -e "██      ██   ██ ██   ██      ██  ██  ██     ██   "
echo -e "██      ██   ██ ██   ██ ███████   ████      ██   \n"
echo -e "Shell script to install ParsVT CRM on Linux."
echo -e "Please run as root. if you are not, enter '0' now and enter 'sudo su' before running the script.${Color_Off}"
if [ "$(id -u)" -ne 0 ]; then
	echo -e "\n${Red}This script must be run as root!${Color_Off}"
	echo -e "Please enter 'sudo su' and run the script again."
	echo -e "\n${Red}The operation aborted!${Color_Off}"
	echo -e "${Yellow}www.parsvt.com${Color_Off}\n"
	exit
fi
trap 'restoreDNS' EXIT
trap 'exit 130' INT TERM
startInstallation
restoreDNS
cd /root
if [ "$installationType" = "Install" ] || [ "$installationType" = "Install2" ]; then
	if [ -e /var/www/html/config.inc.php ]; then
		output "\n${Red}VtigerCRM already exists!${Color_Off}"
		output "Continuing will ${Red}destroy the existing data${Color_Off}!"
		read -r -p "Type 'yes' to continue, anything else cancels the installation: " confirmreset || exit
		if [ "$confirmreset" != "yes" ]; then
			output "\n${Red}The operation aborted!${Color_Off}"
			output "${Yellow}www.parsvt.com${Color_Off}\n"
			exit
		fi
		INSTALLTYPE="Exist"
	fi
	if ! { [ "$installationType" = "Install2" ]; }; then
		checkInternetConnection
	fi
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
		if [ "$installationType" = "Install2" ]; then
			if [ ! -f "/etc/almalinux-release" ]; then
				output "\n${Red}Operating system is not supported!${Color_Off}"
				output "ParsVT (No-Internet) installer only installs on AlmaLinux 9."
				output "\n${Red}The operation aborted!${Color_Off}"
				output "${Yellow}www.parsvt.com${Color_Off}\n"
				exit
			fi
			if ! { [ "$major" = "9" ]; }; then
				output "\n${Red}Operating system is not supported!${Color_Off}"
				output "ParsVT (No-Internet) installer only installs on AlmaLinux 9."
				output "\n${Red}The operation aborted!${Color_Off}"
				output "${Yellow}www.parsvt.com${Color_Off}\n"
				exit
			fi
		fi
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
				read -r -p "Please select an IP address: " DEVS || exit
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
		RESPONSE=$(curl -fsS --max-time 60 -d "licenseid=$LICENSEKEY&serverip=$ETH_DEV" -H "Content-Type: application/x-www-form-urlencoded" -X POST "http://$primarySite/modules/addons/easyservice/Installer/check.php") || die "${Red}Unable to connect to the license server!${Color_Off}"
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
		if ! { [ "$installationType" = "Install2" ]; }; then
			setDNS
		fi
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
		if [ "$installationType" = "Install2" ]; then
			if grep -rnwq "/etc/redhat-release" -e "AlmaLinux"; then
				if [ -f "/etc/yum.repos.d/epel.repo" ]; then
					sed -i 's/download.example\/pub/mirror.mobinhost.com/g' /etc/yum.repos.d/epel*.repo
					sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/epel*.repo
					sed -i 's/^metalink=http/#metalink=http/g' /etc/yum.repos.d/epel*.repo
				fi
				if [ -f "/etc/yum.repos.d/remi.repo" ]; then
					sed -i 's/rpms.remirepo.net/mirror.aweb.co\/remi/g' /etc/yum.repos.d/remi*.repo
					sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/remi*.repo
					sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/remi*.repo
					sed -i 's/baseurl=https/baseurl=http/g' /etc/yum.repos.d/remi*.repo
				fi
			fi
		fi
		if [ "$major" = "8" ]; then
			dnf config-manager --set-enabled powertools
			dnf install --enablerepo=remi,powertools --skip-broken epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA proxychains-ng -y
		elif [ "$major" = "9" ]; then
			dnf config-manager --set-enabled crb
			dnf install --enablerepo=remi,crb --skip-broken epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA proxychains-ng -y
			set +e
			dnf install --enablerepo=remi,crb --skip-broken epel-next-release -y
			set -e
		elif [ "$major" = "10" ]; then
			dnf config-manager --set-enabled crb
			dnf install --enablerepo=remi,crb --skip-broken epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA proxychains-ng -y
		else
			yum install --enablerepo=remi --skip-broken epel-release perl perl-Net-SSLeay openssl perl-IO-Tty perl-Encode-Detect htop iotop perl-Digest-MD5 perl-Digest-SHA proxychains-ng -y
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
				dnf install --enablerepo=remi,remi-php83 --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-curl php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql php-mysqlnd php-sqlsrv php-xz php-fpm php-pdo curl-devel unixODBC-devel make -y
			elif [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
				output "${Cyan}Installing Apache and PHP...${Color_Off}"
				dnf module reset php -y
				dnf module install php:remi-8.3 -y
				dnf install --enablerepo=remi --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-curl php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql php-mysqlnd php-sqlsrv php-xz php-fpm php-pdo curl-devel unixODBC-devel make -y
			else
				output "${Cyan}Installing Apache and PHP...${Color_Off}"
				yum install --enablerepo=remi,remi-php83 --skip-broken httpd httpd-devel mod_ssl python-certbot-apache certbot php php-common php-zip php-gd php-mbstring php-mcrypt php-devel php-bcmath php-xml php-odbc php-pear php-imap php-curl php-ldap php-openssl php-intl php-xmlrpc php-soap php-mysql php-mysqlnd php-sqlsrv php-xz php-fpm php-pdo curl-devel unixODBC-devel make -y
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
			PHP_VER=$(php -r "if (version_compare(PHP_VERSION,'5.6.0','>=')) echo 'Ok'; else echo 'Failed';")
			PHP_VERSION=$(php -r "echo PHP_VERSION;")
			if [ "$PHP_VER" = "Ok" ]; then
				output "Current PHP version: ${Green}${PHP_VERSION}${Color_Off}\n"
				output "Checking the ionCube loader version..."
				wget --no-check-certificate -q http://$primarySite/modules/addons/easyservice/Installer/ic.txt -O /root/IC.php
				set +e
				IONCUBE_VER=$(php -f /root/IC.php)
				IONCUBE_VERSION=$(php -r "error_reporting(0); echo ioncube_loader_version();")
				set -e
				rm -rf /root/IC.php*
				if [ "$IONCUBE_VER" = "Ok" ]; then
					output "Current ionCube loader version: ${Green}${IONCUBE_VERSION}${Color_Off}\n"
					read -r -p "Enter the directory path of your application (default: $(tput bold)${SETUPDIR}$(tput sgr0)): " app_dir || exit
					app_dir="${app_dir#/}"
					app_dir="${app_dir%/}"
					if [ -n "$app_dir" ]; then
						if ! [[ $app_dir =~ ^[A-Za-z0-9._/-]+$ ]] || [[ $app_dir == *".."* ]]; then
							die "${Red}The application directory is invalid!${Color_Off}"
						fi
						SETUPDIR="/var/www/html/$app_dir"
					fi
					if [ "${SETUPDIR:0:14}" != "/var/www/html/" ] && [ "$SETUPDIR" != "/var/www/html" ]; then
						die "${Red}The application directory must be inside /var/www/html!${Color_Off}"
					fi
					mkdir -p "$SETUPDIR"
					rm -rf "${SETUPDIR:?}"/*
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
				output "Current PHP version: ${Red}${PHP_VERSION}${Color_Off}"
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
				dnf module reset mariadb -y
				dnf module enable mariadb:10.11 -y
				dnf install --enablerepo=remi --skip-broken mariadb mariadb-server mariadb-backup mariadb-common mariadb-devel galera php-mysql php-mysqlnd phpMyAdmin -y
			else
				yum install --enablerepo=remi --skip-broken mariadb mariadb-server mariadb-backup mariadb-common mariadb-devel galera php-mysql php-mysqlnd phpMyAdmin -y
			fi
			pmafile="/etc/httpd/conf.d/phpMyAdmin.conf"
			if [ -f "$pmafile" ]; then
				sed -i '/<Directory \/usr\/share\/phpMyAdmin\/>/,/<\/Directory>/ s/Require local/Require all granted/' /etc/httpd/conf.d/phpMyAdmin.conf
			fi
			DBPassword=$(randomPassword 20)
			saveDBPassword
			(umask 077; printf 'MySQL Username: %s\nMySQL Password: %s\n' "$DBUSER" "$DBPassword" >/root/mysql.txt)
			restartDatabase
			restartApache
			if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
				systemctl enable mariadb
			else
				chkconfig mariadb on
			fi
			mysqladmin -uroot create "$DBNAME" 2>/dev/null || true
			set +e
			if [ "$major" = "9" ] || [ "$major" = "10" ]; then
				SECURE_MYSQL=$(expect -c "
set timeout 60
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
set timeout 60
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
			set -e
			echo "$SECURE_MYSQL"
			if ! MYSQL_PWD="$DBPassword" mysql --user=root -e "SELECT 1" >/dev/null 2>&1; then
				output "${Cyan}Setting the MySQL root password manually...${Color_Off}"
				{
					printf "ALTER USER 'root'@'localhost' IDENTIFIED BY '%s';\n" "$DBPassword"
					printf "DELETE FROM mysql.global_priv WHERE User = '';\n"
					printf "DROP DATABASE IF EXISTS test;\n"
					printf "FLUSH PRIVILEGES;\n"
				} | mysql --user=root >/dev/null 2>&1 || true
			fi
			if ! MYSQL_PWD="$DBPassword" mysql --user=root -e "SELECT 1" >/dev/null 2>&1; then
				die "${Red}The MySQL root password could not be set!${Color_Off}"
			fi
			wget --no-check-certificate -q "http://$primarySite/modules/addons/easyservice/Installer/sqlconf.txt" -O /etc/my.cnf.d/disable_mysql_strict_mode.cnf || output "${Yellow}Warning: the MySQL configuration file could not be downloaded!${Color_Off}"
			restartDatabase
			output "${Green}MySQL (MariaDB) successfully installed!${Color_Off}\n"
			output "${Cyan}Creating database...${Color_Off}"
			mysqlExec -e "CREATE DATABASE IF NOT EXISTS \`${DBNAME}\` CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';"
			mysqlExec -e "ALTER DATABASE \`${DBNAME}\` CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';"
			output "${Green}Database successfully created!${Color_Off}\n"
		fi
		restartDatabase
		output "${Cyan}Installing ParsVT CRM package...${Color_Off}"
		file="$SETUPDIR/latest8.zip"
		if [ ! -f "$file" ]; then
			wget --no-check-certificate -q "http://$primarySite/modules/addons/easyservice/Installer/download.php?v=8" -O "$SETUPDIR"/latest8.zip || die "${Red}Unable to download the ParsVT CRM package!${Color_Off}"
		fi
		if ! unzip -q -o "$SETUPDIR/latest8.zip" -d "$SETUPDIR"; then
			die "${Red}The ParsVT CRM package is corrupted!${Color_Off}"
		fi
		mkdir -p "$SETUPDIR/test/data/modules/"
		file="$SETUPDIR/extensions.zip"
		if [ ! -f "$file" ]; then
			wget --no-check-certificate -q "${RESPONSES[2]}" -O "$SETUPDIR"/extensions.zip || die "${Red}Unable to download the extensions package!${Color_Off}"
		fi
		if ! unzip -q -o "$SETUPDIR/extensions.zip" -d "$SETUPDIR"; then
			die "${Red}The extensions package is corrupted!${Color_Off}"
		fi
		chown -R apache:apache "$SETUPDIR"
		find "$SETUPDIR" -type d -exec chmod 0755 {} \;
		find "$SETUPDIR" -type f -exec chmod 0644 {} \;
		rm -f "$SETUPDIR"/latest8.zip*
		rm -f "$SETUPDIR"/extensions.zip*
		if [ "$INSTALLTYPE" = "Exist" ]; then
			(
				echo 'SET foreign_key_checks = 0;'
				(mysqldumpExec --add-drop-table --no-data "$DBNAME" | grep '^DROP' || true)
				echo 'SET foreign_key_checks = 1;'
			) |
				mysqlExec -b "$DBNAME"
		fi
		mysqlExec "$DBNAME" -e "SET NAMES 'utf8mb4';"
		if [ ! -s "$SETUPDIR/test/data/tmp/database.sql" ]; then
			die "${Red}The database schema file was not found!${Color_Off}"
		fi
		mysqlExec "$DBNAME" <"$SETUPDIR/test/data/tmp/database.sql"
		setAdminPassword
		mysqlExec "$DBNAME" -e "UPDATE vtiger_users SET user_password = '$mysqlPWD', crypt_type = '' WHERE id = '1';"
		mysqlExec "$DBNAME" -e "UPDATE vtiger_users SET accesskey = UPPER(SUBSTRING(MD5(RAND()) FROM 1 FOR 16)) WHERE id = 1;"
		mysqlExec "$DBNAME" -e "TRUNCATE vtiger_crmsetup;"
		mysqlExec "$DBNAME" -e "TRUNCATE vtiger_loginhistory;"
		CRMURL="$ETH_DEV"
		if [ -n "$app_dir" ]; then
			CRMURL="$ETH_DEV/$app_dir"
		fi
		wget --no-check-certificate -q -O /dev/null "http://$CRMURL/_install.php?db_hostname=$(urlEncode "$DBHOST")&db_name=$(urlEncode "$DBNAME")&db_username=$(urlEncode "$DBUSER")&db_password=$(urlEncode "$DBPassword")" || output "${Yellow}Warning: the CRM installer endpoint did not respond as expected!${Color_Off}"
		wget --no-check-certificate -q -O /dev/null "http://$CRMURL/_extensions.php?token=$(urlEncode "${RESPONSES[1]}")" || output "${Yellow}Warning: the extensions endpoint did not respond as expected!${Color_Off}"
		grep "http://$CRMURL/vtigercron.php" /var/spool/cron/root || echo "*/15 * * * * wget --no-check-certificate --spider \"http://$CRMURL/vtigercron.php\" >/dev/null 2>&1" >>/var/spool/cron/root
		rm -rf "$SETUPDIR"/_install*
		rm -rf "$SETUPDIR"/_extensions*
		output "${Green}ParsVT CRM package successfully installed!${Color_Off}\n"
		installJava
		output "${Cyan}Setting backup directory...${Color_Off}"
		if [ -f "/home/backup-$DBNAME.sh" ]; then
			rm -f "/home/backup-$DBNAME.sh"
		fi
		cat >"/home/backup-$DBNAME.sh" <<EOF
#!/bin/bash
set -o pipefail

delfile=\$(date --date='-7 day' +%Y-%d-%m)
today=\$(date +%Y-%d-%m)
backupdirectory='$SETUPDIR2'
storagedirectory='$backupdirectory'
dbname='$DBNAME'
dbhost='$DBHOST'
dbuser='$DBUSER'
passfile='$DBPASSFILE'

if [ ! -r "\$passfile" ]; then
	echo "\$(date +'%F %T') - Database password file \$passfile was not found!" >&2
	exit 1
fi

mkdir -p "\$storagedirectory"
MYSQL_PWD="\$(cat "\$passfile")" mysqldump --host="\$dbhost" --user="\$dbuser" "\$dbname" | gzip -c >"\$storagedirectory/\$dbname-\$today.sql.gz"
tar -czf "\$storagedirectory/\$dbname-\$today.tar.gz" "\$backupdirectory"
rm -f "\$storagedirectory/\$dbname-\$delfile.sql.gz"
rm -f "\$storagedirectory/\$dbname-\$delfile.tar.gz"
EOF
		mkdir -p "$backupdirectory"
		chmod 700 "/home/backup-$DBNAME.sh"
		addCronJob "0 22 * * * sh /home/backup-$DBNAME.sh >/dev/null 2>&1" "backup-$DBNAME.sh"
		output "${Green}Backup directory successfully set!${Color_Off}\n"
		output "${Cyan}Installing Webmin...${Color_Off}"
		if [ "$major" = "7" ] || [ "$major" = "8" ] || [ "$major" = "9" ] || [ "$major" = "10" ]; then
			dnf install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/webmin-2.670-1.noarch.rpm -y
			dnf install --skip-broken webmin -y
		else
			yum install --skip-broken http://$primarySite/modules/addons/easyservice/Installer/webmin-2.670-1.noarch.rpm -y
			yum install --skip-broken webmin -y
		fi
		output "${Green}Webmin successfully installed!${Color_Off}\n"
		openPorts
		systemctl enable --now crond
		systemctl daemon-reload
		output "\n${Yellow} ___            __   _______              "
		output "| _ \__ _ _ _ __\ \ / /_   _|__ ___ _ __  "
		output "|  _/ _\` | '_(_-<\ V /  | |_/ _/ _ \ '  \ "
		output "|_| \__,_|_| /__/ \_/   |_(_)__\___/_|_|_|${Color_Off}\n"
		output "${Green}ParsVT installation successfully completed!${Color_Off}\n"
		output "Webmin Information:"
		output "  Webmin URL:        ${Yellow}http://$ETH_DEV:10000${Color_Off}"
		output "  Webmin Username:   ${Yellow}$(id -un)${Color_Off}"
		output "  Webmin Password:   ${Yellow}$(id -un) SSH Password${Color_Off}\n"
		output "MySQL Information:"
		output "  Database Hostname: ${Yellow}$DBHOST${Color_Off}"
		output "  Database Username: ${Yellow}$DBUSER${Color_Off}"
		output "  Database Password: ${Yellow}$DBPassword${Color_Off}"
		output "  Database Name:     ${Yellow}$DBNAME${Color_Off}\n"
		(umask 077; output "CRM URL:      http://$CRMURL\nCRM Username: admin\nCRM Password: $adminPWD" >/root/crm.txt)
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
			PHP_VER=$(php -r "if (version_compare(PHP_VERSION,'5.6.0','>=')) echo 'Ok'; else echo 'Failed';")
			PHP_VERSION=$(php -r "echo PHP_VERSION;")
			if [ "$PHP_VER" = "Ok" ]; then
				output "Current PHP version: ${Green}${PHP_VERSION}${Color_Off}\n"
				output "Checking the ionCube loader version..."
				wget --no-check-certificate -q http://$primarySite/modules/addons/easyservice/Installer/ic.txt -O /root/IC.php
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
				output "Current PHP version: ${Red}${PHP_VERSION}${Color_Off}"
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
		find /var/www/html -type d -exec chmod 0755 {} \;
		find /var/www/html -type f -exec chmod 0644 {} \;
		output "${Green}Permissions of directories and files successfully fixed!${Color_Off}\n"
		set +e
		openPorts
		set -e
		systemctl enable --now crond
		systemctl daemon-reload
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
		output "ParsVT installer only installs on CentOS and RHEL-based Linuxes."
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
			PHP_VER=$(php -r "if (version_compare(PHP_VERSION,'5.6.0','>=')) echo 'Ok'; else echo 'Failed';")
			PHP_VERSION=$(php -r "echo PHP_VERSION;")
			if [ "$PHP_VER" = "Ok" ]; then
				output "Current PHP version: ${Green}${PHP_VERSION}${Color_Off}\n"
				output "Checking the ionCube loader version..."
				wget --no-check-certificate -q http://$primarySite/modules/addons/easyservice/Installer/ic.txt -O /root/IC.php
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
				output "Current PHP version: ${Red}${PHP_VERSION}${Color_Off}"
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
		output "ParsVT installer only installs on CentOS and RHEL-based Linuxes."
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
		wget --no-check-certificate http://$primarySite/modules/addons/easyservice/Installer/daily_clamscan.txt -O /usr/local/bin/daily_clamscan.sh
		chmod +x /usr/local/bin/daily_clamscan.sh
		setfacl -m u:root:rwx /var/log/clamav
		setfacl -m u:root:rx /usr/local/bin/daily_clamscan.sh
		grep "/usr/local/bin/daily_clamscan.sh" /var/spool/cron/root || echo "0 2 * * * /usr/local/bin/daily_clamscan.sh" >>/var/spool/cron/root
		systemctl enable --now crond
		systemctl daemon-reload
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
		output "ParsVT installer only installs on CentOS and RHEL-based Linuxes."
		output "You have to install SSL manually."
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
if [ "$installationType" = "PHP" ]; then
	checkInternetConnection
	if [ ! -f "/etc/redhat-release" ]; then
		output "\n${Red}Operating system is not supported!${Color_Off}"
		output "ParsVT installer only installs on CentOS and RHEL-based Linuxes."
		output "You have to upgrade PHP manually."
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
			PHP_VER=$(php -r "if (version_compare(PHP_VERSION,'8.3.36','>=')) echo 'Ok'; elseif (version_compare(PHP_VERSION,'5.6.0','>=')) echo 'Upgrade'; else echo 'Failed';")
			PHP_VERSION=$(php -r "echo PHP_VERSION;")
			if [ "$PHP_VER" = "Ok" ]; then
				output "Current PHP version: ${Green}${PHP_VERSION}${Color_Off}\n"
				restoreDNS
				exit
			elif [ "$PHP_VER" = "Upgrade" ]; then
				output "Current PHP version: ${Red}${PHP_VERSION}${Color_Off}"
				output "\n${Cyan}Upgrading PHP...${Color_Off}"
				if [ "$major" = "9" ] || [ "$major" = "10" ]; then
					dnf module reset php -y
					dnf module install php:remi-8.3 -y
					dnf update --skip-broken -y
				else
					output "\n${Red}Operating system is not supported!${Color_Off}"
					output "PHP upgrader only works on version 9/10."
					output "You have to upgrade PHP manually."
					output "\n${Red}The operation aborted!${Color_Off}"
					output "${Yellow}www.parsvt.com${Color_Off}\n"
					exit
				fi
				output "${Green}PHP successfully Upgraded!${Color_Off}\n"
			else
				output "Current PHP version: ${Red}${PHP_VERSION}${Color_Off}"
				output "${Red}PHP version must be greater than 5.5${Color_Off}"
				output "\n${Red}The operation aborted!${Color_Off}"
				output "${Yellow}www.parsvt.com${Color_Off}\n"
				restoreDNS
				exit
			fi
		fi
	fi
fi
restoreDNS
