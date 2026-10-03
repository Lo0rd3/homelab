# Manual recovery from Backblaze B2

This is the human-run fallback for recovering the homelab from Restic backups in
Backblaze B2. Use it until the automated recovery workflow is implemented and
tested.

The Git repository recreates guests and service configuration. B2 restores only
the service state exported by `backup-01`. This procedure has not yet been
proved by a full live recovery exercise.

## Read this first

- Run commands from a trusted administrator workstation or through an
  authenticated SSH session.
- Do not put passwords, private keys, restored data, `terraform.tfvars`, or
  secret variable files in Git, shell history, or terminal recordings.
- Stop immediately if a checksum, database validation, Terraform plan, or
  service health check fails. Do not continue to the next step.
- `backup-01` creates repositories in this form:

  ```text
  b2:<bucket>:homelab/<service>
  ```

  Use the colon-separated form in this runbook. It matches the tracked backup
  runner. Do not use the older slash-separated examples elsewhere in the docs.

## What B2 can restore

| Service | B2 recovery scope | Not in B2 |
| --- | --- | --- |
| AdGuard | `AdGuardHome.yaml`; optional DHCP `leases.json` | Nothing can recreate missing DHCP leases. |
| Proxy | Local `idios.crt` and `idios.key` | Other TLS material unless handled by ACME/DuckDNS. |
| Vaultwarden | Quiesced `/opt/vaultwarden/data` archive | `/etc/vaultwarden/secrets.env`. |
| Monitoring | Grafana admin-password file | Prometheus, Grafana, and Alertmanager application data. |
| Tailscale | Nothing | Node enrollment, auth key, and admin approvals. |

## Prerequisites checklist

Before beginning a full rebuild, confirm that all of these are available outside
Git:

- [ ] A Proxmox host with the `vmbr0` network bridge, required storage, and the
  Debian VM and Alpine/Debian LXC templates referenced by Terraform.
- [ ] Repository-root `.env`, including the Proxmox API token.
- [ ] Real `terraform.tfvars`, based on
  `terraform/environments/homelab/terraform.tfvars.example`.
- [ ] `homelab-backup-secrets.yml` containing the B2 bucket, B2 account ID/key,
  Restic password, backup SSH private key, and source-export public key.
- [ ] Administrator SSH key at `$HOME/.ssh/id_ed25519` for fresh AdGuard LXC
  bootstrap.
- [ ] Untracked repository-root `.env` values `ADGUARD_ADMIN_USERNAME` and
  `ADGUARD_ADMIN_PASSWORD` when managed AdGuard DNS rewrites are configured.
- [ ] Vaultwarden `/etc/vaultwarden/secrets.env`.
- [ ] A new Tailscale auth key in the protected external extra-vars file and
  access to the Tailscale admin console.
- [ ] DuckDNS/TLS inputs if proxy certificates must be reissued instead of
  restored.

## Part 1: rebuild from zero

### Step 1: recreate guest infrastructure

From the repository checkout:

```bash
cd terraform/environments/homelab
terraform fmt -check
terraform validate
source ../../../.env
terraform plan
```

Read the plan. It should create the expected VMs and LXCs only. If it proposes
unexpected changes, stop and investigate.

When the plan is correct:

```bash
terraform apply
```

Expected result: Terraform creates `backup-01`, `monitoring-01`, `proxy-01`,
`vaultwarden-01`, `tailscale-01`, and `adguard-01` with the configured IPs.

### Step 2: configure only the backup VM

`backup.yml` also configures source-export accounts. On a zero-state rebuild,
configure `backup-01` alone first so it can retrieve B2 snapshots before the
other guests are ready.

```bash
cd ../../../ansible
ansible-playbook playbooks/backup.yml --syntax-check
ansible-playbook playbooks/backup.yml --limit backup-01 \
  -e @../homelab-backup-secrets.yml
```

Expected result: `backup-01` has Restic installed and its root-only runtime
credential files created. Do not manually `source`
`/etc/homelab-backup/secrets/backup-runtime.conf`; it is an application data
file, not a shell script.

### Step 3: prepare a Restic shell on `backup-01`

Log in and become root:

```bash
ssh debian@backup-01
sudo -i
```

Obtain the B2 account ID, B2 account key, bucket name, and Restic password from
the approved external secret source. Enter them into the current root shell
without printing them:

```bash
read -rsp 'B2 account ID: ' B2_ACCOUNT_ID; echo
read -rsp 'B2 account key: ' B2_ACCOUNT_KEY; echo
read -rsp 'B2 bucket: ' B2_BUCKET; echo
export B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_BUCKET
export RESTIC_PASSWORD_FILE=/etc/homelab-backup/secrets/restic-password
export RESTIC_CACHE_DIR=/var/lib/homelab-backup/cache
```

