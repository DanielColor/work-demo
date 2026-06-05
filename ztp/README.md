# ZTP

Zero Touch Provisioning 自動裝機環境，以 MAAS 為核心，NetBox 作為 SSOT。

## 目錄結構

```
ztp/
├── maas/       # MAAS 安裝腳本與 ZTP 自動化
├── netbox/     # NetBox 安裝腳本
├── ansible/    # Ansible 相關（整理中）
└── docs/       # 流程圖與參考文件
```

## 元件

| 元件 | 說明 |
|------|------|
| [MAAS](maas/README.md) | 裸機生命週期管理，負責 PXE、commission、deploy |
| [NetBox](netbox/README.md) | 裝置資訊 SSOT，提供 hostname 與靜態 IP |

## 裝機流程

```
新機器上架 → PXE Boot → MAAS Enlistment
          → ZTP 自動 Commission → Ready
          → ZTP 查詢 NetBox（hostname + IP）
          → MAAS Deploy → Deployed
```

詳細流程圖：[`docs/maas-ztp-flow.svg`](docs/maas-ztp-flow.svg)

## 快速開始

1. 安裝 NetBox：參考 [netbox/README.md](netbox/README.md)
2. 安裝 MAAS：參考 [maas/README.md](maas/README.md)
3. 在 NetBox 建立裝置（填入 MAC、Primary IPv4、hostname）
4. 設定 ZTP cron，開始自動裝機
