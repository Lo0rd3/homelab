# Backup-01

`backup-01` is the central Debian 12 Restic backup VM. Terraform creates its
single 40 GB VM disk; Ansible configures collection, Restic, the timer, and the
restricted source export account. It collects the approved exports from
`adguard-01`, `proxy-01`, `monitoring-01`, and `vaultwarden-01`.

## 1. Prerequisites and operator-managed inputs

The tracked contracts are:

- `terraform/environments/homelab/terraform.tfvars.example`
- `ansible/inventories/homelab/host_vars/backup-01.yml`
- `ansible/inventories/homelab/host_vars/adguard-01.yml`

Before applying Ansible, provide these **untracked** values from an external
secret source:

- `backup_orchestrator_b2_account_id`
- `backup_orchestrator_b2_account_key`
- `backup_orchestrator_restic_password`
- `backup_orchestrator_ssh_private_key`
- `backup_source_export_central_public_key`

The role writes the first four to root-only files on `backup-01`:

```text
/etc/homelab-backup/secrets/backup-runtime.conf
/etc/homelab-backup/secrets/restic-password
/etc/homelab-backup/secrets/id_ed25519
```

The tracked inventory and Terraform example assign `backup-01` the managed
address `192.168.1.4`; keep any address changes synchronized across Terraform,
inventory, monitoring targets, and source-export allowlists. Replace the B2
bucket placeholder before applying. Verify each source host's SSH host key out
of band and record its pin in `backup_orchestrator_known_hosts`; Ansible writes
the managed file at `/etc/homelab-backup/known_hosts`, which collection uses
with strict host-key checking.

Never commit the inputs above, generated secret files, source key material, or
exported files. Supply credentials, private keys, and password hashes only
through untracked external variables (for example, `homelab-backup-secrets.yml`).

## 2. Provision and apply

Run Terraform first, then configure the backup VM and its source export.

```bash
cd terraform/environments/homelab
terraform fmt -check
terraform validate
source ../../../.env
terraform plan
terraform apply

cd ../../../ansible
ansible-playbook playbooks/backup.yml --syntax-check
ansible-playbook playbooks/backup.yml -e @../homelab-backup-secrets.yml
```

The default timer is `*-*-* 02:00:00`. It runs
`homelab-backup.service` as root with a one-hour execution limit. SSH collection
uses a 15-second connection timeout and ends an unresponsive transfer after
three 30-second keepalive intervals.

## 3. Operation and validation

Run one backup manually and inspect its result:

```bash
ssh debian@backup-01
sudo systemctl start homelab-backup.service
sudo systemctl status homelab-backup.service --no-pager
sudo journalctl -u homelab-backup.service -n 100 --no-pager
sudo systemctl list-timers homelab-backup.timer
sudo cat /var/lib/node_exporter/textfile_collector/homelab_backup.prom
```

The runner atomically replaces the textfile after every target result while
retaining success and failure timestamp series for every configured target.
Confirm Prometheus can scrape the assigned `backup-01:9100` address and that
each target label, including `target="vaultwarden-01"`, is visible in the
textfile metric with a current success timestamp and no newer failure timestamp.

The runner reads the root-only B2 credential file as data; it never sources or
executes it. Run the scheduled job to validate its credential and archive
contracts. Do not manually `source` that file. Repository inspection is a live
operation and requires an operator-approved credential handoff outside Git.

Run `restic check` against `b2:<bucket>:homelab/vaultwarden-01` through the
same approved credential handoff. It reads repository data and may take time or
incur B2 access cost.

## 4. Trust boundary and backup contents

`backup-01` connects as the non-interactive `homelab-backup` source account.
Password and keyboard-interactive authentication are disabled; its one authorized
key is restricted to source address `192.168.1.4`, forces exactly
`homelab-backup-export`, and uses OpenSSH `restrict` to disable PTY, agent
forwarding, port forwarding, X11 forwarding, user rc files, and arbitrary
commands or paths. The forced command alone runs through tightly scoped sudo.

