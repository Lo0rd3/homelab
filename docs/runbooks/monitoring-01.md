# Monitoring-01

This is the main operations runbook for `monitoring-01`.

`monitoring-01` is the VM that runs the homelab monitoring stack.

## 1. Current tracked state

I expect this host to be:
- VM hostname `monitoring-01`
- reachable over Ansible as user `debian`
- Docker host for the monitoring stack
- running Prometheus, Grafana, Alertmanager, node-exporter, and cAdvisor

## 2. Truth sources

Use these files as the tracked source of truth:
- `terraform/environments/homelab/terraform.tfvars.example`
- `ansible/playbooks/monitoring.yml`
- `ansible/playbooks/site.yml`
- `ansible/inventories/homelab/hosts.yml`
- `ansible/inventories/homelab/host_vars/monitoring-01.yml`
- `ansible/inventories/homelab/group_vars/monitoring.yml`
- `ansible/roles/monitoring/defaults/main.yml`

## 3. Prerequisites and manual inputs

If I need to create or rotate the Grafana admin password, I must provide it as an external secret at runtime.

If the secret file already exists on the host, I do not need to pass the password again.

## 4. Terraform checks

From `terraform/environments/homelab`:

```bash
terraform fmt -check
terraform validate
```

## 5. Provision or update the VM

```bash
source ../../../.env
terraform plan
terraform apply
```

I expect the VM to come up as `monitoring-01` and be reachable by Ansible.

## 6. Ansible checks

From `ansible/`:

```bash
ansible-playbook playbooks/monitoring.yml --syntax-check
ansible-playbook playbooks/site.yml --syntax-check
```

## 7. Apply flow

If I need to create or rotate the Grafana admin password, I can pass it at runtime:

```bash
ansible-playbook playbooks/monitoring.yml --limit monitoring-01 \
  -e "monitoring_grafana_admin_password=replace-me-with-a-real-password"
```

If the secret file already exists and I am not changing it, I can run:

```bash
ansible-playbook playbooks/monitoring.yml --limit monitoring-01
```

## 8. Validation

### Check Docker Compose on the VM

```bash
ssh debian@monitoring-01
cd /opt/compose/monitoring
docker compose --env-file monitoring.env -f compose.yml config -q
docker compose --env-file monitoring.env -f compose.yml ps
```

I expect these services to be running:
- `prometheus`
- `grafana`
- `alertmanager`
- `node-exporter`
- `cadvisor`

### Check local service endpoints on the VM

```bash
curl -fsS http://127.0.0.1:9090/-/healthy
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS http://127.0.0.1:9093/-/healthy
curl -fsS http://127.0.0.1:9100/metrics >/dev/null
curl -fsS http://127.0.0.1:8080/healthz
```

### Check Prometheus and Grafana

In Prometheus:
- check that the managed homelab targets I expect today are up
- check that rules are loaded

If I still have extra static scrape targets configured outside the current tracked inventory, I should treat those separately and not confuse them with a monitoring stack deployment failure.

In Grafana:
- log in with the configured admin user
- confirm the Prometheus datasource is there
- confirm the default dashboard is visible

### Check secret and config files

```bash
sudo ls -l /etc/monitoring/secrets/grafana_admin_password
ls -l /opt/monitoring/config/prometheus
ls -l /opt/monitoring/config/alertmanager
ls -l /opt/monitoring/config/grafana/provisioning
```

## 9. Recovery

If a service is down:

```bash
cd /opt/compose/monitoring
docker compose --env-file monitoring.env -f compose.yml ps
docker compose --env-file monitoring.env -f compose.yml logs --tail=100
```

If Grafana auth is wrong:
- check `/etc/monitoring/secrets/grafana_admin_password`
- rerun the playbook with a new `monitoring_grafana_admin_password`

If monitoring targets are missing:
- check Prometheus target status
- check local service health endpoints
- check whether node exporter or cAdvisor is still running

## 10. Related docs

- `docs/runbooks/platform-operations.md` for repo-wide apply order
- `ansible/README.md` for playbook entrypoints
