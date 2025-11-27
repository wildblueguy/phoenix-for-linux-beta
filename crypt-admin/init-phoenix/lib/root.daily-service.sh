set -e
set -a

. /home/ubuntu/platform-admin/init-phoenix/config/config.sh
. /home/ubuntu/platform-admin/init-phoenix/config/config.aas.sh
. /home/ubuntu/platform-admin/init-phoenix/state/state.sh
. /home/ubuntu/platform-admin/init-phoenix/state/state.aas.sh
. /home/ubuntu/crypt/crypt-admin/init-phoenix/config/config.sh
. /home/ubuntu/crypt/crypt-admin/init-phoenix/config/config.aas.sh
. /home/ubuntu/crypt/crypt-admin/init-phoenix/state/state.sh
. /home/ubuntu/crypt/crypt-admin/init-phoenix/state/state.aas.sh

set +e
HOSTNAME=$(hostname)
PHX_MSMTP_MAIL_TEMPLATE_FROM="$HOSTNAME <$PHX_MSMTP_FROM>"
PHX_MSMTP_MAIL_TEMPLATE_TO="PHX Admin <$PHX_ADMIN_EMAIL>"
TIMESTAMP_START=$(date +'%Y-%m-%d-%H%M-%Ss')
PHX_MSMTP_MAIL_TEMPLATE_SUBJECT="[PHX $PHX_INSTANCE_ID] [$TIMESTAMP_START] Daily service started"
INSTANCE_SIG=$(echo -e "PHX: $PHX_INSTANCE_ID\nCryptInit: $PHX_CRYPT_INIT_FEATURE_SET $PHX_CRYPT_INIT_VERSION\nPlatInit: $PHX_PLATFORM_INIT_FEATURE_SET $PHX_PLATFORM_INIT_VERSION\nHost: $HOSTNAME")
PHX_MSMTP_MAIL_TEMPLATE_BODY=$(echo -e "Daily service started\n\n$TIMESTAMP_START\n$INSTANCE_SIG")
cat /home/ubuntu/crypt/crypt-admin/init-phoenix/config/msmtp-message.template | envsubst | msmtp -a crypt $PHX_ADMIN_EMAIL
set -e

# Modified stop

systemctl stop phx.minutely.timer
set +a
set +e
systemctl status --no-pager phx.minutely.service > /dev/null
MINUTELY_STATUS=$?
while [[ $MINUTELY_STATUS -eq 0 ]]; do
  echo Waiting 5 seconds for minutely service to exit...
  sleep 5
  systemctl status --no-pager phx.minutely.service > /dev/null
  MINUTELY_STATUS=$?
done
set -e
set -a

docker compose --file /home/ubuntu/crypt/program-files/dav/compose.yaml down --timeout 60
docker compose --file /home/ubuntu/crypt/program-files/sheets/compose.yaml down --timeout 60
docker compose --file /home/ubuntu/crypt/program-files/docs/compose.yaml down --timeout 60
docker compose --file /home/ubuntu/crypt/program-files/secrets/compose.yaml down --timeout 60
docker compose --file /home/ubuntu/crypt/program-files/auth/compose.yaml down --timeout 60
docker compose --file /home/ubuntu/crypt/program-files/ldap/compose.yaml down --timeout 60

systemctl stop docker.socket
systemctl stop docker.service

systemctl stop prometheus-mysqld-exporter.service
systemctl stop mariadb.service

systemctl stop prometheus-nginx-exporter.service
systemctl stop nginx.service

if [[ $PHX_MANAGE_SWAP = true ]]; then
  swapoff /root/.phx.swapfile
  mv /root/.phx.swapfile /root/crypt/.phx.swapfile
fi

# Backup

if ! [ -d /root/.phx.daily-backup-remote ]; then
  mkdir /root/.phx.daily-backup-remote
  chmod 700 /root/.phx.daily-backup-remote
