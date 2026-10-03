# AdGuard-01

This is the main operations runbook for `adguard-01`.

This repo's current AdGuard flow is **restore-based**, not a blank first-run wizard flow.

That means this runbook assumes I have:
- Terraform create the Alpine LXC
- backup files staged on the Proxmox host
- Ansible perform the one-time bootstrap and restore
- Ansible maintain the steady-state config after that

The tracked configuration documents the recovery procedure only; it does not
attest that a backup or replacement-guest restore has completed. Record live
backup and restore validation in the operator-managed backup inventory.

## 1. Current tracked state

- LXC hostname `adguard-01`
- IP `192.168.1.252/24`
- gateway `192.168.1.254`
- Alpine LXC
- AdGuard Home running on the production IP
- `node_exporter` exposed on `192.168.1.252:9100`

## 2. Truth sources

Use these files as tracked source of truth:
- `terraform/environments/homelab/terraform.tfvars.example`
- `ansible/playbooks/adguard.yml`
- `ansible/playbooks/site.yml`
- `ansible/inventories/homelab/hosts.yml`
- `ansible/inventories/homelab/host_vars/adguard-01.yml`
- `ansible/inventories/homelab/host_vars/prox.yml`
- `ansible/roles/adguard/defaults/main.yml`
- `ansible/roles/proxmox_host_file_exports/defaults/main.yml`

## 3. Prerequisites and manual inputs

Before I run the bootstrap playbook, I need these files on `prox`:

- `/root/AdGuardHome.yaml`
- `/root/leases.json`

These are staged into the LXC by the Proxmox host step before the AdGuard role starts.

### Restore-state backup contract

These files are external operational state, not tracked repository inputs. Keep
the authoritative backup in an operator-managed, access-controlled backup
location; `/root/AdGuardHome.yaml` and `/root/leases.json` on `prox` are only
the staging copies consumed by the restore playbook.

- `AdGuardHome.yaml` is the configuration restore artifact.
- `leases.json` is runtime DHCP lease state; restore it only when preserving
  existing leases is required.
- Record the backup location, backup time, and source host in the operator's
  backup inventory. Do not add either file to Git or to Ansible defaults.
- Before a rebuild, compare the staged files with the selected backup using a
  checksum and confirm they are current enough for the intended recovery.
- Protect both files as secrets: limit access to root and transfer them only
  over an authenticated channel.

If no valid backup exists, do not treat this as a normal restore. Rebuild
AdGuard Home as a new configuration and plan the DHCP cutover separately; the
old lease state cannot be recreated from this repository.

I also need a local SSH public key ready for the one-time bootstrap command, for example:

```bash
ls ~/.ssh/id_ed25519.pub
```

When managed DNS rewrites are configured, the untracked repository-root `.env`
must also provide `ADGUARD_ADMIN_USERNAME` and `ADGUARD_ADMIN_PASSWORD` from the
approved secret source. They authenticate the controller API and must not be
committed.

## 4. Terraform checks

From `terraform/environments/homelab`:

```bash
terraform fmt -check
terraform validate
```

## 5. Provision or update the LXC

```bash
source ../../../.env
terraform plan
terraform apply
```

## 6. Ansible checks

From `ansible/`:

```bash
ansible-playbook playbooks/adguard.yml --syntax-check
ansible-playbook playbooks/site.yml --syntax-check
```

## 7. Apply flow

### Run the one-time bootstrap and restore flow

Use this on a fresh `adguard-01` after Terraform creates the LXC:

```bash
adguard_ssh_bootstrap_public_key="$(ssh-keygen -y -f "$HOME/.ssh/id_ed25519")"
sh ./run-playbook.sh playbooks/adguard.yml --limit prox,adguard-01 \
  --extra-vars "{\"adguard_ssh_bootstrap_public_key\":\"${adguard_ssh_bootstrap_public_key}\"}"
```

Use JSON extra-vars so Ansible receives the complete SSH public-key line as one
value. Passing `-e key=<public key>` splits at spaces and leaves the fresh LXC
with an unusable `authorized_keys` file. The wrapper loads the untracked `.env`
that supplies controller credentials when DNS rewrites are managed.

This flow does all of these steps:
- stages `AdGuardHome.yaml` and `leases.json` from the Proxmox host into the LXC
- bootstraps SSH access inside the fresh Alpine LXC
- installs Python 3 for Ansible modules
- installs and configures AdGuard Home
- restores the tracked config and runtime lease state
- installs and starts `node_exporter`

### Apply steady-state config on later runs

After the host has already been bootstrapped, use the normal site playbook path:

```bash
ansible-playbook playbooks/site.yml --limit adguard-01
```

Use the bootstrap playbook again only when I am rebuilding a fresh LXC or repeating the restore-based migration flow.

## 8. Validation

### Check SSH and basic reachability

