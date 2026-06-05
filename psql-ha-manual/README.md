# PostgreSQL HA Manual

手動建置版本的 PostgreSQL 高可用叢集。與 `psql-ha` 的差別在於：每個節點使用自訂 Docker image，在同一個容器內同時執行 PostgreSQL、Patroni 與 etcd，更接近裸機部署的架構。

## 與 psql-ha 的差異

| | psql-ha | psql-ha-manual |
|-|---------|----------------|
| etcd | 獨立容器（bitnami/etcd）| 內建於每個節點 |
| 節點數 | 3 Patroni + 3 etcd | 3 節點（各自包含 Patroni + etcd）|
| 適合場景 | 快速驗證 | 理解完整部署流程 |

## 架構

```
┌──────────────────────────────────────┐
│  node1 / node2 / node3               │
│  ├── PostgreSQL 16                   │
│  ├── Patroni（leader election）      │
│  └── etcd（分散式設定）              │
└──────────────────────────────────────┘
             │
      ┌──────▼──────┐
      │   HAProxy   │  port 5000 (primary) / 5001 (replica)
      └─────────────┘
```

## 快速開始

```bash
docker compose up -d

# 查看叢集狀態
docker exec node1 patronictl -c /etc/patroni/patroni.yml list
```

## 連線

| 用途 | Port |
|------|------|
| Primary（讀寫）| 5000 |
| Replica（唯讀）| 5001 |
| node1 PostgreSQL | 15432 |
| node2 PostgreSQL | 25432 |
| node3 PostgreSQL | 35432 |
| Patroni REST API | 18008 / 28008 / 38008 |

## 設定檔

| 檔案 | 說明 |
|------|------|
| `configs/patroni.yml` | Patroni 設定範本（三個節點各自調整 name 與 IP）|
| `configs/supervisord.conf` | supervisord 設定，同時管理 etcd 與 Patroni 程序 |
| `haproxy/haproxy.cfg` | HAProxy 設定 |
| `node/Dockerfile` | 自訂節點 image |
