set +e
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
  sudo stat /root/crypt/.phx.swapfile
  echo -e '---'
  sudo stat /root/.phx.swapfile
  echo -e '---'
  swapon --show
  echo -e '---'
fi

systemctl status --no-pager nginx.service
echo -e '---'
systemctl status --no-pager prometheus-nginx-exporter.service
echo -e '---'

systemctl status --no-pager mariadb.service
echo -e '---'
systemctl status --no-pager prometheus-mysqld-exporter.service
echo -e '---'

systemctl status --no-pager docker.service
echo -e '---'
systemctl status --no-pager docker.socket
echo -e '---'

echo -e "Docker containers like 'ldap-*':"
sudo docker container list --all --filter name=ldap-* --format 'table {{.Names}} | {{.Image}} | {{.CreatedAt}} | {{.Status}}'
echo -e "---\nDocker containers like 'auth-*':"
sudo docker container list --all --filter name=auth-* --format 'table {{.Names}} | {{.Image}} | {{.CreatedAt}} | {{.Status}}'
echo -e "---\nDocker containers like 'secrets-*':"
sudo docker container list --all --filter name=secrets-* --format 'table {{.Names}} | {{.Image}} | {{.CreatedAt}} | {{.Status}}'
echo -e "---\nDocker containers like 'docs-*':"
sudo docker container list --all --filter name=docs-* --format 'table {{.Names}} | {{.Image}} | {{.CreatedAt}} | {{.Status}}'
echo -e "---\nDocker containers like 'sheets-*':"
sudo docker container list --all --filter name=sheets-* --format 'table {{.Names}} | {{.Image}} | {{.CreatedAt}} | {{.Status}}'
echo -e "---\nDocker containers like 'dav-*':"
sudo docker container list --all --filter name=dav-* --format 'table {{.Names}} | {{.Image}} | {{.CreatedAt}} | {{.Status}}'
echo -e '---'

systemctl status --no-pager phx.minutely.timer
echo -e '---'
systemctl status --no-pager phx.minutely.service
echo -e '---'

systemctl status --no-pager phx.daily.timer
echo -e '---'
systemctl status --no-pager phx.daily.service
echo -e '---'

set -a
set -e