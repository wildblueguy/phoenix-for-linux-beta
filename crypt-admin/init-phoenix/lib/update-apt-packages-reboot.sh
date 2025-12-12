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

. /home/ubuntu/crypt/crypt-admin/phx.$PHX_CRYPT_INIT_FEATURE_SET.stop.sh

sudo apt update
sudo apt upgrade -y

sudo crudini --set /usr/lib/systemd/system/prometheus-mysqld-exporter.service Service User ubuntu # Reverts on package upgrade (initial in crypt init)

sudo reboot now