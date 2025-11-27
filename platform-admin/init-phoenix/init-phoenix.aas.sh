PLATFORM_ADMIN_DIR=/home/ubuntu/platform-admin
PROGRAM_DIR=$PLATFORM_ADMIN_DIR/init-phoenix # Can be mounted dev/working copy

set -e # Exit if error
set -a # Subsequent variables are exported

# Load environment
. $PROGRAM_DIR/config/config.sh
. $PROGRAM_DIR/config/config.aas.sh
if [ -f $PROGRAM_DIR/state/state.sh ]; then
  . $PROGRAM_DIR/state/state.sh
fi
if [ -f $PROGRAM_DIR/state/state.aas.sh ]; then
  . $PROGRAM_DIR/state/state.aas.sh
fi

PHX_PLATFORM_INIT_FEATURE_SET=aas
PHX_PLATFORM_INIT_VERSION=2025-06

if [[ PHX_PLATFORM_INIT_FEATURE_SET = '' ]]; then
  PHX_PLATFORM_INIT_FEATURE_SET=base
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Detect AES-NI
sudo lscpu | grep 'Flags:.*\Waes\W'
if [[ $? -eq 0 ]]; then
  CPU_HAS_AES_NI=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Common init (stateless)
sudo apt update
sudo apt install -y crudini

# ---

# Common init (port generation)
if [[ $PHX_PLATFORM_INIT_GENERATED_PORTS != true ]]; then
  echo Generating ports... 
  shuf -i 10000-28999 -n 1900 --random-source=/dev/random > $PROGRAM_DIR/state/platform-ports.sh-array
  PHX_PLATFORM_INIT_GENERATED_PORTS=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Common init (port assignment, MAY add/remove indices but MUST NOT re-use)
readarray -t PHX_PLATFORM_PORTS < $PROGRAM_DIR/state/platform-ports.sh-array
PHX_SYSTEM_METRICS_PORT=${PHX_PLATFORM_PORTS[0]}
PHX_NGINX_STATUS_PORT=${PHX_PLATFORM_PORTS[1]}
PHX_NGINX_METRICS_PORT=${PHX_PLATFORM_PORTS[2]}
PHX_MARIA_DB_METRICS_PORT=${PHX_PLATFORM_PORTS[3]}
PHX_DOCKER_METRICS_PORT=${PHX_PLATFORM_PORTS[4]}

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install MSMTP
if [[ $PHX_PLATFORM_INIT_INSTALLED_MSMTP != true ]]; then
  echo Installing MSMTP...
  sudo apt install -y msmtp
  cat $PROGRAM_DIR/config/etc--msmtprc.template | envsubst | sudo tee /etc/msmtprc > /dev/null
  sudo chown root:sudo /etc/msmtprc
  sudo chmod 640 /etc/msmtprc
  PHX_PLATFORM_INIT_INSTALLED_MSMTP=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Configure JournalD
if [[ $PHX_PLATFORM_INIT_CONFIGURED_JOURNAL_D != true ]]; then
  echo Configuring JournalD...
  sudo crudini --set --ini-options=nospace /etc/systemd/journald.conf Journal SystemMaxUse 1000M
  sudo crudini --set --ini-options=nospace /etc/systemd/journald.conf Journal SystemKeepFree 1000M
  sudo crudini --set --ini-options=nospace /etc/systemd/journald.conf Journal SystemMaxFileSize 10M
  sudo crudini --set --ini-options=nospace /etc/systemd/journald.conf Journal SystemMaxFiles 100
  sudo systemctl restart systemd-journald
  PHX_PLATFORM_INIT_CONFIGURED_JOURNAL_D=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install swap file
