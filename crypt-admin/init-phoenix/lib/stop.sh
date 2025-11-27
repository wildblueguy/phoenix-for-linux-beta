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

sudo systemctl stop phx.daily.timer
sudo systemctl stop phx.minutely.timer
set +a
set +e
systemctl status --no-pager phx.minutely.service > /dev/null
MINUTELY_STATUS=$?
while [[ $MINUTELY_STATUS -eq 0 ]]; do
  echo Waiting 5 seconds for minutely service to exit...
  sleep 5
  systemctl status --no-pager phx.minutely.service  > /dev/null
  MINUTELY_STATUS=$?
done
set -e
set -a

set +e
sudo docker compose --file /home/ubuntu/crypt/program-files/dav/compose.yaml down --timeout 60
sudo docker compose --file /home/ubuntu/crypt/program-files/sheets/compose.yaml down --timeout 60
sudo docker compose --file /home/ubuntu/crypt/program-files/docs/compose.yaml down --timeout 60
sudo docker compose --file /home/ubuntu/crypt/program-files/secrets/compose.yaml down --timeout 60
sudo docker compose --file /home/ubuntu/crypt/program-files/auth/compose.yaml down --timeout 60
sudo docker compose --file /home/ubuntu/crypt/program-files/ldap/compose.yaml down --timeout 60
set -e

sudo systemctl stop docker.socket
sudo systemctl stop docker.service

sudo systemctl stop prometheus-mysqld-exporter.service
sudo systemctl stop mariadb.service

sudo systemctl stop prometheus-nginx-exporter.service
sudo systemctl stop nginx.service

if [[ $PHX_MANAGE_SWAP = true ]]; then
  sudo swapoff /root/.phx.swapfile
  sudo mv /root/.phx.swapfile /root/crypt/.phx.swapfile
fi

set -a
set -e