fi
/home/ubuntu/crypt/program-files/rclone/rclone mount daily-remote:$PHX_DAILY_BACKUP_B2_BUCKET/phx-$PHX_INSTANCE_ID /root/.phx.daily-backup-remote --config /root/crypt/program-files/backup-service/rclone.conf --daemon --daemon-wait 60s
set +a
YEAR=$(date +'%Y')
MONTH=$(date +'%m')
TIMESTAMP=$(date +'%Y-%m-%d-%H%M-%Ss')
set -a

# Docker volume crypt
echo Backing up Docker volume crypt...
if ! [ -d /root/.phx.daily-backup-remote/docker-vol-crypt-data ]; then
  mkdir /root/.phx.daily-backup-remote/docker-vol-crypt-data
  chmod 700 /root/.phx.daily-backup-remote/docker-vol-crypt-data
fi
if ! [ -d /root/.phx.daily-backup-remote/docker-vol-crypt-data/$YEAR ]; then
  mkdir /root/.phx.daily-backup-remote/docker-vol-crypt-data/$YEAR
  chmod 700 /root/.phx.daily-backup-remote/docker-vol-crypt-data/$YEAR
fi
if ! [ -d /root/.phx.daily-backup-remote/docker-vol-crypt-data/$YEAR/$MONTH ]; then
  mkdir /root/.phx.daily-backup-remote/docker-vol-crypt-data/$YEAR/$MONTH
  chmod 700 /root/.phx.daily-backup-remote/docker-vol-crypt-data/$YEAR/$MONTH
fi
tar -cpz -g /root/crypt/program-files/backup-service/daily.docker-vol-crypt-data.snar -f /root/.phx.daily-backup-remote/docker-vol-crypt-data/$YEAR/$MONTH/docker-vol-crypt-data-$TIMESTAMP.incremental.tar.gz /root/docker-vol-crypt-data

# Admin crypt
echo Backing up admin crypt...
if ! [ -d /root/.phx.daily-backup-remote/admin-crypt-data ]; then
  mkdir /root/.phx.daily-backup-remote/admin-crypt-data
  chmod 700 /root/.phx.daily-backup-remote/admin-crypt-data
fi
if ! [ -d /root/.phx.daily-backup-remote/admin-crypt-data/$YEAR ]; then
  mkdir /root/.phx.daily-backup-remote/admin-crypt-data/$YEAR
  chmod 700 /root/.phx.daily-backup-remote/admin-crypt-data/$YEAR
fi
if ! [ -d /root/.phx.daily-backup-remote/admin-crypt-data/$YEAR/$MONTH ]; then
  mkdir /root/.phx.daily-backup-remote/admin-crypt-data/$YEAR/$MONTH
  chmod 700 /root/.phx.daily-backup-remote/admin-crypt-data/$YEAR/$MONTH
fi
tar -cpz -g /root/crypt/program-files/backup-service/daily.admin-crypt-data.snar -f /root/.phx.daily-backup-remote/admin-crypt-data/$YEAR/$MONTH/admin-crypt-data-$TIMESTAMP.incremental.tar.gz /home/ubuntu/crypt-data

# mysql crypt
echo Backing up mysql crypt...
if ! [ -d /root/.phx.daily-backup-remote/mysql-crypt-data ]; then
  mkdir /root/.phx.daily-backup-remote/mysql-crypt-data
  chmod 700 /root/.phx.daily-backup-remote/mysql-crypt-data
fi
if ! [ -d /root/.phx.daily-backup-remote/mysql-crypt-data/$YEAR ]; then
  mkdir /root/.phx.daily-backup-remote/mysql-crypt-data/$YEAR
  chmod 700 /root/.phx.daily-backup-remote/mysql-crypt-data/$YEAR
fi
if ! [ -d /root/.phx.daily-backup-remote/mysql-crypt-data/$YEAR/$MONTH ]; then
  mkdir /root/.phx.daily-backup-remote/mysql-crypt-data/$YEAR/$MONTH
  chmod 700 /root/.phx.daily-backup-remote/mysql-crypt-data/$YEAR/$MONTH
fi
tar -cpz -g /root/crypt/program-files/backup-service/daily.mysql-crypt-data.snar -f /root/.phx.daily-backup-remote/mysql-crypt-data/$YEAR/$MONTH/mysql-crypt-data-$TIMESTAMP.incremental.tar.gz /mysql/crypt-data

