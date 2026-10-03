# Monitoring-01

This is the main operations runbook for `monitoring-01`.

`monitoring-01` is the VM that runs the homelab monitoring stack.

The monitoring administrative endpoints are published only on `127.0.0.1`.
Prometheus, Grafana, Alertmanager, node-exporter, and cAdvisor must not be
reachable on the LAN. Any future external access requires an approved
reverse-proxy path; do not widen the Compose port bindings.

## 1. Current tracked state

I expect this host to be:
- VM hostname `monitoring-01`
- static address `192.168.1.87`
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

If I need to create or rotate the Grafana admin password, I must provide it as
an untracked external secret at runtime. Never commit credentials, private
keys, or password hashes.

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

I expect the VM to come up as `monitoring-01` at `192.168.1.87` and be
reachable by Ansible.

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
docker compose --env-file monitoring.env -f compose.yml config
```

In the rendered configuration, each published port must begin with
`127.0.0.1:`. The final command is intentionally not quiet so the bindings can
be reviewed without starting or changing containers.

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

Confirm these endpoints are not listening on `192.168.1.87` or any other LAN
address. cAdvisor runs without privileged mode or `/dev/kmsg`; its read-only
mounts and Docker socket are limited to the host data needed for container
metrics.

### Check Prometheus and Grafana

In Prometheus:
- check that the managed homelab targets I expect today are up
- check that rules are loaded
- check that `backup-01` (`192.168.1.4:9100`) is up under the `node_exporter`
  job
- check that `monitoring-01` (`192.168.1.87:9100`) is up under the
  `node_exporter` job
- query `homelab_backup_last_success_timestamp_seconds` and
  `homelab_backup_last_failure_timestamp_seconds` to confirm that backup status
  metrics carry a `target` label

If I still have extra static scrape targets configured outside the current tracked inventory, I should treat those separately and not confuse them with a monitoring stack deployment failure.

### Validate rendered Prometheus configuration and rules

After applying the monitoring playbook, validate the rendered configuration on
`monitoring-01`. `promtool` is available in the Prometheus container, so this
does not require installing another package on the VM:

```bash
ssh debian@monitoring-01 \
  'docker compose --env-file /opt/compose/monitoring/monitoring.env \
  -f /opt/compose/monitoring/compose.yml exec -T prometheus \
  promtool check config /etc/prometheus/prometheus.yml'
```

I also check that Prometheus accepted the active configuration:

```bash
ssh debian@monitoring-01 'curl -fsS http://127.0.0.1:9090/-/healthy'
```

### Backup status alert contract

`backup-01` exposes its root-owned textfile metric through node_exporter. The
orchestrator atomically replaces the file after every target result while
retaining current success and failure series for every `target=<target-name>`:

- `homelab_backup_last_success_timestamp_seconds` records a successful snapshot.
- `homelab_backup_last_failure_timestamp_seconds` records a failed run.

`monitoring_backup_targets` declares every configured backup target. Do not rely
on backup alerts until the rendered rules pass `promtool` validation. Check the
textfile metrics and backup service manually until that check succeeds.

The metric file, Prometheus configuration, and alert annotations must never
contain B2 credentials, Restic passwords, SSH private keys, or exported data.

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

## 9. Backup and restore scope

`backup-01` stores only the required Grafana password file:

- `/etc/monitoring/secrets/grafana_admin_password` → `grafana_admin_password`
- Restic prefix: `homelab/monitoring-01`

Prometheus, Grafana, and Alertmanager application data are explicitly excluded.
Their live data directories must not be copied until a consistent snapshot or
quiesce design exists.

After a backup has run, validate and restore only to a protected temporary
directory on `backup-01`:

```bash
ssh debian@backup-01
sudo -i
read -rsp 'B2 account ID: ' B2_ACCOUNT_ID; echo
read -rsp 'B2 account key: ' B2_ACCOUNT_KEY; echo
read -rsp 'B2 bucket: ' B2_BUCKET; echo
export B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_BUCKET
export RESTIC_PASSWORD_FILE=/etc/homelab-backup/secrets/restic-password
repo="b2:${B2_BUCKET}:homelab/monitoring-01"
restore_dir=$(mktemp -d /root/restore-monitoring-01.XXXXXX)
restic -r "$repo" snapshots --tag monitoring-01
restic -r "$repo" restore <snapshot-id> --target "$restore_dir"
manifest=$(find "$restore_dir" -type f -name manifest -print -quit)
test -n "$manifest"
payload=$(dirname "$manifest")
(cd "$payload" && sha256sum -c --strict checksums.sha256)
grafana_password=$(find "$restore_dir" -type f -name grafana_admin_password -print -quit)
test -n "$grafana_password"
```

Obtain credentials from the approved external secret source; do not source
`backup-runtime.conf`, which the runner parses as data. Restic preserves the
original staging path below `"$restore_dir"`, so use `"$grafana_password"`
rather than an assumed path. Compare the restored file before installing it as
root at `/etc/monitoring/secrets/grafana_admin_password`; do not put the value
in Git or logs. The tracked repository does not attest to a completed backup or
restore; record any live validation in the operator-managed backup inventory.

## 10. Recovery

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

## 11. Related docs

- `docs/runbooks/platform-operations.md` for repo-wide apply order
- `docs/runbooks/manual-recovery.md` for full-platform or service recovery
- `ansible/README.md` for playbook entrypoints
