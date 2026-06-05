# Lab Projects

Personal infrastructure lab — a collection of self-hosted service configs, automation scripts, and homelab experiments.

## Projects

| Directory | Description |
|-----------|-------------|
| `ansible` | Ansible roles and playbooks for provisioning lab hosts |
| `ci-templates` | Reusable GitLab CI job templates |
| `gitlab` | GitLab self-hosted deployment config |
| `k8s-lab` | Kubernetes cluster setup with Vagrant |
| `kubevirt-lab` | KubeVirt VM management on Kubernetes |
| `monitor` | Monitoring stack: Prometheus, Grafana, Loki, Alertmanager |
| `ollama` | Ollama + Open WebUI + n8n stack |
| `openldap` | OpenLDAP directory service deployment |
| `openstack-lab` | OpenStack lab environment |
| `psql-ha` | PostgreSQL HA with Patroni (Docker-based) |
| `psql-ha-manual` | PostgreSQL HA with Patroni (manual setup) |
| `ztp` | Zero-touch provisioning with MAAS and NetBox |

## Usage

Each directory is self-contained. See the `README.md` inside each project for setup instructions.

Most projects use Docker Compose. Copy `.env.example` to `.env` and fill in your values before starting.