fusermount -u /root/.phx.daily-backup-remote

# Metadata
echo Copying backup metadata to admin crypt, to be included in next backup...
if ! [ -d /home/ubuntu/crypt/.daily-backup-metadata ]; then
  mkdir /home/ubuntu/crypt/.daily-backup-metadata
  chmod 700 /home/ubuntu/crypt/.daily-backup-metadata
fi
if ! [ -d /home/ubuntu/crypt/.daily-backup-metadata/$YEAR ]; then
  mkdir /home/ubuntu/crypt/.daily-backup-metadata/$YEAR
  chmod 700 /home/ubuntu/crypt/.daily-backup-metadata/$YEAR
fi
if ! [ -d /home/ubuntu/crypt/.daily-backup-metadata/$YEAR/$MONTH ]; then
  mkdir /home/ubuntu/crypt/.daily-backup-metadata/$YEAR/$MONTH
  chmod 700 /home/ubuntu/crypt/.daily-backup-metadata/$YEAR/$MONTH
fi
sudo cp /root/crypt/program-files/backup-service/daily.docker-vol-crypt-data.snar /home/ubuntu/crypt/.daily-backup-metadata/$YEAR/$MONTH/docker-vol-crypt-data-$TIMESTAMP.snar
sudo cp /root/crypt/program-files/backup-service/daily.admin-crypt-data.snar /home/ubuntu/crypt/.daily-backup-metadata/$YEAR/$MONTH/admin-crypt-data-$TIMESTAMP.snar
sudo cp /root/crypt/program-files/backup-service/daily.mysql-crypt-data.snar /home/ubuntu/crypt/.daily-backup-metadata/$YEAR/$MONTH/mysql-crypt-data-$TIMESTAMP.snar

# Modified start

if [[ $PHX_MANAGE_SWAP = true ]]; then
  mv /root/crypt/.phx.swapfile /root/.phx.swapfile
  swapon /root/.phx.swapfile
fi

if [[ $PHX_DAILY_CERT_RENEWAL_ENABLED = true ]]; then
  rm -f /etc/nginx/sites-enabled/ldap
  rm -f /etc/nginx/sites-enabled/auth
  rm -f /etc/nginx/sites-enabled/secrets
  rm -f /etc/nginx/sites-enabled/docs
  rm -f /etc/nginx/sites-enabled/sheets
  rm -f /etc/nginx/sites-enabled/dav
  rm -f  /home/ubuntu/crypt/program-files/nginx/stream-sites-enabled/lego.tls-alpn
  runuser -u ubuntu -- ln -s /home/ubuntu/crypt/program-files/lego.tls-alpn.nginx.conf /home/ubuntu/crypt/program-files/nginx/stream-sites-enabled/lego.tls-alpn
fi

systemctl restart nginx.service
systemctl restart prometheus-nginx-exporter.service

