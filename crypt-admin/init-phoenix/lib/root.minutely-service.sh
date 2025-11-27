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

set +a
set +e
LDAP_STATUS=$(docker container list --all --filter name=ldap-* --filter status=running)
LDAP_STATUS_EXIT=$?
AUTH_STATUS=$(docker container list --all --filter name=auth-* --filter status=running)
AUTH_STATUS_EXIT=$?
SECRETS_STATUS=$(docker container list --all --filter name=secrets-* --filter status=running)
SECRETS_STATUS_EXIT=$?
DOCS_STATUS=$(docker container list --all --filter name=docs-* --filter status=running)
DOCS_STATUS_EXIT=$?
SHEETS_STATUS=$(docker container list --all --filter name=sheets-* --filter status=running)
SHEETS_STATUS_EXIT=$?
DAV_STATUS=$(docker container list --all --filter name=dav-* --filter status=running)
DAV_STATUS_EXIT=$?
HOSTNAME=$(hostname)
INSTANCE_SIG=$(echo -e "PHX: $PHX_INSTANCE_ID\nCryptInit: $PHX_CRYPT_INIT_FEATURE_SET $PHX_CRYPT_INIT_VERSION\nPlatInit: $PHX_PLATFORM_INIT_FEATURE_SET $PHX_PLATFORM_INIT_VERSION\nHost: $HOSTNAME")
set -e
set -a

PHX_MSMTP_MAIL_TEMPLATE_FROM="$HOSTNAME <$PHX_MSMTP_FROM>"
PHX_MSMTP_MAIL_TEMPLATE_TO="PHX Admin <$PHX_ADMIN_EMAIL>"

# LDAP
if [[ $PHX_LDAP_ENABLED = true && LDAP_STATUS_EXIT -eq 0 && $(echo "$LDAP_STATUS" | wc -l) != 2 ]]; then
  echo WARNING: Not all LDAP Docker services are running. Attempting to notify admin and run compose down/up cycle...
  PHX_MSMTP_MAIL_TEMPLATE_SUBJECT="[PHX $PHX_INSTANCE_ID] $PHX_LDAP_DOMAIN is degraded"
  PHX_MSMTP_MAIL_TEMPLATE_BODY=$(echo -e "Not all LDAP Docker services are running. Attempting compose down/up cycle...\n\nLDAP: $PHX_LDAP_DOMAIN\n$INSTANCE_SIG")
  cat /home/ubuntu/crypt/crypt-admin/init-phoenix/config/msmtp-message.template | envsubst | msmtp -a crypt $PHX_ADMIN_EMAIL
  set +e; docker compose --file /home/ubuntu/crypt/program-files/ldap/compose.yaml down --timeout 60; set -e
  if [[ $? -eq 0 ]]; then
    set +e; docker compose --file /home/ubuntu/crypt/program-files/ldap/compose.yaml up --detach; set -e
  fi
fi

# Auth
if [[ $PHX_AUTH_ENABLED = true && AUTH_STATUS_EXIT -eq 0 && $(echo "$AUTH_STATUS" | wc -l) != 2 ]]; then
  echo WARNING: Not all Auth Docker services are running. Attempting to notify admin and run compose down/up cycle...
  PHX_MSMTP_MAIL_TEMPLATE_SUBJECT="[PHX $PHX_INSTANCE_ID] $PHX_AUTH_DOMAIN is degraded"
  PHX_MSMTP_MAIL_TEMPLATE_BODY=$(echo -e "Not all Auth Docker services are running. Attempting compose down/up cycle...\n\nAuth: $PHX_AUTH_DOMAIN\n$INSTANCE_SIG")
  cat /home/ubuntu/crypt/crypt-admin/init-phoenix/config/msmtp-message.template | envsubst | msmtp -a crypt $PHX_ADMIN_EMAIL
  set +e; docker compose --file /home/ubuntu/crypt/program-files/auth/compose.yaml down --timeout 60; set -e
  if [[ $? -eq 0 ]]; then
    set +e; docker compose --file /home/ubuntu/crypt/program-files/auth/compose.yaml up --detach; set -e
  fi
fi

# Secrets
if [[ $PHX_SECRETS_ENABLED = true && SECRETS_STATUS_EXIT -eq 0 && $(echo "$SECRETS_STATUS" | wc -l) != 2 ]]; then
  echo WARNING: Not all Secrets Docker services are running. Attempting to notify admin and run compose down/up cycle...
  PHX_MSMTP_MAIL_TEMPLATE_SUBJECT="[PHX $PHX_INSTANCE_ID] $PHX_SECRETS_DOMAIN is degraded"
  PHX_MSMTP_MAIL_TEMPLATE_BODY=$(echo -e "Not all Secrets Docker services are running. Attempting compose down/up cycle...\n\nSecrets: $PHX_SECRETS_DOMAIN\n$INSTANCE_SIG")
  cat /home/ubuntu/crypt/crypt-admin/init-phoenix/config/msmtp-message.template | envsubst | msmtp -a crypt $PHX_ADMIN_EMAIL
  set +e; docker compose --file /home/ubuntu/crypt/program-files/secrets/compose.yaml down --timeout 60; set -e
  if [[ $? -eq 0 ]]; then
    set +e; docker compose --file /home/ubuntu/crypt/program-files/secrets/compose.yaml up --detach; set -e
  fi
