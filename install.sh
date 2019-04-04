#!/bin/bash

#选择服务器类型
function selectServerType() {
	printf 'Please select the server type [1-All Server/2-Application Server/3-Database Server]:'
	read server_type
	#if [[ $server_type -eq '' ]] || [ $server_type != 1 -a $server_type != 2 -a $server_type != 3 ] ; then
	if [[ $server_type -lt 1 || $server_type -gt 3 ]]; then
		selectServerType
	fi
}
selectServerType

#安装依赖
echo 'Install dependencies start...'
case $server_type in
	1) yum install -y gcc-c++ openssl-devel unzip wget libxml2-devel libcurl-devel libjpeg-turbo-devel libpng-devel freetype-devel openldap-devel pcre-devel cmake ncurses-devel bison perl ;;
	2) yum install -y gcc-c++ openssl-devel unzip wget libxml2-devel libcurl-devel libjpeg-turbo-devel libpng-devel freetype-devel openldap-devel pcre-devel ;;
	3) yum install -y gcc-c++ openssl-devel unzip wget cmake ncurses-devel bison perl ;;
	*) installDependencies ;;
esac
echo 'Install dependencies finish'

#预处理
echo 'Preprocess start...'
basepath=$(cd `dirname $0`; pwd)
mkdir -p /data/sourcecode
echo 'Preprocess finish'

#安装MySQL
if [ $server_type == 1 -o $server_type == 3 ]; then
	echo 'Install mysql start...'
	mkdir -p /data/webserver/mysql/data /data/webserver/mysql/etc
	groupadd mysql
	useradd -r -g mysql mysql -s /bin/false
	chown -R mysql:mysql /data/webserver/mysql
	tar -zxvf $basepath/src/mysql-5.6.27.tar.gz -C /data/sourcecode
	cd /data/sourcecode/mysql-5.6.27
	cmake -DCMAKE_INSTALL_PREFIX=/data/webserver/mysql -DMYSQL_UNIX_ADDR=/data/webserver/mysql/mysql.sock -DMYSQL_DATADIR=/data/webserver/mysql/data -DSYSCONFDIR=/data/webserver/mysql/etc -DINSTALL_SHAREDIR=share -DMYSQL_TCP_PORT=3306 -DDEFAULT_CHARSET=utf8 -DWITH_EXTRA_CHARSETS=all -DDEFAULT_COLLATION=utf8_general_ci -DWITH_ARCHIVE_STORAGE_ENGINE=1 -DWITH_BLACKHOLE_STORAGE_ENGINE=1 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_MYISAM_STORAGE_ENGINE=1 -DENABLED_LOCAL_INFILE=1 -DENABLE_DOWNLOADS=1 -DWITH_SSL=yes
	make
	make install
	rm -f /etc/my.cnf
	cp $basepath/conf/my.cnf /data/webserver/mysql/etc
	/data/webserver/mysql/scripts/mysql_install_db --user=mysql --basedir=/data/webserver/mysql --datadir=/data/webserver/mysql/data --defaults-file=/data/webserver/mysql/etc/my.cnf
	cp $basepath/service/mysqld /etc/rc.d/init.d
	chmod 755 /etc/rc.d/init.d/mysqld
	chkconfig mysqld on
	service mysqld start
	sed -i '$a PATH=$PATH:/data/webserver/mysql/bin' /etc/profile
	source /etc/profile
	echo 'Install mysql finish'
fi

#安装PHP和Nginx
if [ $server_type == 1 -o $server_type == 2 ]; then
	echo 'Install php start...'
	tar -zxvf $basepath/src/mhash-0.9.9.9.tar.gz -C /data/sourcecode
	cd /data/sourcecode/mhash-0.9.9.9
	./configure
	make
	make install

	tar -zxvf $basepath/src/libmcrypt-2.5.8.tar.gz -C /data/sourcecode
	cd /data/sourcecode/libmcrypt-2.5.8
	./configure
	make
	make install

	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
	tar -zxvf $basepath/src/mcrypt-2.6.8.tar.gz -C /data/sourcecode
	cd /data/sourcecode/mcrypt-2.6.8
	./configure
	make
	make install

	groupadd www
	useradd -g www www -s /bin/false
	ln -s /usr/lib64/libldap* /usr/lib/
	tar -zxvf $basepath/src/php-5.6.16.tar.gz -C /data/sourcecode
	cd /data/sourcecode/php-5.6.16
	./configure --prefix=/data/webserver/php --with-config-file-path=/data/webserver/php/etc --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --enable-bcmath --enable-fpm --enable-ftp --enable-gd-native-ttf --enable-mbstring --enable-pcntl --enable-shmop --enable-soap --enable-sockets --enable-sysvsem --enable-zip --disable-rpath --with-curl --with-freetype-dir --with-gd --with-gettext --with-iconv --with-jpeg-dir --with-ldap --with-ldap-sasl --with-libxml-dir --with-mcrypt --with-mhash --with-openssl --without-pear --with-png-dir --with-xmlrpc --with-zlib
	make
	make install

	mkdir /data/webserver/php/var/session
	chown www:www /data/webserver/php/var/session
	cp $basepath/conf/php.ini /data/webserver/php/etc
	rm -f /data/webserver/php/etc/php-fpm.conf.default
	cp $basepath/conf/php-fpm.conf /data/webserver/php/etc
	cp ./sapi/fpm/init.d.php-fpm /etc/rc.d/init.d/php-fpm
	chmod 775 /etc/rc.d/init.d/php-fpm
	chkconfig php-fpm on
	service php-fpm start
	echo 'Install php finish'

	echo 'Install nginx start...'
	tar -zxvf $basepath/src/nginx-1.9.7.tar.gz -C /data/sourcecode
	cd /data/sourcecode/nginx-1.9.7
	./configure --prefix=/data/webserver/nginx --user=www --group=www --with-http_flv_module --with-http_gzip_static_module --with-http_ssl_module --with-http_stub_status_module --with-pcre
	make
	make install
	mkdir /data/wwwroot
	cp $basepath/code/index.php /data/wwwroot
	rm -f /data/webserver/nginx/conf/nginx.conf.default
	cp $basepath/conf/nginx.conf /data/webserver/nginx/conf
	cp $basepath/service/nginx /etc/rc.d/init.d
	chmod 775 /etc/rc.d/init.d/nginx
	chkconfig nginx on
	service nginx start
	echo 'Install nginx finish'
fi

echo 'Congratulations, the installation is complete.'