PLATFORM_ADMIN_DIR=/home/ubuntu/platform-admin
PLATFORM_INIT_DIR=$PLATFORM_ADMIN_DIR/init-phoenix # Can be mounted dev/working copy

ROOT_CRYPT=/root/crypt

DOCKER_VOL_CRYPT=/root/docker-vol-crypt

ADMIN_CRYPT=/home/ubuntu/crypt
CRYPT_ADMIN_DIR=$ADMIN_CRYPT/crypt-admin
PROGRAM_DIR=$CRYPT_ADMIN_DIR/init-phoenix # Can be mounted dev/working copy

MYSQL_CRYPT=/mysql/crypt

SECRETS_CHARSET=0123456789abcdefghjkmnpqrstuvwxy

set -e # Exit if error
set -a # Subsequent variables are exported

# Load platform init environment
. $PLATFORM_INIT_DIR/config/config.sh
. $PLATFORM_INIT_DIR/config/config.aas.sh
. $PLATFORM_INIT_DIR/state/state.sh
. $PLATFORM_INIT_DIR/state/state.aas.sh

# Load environment
. $PROGRAM_DIR/config/config.sh
. $PROGRAM_DIR/config/config.aas.sh
if [ -f $PROGRAM_DIR/state/state.sh ]; then
  . $PROGRAM_DIR/state/state.sh
fi
if [ -f $PROGRAM_DIR/state/state.aas.sh ]; then
  . $PROGRAM_DIR/state/state.aas.sh
fi

PHX_CRYPT_INIT_FEATURE_SET=aas
PHX_CRYPT_INIT_VERSION=2025-06

if [[ PHX_CRYPT_INIT_FEATURE_SET = '' ]]; then
  PHX_CRYPT_INIT_FEATURE_SET=base
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh
chmod 600 $PROGRAM_DIR/state/state.sh
chmod 600 $PROGRAM_DIR/state/state.aas.sh

# ---

# Common init (stateless)
sudo apt update
sudo apt install -y unzip

# ---

# Common init (port generation)
if [[ $PHX_CRYPT_INIT_GENERATED_PORTS != true ]]; then
  echo Generating ports... 
  shuf -i 29000-47999 -n 1900 --random-source=/dev/random > $PROGRAM_DIR/state/crypt-ports.sh-array
  PHX_CRYPT_INIT_GENERATED_PORTS=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Common init (port assignment, MAY add/remove indices but MUST NOT re-use)
readarray -t PHX_CRYPT_PORTS < $PROGRAM_DIR/state/crypt-ports.sh-array
PHX_LEGO_TLS_ALPN_PORT=${PHX_CRYPT_PORTS[0]}
PHX_LDAP_LDAP_PORT=${PHX_CRYPT_PORTS[1]}
PHX_LDAP_LDAPS_PORT=${PHX_CRYPT_PORTS[2]}
PHX_LDAP_HTTP_PORT=${PHX_CRYPT_PORTS[3]}
PHX_AUTH_HTTP_PORT=${PHX_CRYPT_PORTS[4]}
PHX_SECRETS_HTTP_PORT=${PHX_CRYPT_PORTS[5]}
PHX_DOCS_HTTP_PORT=${PHX_CRYPT_PORTS[6]}
PHX_SHEETS_HTTP_PORT=${PHX_CRYPT_PORTS[7]}
PHX_DAV_HTTP_PORT=${PHX_CRYPT_PORTS[8]}

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Common init (stateful)
if [[ $PHX_CRYPT_INIT_COMMON_INIT_STATE != true ]]; then

  # Crypt admin directory
  if ! [ -d $CRYPT_ADMIN_DIR ]; then
    mkdir $CRYPT_ADMIN_DIR
    chmod 700 $CRYPT_ADMIN_DIR
  fi

  # Program files directory
  if ! [ -d $ADMIN_CRYPT/program-files ]; then
    mkdir $ADMIN_CRYPT/program-files
    chmod 700 $ADMIN_CRYPT/program-files
  fi

  # Nginx directory
  if ! [ -d $ADMIN_CRYPT/program-files/nginx ]; then
    mkdir $ADMIN_CRYPT/program-files/nginx
    chmod 700 $ADMIN_CRYPT/program-files/nginx
  fi

  # Nginx stream sites directory
  if ! [ -d $ADMIN_CRYPT/program-files/nginx/stream-sites-enabled ]; then
    mkdir $ADMIN_CRYPT/program-files/nginx/stream-sites-enabled
    chmod 700 $ADMIN_CRYPT/program-files/nginx/stream-sites-enabled
  fi

  # LLDAP CLI
  cat $PROGRAM_DIR/lib/lldap-cli.sh > $ADMIN_CRYPT/program-files/lldap-cli.sh

  # Authelia CLI
  rm -fr $ADMIN_CRYPT/program-files/authelia-cli
  mkdir $ADMIN_CRYPT/program-files/authelia-cli
  chmod 700 $ADMIN_CRYPT/program-files/authelia-cli
  wget -q -O - $PHX_AUTHELIA_CLI_PACKAGE_URL | tar -xz --directory=$ADMIN_CRYPT/program-files/authelia-cli

  # Rclone
  rm -fr $ADMIN_CRYPT/program-files/rclone
  wget -O $ADMIN_CRYPT/program-files/rclone.zip $PHX_RCLONE_PACKAGE_URL
  unzip -d $ADMIN_CRYPT/program-files/rclone.temp $ADMIN_CRYPT/program-files/rclone.zip
  rm $ADMIN_CRYPT/program-files/rclone.zip
  mv $ADMIN_CRYPT/program-files/rclone.temp/$PHX_RCLONE_PACKAGE_INNER $ADMIN_CRYPT/program-files/rclone
  rm -r $ADMIN_CRYPT/program-files/rclone.temp
  chmod 700 $ADMIN_CRYPT/program-files/rclone

  # LEGo
  rm -fr $ADMIN_CRYPT/program-files/lego
  mkdir $ADMIN_CRYPT/program-files/lego
  chmod 700 $ADMIN_CRYPT/program-files/lego
  wget -q -O - $PHX_LEGO_PACKAGE_URL | tar -xz --directory=$ADMIN_CRYPT/program-files/lego
  PHX_NGINX_STREAM_SITE_TEMPLATE_LISTEN_PORT=443
  PHX_NGINX_STREAM_SITE_TEMPLATE_PROXY_PASS=127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT
  cat $PROGRAM_DIR/config/SITE.TCP_PROTO.nginx.conf.template | envsubst > $ADMIN_CRYPT/program-files/lego.tls-alpn.nginx.conf
  
  # LEGo data (cert issuance)
  if [[ $PHX_DAILY_CERT_RENEWAL_ENABLED = true ]]; then
    rm -f $ADMIN_CRYPT/program-files/nginx/stream-sites-enabled/lego.tls-alpn
    ln -s $ADMIN_CRYPT/program-files/lego.tls-alpn.nginx.conf $ADMIN_CRYPT/program-files/nginx/stream-sites-enabled/lego.tls-alpn
    sudo systemctl restart nginx.service
    $ADMIN_CRYPT/program-files/lego/lego --path $ADMIN_CRYPT/lego --domains $PHX_LDAP_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos run
    $ADMIN_CRYPT/program-files/lego/lego --path $ADMIN_CRYPT/lego --domains $PHX_AUTH_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos run
    $ADMIN_CRYPT/program-files/lego/lego --path $ADMIN_CRYPT/lego --domains $PHX_SECRETS_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos run
    $ADMIN_CRYPT/program-files/lego/lego --path $ADMIN_CRYPT/lego --domains $PHX_DOCS_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos run
    $ADMIN_CRYPT/program-files/lego/lego --path $ADMIN_CRYPT/lego --domains $PHX_SHEETS_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos run
    $ADMIN_CRYPT/program-files/lego/lego --path $ADMIN_CRYPT/lego --domains $PHX_DAV_DOMAIN --tls --tls.port 127.0.0.1:$PHX_LEGO_TLS_ALPN_PORT --email $PHX_DAILY_CERT_RENEWAL_LE_ACCOUNT --accept-tos run
    sudo systemctl stop nginx.service
    rm -f $ADMIN_CRYPT/program-files/nginx/stream-sites-enabled/lego.tls-alpn
  fi

  PHX_CRYPT_INIT_COMMON_INIT_STATE=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install swap file