```bash
ssh root@192.168.1.252
ping -c 3 192.168.1.254
```

### Check AdGuard service and config

```bash
rc-service AdGuardHome status
/opt/AdGuardHome/AdGuardHome --config /etc/adguardhome/AdGuardHome.yaml --work-dir /var/lib/adguardhome --check-config
```

I expect:
- AdGuard Home service is running
- config check passes

### Check web UI and DNS on production IP

From another host on the LAN:

```bash
curl -I http://192.168.1.252
nslookup example.org 192.168.1.252
```

### DHCP checks

At this point, `adguard-01` should be the active DHCP server for this tracked service state.

I expect:
- `adguard-01` answers on the final production IP
- clients can renew or receive leases normally

### Monitoring checks

From `monitoring-01`:

```bash
curl -fsS http://192.168.1.252:9100/metrics >/dev/null
```

In Prometheus, I expect:
- `192.168.1.252:9100` is up

In Grafana, I expect:
- host metrics for `adguard-01` are visible

## 9. Recovery

### Restore from the central backup pilot

Use this only after `backup-01` has a validated `adguard-01` snapshot. The
backup stores `AdGuardHome.yaml` and, when present, `data/leases.json` with an
export manifest and SHA-256 checksums.

On `backup-01`, restore the desired tagged snapshot to a root-only temporary
directory. Do not copy the secret files or the entire staging directory to
`adguard-01`.

```bash
sudo -i
read -rsp 'B2 account ID: ' B2_ACCOUNT_ID; echo
read -rsp 'B2 account key: ' B2_ACCOUNT_KEY; echo
read -rsp 'B2 bucket: ' B2_BUCKET; echo
export B2_ACCOUNT_ID B2_ACCOUNT_KEY B2_BUCKET
export RESTIC_PASSWORD_FILE=/etc/homelab-backup/secrets/restic-password
export RESTIC_CACHE_DIR=/var/lib/homelab-backup/cache
repo="b2:${B2_BUCKET}:homelab/adguard-01"
restore_dir=$(mktemp -d /root/adguard-restore.XXXXXX)
restic -r "$repo" snapshots --tag adguard-01
restic -r "$repo" restore latest --tag adguard-01 --target "$restore_dir"
manifest=$(find "$restore_dir" -type f -name manifest -print -quit)
test -n "$manifest"
payload=$(dirname "$manifest")
(cd "$payload" && sha256sum -c --strict checksums.sha256)
```

Obtain the values from the approved external secret source; do not source
`backup-runtime.conf`, which the runner parses as data. If selecting an older
snapshot, replace `latest` with its snapshot ID. Stop if the manifest is missing
or any checksum fails. Restic preserves the original staging path below
`"$restore_dir"`, so locate files before copying them:

```bash
find "$restore_dir" -type f \( -name AdGuardHome.yaml -o -name leases.json \) -print
```

`leases.json` is optional, so its absence is valid when the snapshot's `files`
list does not declare it.

Copy the validated files to a root-only temporary location on `adguard-01`,
then stop AdGuard before replacing state:

```bash
rc-service AdGuardHome stop
install -o root -g root -m 0600 <restored-AdGuardHome.yaml> /etc/adguardhome/AdGuardHome.yaml
# Only when present in the validated export and lease recovery is required:
install -o root -g root -m 0600 <restored-leases.json> /var/lib/adguardhome/data/leases.json
/opt/AdGuardHome/AdGuardHome --config /etc/adguardhome/AdGuardHome.yaml --work-dir /var/lib/adguardhome --check-config
rc-service AdGuardHome start
rc-service AdGuardHome status
```

Validate DNS and DHCP behavior as in section 8 after starting the service. Keep
the restored files protected and remove the temporary restore directory after
the recovery is accepted. This procedure is documented but has not been run
against a live repository or replacement guest.

If bootstrap fails on a fresh LXC:
- confirm `/root/AdGuardHome.yaml` exists on `prox`
- confirm `/root/leases.json` exists on `prox`
- verify both staging files against the selected backup checksum before retrying
- confirm the SSH public key file exists locally
- rerun `playbooks/adguard.yml` with the wrapper and JSON extra-vars command
  from section 7

If AdGuard does not start:
- re-check `/etc/adguardhome/AdGuardHome.yaml`
- rerun the config check command
- inspect restored data under `/var/lib/adguardhome`

If DNS is wrong on the production IP:
- confirm `AdGuardHome.yaml` still matches `192.168.1.252`

If monitoring is missing:
- check the `node-exporter` service on `adguard-01`
- check Prometheus target health for `192.168.1.252:9100`

## 10. Related docs

- `docs/runbooks/platform-operations.md` for repo-wide apply order
- `docs/runbooks/manual-recovery.md` for full-platform or service recovery
- `ansible/README.md` for playbook entrypoints
