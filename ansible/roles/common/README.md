# common

安裝基礎套件並套用系統設定，所有機器初始化時都會執行。

## 執行內容

- 安裝基礎套件（vim、net-tools、sudo、bash-completion）
- 啟用 bash-completion（系統全域）
- 部署 vim 設定（`/etc/vim/vimrc.local` 或各 OS 對應路徑）

## 變數

| 變數 | 說明 |
|------|------|
| `common_packages_debian` | Debian/Ubuntu 安裝的套件清單 |
| `common_packages_redhat` | RedHat/CentOS 安裝的套件清單 |
| `common_packages_alpine` | Alpine 安裝的套件清單 |

需要新增套件時，在 `defaults/main.yml` 對應的清單加入即可。

## 支援的 OS

| OS Family | 套件管理 |
|-----------|---------|
| Debian / Ubuntu | apt |
| RedHat / CentOS | dnf |
| Alpine | apk |

## 執行方式

通常透過 `init.yml` 執行，不單獨跑：

```bash
ansible-playbook init.yml --limit <hostname>
```

若需要單獨套用：

```bash
ansible-playbook site.yml --limit <hostname> --tags common
```
