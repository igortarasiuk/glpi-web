
FROM debian:latest

LABEL maintainer="Vlad Danko <v.danko@univest.ua>"

ARG GLPI_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    GLPI_CHMOD_PATHS_FILES=yes \
    TIMEZONE=Europe/Kiev \
    GLPI_VERSION="${GLPI_VERSION}" \
    GLPI_PATHS_ROOT=/var/www/html/glpi \
    GLPI_PATHS_PLUGINS=/var/www/html/glpi/plugins \
    GLPI_REMOVE_INSTALLER=no \
    GLPI_INSTALL_PLUGINS="dashboard|https://forge.glpi-project.org/attachments/download/2249/GLPI-dashboard_plugin-0.9.3.tar.gz, \
cleanarchivedemails|https://github.com/tomolimo/cleanarchivedemails/archive/master.zip, \
badges|https://github.com/InfotelGLPI/badges/archive/master.zip, \
barcode|https://github.com/pluginsGLPI/barcode/archive/master.zip, \
certificates|https://github.com/InfotelGLPI/certificates/archive/master.zip, \
environment|https://github.com/InfotelGLPI/environment/archive/master.zip"

#VOLUME /etc/timezone
#VOLUME /etc/localtime
#VOLUME /var/www/html/glpi

RUN apt update \
#    && apt -y upgrade \
    && apt -y install \
    unzip \
    apache2 \
    php \
    php-mysql \
    php-ldap \
    php-xmlrpc \
    php-imap \
    curl \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-apcu-bc \
    php-cas \
    cron \
    wget \
    jq && \
# Install GLPI sources
    mkdir -p "${GLPI_PATHS_ROOT}" && \
    cd "${GLPI_PATHS_ROOT}" && \
    curl -O -L "https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz" && \
    tar -xzf "glpi-${GLPI_VERSION}.tgz" --strip 1 && \
    rm "glpi-${GLPI_VERSION}.tgz" && \
    rm -rf AUTHORS.txt CHANGELOG.txt LISEZMOI.txt README.md && \
# Enable apache modes
    a2enmod expires && \
    service apache2 restart

COPY apache-glpi.conf /etc/apache2/sites-available/000-default.conf
COPY glpi-start.sh /opt/

WORKDIR "${GLPI_PATHS_ROOT}"

RUN chmod +x /opt/glpi-start.sh
ENTRYPOINT ["/opt/glpi-start.sh"]
#ENTRYPOINT ["/bin/bash"]
HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
    CMD curl --silent --fail http://localhost:80 || exit 1

EXPOSE 80 443
