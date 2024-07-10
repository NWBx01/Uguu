#!/bin/bash

service nginx stop

echo "Seting up Uguu"
make no-dependencies && make install

echo "Uguu starting..."


rm /etc/nginx/sites-enabled/default

# If EXPIRE_TIME is non-zero, setup scripts for file expiration
if [ ! ${EXPIRE_TIME} = "0" ]; then \
	# Add scripts to cron
	echo "0,30 * * * * bash /var/www/uguu/src/static/scripts/checkfiles.sh" >> /var/spool/cron/crontabs/www-data; \
	echo "0,30 * * * * bash /var/www/uguu/src/static/scripts/checkdb.sh" >> /var/spool/cron/crontabs/www-data; \

	# Fix script paths
	chmod a+x /var/www/uguu/src/static/scripts/checkdb.sh; \
	chmod a+x /var/www/uguu/src/static/scripts/checkfiles.sh; \
	sed -i 's#/path/to/files/#${FILES_ROOT}#g' /var/www/uguu/src/static/scripts/checkfiles.sh; \
	sed -i 's#/path/to/db/uguu.sq3#${DB_PATH}#g' /var/www/uguu/src/static/scripts/checkdb.sh; \

	# Modify expire time
	sed -i "s#XXX#${EXPIRE_TIME}#g" /var/www/uguu/src/static/scripts/checkfiles.sh; \
	sed -i "s#XXX#${EXPIRE_TIME}#g" /var/www/uguu/src/static/scripts/checkdb.sh; \
fi

# Modify nginx values
sed -i "s#XMAINDOMAINX#${DOMAIN}#g" /etc/nginx/sites-enabled/uguu.conf
sed -i "s#XFILESDOMAINX#${FILE_DOMAIN}#g" /etc/nginx/sites-enabled/uguu.conf
sed -i "s#client_max_body_size 128M#client_max_body_size ${MAX_UPLOAD_SIZE}M#g" /etc/nginx/nginx.conf

# If SSL is false, then change settings so that files are served by plain HTTP.
# Else leave everything as-is and generate SSL certs via Let's Encrypt
if [ ${SSL} = "false" ]; then \
	sed -i "s#ssl on#ssl off#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#443 ssl http2#80#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#443 ssl#80#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#ssl_#\#ssl_#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#resolver#\#resolver#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#add_header#\#add_header#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#https#http#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#80;#443;#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#https#http#g" /var/www/uguu/dist/Classes/Upload.php; \
	else \
	/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt; \
	/root/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" -d "$FILE_DOMAIN"; \
fi

# Modify php-fpm values
sed -i "s#post_max_size = 8M#post_max_size = ${MAX_UPLOAD_SIZE}M#g" /etc/php/8.3/fpm/php.ini
sed -i "s#upload_max_filesize = 2M#upload_max_filesize = ${MAX_UPLOAD_SIZE}M#g" /etc/php/8.3/fpm/php.ini

# Create config.json from template and substitute in environment variable values.
envsubst < /var/www/uguu/config-template.json > /var/www/uguu/dist/config.json 

# If an Uguu database is not found, create one.
if [ ! -e ${DB_PATH} ]; then echo "Creating new Uguu database." && sqlite3 ${DB_PATH} -init /var/www/uguu/src/static/dbSchemas/sqlite_schema.sql ""; else echo "Uguu database found."; fi

cd /var/www/moepanel

if [ ${MOE_FIRST_RUN} = "true" ]; then \
	sed -i "s#YOURPASSWORDHERE#${MOE_PASS}#g" /var/www/moepanel/gen_pw.php; \
	php /var/www/moepanel/gen_pw.php > /tmp/password_hash.txt; \
    passhash=$(cat /tmp/password_hash.txt); \
    make; \
    sqlite3 ${DB_PATH} "INSERT INTO accounts VALUES(1,'${MOE_USER}','$passhash',1);"; \
fi

if [ ${MOE_REBUILD} = "true" ]; then \
    echo "Setting up MoePanel"; \
	mkdir ${MOE_ROOT}; \
	chown www-data:www-data ${MOE_ROOT}; \
	rm /var/www/moepanel/dist/; \
	sed -i "s#\#Moe##g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#XMOEPANELDOMAINX#${MOE_URL}#g" /etc/nginx/sites-enabled/uguu.conf; \
	sed -i "s#/path/to/your/uguu/or/pomf/db.sq3#${DB_PATH}#g" /var/www/moepanel/static/php/settings.inc.php; \
	sed -i "s#\'MOE_DB_USER\', null#$\'MOE_DB_USER\', ${DB_USER}#g" /var/www/moepanel/static/php/settings.inc.php; \
	sed -i "s#\'MOE_DB_PASS\', null#$\'MOE_DB_PASS\', ${DB_PASS}#g" /var/www/moepanel/static/php/settings.inc.php; \
	sed -i "s#/var/www/moepanel/#${MOE_ROOT}#g" /var/www/moepanel/static/php/settings.inc.php; \
	sed -i "s#/var/www/files/#${FILES_ROOT}#g" /var/www/moepanel/static/php/settings.inc.php; \
	sed -i "s#'PU_NAME', 'Uguu'#'PU_NAME', '${SITE_NAME}'#g" /var/www/moepanel/static/php/settings.inc.php; \
	sed -i "s#'PU_ADDRESS', 'uguu.se'#'PU_ADDRESS', '${DOMAIN}'#g" /var/www/moepanel/static/php/settings.inc.php; \
	sed -i "s#https://a.uguu.se/#${FILE_DOMAIN}#g" /var/www/moepanel/static/php/settings.inc.php; \
	sed -i "s#https://moepanel.uguu.se##g" /var/www/moepanel/static/php/settings.inc.php; \
    sed -i "s#index.html\#fail-cred#index.php\#fail-cred#g" /var/www/moepanel/static/php/core.php; \
fi

# Set file and folder permissions
chown www-data:www-data ${DB_PATH}
chown www-data:www-data ${FILES_ROOT}
chown -R www-data:www-data /var/www/
chmod -R 775 /var/www/

# Change directory. Not really necessary, but might as well.
cd /var/www/uguu || exit

# Start everything for real.
service nginx start
service php8.3-fpm start
echo "Uguu started."
tail -f /dev/null