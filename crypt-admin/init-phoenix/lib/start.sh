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

if [[ $PHX_MANAGE_SWAP = true ]]; then
  sudo mv /root/crypt/.phx.swapfile /root/.phx.swapfile
  sudo swapon /root/.phx.swapfile
fi

sudo systemctl restart nginx.service
sudo systemctl restart prometheus-nginx-exporter.service

sudo systemctl restart mariadb.service
sudo systemctl restart prometheus-mysqld-exporter.service

sudo systemctl restart docker.service
sudo systemctl restart docker.socket

if [[ $PHX_LDAP_ENABLED = true ]]; then
  set +e; sudo docker compose --file /home/ubuntu/crypt/program-files/ldap/compose.yaml up --detach; set -e
fi
if [[ $PHX_AUTH_ENABLED = true ]]; then
  set +e; sudo docker compose --file /home/ubuntu/crypt/program-files/auth/compose.yaml up --detach; set -e
fi
if [[ $PHX_SECRETS_ENABLED = true ]]; then
  set +e; sudo docker compose --file /home/ubuntu/crypt/program-files/secrets/compose.yaml up --detach; set -e
fi
if [[ $PHX_DOCS_ENABLED = true ]]; then
  set +e; sudo docker compose --file /home/ubuntu/crypt/program-files/docs/compose.yaml up --detach; set -e
fi
if [[ $PHX_SHEETS_ENABLED = true ]]; then
  set +e; sudo docker compose --file /home/ubuntu/crypt/program-files/sheets/compose.yaml up --detach; set -e
fi
if [[ $PHX_DAV_ENABLED = true ]]; then
  set +e; sudo docker compose --file /home/ubuntu/crypt/program-files/dav/compose.yaml up --detach; set -e
fi

sudo systemctl restart phx.minutely.timer
sudo systemctl restart phx.daily.timer

set -a
set -e