if [[ $PHX_MANAGE_SWAP = true && $PHX_CRYPT_INIT_INSTALLED_SWAP_FILE != true ]]; then
  echo Installing swap file...
  sudo mv /root/.phx.swapfile $ROOT_CRYPT/.phx.swapfile
  PHX_CRYPT_INIT_INSTALLED_SWAP_FILE=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install MariaDB
if [[ $PHX_CRYPT_INIT_INSTALLED_MARIA_DB != true ]]; then
  echo Installing MariaDB...

  # Data directory
  if ! sudo [ -d $MYSQL_CRYPT/var--lib--mysql.init-phoenix.aas.backup ]; then
    sudo mkdir $MYSQL_CRYPT/var--lib--mysql.init-phoenix.aas.backup
    sudo rsync -a --no-owner --no-group /var/lib/mysql/ $MYSQL_CRYPT/var--lib--mysql.init-phoenix.aas.backup
  fi
  if [[ $PHX_CRYPT_INIT_GUARD_EXISTING_MARIA_DB_DATA = false ]]; then
    sudo rm -fr $MYSQL_CRYPT/maria-db
  fi
  sudo mkdir $MYSQL_CRYPT/maria-db
  sudo rsync -a --no-owner --no-group $MYSQL_CRYPT/var--lib--mysql.init-phoenix.aas.backup/ $MYSQL_CRYPT/maria-db

  # Host user passwords
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_MARIA_DB_ROOT_DB_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_MARIA_DB_MYSQL_DB_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Metrics exporter password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_MARIA_DB_METRICS_EXPORTER_DB_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # LDAP main process password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_LDAP_LLDAP_DB_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Auth main process password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_AUTH_AUTHELIA_DB_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Secrets main process password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_SECRETS_VAULTWARDEN_DB_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Docs main process password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_DOCS_HEDGEDOC_DB_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # DAV main process password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_DAV_NEXTCLOUD_DB_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  echo WARNING: MARIA DB UNIX SOCKET AUTHENTICATION WILL BE DISABLED, but a crypto-quality root password will be set first.
  echo YOU WILL BE LOCKED OUT, but the new root password can be found in the persistent state of this script. This password is safe to transfer to a password manager and delete.
  echo THIS WILL BE YOUR ONLY WARNING.

  # Internal
  sudo systemctl restart mariadb.service
  sudo mysql < <(cat $PROGRAM_DIR/lib/init-maria-db.sql.template | envsubst)
  sudo systemctl stop mariadb.service

  # Metrics exporter config
  cat $PROGRAM_DIR/config/maria-db-metrics-exporter.my.cnf.template | envsubst > $ADMIN_CRYPT/program-files/maria-db-metrics-exporter.my.cnf
  chmod 600 $ADMIN_CRYPT/program-files/maria-db-metrics-exporter.my.cnf

  PHX_CRYPT_INIT_INSTALLED_MARIA_DB=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh

