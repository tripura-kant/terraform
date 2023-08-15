#!/bin/bash

#variable will be populated by terraform template
db_username=${db_username}
db_user_password=${db_user_password}
db_name=${db_name}
db_RDS=${db_RDS}

touch new-file
pwd
#install LAMP Server
sudo yum update -y
#install apache server and mysql client
sudo yum install -y httpd
sudo yum install -y mysql


#first enable php7.xx from amazon-linux-extra and install it

sudo amazon-linux-extras enable php7.4
sudo yum clean metadata
sudo yum install -y php php{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap,devel}
#install imagick extension
sudo yum -y install gcc ImageMagick ImageMagick-devel ImageMagick-perl
sudo yum update -y
#sudo yum install -y php-pear php-devel gcc ImageMagick-devel
sudo pecl install imagick
chmod 755 /usr/lib64/php/modules/imagick.so
cat &lt;&gt;/etc/php.d/20-imagick.ini

extension=imagick

#EOF

systemctl restart php-fpm.service

systemctl start httpd

#Change OWNER and permission of directory /var/www
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

sudo yum -y install mariadb-server
sudo service mariadb start

#*********************Installing Wordpress using WP CLI********************************
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
wp core download --path=/var/www/html --allow-root
wp config create --dbname=$db_name --dbuser=$db_username --dbpass=$db_user_password --dbhost=$db_RDS --path=/var/www/html --allow-root --extra-php &lt;&lt;PHP
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
PHP

Change permission of /var/www/html/
chown -R ec2-user:apache /var/www/html
chmod -R 774 /var/www/html

enable .htaccess files in Apache config using sed command
sed -i '//,// s/AllowOverride None/AllowOverride all/' /etc/httpd/conf/httpd.conf

    #Make apache autostart and restart apache
    systemctl enable httpd.service
    systemctl restart httpd.service
echo WordPress Installed

For the previous userdata script to work, use this block to call your script in terraform:

# -----------------------------------------------
# Change USERDATA variable value after grabbing RDS endpoint info
# -----------------------------------------------
