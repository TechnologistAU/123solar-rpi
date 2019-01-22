#!/bin/bash

# Inverter Support

_AURORA=1
_485SOLAR_GET=1

###############################################################################

_123SOLAR_VER=1.8
_123SOLAR_URL=https://www.123solar.org/downloads/123solar/123solar$_123SOLAR_VER.tar.gz
_123SOLAR_SVC=http://www.123solar.org/downloads/123solar/123solar.service
_485SOLAR_GET_VER=1.000
_485SOLAR_GET_URL=http://downloads.sourceforge.net/project/solarget/485solar-get-$_485SOLAR_GET_VER-sources.tgz
_AURORA_VER=1.9.3
_AURORA_URL=http://www.curtronics.com/Solar/ftp/aurora-$_AURORA_VER.tar.gz
_YASDI_VER=1.8.1build9
_YASDI_URL=http://files.sma.de/dl/11705/yasdi-$_YASDI_VER-src.zip

###############################################################################

GIT_PATH="$(dirname $(readlink -f $0))"

if [[ $(id -u) -ne 0 ]] ; then
	echo "This script must be executed as 'root' (hint: use the 'sudo' command)."
	exit 1
fi

apt-get update
apt-get -y upgrade

# Install Components
apt-get -y install nginx php php-fpm php-cgi php-curl msmtp

PHP_VERSION=$(php -r "echo PHP_VERSION;" | awk -F "." '{printf("%s.%s\n",$1,$2)}')
PHP_FPM=php$PHP_VERSION_fpm

# nginx/PHP
cp $GIT_PATH/nginx.conf /etc/nginx/sites-available/default
sed -i s/php-fpm/$PHP_FPM/g /etc/nginx/sites-available/default

# msmtp
cp $GIT_PATH/msmtprc /etc/msmtprc
chmod 600 /etc/msmtprc
chown www-data:root /etc/msmtprc
sed -i '/;sendmail_path/a sendmail_path = "/usr/bin/msmtp -C /etc/msmtprc -t"' /etc/php/7.0/fpm/php.ini

# 123Solar
wget -P ~ $_123SOLAR_URL
tar -xzvf ~/123solar*.tar.gz -C /var/www/html
rm ~/123solar*.tar.gz
chown -R www-data:www-data /var/www/html/123solar
wget -P /etc/systemd/system $_123SOLAR_SVC
sed -i s/php-fpm/$PHP_FPM/g /etc/systemd/system/123solar.service

# Ports
usermod -a -G dialout www-data

# aurora
if [ $_AURORA -eq 1 ]; then
	wget -P ~ $_AURORA_URL
	tar -xzvf ~/aurora*.tar.gz -C ~
	cd "$(find ~/aurora* | head -1)"
	make
	make install
	cd ~
	rm -fr ~/aurora*
fi

# 485solar-get
if [ $_485SOLAR_GET -eq 1 ]; then
	apt-get -y install cmake

	# YASDI
	wget -P ~ $_YASDI_URL
	unzip ~/yasdi*.zip -d ~/yasdi
	rm ~/yasdi*.zip
	cd ~/yasdi/projects/generic-cmake
	cmake .
	make
	make install
	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
	ldconfig /usr/local/lib
	cp $GIT_PATH/yasdi.ini /etc/yasdi.ini

	# 485solar-get
	wget -P ~ $_485SOLAR_GET_URL
	tar -xzvf ~/485solar-get*.tgz -C ~/yasdi
	rm ~/485solar-get*.tgz
	cd ~/yasdi/485solar-get*
	./make.sh
	cd ~
	rm -fr ~/yasdi
fi

# Exit
systemctl restart nginx $PHP_FPM
systemctl enable 123solar
systemctl start 123solar

echo "Don't forget to configure msmtp, using the following command:"
echo "  sudo nano /etc/msmtprc"