Do not continue until a snapshot list works. This is the first proof that the
credentials, password file, and repository path are correct:

```bash
repo="b2:${B2_BUCKET}:homelab/adguard-01"
restic -r "$repo" snapshots --tag adguard-01
```

Expected result: Restic prints one or more snapshots. If it does not, stop; do
not initialize a repository or guess a different path.

### Step 4: restore and bootstrap AdGuard

On `backup-01`, select the desired snapshot. `latest` is acceptable only when
the most recent backup is known to be the desired recovery point.

```bash
repo="b2:${B2_BUCKET}:homelab/adguard-01"
restore_dir=$(mktemp -d /root/adguard-restore.XXXXXX)
restic -r "$repo" snapshots --tag adguard-01
restic -r "$repo" restore latest --tag adguard-01 --target "$restore_dir"
manifest=$(find "$restore_dir" -type f -name manifest -print -quit)
test -n "$manifest"
payload=$(dirname "$manifest")
(cd "$payload" && sha256sum -c --strict checksums.sha256)
```

Expected result: the checksum command reports only `OK` results. Locate the
restored files. Restic retains its original staging path under the restore
directory, so they are not necessarily at the directory root:

```bash
find "$restore_dir" -type f \( -name AdGuardHome.yaml -o -name leases.json \) -print
```

Copy `AdGuardHome.yaml` and, only if present and required, `leases.json` through
an authenticated administrator channel to `prox` as:

```text
/root/AdGuardHome.yaml
/root/leases.json
```

From the administrator workstation, bootstrap and configure the fresh LXC:

```bash
cd /path/to/homelab-repo/ansible
adguard_ssh_bootstrap_public_key="$(ssh-keygen -y -f "$HOME/.ssh/id_ed25519")"
sh ./run-playbook.sh playbooks/adguard.yml --limit prox,adguard-01 \
  --extra-vars "{\"adguard_ssh_bootstrap_public_key\":\"${adguard_ssh_bootstrap_public_key}\"}"
```

The wrapper loads the untracked repository-root `.env`. If managed DNS rewrites
are configured, it must contain `ADGUARD_ADMIN_USERNAME` and
`ADGUARD_ADMIN_PASSWORD`; obtain both from the approved secret source.

Validate from a LAN host:

```bash
ssh root@adguard-01 'rc-service AdGuardHome status'
curl -I http://192.168.1.252
nslookup example.org 192.168.1.252
```

Expected result: AdGuard is running and answers DNS requests. Confirm DHCP
client renewals separately before depending on restored leases.

### Step 5: configure Tailscale

Create a protected, untracked external extra-vars file; do not put the auth key
on the command line or in the repository:

```bash
install -d -m 0700 "$HOME/.config/homelab"
install -m 0600 /dev/null "$HOME/.config/homelab/tailscale-recovery-secrets.yml"
```

Edit `$HOME/.config/homelab/tailscale-recovery-secrets.yml` from the approved
secret source:

```yaml
tailscale_auth_key: <new-tailscale-auth-key>
```

Run the dedicated playbook with that file:

```bash
cd /path/to/homelab-repo/ansible
ansible-playbook playbooks/tailscale.yml --limit prox,tailscale-01 \
  --extra-vars "@$HOME/.config/homelab/tailscale-recovery-secrets.yml"
```

In the Tailscale admin console, approve:

- subnet route `192.168.1.0/24`;
- exit-node capability;
- the replacement node enrollment and key-expiry policy.

Validate:

```bash
ssh root@tailscale-01 'tailscale status && tailscale ip -4'
```

### Step 6: restore the proxy certificate pair and configure Nginx

On `backup-01`, restore both files from the same snapshot:

```bash
repo="b2:${B2_BUCKET}:homelab/proxy-01"
restore_dir=$(mktemp -d /root/proxy-restore.XXXXXX)
restic -r "$repo" snapshots --tag proxy-01
restic -r "$repo" restore latest --tag proxy-01 --target "$restore_dir"
manifest=$(find "$restore_dir" -type f -name manifest -print -quit)
test -n "$manifest"
payload=$(dirname "$manifest")
(cd "$payload" && sha256sum -c --strict checksums.sha256)
crt=$(find "$restore_dir" -type f -name idios.crt -print -quit)
key=$(find "$restore_dir" -type f -name idios.key -print -quit)
test -n "$crt" && test -n "$key"
```