Each source exports only its fixed, root-readable files:

- required: `/etc/adguardhome/AdGuardHome.yaml`
- optional: `/var/lib/adguardhome/data/leases.json`
- `proxy-01`: required matched pair `/etc/nginx/secrets/idios.crt` and
  `/etc/nginx/secrets/idios.key`
- `monitoring-01`: required `/etc/monitoring/secrets/grafana_admin_password`
- `vaultwarden-01`: a fixed `vaultwarden-data.tar` containing the complete,
  quiesced `/opt/vaultwarden/data` tree; `/etc/vaultwarden/secrets.env` is
  excluded

`monitoring-01` does not export Prometheus, Grafana, or Alertmanager
application data. Those live data directories remain excluded until a
consistent snapshot or quiesce design exists.

The source streams a fixed tar archive containing `manifest`, `files`, and
`checksums.sha256`. The collector rejects unsafe archive paths, non-regular
payload entries, malformed manifests, undeclared files, and checksum failures
before uploading. Each target has an independent B2/Restic repository prefix:

- `adguard-01`: `homelab/adguard-01`
- `proxy-01`: `homelab/proxy-01`
- `monitoring-01`: `homelab/monitoring-01`
- `vaultwarden-01`: `homelab/vaultwarden-01`

All targets, including `vaultwarden-01`, retain 7 daily, 4 weekly, 12 monthly,
and 2 yearly snapshots.


## 5. Failures and staging

Staging is root-only under `/var/lib/homelab-backup/staging`. Collection,
archive-validation, manifest-validation, and upload failures leave that target's
unique staging directory for diagnosis. Inspect it only as root, then remove it
after investigation:

```bash
sudo find /var/lib/homelab-backup/staging -maxdepth 1 -mindepth 1 -type d -ls
sudo rm -rf -- /var/lib/homelab-backup/staging/<failed-target-directory>
```

Immediately after Restic successfully creates a snapshot, staging is removed
before retention/pruning runs. If the subsequent retention/prune command fails,
the snapshot staging directory is still removed, even though the service fails.
A failed target also stops the current run, so later configured targets are not
attempted. Retry the service after fixing the cause and inspect the journal and
the failure metric first.

The textfile collector retains a simultaneous success and failure timestamp
series for every configured target. Prometheus derives per-target backup age
and failure-state recording rules from those series.

## 6. Restore scope

Restore only to a protected temporary directory on `backup-01`; copy validated
files to the source host over an authenticated administrator channel. Do not
place Restic credentials or restored files in Git. Use the host-specific
procedures in `docs/runbooks/adguard-01.md`, `docs/runbooks/proxy-01.md`, and
`docs/runbooks/monitoring-01.md`. For Vaultwarden, use
`docs/runbooks/vaultwarden-migration.md`: validate the isolated SQLite copy with
both `PRAGMA integrity_check` (only `ok`) and `PRAGMA foreign_key_check` (no
rows) before installing it.

For a complete or junior-friendly service recovery procedure, use
`docs/runbooks/manual-recovery.md`. It includes the approved external credential
handoff, restored-path discovery, and manifest/checksum validation.

## 7. Current limits

- `backup-01` uses the managed address declared in inventory. The B2 bucket and
  all credentials remain operator-managed inputs outside Git.
- The tracked configuration does not prove that a backup, `restic check`, or
  replacement-guest restore has completed. Record successful live validation
  and snapshot identifiers only in the operator-managed backup inventory.
- The initial zero success timestamp for a target that has never completed is
  intentionally stale until its first successful backup.
- Backup alerting requires rendered-rule validation with `promtool` after the
  monitoring playbook is applied. Until that check succeeds, check backup
  service status and textfile metrics manually.

## 8. Related docs

- `docs/runbooks/adguard-01.md` for AdGuard recovery
- `docs/runbooks/manual-recovery.md` for canonical full-platform recovery
- `docs/runbooks/platform-operations.md` for repo-wide apply order
