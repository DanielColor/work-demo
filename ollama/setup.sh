#!/bin/bash

# 1. 安裝 Docker 與相關套件
echo "--- 正在安裝 Docker Engine ---"
sudo apt update
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 2. 安裝 nvidia-container-toolkit（GPU 支援）
echo "--- 正在安裝 nvidia-container-toolkit ---"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 3. 設定免 sudo 權限
sudo usermod -aG docker $USER

# 4. 在 /opt 下建立專案目錄並設定權限
echo "--- 正在 /opt 下配置 Ollama 與 Open WebUI ---"
PROJECT_DIR="/opt/ollama-webui"
sudo mkdir -p "$PROJECT_DIR"
sudo chown $USER:$USER "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 5. 寫入 docker-compose.yaml
cat << 'DOCKER_EOF' > docker-compose.yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    pull_policy: always
    tty: true
    restart: unless-stopped
    volumes:
      - ./ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  open-webui:
    image: ghcr.io/open-webui/open-webui:v0.5.2
    container_name: open-webui
    volumes:
      - ./open-webui:/app/backend/data
    depends_on:
      - ollama
    ports:
      - "3000:8080"
    environment:
      - 'OLLAMA_BASE_URL=http://ollama:11434'
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
DOCKER_EOF

# 6. 啟動容器
echo "--- 正在啟動容器 ---"
sudo docker compose up -d

echo "===================================================="
echo "安裝完成！"
echo "專案路徑: $PROJECT_DIR"
echo "Open WebUI 位址: http://localhost:3000"
echo "===================================================="
