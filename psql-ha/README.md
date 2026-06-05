# PostgreSQL HA

以 Docker Compose 部署的 PostgreSQL 高可用叢集，使用 Patroni 管理主從切換，etcd 作為分散式設定儲存，HAProxy 提供統一連線入口。

## 架構

```
            ┌─────────────┐
  應用程式 ──► HAProxy       │  (port 5000 primary / 5001 replica)
            └──────┬──────┘
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
  ┌─────────┐ ┌─────────┐ ┌─────────┐
  │Patroni 1│ │Patroni 2│ │Patroni 3│
  │PostgreSQL│ │PostgreSQL│ │PostgreSQL│
  └────┬────┘ └────┬────┘ └────┬────┘
       │           │           │
  ┌────▼───────────▼───────────▼────┐
  │        etcd cluster (3 nodes)   │
  └─────────────────────────────────┘
```

| 元件 | 數量 | 說明 |
|------|------|------|
| Patroni + PostgreSQL | 3 | 自動 leader election，支援 failover |
| etcd | 3 | 儲存叢集狀態與 leader 資訊 |
| HAProxy | 1 | 自動路由到 primary（5000）或 replica（5001）|

## 快速開始

```bash
cp .env.example .env
# 填入密碼
vim .env

docker compose up -d
```

## 連線

| 用途 | Port |
|------|------|
| Primary（讀寫）| 5000 |
| Replica（唯讀）| 5001 |
| HAProxy 狀態頁 | 7000 |
| Patroni REST API | 8008–8010 |

```bash
# 連線到 primary
psql -h localhost -p 5000 -U postgres

# 查看叢集狀態
docker exec patroni1 patronictl -c /etc/patroni/patroni.yml list
```

## Failover

```bash
# 手動切換 primary
docker exec patroni1 patronictl -c /etc/patroni/patroni.yml failover pg-ha-cluster
```

## 環境變數

| 變數 | 說明 |
|------|------|
| `POSTGRES_PASSWORD` | superuser 密碼 |
| `REPLICATION_PASSWORD` | replication 帳號密碼 |
