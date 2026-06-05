FROM postgres:16-bookworm

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    curl gettext-base \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/patroni \
    && /opt/patroni/bin/pip install --no-cache-dir \
       "patroni[etcd3]>=3.3" \
       psycopg2-binary

ENV PATH="/opt/patroni/bin:${PATH}"

COPY patroni.yml.template /etc/patroni/patroni.yml.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 5432 8008

ENTRYPOINT ["/entrypoint.sh"]