Restic retains the original staging path under `"$restore_dir"`; use `"$crt"`
and `"$key"`, not assumed paths at the restore-directory root. Copy both files
from the same validated snapshot to `proxy-01`, then install them as root before
running the proxy playbook:

```bash
sudo install -d -o root -g root -m 0700 /etc/nginx/secrets
sudo install -o root -g root -m 0640 <restored-idios.crt> /etc/nginx/secrets/idios.crt
sudo install -o root -g root -m 0600 <restored-idios.key> /etc/nginx/secrets/idios.key
```

The B2 proxy backup contains only the local `idios` certificate pair. It does
not contain the DuckDNS certificate pair. If `acme_duckdns_enabled` is true,
place `DUCKDNS_TOKEN` in the untracked repository-root `.env` from the approved
secret source before running the proxy playbook; this lets the ACME role issue
or renew the DuckDNS certificate. See `vaultwarden-duckdns-tls.md` for the
required inventory values.

Configure and validate the proxy. Use the wrapper so it passes untracked `.env`
values to Ansible:

```bash
cd /path/to/homelab-repo/ansible
sh ./run-playbook.sh playbooks/proxy.yml --limit proxy-01
ssh debian@proxy-01 'sudo nginx -t && sudo systemctl status nginx --no-pager'
```

### Step 7: configure and restore Vaultwarden

Create `/etc/vaultwarden/secrets.env` from the separately retained secret before
running the playbook. B2 does not contain this file.

```bash
cd /path/to/homelab-repo/ansible
ansible-playbook playbooks/vaultwarden.yml --limit vaultwarden-01
```

On `backup-01`, restore and validate the selected archive:

```bash
repo="b2:${B2_BUCKET}:homelab/vaultwarden-01"
sudo install -d -m 0700 /root/restore/vaultwarden-01/{snapshot,data}
restic -r "$repo" snapshots --tag vaultwarden-01
restic -r "$repo" restore latest --tag vaultwarden-01 \
  --target /root/restore/vaultwarden-01/snapshot
archive=$(find /root/restore/vaultwarden-01/snapshot -type f -name vaultwarden-data.tar -print -quit)
test -n "$archive"
manifest=$(find /root/restore/vaultwarden-01/snapshot -type f -name manifest -print -quit)
test -n "$manifest"
payload=$(dirname "$manifest")
(cd "$payload" && sha256sum -c --strict checksums.sha256)
sudo tar -C /root/restore/vaultwarden-01/data -xf "$archive"
sudo sqlite3 /root/restore/vaultwarden-01/data/data/db.sqlite3 'PRAGMA integrity_check;'
sudo sqlite3 /root/restore/vaultwarden-01/data/data/db.sqlite3 'PRAGMA foreign_key_check;'
```

Expected result: `integrity_check` prints only `ok`; `foreign_key_check` prints
no rows. If either check fails, stop.

Copy the validated `vaultwarden-data.tar` to `/root/restore/vaultwarden-data.tar`
on `vaultwarden-01`, then run:

```bash
sudo docker compose -f /opt/compose/vaultwarden/compose.yml -p vaultwarden stop
sudo mv /opt/vaultwarden/data "/opt/vaultwarden/data.pre-restore-$(date -u +%Y%m%dT%H%M%SZ)"
sudo install -d -o root -g root -m 0750 /opt/vaultwarden/data
sudo rm -f /opt/vaultwarden/data/db.sqlite3-wal
sudo tar -C /opt/vaultwarden -xf /root/restore/vaultwarden-data.tar
sudo docker compose -f /opt/compose/vaultwarden/compose.yml -p vaultwarden up -d
curl --fail --silent --show-error http://192.168.1.5:8000/alive
```

### Step 8: configure monitoring

Restore the Grafana password only if it is needed. On `backup-01`, restore and
validate it before configuring the monitoring host:

```bash
repo="b2:${B2_BUCKET}:homelab/monitoring-01"
restore_dir=$(mktemp -d /root/monitoring-restore.XXXXXX)
restic -r "$repo" snapshots --tag monitoring-01
restic -r "$repo" restore latest --tag monitoring-01 --target "$restore_dir"
manifest=$(find "$restore_dir" -type f -name manifest -print -quit)
test -n "$manifest"
payload=$(dirname "$manifest")
(cd "$payload" && sha256sum -c --strict checksums.sha256)
grafana_password=$(find "$restore_dir" -type f -name grafana_admin_password -print -quit)
test -n "$grafana_password"
```

Restic preserves the original staging path below `"$restore_dir"`; copy
`"$grafana_password"` through an authenticated administrator channel and
install it root-only at `/etc/monitoring/secrets/grafana_admin_password` on
`monitoring-01`. The monitoring application data is intentionally excluded from
B2 and must be recreated by Ansible.

