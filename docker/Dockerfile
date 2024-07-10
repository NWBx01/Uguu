FROM --platform=linux/amd64 debian:bookworm-slim

# Install needed software
RUN apt-get update
RUN apt-get install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2 curl cron socat gettext git nano
RUN echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
RUN curl -fsSL  https://packages.sury.org/php/apt.gpg| gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
RUN apt-get update
RUN apt-get upgrade -y
RUN curl -o nodejssetup.sh https://deb.nodesource.com/setup_20.x
RUN chmod a+x nodejssetup.sh
RUN ./nodejssetup.sh
RUN apt-get install -y nodejs gcc g++ make
RUN apt-get install -y build-essential nginx-full php8.3-fpm php8.3 sqlite3 php8.3-sqlite3 \
                       php8.3-curl php8.3-cli php-horde-lz4 php8.3-pgsql \
                       php8.3-mcrypt php8.3-mysql php8.3-xdebug php8.3-zip \
                       php8.3-common php8.3-readline php8.3-bcmath php8.3-common php8.3-xml

# Uguu Settings
ENV DEBUG "false"
ENV BENCHMARK_MODE "true"
ENV MAX_UPLOAD_SIZE "128"
ENV EXPIRE_TIME "8"
ENV EXPIRE_TIME_UNIT "hours"
ENV SITE_NAME "Uguu"
ENV SITE_SUBTITLE "Temporary file hosting"
ENV DOMAIN "dev.uguu.se"
ENV FILE_DOMAIN "files.dev.uguu.se"
ENV ABUSE_CONTACT "abuse@email.com"
ENV INFO_CONTACT "info@email.com"
ENV SERVER_CN_LOC "Sweden"
ENV SITE_META_INFO "${SITENAME} is a temporary file hosting service, upload files up to ${MAX_UPLOAD_SIZE}MiB for 24 hours."
ENV RESPONSE_TIME "24 hours"
ENV SHOW_GITHUB "true"
ENV SHOW_DONATION_BANNER "false"
ENV PAYPAL_URL ""
ENV BTC_ADDR ""
ENV ETH_ADDR ""
ENV KOFI_URL ""
ENV SHOW_MALWARE_BANNER "false"
ENV DB_MODE "sqlite"
ENV DB_PATH "/var/www/db/uguu.sq3"
ENV DB_USER "NULL"
ENV DB_PASS "NULL"
ENV LOG_IP "false"
ENV ANTI_DUPE "false"
ENV BLACKLIST_DB "false"
ENV FILTER_MODE "true"
ENV RATE_LIMIT "false"
ENV RATE_LIMIT_TIMEOUT "60"
ENV RATE_LIMIT_FILES "100"
ENV FILES_ROOT "/var/www/files/"
ENV FILES_RETRIES "15"
ENV NAME_LENGTH "8"
ENV ID_CHARSET "abcdefghijklmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ"
ENV SSL "false"

# MoePanel Settings
ENV MOE_INSTALL "true"
ENV MOE_ADDUSER "false"
ENV MOE_REBUILD "false"
ENV MOE_ROOT "/var/www/moepanel/"
ENV MOE_URL "moepanel.dev.uguu.se"
ENV MOE_USER "admin@example.com"
ENV MOE_PASS "SUPERSECUREPASSWORD"

# Set default workdir
WORKDIR  /var/www/

COPY docker/docker-entrypoint.sh .

# Decompress into Docker
COPY docker/uguuForDocker.tar.gz /var/www/
RUN mkdir /var/www/uguu
RUN tar -xvf uguuForDocker.tar.gz -C uguu

# Create the needed directories
RUN mkdir ${FILES_ROOT} && \
    mkdir /var/www/uguu-dev/

# Set Permissions
RUN chown -R www-data:www-data /var/www && \
    chmod -R 775 /var/www/

# Copy Nginx Server conf
COPY docker/nginx/uguu.conf /etc/nginx/sites-enabled/uguu.conf
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Copy Uguu config
COPY docker/dist.json /var/www/uguu/config-template.json 
RUN envsubst < /var/www/uguu/config-template.json > /var/www/uguu/src/config.json 

WORKDIR /var/www/moepanel

RUN if [ ${MOE_INSTALL} = "true" ]; then \
      mkdir ${MOE_ROOT}; \
      git clone https://github.com/pomf/MoePanel.git ${MOE_ROOT}; \
      sed -i "s#\#Moe##g" /etc/nginx/sites-enabled/uguu.conf; \
      sed -i "s#XMOEPANELDOMAINX#${MOE_URL}#g" /etc/nginx/sites-enabled/uguu.conf; \
      sed -i "s#/path/to/your/uguu/or/pomf/db.sq3#${DB_PATH}#g" /var/www/moepanel/static/php/settings.inc.php; \
      sed -i "s#'MOE_DB_USER', null#'MOE_DB_USER', ${DB_USER}#g" /var/www/moepanel/static/php/settings.inc.php; \
      sed -i "s#'MOE_DB_PASS', null#'MOE_DB_PASS', ${DB_PASS}#g" /var/www/moepanel/static/php/settings.inc.php; \
	  sed -i "s#/var/www/moepanel/#${MOE_ROOT}#g" /var/www/moepanel/static/php/settings.inc.php; \
	  sed -i "s#/var/www/files/#${FILES_ROOT}#g" /var/www/moepanel/static/php/settings.inc.php; \
	  sed -i "s#'PU_NAME', 'Uguu'#'PU_NAME', '${SITE_NAME}'#g" /var/www/moepanel/static/php/settings.inc.php; \
	  sed -i "s#'PU_ADDRESS', 'uguu.se'#'PU_ADDRESS', '${DOMAIN}'#g" /var/www/moepanel/static/php/settings.inc.php; \
	  sed -i "s#https://moepanel.uguu.se##g" /var/www/moepanel/static/php/settings.inc.php; \
      sed -i "s#index.html\#fail-cred#index.php\#fail-cred#g" /var/www/moepanel/static/php/core.php; \
	  make; \
    fi

WORKDIR  /var/www/

# Expose port 80 from the container
EXPOSE 80

# Expose port 443 from the container
EXPOSE 443

# Install acme.sh
RUN if [ ${SSL} = "true" ]; then \
      curl -o acmeinstall.sh https://get.acme.sh; \
      chmod a+x acmeinstall.sh; \
      ./acmeinstall.sh; \
    fi

# Set default workdir
WORKDIR /var/www/uguu

#Install npm dependencies and run the makefile
RUN npm install
RUN make && make install

# Load entrypoint
ENTRYPOINT [ "bash", "/var/www/docker-entrypoint.sh" ]
