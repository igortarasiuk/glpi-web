#!/bin/bash
set -e

basedir="${GLPI_PATHS_ROOT}"

if [[ -z "${TIMEZONE}" ]]; then echo "TIMEZONE is unset";
else echo "date.timezone = \"$TIMEZONE\"" > /etc/php/7.0/apache2/conf.d/timezone.ini;
fi

## Install plugins
function installPlugin() {
  plugin="${1}"
  url="${2}"
  file="$(basename "$url")"

  # continue if plugin already installed
  if [ -d "$plugin" ]; then
    echo "..plugin ${plugin} already installed"
  # Download plugin source if not exists
  else
    echo "..downloading plugin '${plugin}' from '${url}'"
    curl -o "${file}" -L "${url}"
	echo "..extracting plugin '${plugin}'"
  # extract the archive according to the extension
    case "$file" in
      *.tar.gz)
        tar xzf "${file}"
        ;;
      *.tar.bz2)
        tar xjf "${file}"
        ;;
      *.zip)
        unzip "${file}"
        ;;
      *)
        echo "..#ERROR# unknown extension for ${file}" 1>&2
        false
        ;;
    esac
    # remove source and set file permissions
    rm -f "${file}"
    mv "${plugin}"* "${plugin}" || true
    chown -R www-data:www-data "${plugin}"
    chmod -R g=rX,o=--- "${plugin}"
  fi
}


echo "Installing plugins... in ${GLPI_PATHS_PLUGINS}"
cd "${GLPI_PATHS_PLUGINS}" > /dev/null

if [ ! -z "${GLPI_INSTALL_PLUGINS}" ]; then
  OLDIFS=$IFS
  IFS=','
  for item in ${GLPI_INSTALL_PLUGINS}; do
    IFS=$OLDIFS
    name="${item%|*}"
    url="${item#*|}"
    installPlugin "${name}" "${url}"
  done
fi

cd - > /dev/null

## Remove installer
echo 'Removing installer if needed...'
# used to remove the installer after first installation
if [ "x${GLPI_REMOVE_INSTALLER}" = 'xyes' ]; then
  rm -f "${basedir}/install/install.php"
fi

## Files structure
echo "Create file structure..."
for f in _cache _cron _dumps _graphs _lock _log _pictures _plugins _rss _sessions _tmp _uploads; do
  dir="${basedir}/files/${f}"
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
    chown www-data:www-data "${dir}"
    chmod u=rwX,g=rwX,o=--- "${dir}"
  fi
done

## Files permissions
echo 'Set files permissions...'
if [ "x${GLPI_CHMOD_PATHS_FILES}" = 'xyes' ]; then
  chown -R www-data:www-data "${basedir}/files" "${basedir}/config"
  chmod -R u=rwX,g=rX,o=--- "${basedir}/files" "${basedir}/config"
fi

#echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

service cron start

a2enmod rewrite && service apache2 restart && service apache2 stop

/usr/sbin/apache2ctl -D FOREGROUND