if [[ $PHX_DAILY_CERT_RENEWAL_ENABLED = true ]]; then
  runuser -u ubuntu -- /home/ubuntu/crypt/program-files/lego/lego --path /home/ubuntu/crypt/lego --domains $PHX_LDAP_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos renew
  runuser -u ubuntu -- /home/ubuntu/crypt/program-files/lego/lego --path /home/ubuntu/crypt/lego --domains $PHX_AUTH_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos renew
  runuser -u ubuntu -- /home/ubuntu/crypt/program-files/lego/lego --path /home/ubuntu/crypt/lego --domains $PHX_SECRETS_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos renew
  runuser -u ubuntu -- /home/ubuntu/crypt/program-files/lego/lego --path /home/ubuntu/crypt/lego --domains $PHX_DOCS_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos renew
  runuser -u ubuntu -- /home/ubuntu/crypt/program-files/lego/lego --path /home/ubuntu/crypt/lego --domains $PHX_SHEETS_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos renew
  runuser -u ubuntu -- /home/ubuntu/crypt/program-files/lego/lego --path /home/ubuntu/crypt/lego --domains $PHX_DAV_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos renew
  # ---
  runuser -u ubuntu -- cp /home/ubuntu/crypt/lego/certificates/$PHX_LDAP_DOMAIN* /home/ubuntu/crypt/program-files/ldap/lldap/data
  # ---
  rm -f /home/ubuntu/crypt/program-files/nginx/stream-sites-enabled/lego.tls-alpn
  rm -f /etc/nginx/sites-enabled/ldap
  ln -s /home/ubuntu/crypt/program-files/ldap/http.nginx.conf /etc/nginx/sites-enabled/ldap
  rm -f /etc/nginx/sites-enabled/auth
  ln -s /home/ubuntu/crypt/program-files/auth/http.nginx.conf /etc/nginx/sites-enabled/auth
  rm -f /etc/nginx/sites-enabled/secrets
  ln -s /home/ubuntu/crypt/program-files/secrets/http.nginx.conf /etc/nginx/sites-enabled/secrets
  rm -f /etc/nginx/sites-enabled/docs
  ln -s /home/ubuntu/crypt/program-files/docs/http.nginx.conf /etc/nginx/sites-enabled/docs
  rm -f /etc/nginx/sites-enabled/sheets
  ln -s /home/ubuntu/crypt/program-files/sheets/http.nginx.conf /etc/nginx/sites-enabled/sheets
  rm -f /etc/nginx/sites-enabled/dav
  ln -s /home/ubuntu/crypt/program-files/dav/http.nginx.conf /etc/nginx/sites-enabled/dav
  # ---
  systemctl reload nginx.service
fi

systemctl restart mariadb.service
systemctl restart prometheus-mysqld-exporter.service

systemctl restart docker.service
systemctl restart docker.socket

# Container updates
if [[ $PHX_LDAP_ENABLED = true ]]; then
  docker compose --file /home/ubuntu/crypt/program-files/ldap/compose.yaml pull
  set +e; docker compose --file /home/ubuntu/crypt/program-files/ldap/compose.yaml up --detach; set -e
fi
if [[ $PHX_AUTH_ENABLED = true ]]; then
  docker compose --file /home/ubuntu/crypt/program-files/auth/compose.yaml pull
  set +e; docker compose --file /home/ubuntu/crypt/program-files/auth/compose.yaml up --detach; set -e
fi
if [[ $PHX_SECRETS_ENABLED = true ]]; then
  docker compose --file /home/ubuntu/crypt/program-files/secrets/compose.yaml pull
  set +e; docker compose --file /home/ubuntu/crypt/program-files/secrets/compose.yaml up --detach; set -e
fi
if [[ $PHX_DOCS_ENABLED = true ]]; then
  docker compose --file /home/ubuntu/crypt/program-files/docs/compose.yaml pull
  set +e; docker compose --file /home/ubuntu/crypt/program-files/docs/compose.yaml up --detach; set -e
fi
if [[ $PHX_SHEETS_ENABLED = true ]]; then
  docker compose --file /home/ubuntu/crypt/program-files/sheets/compose.yaml pull
  set +e; docker compose --file /home/ubuntu/crypt/program-files/sheets/compose.yaml up --detach; set -e
fi
if [[ $PHX_DAV_ENABLED = true ]]; then
  docker compose --file /home/ubuntu/crypt/program-files/dav/compose.yaml pull
  set +e; docker compose --file /home/ubuntu/crypt/program-files/dav/compose.yaml up --detach; set -e
fi
docker image prune --all --force

systemctl restart phx.minutely.timer

set +e
TIMESTAMP_END=$(date +'%Y-%m-%d-%H%M-%Ss')
PHX_MSMTP_MAIL_TEMPLATE_SUBJECT="[PHX $PHX_INSTANCE_ID] [$TIMESTAMP_END] Daily service ended"
PHX_MSMTP_MAIL_TEMPLATE_BODY=$(echo -e "Daily service ended\n\n$TIMESTAMP_END\n$INSTANCE_SIG")
cat /home/ubuntu/crypt/crypt-admin/init-phoenix/config/msmtp-message.template | envsubst | msmtp -a crypt $PHX_ADMIN_EMAIL
set -e