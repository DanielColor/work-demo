# Ollama Stack

以 Docker Compose 部署的本地 AI 推論環境，包含模型服務、聊天介面與 workflow 自動化。

## 架構

```
┌─────────────────────────────────────────┐
│  Ollama          (模型推論，port 11434)  │
│  Open WebUI      (聊天介面，port 3000)   │
│  n8n             (自動化流程，port 5678) │
│  PostgreSQL      (n8n 資料庫)            │
└─────────────────────────────────────────┘
```

| 元件 | 說明 |
|------|------|
| [Ollama](https://ollama.com) | 本地 LLM 推論引擎，支援 Llama、Mistral、Gemma 等 |
| [Open WebUI](https://github.com/open-webui/open-webui) | ChatGPT-like 聊天介面 |
| [n8n](https://n8n.io) | 視覺化 workflow 自動化平台 |

## Compose 檔案

| 檔案 | 說明 |
|------|------|
| `docker-compose.yml` | Ollama + Open WebUI（最小組合）|
| `docker-compose.separate.yml` | 各服務獨立設定版本 |
| `docker-compose.n8n.yml` | 加入 n8n + PostgreSQL |
| `docker-compose.all.yml` | 所有元件一次啟動 |

## 前置需求

- NVIDIA GPU（含 CUDA driver）
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- Docker Compose v2

## 快速開始

```bash
# 啟動 Ollama + Open WebUI
docker compose up -d

# 下載模型
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull nomic-embed-text

# 啟動完整 stack（含 n8n）
docker compose -f docker-compose.all.yml up -d
```

## 存取

| 服務 | URL |
|------|-----|
| Open WebUI | http://localhost:3000 |
| Ollama API | http://localhost:11434 |
| n8n | http://localhost:5678 |