if [[ $PHX_MANAGE_SWAP = true && $PHX_PLATFORM_INIT_INSTALLED_SWAP_FILE != true ]]; then
  echo Installing swap file...
  set +a; SWAPON_SHOW_OUTPUT=$(swapon --show); set -a
  if [[ $? -ne 0 ]]; then
    echo FATAL: Error executing command \`swapon --show\`
    exit 1
  fi
  if [[ $SWAPON_SHOW_OUTPUT != '' ]]; then
    PHX_SYSTEM_HAS_UNMANAGED_SWAP=true
  fi
  sudo touch /root/.phx.swapfile
  sudo chmod 600 /root/.phx.swapfile
  sudo dd if=/dev/zero of=/root/.phx.swapfile bs=$PHX_SWAP_FILE_GEN_DD_BLOCK_SIZE count=$PHX_SWAP_FILE_GEN_DD_BLOCK_COUNT status=progress
  sudo mkswap /root/.phx.swapfile
  PHX_PLATFORM_INIT_INSTALLED_SWAP_FILE=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install system metrics exporter
if [[ $PHX_PLATFORM_INIT_INSTALLED_SYSTEM_METRICS_EXPORTER != true ]]; then
  echo Installing system metrics exporter...
  sudo apt install -y prometheus-node-exporter
  sudo crudini --set /etc/default/prometheus-node-exporter '' ARGS \"--web.listen-address=$PHX_PRIVATE_NIC_ADDRESS:$PHX_SYSTEM_METRICS_PORT\"
  sudo systemctl restart prometheus-node-exporter
  PHX_PLATFORM_INIT_INSTALLED_SYSTEM_METRICS_EXPORTER=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install Nginx
if [[ $PHX_PLATFORM_INIT_INSTALLED_NGINX != true ]]; then
  echo Installing Nginx...
  sudo apt install -y nginx libnginx-mod-stream
  sudo systemctl disable nginx.service
  sudo systemctl stop nginx.service
  sudo rm -f /etc/nginx/sites-enabled/default
  if ! [ -f /etc/nginx/nginx.conf.init-phoenix.aas.backup ]; then
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.init-phoenix.aas.backup
  fi
  sudo cp $PROGRAM_DIR/config/etc--nginx--nginx.conf /etc/nginx/nginx.conf
  cat $PROGRAM_DIR/config/nginx-status.http.nginx.conf.template | envsubst | sudo tee /etc/nginx/sites-available/nginx-status > /dev/null
  sudo rm -f /etc/nginx/sites-enabled/nginx-status
  sudo ln -s /etc/nginx/sites-available/nginx-status /etc/nginx/sites-enabled/nginx-status
  PHX_PLATFORM_INIT_INSTALLED_NGINX=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install Nginx metrics exporter
if [[ $PHX_PLATFORM_INIT_INSTALLED_NGINX_METRICS_EXPORTER != true ]]; then
  echo Installing Nginx metrics exporter...
  sudo apt install -y prometheus-nginx-exporter
  sudo systemctl disable prometheus-nginx-exporter
  sudo systemctl stop prometheus-nginx-exporter
  sudo crudini --set /etc/default/prometheus-nginx-exporter '' ARGS "\"--nginx.scrape-uri=http://127.0.0.1:$PHX_NGINX_STATUS_PORT/nginx-status --web.listen-address=$PHX_PRIVATE_NIC_ADDRESS:$PHX_NGINX_METRICS_PORT\""
  PHX_PLATFORM_INIT_INSTALLED_NGINX_METRICS_EXPORTER=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install MariaDB
if [[ $PHX_PLATFORM_INIT_INSTALLED_MARIA_DB != true ]]; then
  echo Installing MariaDB...
  sudo apt install -y mariadb-server
  sudo systemctl disable mariadb.service
  sudo systemctl stop mariadb.service
  PHX_MYSQL_UID=$(id --user mysql)
  PHX_MYSQL_GID=$(id --group mysql)
  sudo rm -f /root/.mysql_history
  sudo ln -s /dev/null /root/.mysql_history
  sudo cp $PROGRAM_DIR/config/etc--mysql--mariadb.conf.d--99-overrides.cnf /etc/mysql/mariadb.conf.d/99-overrides.cnf
  sudo chmod 644 /etc/mysql/mariadb.conf.d/99-overrides.cnf
  sudo mkdir /mysql
  sudo chown mysql:mysql /mysql
  sudo chmod 700 /mysql
  PHX_PLATFORM_INIT_INSTALLED_MARIA_DB=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install MariaDB metrics exporter
if [[ $PHX_PLATFORM_INIT_INSTALLED_MARIA_DB_METRICS_EXPORTER != true ]]; then
  echo Installing MariaDB metrics exporter...
  sudo apt install -y prometheus-mysqld-exporter
  sudo systemctl disable prometheus-mysqld-exporter
  sudo systemctl stop prometheus-mysqld-exporter
  sudo crudini --set /usr/lib/systemd/system/prometheus-mysqld-exporter.service Service User ubuntu
  sudo crudini --set /etc/default/prometheus-mysqld-exporter '' ARGS "\"--config.my-cnf=/home/ubuntu/crypt/program-files/maria-db-metrics-exporter.my.cnf --web.listen-address=$PHX_PRIVATE_NIC_ADDRESS:$PHX_MARIA_DB_METRICS_PORT\""
  PHX_PLATFORM_INIT_INSTALLED_MARIA_DB_METRICS_EXPORTER=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install Docker
if [[ $PHX_PLATFORM_INIT_INSTALLED_DOCKER != true ]]; then
  echo Installing Docker...
  . $PROGRAM_DIR/lib/install-docker.sh
  sudo systemctl disable docker.service docker.socket
  sudo systemctl stop docker.socket docker.service
  cat $PROGRAM_DIR/config/etc--docker--daemon.json.aas.template | envsubst | sudo tee /etc/docker/daemon.json > /dev/null
  sudo chmod 600 /etc/docker/daemon.json
  PHX_PLATFORM_INIT_INSTALLED_DOCKER=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install crypts
if [[ $PHX_PLATFORM_INIT_INSTALLED_CRYPTS != true ]]; then
  echo Installing crypts...
  if ! [ -d /root/crypt ]; then
    sudo mkdir /root/crypt
    sudo chmod 700 /root/crypt
  fi
  if ! [ -d /root/docker-vol-crypt ]; then
    sudo mkdir /root/docker-vol-crypt
    sudo chmod 701 /root/docker-vol-crypt # Emulate default Docker volume dir
  fi
  if ! [ -d /home/ubuntu/crypt ]; then
    sudo mkdir /home/ubuntu/crypt
    sudo chown ubuntu:ubuntu /home/ubuntu/crypt
    sudo chmod 700 /home/ubuntu/crypt
  fi
  if ! [ -d /mysql/crypt ]; then
    sudo mkdir /mysql/crypt
    sudo chown mysql:mysql /mysql/crypt
    sudo chmod 700 /mysql/crypt
  fi
  if [[ $PHX_PROTECT_CRYPTS_WITH_FS_ENCRYPTION = true ]]; then
    if ! [ -d /root/crypt-data ]; then
      sudo mkdir /root/crypt-data
      sudo chmod 700 /root/crypt-data
    fi
    if ! [ -d /root/docker-vol-crypt-data ]; then
      sudo mkdir /root/docker-vol-crypt-data
      sudo chmod 701 /root/docker-vol-crypt-data # Emulate default Docker volume dir
    fi
    if ! [ -d /home/ubuntu/crypt-data ]; then
      sudo mkdir /home/ubuntu/crypt-data
      sudo chown ubuntu:ubuntu /home/ubuntu/crypt-data
      sudo chmod 700 /home/ubuntu/crypt-data
    fi
    if ! [ -d /mysql/crypt-data ]; then
      sudo mkdir /mysql/crypt-data
      sudo chown mysql:mysql /mysql/crypt-data
      sudo chmod 700 /mysql/crypt-data
    fi
    if ! [ -f /etc/fuse.conf.init-phoenix.aas.backup ]; then
      sudo cp /etc/fuse.conf /etc/fuse.conf.init-phoenix.aas.backup
    else
      sudo cp /etc/fuse.conf.init-phoenix.aas.backup /etc/fuse.conf
    fi
    echo -e '\nuser_allow_other' | sudo tee -a /etc/fuse.conf > /dev/null
    sudo apt install -y gocryptfs
    echo root crypt:
    sudo gocryptfs -init /root/crypt-data
    echo docker volume crypt:
    sudo gocryptfs -init /root/docker-vol-crypt-data
    echo admin crypt:
    gocryptfs -init /home/ubuntu/crypt-data
    echo mysql crypt:
    sudo -u mysql gocryptfs -init /mysql/crypt-data
  fi
  PHX_PLATFORM_INIT_INSTALLED_CRYPTS=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh 

# ---

# Install crypt mount script
if [[ $PHX_PLATFORM_INIT_INSTALLED_CRYPT_MOUNT_SCRIPT != true ]]; then
  echo Installing crypt mount script...
  if ! [ -d $PLATFORM_ADMIN_DIR ]; then
    mkdir $PLATFORM_ADMIN_DIR
    chmod 700 $PLATFORM_ADMIN_DIR
  fi
  cat $PROGRAM_DIR/lib/mount-crypts.sh.template | envsubst > $PLATFORM_ADMIN_DIR/phx.$PHX_PLATFORM_INIT_FEATURE_SET.mount-crypts.sh
  PHX_PLATFORM_INIT_INSTALLED_CRYPT_MOUNT_SCRIPT=true
fi

# Save state
cat $PROGRAM_DIR/state/state.sh.template | envsubst > $PROGRAM_DIR/state/state.sh
cat $PROGRAM_DIR/state/state.aas.sh.template | envsubst > $PROGRAM_DIR/state/state.aas.sh