# ---

# Install Docker
if [[ $PHX_CRYPT_INIT_INSTALLED_DOCKER != true ]]; then
  echo Installing Docker...
  if [[ $PHX_CRYPT_INIT_GUARD_EXISTING_DOCKER_DATA = false ]]; then
    sudo rm -fr $ROOT_CRYPT/docker
  fi
  sudo mkdir $ROOT_CRYPT/docker
  # Docker sets its own perms (710 observed)
  PHX_CRYPT_INIT_INSTALLED_DOCKER=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install LDAP service
if [[ $PHX_CRYPT_INIT_INSTALLED_LDAP != true ]]; then
  echo Installing LDAP service...

  # Directories
  if ! [ -d $ADMIN_CRYPT/program-files/ldap ]; then
    mkdir $ADMIN_CRYPT/program-files/ldap
    chmod 700 $ADMIN_CRYPT/program-files/ldap
  fi
  if ! [ -d $ADMIN_CRYPT/program-files/ldap/lldap ]; then
    mkdir $ADMIN_CRYPT/program-files/ldap/lldap
    chmod 700 $ADMIN_CRYPT/program-files/ldap/lldap
  fi
  if ! [ -d $ADMIN_CRYPT/program-files/ldap/lldap/data ]; then
    mkdir $ADMIN_CRYPT/program-files/ldap/lldap/data
    chmod 700 $ADMIN_CRYPT/program-files/ldap/lldap/data
  fi

  # Nginx sites
  PHX_NGINX_STREAM_SITE_TEMPLATE_LISTEN_PORT=$PHX_LDAP_LDAP_NGINX_PORT
  PHX_NGINX_STREAM_SITE_TEMPLATE_PROXY_PASS=127.0.0.1:$PHX_LDAP_LDAP_PORT
  cat $PROGRAM_DIR/config/SITE.TCP_PROTO.nginx.conf.template | envsubst > $ADMIN_CRYPT/program-files/ldap/ldap.nginx.conf
  rm -f $ADMIN_CRYPT/program-files/nginx/stream-sites-enabled/ldap.ldap
  ln -s ${ADMIN_CRYPT}/program-files/ldap/ldap.nginx.conf ${ADMIN_CRYPT}/program-files/nginx/stream-sites-enabled/ldap.ldap
  # ---
  PHX_NGINX_STREAM_SITE_TEMPLATE_LISTEN_PORT=$PHX_LDAP_LDAPS_NGINX_PORT
  PHX_NGINX_STREAM_SITE_TEMPLATE_PROXY_PASS=127.0.0.1:$PHX_LDAP_LDAPS_PORT
  cat $PROGRAM_DIR/config/SITE.TCP_PROTO.nginx.conf.template | envsubst > $ADMIN_CRYPT/program-files/ldap/ldaps.nginx.conf
  rm -f $ADMIN_CRYPT/program-files/nginx/stream-sites-enabled/ldap.ldaps
  ln -s ${ADMIN_CRYPT}/program-files/ldap/ldaps.nginx.conf ${ADMIN_CRYPT}/program-files/nginx/stream-sites-enabled/ldap.ldaps
  # ---
  PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME=$PHX_LDAP_DOMAIN
  PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS=http://127.0.0.1:$PHX_LDAP_HTTP_PORT
  cat $PROGRAM_DIR/config/SITE.http.nginx.conf.template | envsubst '$PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME $PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS' > $ADMIN_CRYPT/program-files/ldap/http.nginx.conf
  sudo rm -f /etc/nginx/sites-enabled/ldap
  sudo ln -s $ADMIN_CRYPT/program-files/ldap/http.nginx.conf /etc/nginx/sites-enabled/ldap

  # Compose file
  cat $PROGRAM_DIR/config/ldap.compose.yaml.template | envsubst > $ADMIN_CRYPT/program-files/ldap/compose.yaml

  # JWT signing secret
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_LDAP_LLDAP_JWT_SECRET=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Admin password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_LDAP_LLDAP_USER_PASS=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Private key seed
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_LDAP_LLDAP_KEY_SEED=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Config
  cat $PROGRAM_DIR/config/ldap.lldap_config.toml.template | envsubst > $ADMIN_CRYPT/program-files/ldap/lldap/data/lldap_config.toml
  chmod 600 $ADMIN_CRYPT/program-files/ldap/lldap/data/lldap_config.toml

  # Certs
  if [[ $PHX_DAILY_CERT_RENEWAL_ENABLED = true ]]; then
    cp $ADMIN_CRYPT/lego/certificates/$PHX_LDAP_DOMAIN* $ADMIN_CRYPT/program-files/ldap/lldap/data
  fi

  # Auth main process password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_AUTH_AUTHELIA_LDAP_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # DAV main process password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_DAV_NEXTCLOUD_LDAP_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Internal
  crudini --set $ADMIN_CRYPT/program-files/ldap/lldap/data/lldap_config.toml ldaps_options enabled false
  sudo systemctl restart mariadb.service docker.service docker.socket
  sudo docker compose --file $ADMIN_CRYPT/program-files/ldap/compose.yaml up --detach --wait --wait-timeout 60
  sudo docker cp $ADMIN_CRYPT/program-files/lldap-cli.sh ldap-lldap:/app/lldap-cli
  sudo docker exec ldap-lldap chmod 755 /app/lldap-cli
  sudo docker exec ldap-lldap /app/lldap-cli user add $PHX_AUTH_AUTHELIA_LDAP_UID $PHX_AUTH_AUTHELIA_LDAP_EMAIL -p $PHX_AUTH_AUTHELIA_LDAP_PASSWORD
  sudo docker exec ldap-lldap /app/lldap-cli user group add $PHX_AUTH_AUTHELIA_LDAP_UID lldap_password_manager
  sudo docker exec ldap-lldap /app/lldap-cli user add $PHX_DAV_NEXTCLOUD_LDAP_UID $PHX_DAV_NEXTCLOUD_LDAP_EMAIL -p $PHX_DAV_NEXTCLOUD_LDAP_PASSWORD
  sudo docker exec ldap-lldap /app/lldap-cli user group add $PHX_DAV_NEXTCLOUD_LDAP_UID lldap_strict_readonly
  sudo docker compose --file $ADMIN_CRYPT/program-files/ldap/compose.yaml down
  crudini --set $ADMIN_CRYPT/program-files/ldap/lldap/data/lldap_config.toml ldaps_options enabled true
  sudo systemctl stop docker.socket docker.service mariadb.service

  PHX_CRYPT_INIT_INSTALLED_LDAP=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh

# ---

# Install auth service
if [[ $PHX_CRYPT_INIT_INSTALLED_AUTH != true ]]; then
  echo Installing auth service...

  # Directories
  if ! [ -d $ADMIN_CRYPT/program-files/auth ]; then
    mkdir $ADMIN_CRYPT/program-files/auth
    chmod 700 $ADMIN_CRYPT/program-files/auth
  fi
  if ! [ -d $ADMIN_CRYPT/program-files/auth/authelia ]; then
    mkdir $ADMIN_CRYPT/program-files/auth/authelia
    chmod 700 $ADMIN_CRYPT/program-files/auth/authelia
  fi
  if ! [ -d $ADMIN_CRYPT/program-files/auth/authelia/config ]; then
    mkdir $ADMIN_CRYPT/program-files/auth/authelia/config
    chmod 700 $ADMIN_CRYPT/program-files/auth/authelia/config
  fi

  # Nginx site
  PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME=$PHX_AUTH_DOMAIN
  PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS=http://127.0.0.1:$PHX_AUTH_HTTP_PORT
  cat $PROGRAM_DIR/config/SITE.http.nginx.conf.template | envsubst '$PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME $PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS' > $ADMIN_CRYPT/program-files/auth/http.nginx.conf
  sudo rm -f /etc/nginx/sites-enabled/auth
  sudo ln -s $ADMIN_CRYPT/program-files/auth/http.nginx.conf /etc/nginx/sites-enabled/auth

  # Compose file
  cat $PROGRAM_DIR/config/auth.compose.yaml.template | envsubst > $ADMIN_CRYPT/program-files/auth/compose.yaml
  
  # LDAP implementation
  PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_IMPLEMENTATION=lldap
  if [[ $PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_IMPLEMENTATION_OVERRIDE != '' ]]; then
    PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_IMPLEMENTATION=$PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_IMPLEMENTATION_OVERRIDE
  fi

  # LDAP protocol
  PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PROTOCOL=ldap
  if [[ $PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PROTOCOL_OVERRIDE != '' ]]; then
    PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PROTOCOL=$PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PROTOCOL_OVERRIDE
  fi

  # LDAP host
  PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_HOST=172.17.0.1
  if [[ $PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_HOST_OVERRIDE != '' ]]; then
    PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_HOST=$PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_HOST_OVERRIDE
  fi

  # LDAP port
  PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PORT=$PHX_LDAP_LDAP_PORT
  if [[ $PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PORT_OVERRIDE != '' ]]; then
    PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PORT=$PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PORT_OVERRIDE
  fi

  # LDAP base DN
  PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_BASE_DN=$PHX_LDAP_LLDAP_BASE_DN
  if [[ $PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_BASE_DN_OVERRIDE != '' ]]; then
    PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_BASE_DN=$PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_BASE_DN_OVERRIDE
  fi

  # LDAP user
  PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_USER=uid=$PHX_AUTH_AUTHELIA_LDAP_UID,ou=people,$PHX_LDAP_LLDAP_BASE_DN
  if [[ $PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_USER_OVERRIDE != '' ]]; then
    PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_USER=$PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_USER_OVERRIDE
  fi

  # LDAP password
  PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD=$PHX_AUTH_AUTHELIA_LDAP_PASSWORD
  if [[ $PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_OVERRIDE != '' ]]; then
    PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD=$PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_OVERRIDE
  fi

  # LDAP users filter
  PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_USERS_FILTER='(&(|({username_attribute}={input})({mail_attribute}={input}))(objectClass=person))'
  if [[ $PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_USERS_FILTER_OVERRIDE != '' ]]; then
    PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_USERS_FILTER=$PHX_AUTH_AUTHELIA_AUTHENTICATION_BACKEND_LDAP_USERS_FILTER_OVERRIDE
  fi

  # Password reset JWT signing secret
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_AUTH_AUTHELIA_IDENTITY_VALIDATION_PASSWORD_RESET_JWT_SECRET=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Storage encryption key
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_AUTH_AUTHELIA_STORAGE_ENCRYPTION_KEY=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # OIDC JWT signing secret
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_AUTH_AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp
  
  # OIDC JWKS files: https://www.authelia.com/reference/guides/generating-secure-values#generating-an-rsa-keypair
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto pair rsa generate --directory $ADMIN_CRYPT/program-files/auth/authelia/config --file.private-key oidc-jwks.private.pem --file.public-key oidc-jwks.public.pem
  chmod 600 $ADMIN_CRYPT/program-files/auth/authelia/config/oidc-jwks.private.pem
  
  # Docs OIDC client ID: https://www.authelia.com/integration/openid-connect/frequently-asked-questions#client-id--identifier
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_DOCS_OIDC_CLIENT_ID=phx-docs-$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Docs OIDC client secret: https://www.authelia.com/reference/guides/generating-secure-values#generating-a-random-alphanumeric-string
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_DOCS_OIDC_CLIENT_SECRET=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp
  
  # Docs OIDC client secret hash: https://www.authelia.com/reference/guides/generating-secure-values#generating-a-random-password-hash
  PHX_AUTH_AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_CLIENT_SECRET_DOCS=$($ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto hash generate argon2 --password $PHX_DOCS_OIDC_CLIENT_SECRET)
  PHX_AUTH_AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_CLIENT_SECRET_DOCS=${PHX_AUTH_AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_CLIENT_SECRET_DOCS:8}

  # Sheets OIDC client ID
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_SHEETS_OIDC_CLIENT_ID=phx-sheets-$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # Sheets OIDC client secret
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_SHEETS_OIDC_CLIENT_SECRET=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp
  
  # Sheets OIDC client secret hash
  PHX_AUTH_AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_CLIENT_SECRET_SHEETS=$($ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto hash generate argon2 --password $PHX_SHEETS_OIDC_CLIENT_SECRET)
  PHX_AUTH_AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_CLIENT_SECRET_SHEETS=${PHX_AUTH_AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_CLIENT_SECRET_SHEETS:8}
  
  # Config file
  cat $PROGRAM_DIR/config/auth.authelia.configuration.yml.template | envsubst > $ADMIN_CRYPT/program-files/auth/authelia/config/configuration.yml
  chmod 600 $ADMIN_CRYPT/program-files/auth/authelia/config/configuration.yml

  PHX_CRYPT_INIT_INSTALLED_AUTH=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh

