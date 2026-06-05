# CI Templates

GitLab CI/CD 可重用模板，透過 `include` 引用到各專案的 `.gitlab-ci.yml`。

## 目錄結構

```
ci-templates/
├── jobs/
│   ├── notify-telegram.yml   # Telegram 部署通知
│   ├── secret-detection.yml  # 機敏資訊掃描
│   └── ssh-deploy.yml        # SSH 遠端部署
└── templates/
    ├── gitlab-ci-starter.yml # 完整 CI 範本
    ├── gitignore-python.txt  # Python 專案 .gitignore
    └── gitignore-react.txt   # React 專案 .gitignore
```

## 使用方式

在專案的 `.gitlab-ci.yml` 加入 `include`：

```yaml
include:
  - project: 'your-group/ci-templates'
    ref: main
    file: '/jobs/ssh-deploy.yml'
  - project: 'your-group/ci-templates'
    ref: main
    file: '/jobs/notify-telegram.yml'
```

## Jobs

### ssh-deploy

透過 SSH 將檔案部署到遠端主機，執行 `docker compose up -d`。

**需要的 CI/CD 變數：**

| 變數 | 類型 | 說明 |
|------|------|------|
| `SSH_DEPLOY_KEY` | File | 部署用 SSH 私鑰 |
| `DEPLOY_HOST` | Variable | 目標主機 IP 或 hostname |
| `DEPLOY_USER` | Variable | 登入帳號 |
| `DEPLOY_PATH` | Variable | 部署路徑 |

### notify-telegram

在 pipeline 結束後發送 Telegram 通知，帶有 commit 資訊與 job 結果。

**需要的 CI/CD 變數：**

| 變數 | 說明 |
|------|------|
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token |
| `TELEGRAM_CHAT_ID` | 接收通知的 Chat ID |

### secret-detection

掃描 repository 中的機敏資訊（API key、密碼、憑證檔）。建議加入所有專案的 CI pipeline。

## 新專案快速啟動

複製 `templates/gitlab-ci-starter.yml` 到專案根目錄，重新命名為 `.gitlab-ci.yml`，依需求調整。
