# prometheus_file_sd

在 monitor 機器上根據 inventory 群組，產生 Prometheus [file-based service discovery](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#file_sd_config) 的 target 檔案，並在有變更時自動 reload Prometheus。

## 運作方式

1. 讀取 `prometheus_file_sd_exporter_groups` 列出的群組，找出所有有被監控的機器
2. 對每台機器產生一個 `{hostname}.yml` 放到 Prometheus targets 目錄
3. 清理已不在 inventory 的舊 target 檔案
4. 有變更時 POST `/-/reload` 通知 Prometheus 重新載入

## 變數

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `prometheus_file_sd_dir` | `{{ monitoring_src_path }}/prometheus/targets` | target 檔案目錄 |
| `prometheus_reload_url` | `http://localhost:9090/-/reload` | Prometheus reload endpoint |
| `prometheus_file_sd_exporter_groups` | `[node_exporter]` | 要納入監控的 exporter 群組清單 |

## Target 檔案格式

每台機器產生一個獨立檔案，例如 `demo-service.yml`：

```yaml
- targets: ["192.168.1.x:9100"]
  labels:
    hostname: demo-service
    job: node-exporter
    env: internal
    role: server
```

## 新增 exporter 群組

當新增一種 exporter（例如 `haproxy_exporter`）時，在 `defaults/main.yml` 加入群組名稱：

```yaml
prometheus_file_sd_exporter_groups:
  - node_exporter
  - haproxy_exporter
```

同時在 `templates/host_targets.yml.j2` 加入對應的 entry：

```yaml
{% if item in groups.get('haproxy_exporter', []) %}
- targets: ["{{ hostvars[item].ansible_host }}:9101"]
  labels:
    hostname: "{{ item }}"
    job: haproxy-exporter
    env: "{{ prom_env }}"
    role: "{{ hostvars[item].prom_role }}"
{% endif %}
```

## 執行方式

```bash
ansible-playbook site.yml --tags prometheus_file_sd
```

這個 role 永遠在最後執行。安裝 node_exporter 後必須跑一次，Prometheus 才會認識新的 target。
