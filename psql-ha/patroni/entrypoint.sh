#!/bin/bash
set -e

# Wait for at least one etcd node to be reachable
FIRST_ETCD=$(echo "${PATRONI_ETCD3_HOSTS:-etcd1:2379}" | cut -d',' -f1)
echo "Waiting for etcd at http://$FIRST_ETCD ..."
until curl -sf "http://$FIRST_ETCD/health" >/dev/null 2>&1; do
    sleep 2
done
echo "etcd is ready"

# Render config from template (only substitute our known vars to avoid clobbering YAML)
envsubst '${PATRONI_NAME} ${PATRONI_RESTAPI_CONNECT_ADDRESS} ${PATRONI_ETCD3_HOSTS} ${PATRONI_POSTGRESQL_CONNECT_ADDRESS} ${PATRONI_REPLICATION_PASSWORD} ${PATRONI_SUPERUSER_PASSWORD}' \
    < /etc/patroni/patroni.yml.template > /tmp/patroni.yml

exec patroni /tmp/patroni.yml