# ---

# Install secrets app
if [[ $PHX_CRYPT_INIT_INSTALLED_SECRETS != true ]]; then
  echo Installing secrets app...
  
  # Directories
  if ! [ -d $ADMIN_CRYPT/program-files/secrets ]; then
    mkdir $ADMIN_CRYPT/program-files/secrets
    chmod 700 $ADMIN_CRYPT/program-files/secrets
  fi
  if ! [ -d $ADMIN_CRYPT/program-files/secrets/vaultwarden ]; then
    mkdir $ADMIN_CRYPT/program-files/secrets/vaultwarden
    chmod 700 $ADMIN_CRYPT/program-files/secrets/vaultwarden
  fi
  if ! [ -d $ADMIN_CRYPT/program-files/secrets/vaultwarden/data ]; then
    mkdir $ADMIN_CRYPT/program-files/secrets/vaultwarden/data
    chmod 700 $ADMIN_CRYPT/program-files/secrets/vaultwarden/data
  fi
  
  # Nginx site
  PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME=$PHX_SECRETS_DOMAIN
  PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS=http://127.0.0.1:$PHX_SECRETS_HTTP_PORT
  cat $PROGRAM_DIR/config/SITE.http.nginx.conf.template | envsubst '$PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME $PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS' > $ADMIN_CRYPT/program-files/secrets/http.nginx.conf
  sudo rm -f /etc/nginx/sites-enabled/secrets
  sudo ln -s $ADMIN_CRYPT/program-files/secrets/http.nginx.conf /etc/nginx/sites-enabled/secrets
  
  # Admin token
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp
  
  # Admin token hash
  PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN_HASH=$($ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto hash generate argon2 --password $PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN)
  PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN_HASH=${PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN_HASH:8}
  
  # Compose file
  PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN_HASH=${PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN_HASH//'$'/'$$'}
  cat $PROGRAM_DIR/config/secrets.compose.yaml.template | envsubst > $ADMIN_CRYPT/program-files/secrets/compose.yaml
  PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN_HASH=${PHX_SECRETS_VAULTWARDEN_ADMIN_TOKEN_HASH//'$$'/'$'}
  
  PHX_CRYPT_INIT_INSTALLED_SECRETS=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh

# ---

# Install docs app
if [[ $PHX_CRYPT_INIT_INSTALLED_DOCS != true ]]; then
  echo Installing docs app...
  
  # Directories
  if ! [ -d $ADMIN_CRYPT/program-files/docs ]; then
    mkdir $ADMIN_CRYPT/program-files/docs
    chmod 700 $ADMIN_CRYPT/program-files/docs
  fi

  # Nginx site
  PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME=$PHX_DOCS_DOMAIN
  PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS=http://127.0.0.1:$PHX_DOCS_HTTP_PORT
  cat $PROGRAM_DIR/config/SITE.http.nginx.conf.template | envsubst '$PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME $PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS' > $ADMIN_CRYPT/program-files/docs/http.nginx.conf
  sudo rm -f /etc/nginx/sites-enabled/docs
  sudo ln -s $ADMIN_CRYPT/program-files/docs/http.nginx.conf /etc/nginx/sites-enabled/docs
  
  # Session secret
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_DOCS_HEDGEDOC_SESSION_SECRET=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp

  # OIDC authorization URL
  PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL=https://${PHX_AUTH_DOMAIN}/api/oidc/authorization
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL=$PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # OIDC token URL
  PHX_DOCS_HEDGEDOC_OAUTH2_TOKEN_URL=https://${PHX_AUTH_DOMAIN}/api/oidc/token
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_TOKEN_URL_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_TOKEN_URL=$PHX_DOCS_HEDGEDOC_OAUTH2_TOKEN_URL_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # OIDC profile URL
  PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_URL=https://${PHX_AUTH_DOMAIN}/api/oidc/userinfo
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_URL_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_URL=$PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_URL_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # OIDC client ID
  PHX_DOCS_HEDGEDOC_OAUTH2_CLIENT_ID=${PHX_DOCS_OIDC_CLIENT_ID}
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_CLIENT_ID_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_CLIENT_ID=$PHX_DOCS_HEDGEDOC_OAUTH2_CLIENT_ID_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # OIDC client secret
  PHX_DOCS_HEDGEDOC_OAUTH2_CLIENT_SECRET=${PHX_DOCS_OIDC_CLIENT_SECRET}
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_CLIENT_SECRET_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_CLIENT_SECRET=$PHX_DOCS_HEDGEDOC_OAUTH2_CLIENT_SECRET_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # OIDC scopes
  PHX_DOCS_HEDGEDOC_OAUTH2_SCOPE='openid email groups profile'
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_SCOPE_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_SCOPE=$PHX_DOCS_HEDGEDOC_OAUTH2_SCOPE_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # OIDC profile UID attribute
  PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_USERNAME_ATTR=preferred_username
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_USERNAME_ATTR_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_USERNAME_ATTR=$PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_USERNAME_ATTR_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # OIDC profile display name attribute
  PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR=name
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR=$PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi
  
  # OIDC profile e-mail attribute
  PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_EMAIL_ATTR=email
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_EMAIL_ATTR_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_EMAIL_ATTR=$PHX_DOCS_HEDGEDOC_OAUTH2_USER_PROFILE_EMAIL_ATTR_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # OIDC roles claim
  PHX_DOCS_HEDGEDOC_OAUTH2_ROLES_CLAIM=groups
  if [[ $PHX_DOCS_HEDGEDOC_OAUTH2_ROLES_CLAIM_OVERRIDE != '' ]]; then
    PHX_DOCS_HEDGEDOC_OAUTH2_ROLES_CLAIM=$PHX_DOCS_HEDGEDOC_OAUTH2_ROLES_CLAIM_PHX_DOCS_HEDGEDOC_OAUTH2_AUTHORIZATION_URL_OVERRIDE
  fi

  # Compose file
  cat $PROGRAM_DIR/config/docs.compose.yaml.template | envsubst > $ADMIN_CRYPT/program-files/docs/compose.yaml

  # Uploads volume
  if ! sudo [ -d $DOCKER_VOL_CRYPT/docs_uploads ]; then
    sudo mkdir $DOCKER_VOL_CRYPT/docs_uploads
    sudo chmod 700 $DOCKER_VOL_CRYPT/docs_uploads
  fi

  PHX_CRYPT_INIT_INSTALLED_DOCS=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh

# ---

# Install sheets app
if [[ $PHX_CRYPT_INIT_INSTALLED_SHEETS != true ]]; then
  echo Installing sheets app...

  # Directories
  if ! [ -d $ADMIN_CRYPT/program-files/sheets ]; then
    mkdir $ADMIN_CRYPT/program-files/sheets
    chmod 700 $ADMIN_CRYPT/program-files/sheets
  fi
  if ! [ -d $ADMIN_CRYPT/program-files/sheets ]; then
    mkdir $ADMIN_CRYPT/program-files/sheets
    chmod 700 $ADMIN_CRYPT/program-files/sheets
  fi

  # Nginx site
  PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME=$PHX_SHEETS_DOMAIN
  PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS=http://127.0.0.1:$PHX_SHEETS_HTTP_PORT
  cat $PROGRAM_DIR/config/SITE.http.nginx.conf.template | envsubst '$PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME $PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS' > $ADMIN_CRYPT/program-files/sheets/http.nginx.conf
  sudo rm -f /etc/nginx/sites-enabled/sheets
  sudo ln -s $ADMIN_CRYPT/program-files/sheets/http.nginx.conf /etc/nginx/sites-enabled/sheets
  
  # OIDC issuer
  PHX_SHEETS_GRIST_OIDC_IDP_ISSUER=https://${PHX_AUTH_DOMAIN}
  if [[ $PHX_SHEETS_GRIST_OIDC_IDP_ISSUER_OVERRIDE != '' ]]; then
    PHX_SHEETS_GRIST_OIDC_IDP_ISSUER = $PHX_SHEETS_GRIST_OIDC_IDP_ISSUER_OVERRIDE
  fi
  
  # OIDC client ID
  PHX_SHEETS_GRIST_OIDC_IDP_CLIENT_ID=$PHX_SHEETS_OIDC_CLIENT_ID
  if [[ $PHX_SHEETS_GRIST_OIDC_IDP_CLIENT_ID_OVERRIDE != '' ]]; then
    PHX_SHEETS_GRIST_OIDC_IDP_CLIENT_ID = $PHX_SHEETS_GRIST_OIDC_IDP_CLIENT_ID_OVERRIDE
  fi
  
  # OIDC client secret
  PHX_SHEETS_GRIST_OIDC_IDP_CLIENT_SECRET=$PHX_SHEETS_OIDC_CLIENT_SECRET
  if [[ $PHX_SHEETS_GRIST_OIDC_IDP_CLIENT_SECRET_OVERRIDE != '' ]]; then
    PHX_SHEETS_GRIST_OIDC_IDP_CLIENT_SECRET = $PHX_SHEETS_GRIST_OIDC_IDP_CLIENT_SECRET_OVERRIDE
  fi
  
  # OIDC end session endpoint
  PHX_SHEETS_GRIST_OIDC_IDP_END_SESSION_ENDPOINT=https://${PHX_AUTH_DOMAIN}/logout
  if [[ $PHX_SHEETS_GRIST_OIDC_IDP_END_SESSION_ENDPOINT_OVERRIDE != '' ]]; then
    PHX_SHEETS_GRIST_OIDC_IDP_END_SESSION_ENDPOINT = $PHX_SHEETS_GRIST_OIDC_IDP_END_SESSION_ENDPOINT_OVERRIDE
  fi
  
  # Compose file
  cat $PROGRAM_DIR/config/sheets.compose.yaml.template | envsubst > $ADMIN_CRYPT/program-files/sheets/compose.yaml
  
  # Persist volume
  if ! sudo [ -d $DOCKER_VOL_CRYPT/sheets_persist ]; then
    sudo mkdir $DOCKER_VOL_CRYPT/sheets_persist
    sudo chmod 700 $DOCKER_VOL_CRYPT/sheets_persist
  fi

  PHX_CRYPT_INIT_INSTALLED_SHEETS=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh

# ---

# Install DAV service
if [[ $PHX_CRYPT_INIT_INSTALLED_DAV != true ]]; then
  echo Installing DAV service...
  
  # Directories
  if ! [ -d $ADMIN_CRYPT/program-files/dav ]; then
    mkdir $ADMIN_CRYPT/program-files/dav
    chmod 700 $ADMIN_CRYPT/program-files/dav
  fi

  # Nginx site
  PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME=$PHX_DAV_DOMAIN
  PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS=http://127.0.0.1:$PHX_DAV_HTTP_PORT
  cat $PROGRAM_DIR/config/SITE.http.nginx.conf.template | envsubst '$PHX_NGINX_HTTP_SITE_TEMPLATE_SERVER_NAME $PHX_NGINX_HTTP_SITE_TEMPLATE_PROXY_PASS' > $ADMIN_CRYPT/program-files/dav/http.nginx.conf
  sudo rm -f /etc/nginx/sites-enabled/dav
  sudo ln -s $ADMIN_CRYPT/program-files/dav/http.nginx.conf /etc/nginx/sites-enabled/dav
  
  # Admin password
  $ADMIN_CRYPT/program-files/authelia-cli/authelia-linux-amd64 crypto rand --characters $SECRETS_CHARSET --length 64 $PROGRAM_DIR/state/.temp
  PHX_DAV_NEXTCLOUD_ADMIN_PASSWORD=$(cat $PROGRAM_DIR/state/.temp)
  rm $PROGRAM_DIR/state/.temp
  
  # Compose file
  cat $PROGRAM_DIR/config/dav.compose.yaml.template | envsubst > $ADMIN_CRYPT/program-files/dav/compose.yaml
  
  # HTML volume
  if ! sudo [ -d $DOCKER_VOL_CRYPT/dav_html ]; then
    sudo mkdir $DOCKER_VOL_CRYPT/dav_html
    sudo chmod 700 $DOCKER_VOL_CRYPT/dav_html
  fi

  # Custom apps volume
  if ! sudo [ -d $DOCKER_VOL_CRYPT/dav_custom_apps ]; then
    sudo mkdir $DOCKER_VOL_CRYPT/dav_custom_apps
    sudo chmod 700 $DOCKER_VOL_CRYPT/dav_custom_apps
  fi

  # Config volume
  if ! sudo [ -d $DOCKER_VOL_CRYPT/dav_config ]; then
    sudo mkdir $DOCKER_VOL_CRYPT/dav_config
    sudo chmod 700 $DOCKER_VOL_CRYPT/dav_config
  fi

  # Data volume
  if ! sudo [ -d $DOCKER_VOL_CRYPT/dav_data ]; then
    sudo mkdir $DOCKER_VOL_CRYPT/dav_data
    sudo chmod 700 $DOCKER_VOL_CRYPT/dav_data
  fi

  # Custom theme volume
  if ! sudo [ -d $DOCKER_VOL_CRYPT/dav_custom_theme ]; then
    sudo mkdir $DOCKER_VOL_CRYPT/dav_custom_theme
    sudo chmod 700 $DOCKER_VOL_CRYPT/dav_custom_theme
  fi
  
  # Internal
  sudo systemctl restart mariadb.service docker.service docker.socket
  sudo docker compose --file $ADMIN_CRYPT/program-files/dav/compose.yaml up --detach --wait --wait-timeout 60
  
  # Internal (racy if slow HTML volume)
  echo Sleeping for 2.5 minutes while Nextcloud initializes...
  sleep 30
  echo 2 minutes remaining...
  sleep 30
  echo 1.5 minutes remaining...
  sleep 30
  echo 1 minute remaining...
  sleep 30
  echo 30 seconds remaining...
  sleep 30
  sudo docker compose --file $ADMIN_CRYPT/program-files/dav/compose.yaml down
  sudo systemctl stop docker.socket docker.service mariadb.service
  
  # Remove files skeleton (deprecated, returns with updates)
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/core/skeleton
  
  # Remove unwanted apps (deprecated, return with updates, see manual config)
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/activity
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/app_api
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/systemtags
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/comments
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/contactsinteraction
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/dashboard
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/encryption
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/files_external
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/federation
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/files_reminders
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/firstrunwizard
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/nextcloud_announcements
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/webhook_listeners
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/notifications
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/files_pdfviewer
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/password_policy
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/photos
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/recommendations
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/related_resources
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/support
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/circles
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/text
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/twofactor_nextcloud_notification
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/updatenotification
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/survey_client
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/user_status
  # sudo rm -fr $DOCKER_VOL_CRYPT/dav_html/apps/weather_status

  PHX_CRYPT_INIT_INSTALLED_DAV=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh

# ---

# Install minutely service
if [[ $PHX_CRYPT_INIT_INSTALLED_MINUTELY_SERVICE != true ]]; then
  echo Installing minutely service...
  if ! sudo [ -d $ROOT_CRYPT/program-files ]; then
    sudo mkdir $ROOT_CRYPT/program-files
    sudo chmod 700 $ROOT_CRYPT/program-files
  fi
  if ! sudo [ -d $ROOT_CRYPT/program-files/minutely-service ]; then
    sudo mkdir $ROOT_CRYPT/program-files/minutely-service
    sudo chmod 700 $ROOT_CRYPT/program-files/minutely-service
  fi
  cat $PROGRAM_DIR/config/etc--systemd--system--minutely.timer.template | envsubst | sudo tee $ROOT_CRYPT/program-files/minutely-service/minutely.timer > /dev/null
  sudo rm -f /etc/systemd/system/phx.minutely.timer
  sudo ln -s $ROOT_CRYPT/program-files/minutely-service/minutely.timer /etc/systemd/system/phx.minutely.timer
  sudo cp $PROGRAM_DIR/config/etc--systemd--system--minutely.service $ROOT_CRYPT/program-files/minutely-service/minutely.service
  sudo rm -f /etc/systemd/system/phx.minutely.service
  sudo ln -s $ROOT_CRYPT/program-files/minutely-service/minutely.service /etc/systemd/system/phx.minutely.service
  sudo systemctl daemon-reload
  sudo cp $PROGRAM_DIR/lib/root.minutely-service.sh $ROOT_CRYPT/program-files/minutely-service/minutely-service.sh
  PHX_CRYPT_INIT_INSTALLED_MINUTELY_SERVICE=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install daily service
if [[ $PHX_CRYPT_INIT_INSTALLED_DAILY_SERVICE != true ]]; then
  echo Installing daily service...
  if ! sudo [ -d $ROOT_CRYPT/program-files ]; then
    sudo mkdir $ROOT_CRYPT/program-files
    sudo chmod 700 $ROOT_CRYPT/program-files
  fi
  if ! sudo [ -d $ROOT_CRYPT/program-files/daily-service ]; then
    sudo mkdir $ROOT_CRYPT/program-files/daily-service
    sudo chmod 700 $ROOT_CRYPT/program-files/daily-service
  fi
  if ! sudo [ -d $ROOT_CRYPT/program-files/backup-service ]; then
    sudo mkdir $ROOT_CRYPT/program-files/backup-service
    sudo chmod 700 $ROOT_CRYPT/program-files/backup-service
  fi
  cat $PROGRAM_DIR/config/etc--systemd--system--daily.timer.template | envsubst | sudo tee $ROOT_CRYPT/program-files/daily-service/daily.timer > /dev/null
  sudo rm -f /etc/systemd/system/phx.daily.timer
  sudo ln -s $ROOT_CRYPT/program-files/daily-service/daily.timer /etc/systemd/system/phx.daily.timer
  sudo cp $PROGRAM_DIR/config/etc--systemd--system--daily.service $ROOT_CRYPT/program-files/daily-service/daily.service
  sudo rm -f /etc/systemd/system/phx.daily.service
  sudo ln -s $ROOT_CRYPT/program-files/daily-service/daily.service /etc/systemd/system/phx.daily.service
  sudo systemctl daemon-reload
  sudo cp $PROGRAM_DIR/lib/root.daily-service.sh $ROOT_CRYPT/program-files/daily-service/daily-service.sh
  cat $PROGRAM_DIR/config/backup-service.rclone.conf.template | envsubst | sudo tee $ROOT_CRYPT/program-files/backup-service/rclone.conf > /dev/null
  sudo rm -f $ROOT_CRYPT/program-files/backup-service/daily.docker-vol-crypt-data.snar
  sudo rm -f $ROOT_CRYPT/program-files/backup-service/daily.admin-crypt-data.snar
  sudo rm -f $ROOT_CRYPT/program-files/backup-service/daily.mysql-crypt-data.snar
  PHX_CRYPT_INIT_INSTALLED_DAILY_SERVICE=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install admin scripts
if [[ $PHX_CRYPT_INIT_INSTALLED_ADMIN_SCRIPTS != true ]]; then
  echo Installing admin scripts...
  cp $PROGRAM_DIR/lib/start.sh $CRYPT_ADMIN_DIR/phx.$PHX_CRYPT_INIT_FEATURE_SET.start.sh
  cp $PROGRAM_DIR/lib/stop.sh $CRYPT_ADMIN_DIR/phx.$PHX_CRYPT_INIT_FEATURE_SET.stop.sh
  cp $PROGRAM_DIR/lib/status.sh $CRYPT_ADMIN_DIR/phx.$PHX_CRYPT_INIT_FEATURE_SET.status.sh
  cp $PROGRAM_DIR/lib/update-apt-packages-reboot.sh $CRYPT_ADMIN_DIR/phx.$PHX_CRYPT_INIT_FEATURE_SET.update-apt-packages-reboot.sh
  PHX_CRYPT_INIT_INSTALLED_ADMIN_SCRIPTS=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 