```bash
cd /path/to/homelab-repo/ansible
ansible-playbook playbooks/monitoring.yml --limit monitoring-01
ssh debian@monitoring-01 \
  'docker compose --env-file /opt/compose/monitoring/monitoring.env -f /opt/compose/monitoring/compose.yml config -q'
ssh debian@monitoring-01 'curl -fsS http://127.0.0.1:9090/-/healthy'
ssh debian@monitoring-01 'curl -fsS http://127.0.0.1:3000/api/health'
ssh debian@monitoring-01 'curl -fsS http://127.0.0.1:9093/-/healthy'
```

### Step 9: re-enable and test backups

After every source service is healthy, configure backup exports on all hosts:

```bash
cd /path/to/homelab-repo/ansible
ansible-playbook playbooks/backup.yml -e @../homelab-backup-secrets.yml
```

Run one backup and check its status:

```bash
ssh debian@backup-01 'sudo systemctl start homelab-backup.service'
ssh debian@backup-01 'sudo systemctl status homelab-backup.service --no-pager'
ssh debian@backup-01 'sudo cat /var/lib/node_exporter/textfile_collector/homelab_backup.prom'
```

Recovery is complete only after all expected services are healthy and the new
backup run succeeds.

## Part 2: recover one service

Use this path when the guest still exists and only one service needs state
recovery.

### Shared restore steps

1. Log in to `backup-01` as root and prepare the Restic shell as shown in Part
   1, Step 3.
2. Set the service name and repository:

   ```bash
   service=adguard-01
   repo="b2:${B2_BUCKET}:homelab/${service}"
   restore_dir=$(mktemp -d "/root/${service}-restore.XXXXXX")
   restic -r "$repo" snapshots --tag "$service"
   ```

3. Select a snapshot ID from the list and restore it. Replace `<snapshot-id>`:

   ```bash
   restic -r "$repo" restore <snapshot-id> --target "$restore_dir"
    manifest=$(find "$restore_dir" -type f -name manifest -print -quit)
    test -n "$manifest"
    payload=$(dirname "$manifest")
   (cd "$payload" && sha256sum -c --strict checksums.sha256)
   ```

4. Do not install any file unless all checksum results are `OK`.

### AdGuard

Copy the validated files to `adguard-01`, then run there:

```bash
rc-service AdGuardHome stop
install -o root -g root -m 0600 <restored-AdGuardHome.yaml> /etc/adguardhome/AdGuardHome.yaml
# Run this only if leases.json exists in the selected snapshot and lease recovery is required.
install -o root -g root -m 0600 <restored-leases.json> /var/lib/adguardhome/data/leases.json
/opt/AdGuardHome/AdGuardHome --config /etc/adguardhome/AdGuardHome.yaml --work-dir /var/lib/adguardhome --check-config
rc-service AdGuardHome start
rc-service AdGuardHome status
```

### Proxy

Copy the validated certificate and key from the same snapshot to `proxy-01` and
install both before reloading Nginx:

```bash
sudo install -o root -g root -m 0640 <restored-idios.crt> /etc/nginx/secrets/idios.crt
sudo install -o root -g root -m 0600 <restored-idios.key> /etc/nginx/secrets/idios.key
sudo nginx -t
sudo systemctl reload nginx
curl -kI -H 'Host: proxmox.idios' https://127.0.0.1/
curl -kI -H 'Host: adguard.idios' https://127.0.0.1/
curl -kI -H 'Host: vault.idios' https://127.0.0.1/
```

### Vaultwarden

Use the validation and activation commands in Part 1, Step 7. The required
database checks are not optional. Retain the renamed pre-restore data directory
until Vaultwarden is verified by the web vault, browser extension, and mobile
client.

### Monitoring

Only `grafana_admin_password` can be restored. Copy it to `monitoring-01` and
install it with root-only access:

```bash
sudo install -o root -g root -m 0600 <restored-grafana_admin_password> \
  /etc/monitoring/secrets/grafana_admin_password
```

Then rerun the monitoring playbook and its health checks from Part 1, Step 8.

### Tailscale

There is no service state to restore from B2. Re-run the Tailscale command in
Part 1, Step 5 with a fresh auth key and approve the node, route, and exit-node
capability in the Tailscale admin console.

## Related runbooks

- `docs/runbooks/backup-01.md`
- `docs/runbooks/adguard-01.md`
- `docs/runbooks/proxy-01.md`
- `docs/runbooks/monitoring-01.md`
- `docs/runbooks/vaultwarden-migration.md`
- `docs/runbooks/tailscale-01.md`
