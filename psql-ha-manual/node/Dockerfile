FROM postgres:16-bookworm

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget \
    python3 python3-pip python3-venv \
    vim less procps net-tools iputils-ping \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/lib/postgresql/data \
    && chown -R postgres:postgres /var/lib/postgresql

EXPOSE 5432 8008 2379 2380

# 不啟動 postgres，由 patroni 管理
CMD ["sleep", "infinity"]