fi

# Docs
if [[ $PHX_DOCS_ENABLED = true && DOCS_STATUS_EXIT -eq 0 && LDAP_STATUS_EXIT -eq 0 && $(echo "$DOCS_STATUS" | wc -l) != 3 ]]; then
  echo WARNING: Not all Docs Docker services are running. Attempting to notify admin and run compose down/up cycle...
  PHX_MSMTP_MAIL_TEMPLATE_SUBJECT="[PHX $PHX_INSTANCE_ID] $PHX_DOCS_DOMAIN is degraded"
  PHX_MSMTP_MAIL_TEMPLATE_BODY=$(echo -e "Not all Docs Docker services are running. Attempting compose down/up cycle...\n\nDocs: $PHX_DOCS_DOMAIN\n$INSTANCE_SIG")
  cat /home/ubuntu/crypt/crypt-admin/init-phoenix/config/msmtp-message.template | envsubst | msmtp -a crypt $PHX_ADMIN_EMAIL
  set +e; docker compose --file /home/ubuntu/crypt/program-files/docs/compose.yaml down --timeout 60; set -e
  if [[ $? -eq 0 ]]; then
    set +e; docker compose --file /home/ubuntu/crypt/program-files/docs/compose.yaml up --detach; set -e
  fi
fi

# Sheets
if [[ $PHX_SHEETS_ENABLED = true && SHEETS_STATUS_EXIT -eq 0 && $(echo "$SHEETS_STATUS" | wc -l) != 2 ]]; then
  echo WARNING: Not all Sheets Docker services are running. Attempting to notify admin and run compose down/up cycle...
  PHX_MSMTP_MAIL_TEMPLATE_SUBJECT="[PHX $PHX_INSTANCE_ID] $PHX_SHEETS_DOMAIN is degraded"
  PHX_MSMTP_MAIL_TEMPLATE_BODY=$(echo -e "Not all Sheets Docker services are running. Attempting compose down/up cycle...\n\nSheets: $PHX_SHEETS_DOMAIN\n$INSTANCE_SIG")
  cat /home/ubuntu/crypt/crypt-admin/init-phoenix/config/msmtp-message.template | envsubst | msmtp -a crypt $PHX_ADMIN_EMAIL
  set +e; docker compose --file /home/ubuntu/crypt/program-files/sheets/compose.yaml down --timeout 60; set -e
  if [[ $? -eq 0 ]]; then
    set +e; docker compose --file /home/ubuntu/crypt/program-files/sheets/compose.yaml up --detach; set -e
  fi
fi

PHX_RECOMPOSED_DAV=false

# DAV
if [[ $PHX_DAV_ENABLED = true && DAV_STATUS_EXIT -eq 0 && $(echo "$DAV_STATUS" | wc -l) != 2 ]]; then
  echo WARNING: Not all DAV Docker services are running. Attempting to notify admin and run compose down/up cycle...
  PHX_MSMTP_MAIL_TEMPLATE_SUBJECT="[PHX $PHX_INSTANCE_ID] $PHX_DAV_DOMAIN is degraded"
  PHX_MSMTP_MAIL_TEMPLATE_BODY=$(echo -e "Not all DAV Docker services are running. Attempting compose down/up cycle...\n\nDAV: $PHX_DAV_DOMAIN\n$INSTANCE_SIG")
  cat /home/ubuntu/crypt/crypt-admin/init-phoenix/config/msmtp-message.template | envsubst | msmtp -a crypt $PHX_ADMIN_EMAIL
  set +e; docker compose --file /home/ubuntu/crypt/program-files/dav/compose.yaml down --timeout 60; set -e
  if [[ $? -eq 0 ]]; then
    set +e; docker compose --file /home/ubuntu/crypt/program-files/dav/compose.yaml up --detach; set -e
  fi
  PHX_RECOMPOSED_DAV=true
fi

# If DAV enabled and all services running...
if [[ $PHX_DAV_ENABLED = true && DAV_STATUS_EXIT -eq 0 && $PHX_RECOMPOSED_DAV = false ]]; then
  # Restart Nextcloud once per 6 'minutely' periods, on average
  set +a; RESTART_NEXTCLOUD=$((RANDOM % 6)); set -a
  if [[ $RESTART_NEXTCLOUD = 0 ]]; then
    echo Doing random restart of Nextcloud...
    set +e; docker container restart dav-nextcloud; set -e
  fi
fi